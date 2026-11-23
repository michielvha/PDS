BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    function Write-TestJson {
        param ([string]$Path, $Value)
        New-Item -ItemType Directory -Path (Split-Path -Path $Path -Parent) -Force | Out-Null
        $Value | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path
    }

    function Get-CommandResult {
        param ([int]$ExitCode = 0, [string[]]$Output = @())
        [pscustomobject]@{ ExitCode = $ExitCode; Output = $Output }
    }
}

Describe 'Get-ClaudeRemoteControlStatus' {
    BeforeEach {
        $script:oldHome = $env:HOME
        $script:oldSsh = $env:SSH_CONNECTION, $env:SSH_TTY
        $env:SSH_CONNECTION = $null
        $env:SSH_TTY = $null
        $script:root = Join-Path $TestDrive ([guid]::NewGuid())
        $env:HOME = Join-Path $root 'home'
        $script:repo = (New-Item -ItemType Directory -Path (Join-Path $root 'code/vh-adlc') -Force).FullName
        $script:claude = (New-Item -ItemType File -Path (Join-Path $root 'bin/claude') -Force).FullName
        $script:configPath = Join-Path $env:HOME '.claude.json'

        Mock Get-ClaudeRcPlatform -ModuleName PDS { 'macOS' }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS { Get-CommandResult -ExitCode 1 }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'id' } { Get-CommandResult -Output '501' }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq $script:claude } { Get-CommandResult -Output '{"loggedIn": true, "email": "someone@example.com"}' }
    }

    AfterEach {
        $env:HOME = $script:oldHome
        $env:SSH_CONNECTION, $env:SSH_TTY = $script:oldSsh
    }

    It 'names the LaunchAgent after the last segment of the working directory' {
        $status = Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath $claude

        $status.Service | Should -Be 'pro.vhco.claude-remote-control.vh-adlc'
        $status.ServiceFile | Should -Be (Join-Path $env:HOME 'Library/LaunchAgents/pro.vhco.claude-remote-control.vh-adlc.plist')
        $status.Log | Should -Be (Join-Path $env:HOME 'Library/Logs/claude-remote-control-vh-adlc.log')
        $status.Installed | Should -BeFalse
        $status.Loaded | Should -BeFalse
    }

    It 'reads the running process from launchctl print' {
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'launchctl' } {
            Get-CommandResult -Output @('gui/501/pro.vhco.claude-remote-control.vh-adlc = {', "`tstate = running", "`tpid = 4242")
        }

        $status = Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath $claude

        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter {
            $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'print' -and $ArgumentList[1] -eq 'gui/501/pro.vhco.claude-remote-control.vh-adlc'
        }
        $status.Loaded | Should -BeTrue
        $status.Running | Should -BeTrue
        $status.ProcessId | Should -Be 4242
    }

    It 'asks the owner for trust and consent when neither is recorded' {
        $checks = (Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath $claude).Checks

        ($checks | Where-Object Check -EQ 'Workspace trust').Status | Should -Be 'Action'
        ($checks | Where-Object Check -EQ 'Workspace trust').Step | Should -BeLike '*run claude in*accept the workspace trust dialog*'
        ($checks | Where-Object Check -EQ 'Remote Control consent').Status | Should -Be 'Action'
        ($checks | Where-Object Check -EQ 'Remote Control consent').Step | Should -BeLike "*claude remote-control once, answer y*"
    }

    It 'accepts trust recorded for the directory or a parent, and recorded consent' {
        Write-TestJson -Path $configPath -Value @{
            remoteDialogSeen = $true
            projects         = @{ (Split-Path -Path $repo -Parent) = @{ hasTrustDialogAccepted = $true } }
        }

        $checks = (Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath $claude).Checks

        ($checks | Where-Object Check -EQ 'Workspace trust').Status | Should -Be 'Ready'
        ($checks | Where-Object Check -EQ 'Remote Control consent').Status | Should -Be 'Ready'
    }

    It 'flags CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC in the user settings' {
        $settings = Join-Path $env:HOME '.claude/settings.json'
        Write-TestJson -Path $settings -Value @{ env = @{ CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1' } }

        $check = (Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath $claude).Checks | Where-Object Check -EQ 'Nonessential traffic'

        $check.Status | Should -Be 'Action'
        $check.Step | Should -BeLike "*$settings*settings env overrides the shell*"
    }

    It 'flags the traffic setting in the project local settings too' {
        Write-TestJson -Path (Join-Path $repo '.claude/settings.local.json') -Value @{ env = @{ CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = 'true' } }

        $check = (Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath $claude).Checks | Where-Object Check -EQ 'Nonessential traffic'

        $check.Status | Should -Be 'Action'
    }

    It 'reads only loggedIn from claude auth status and never returns the account' {
        $status = Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath $claude

        ($status.Checks | Where-Object Check -EQ 'Login').Status | Should -Be 'Ready'
        ($status | ConvertTo-Json -Depth 5) | Should -Not -BeLike '*someone@example.com*'
    }

    It 'asks for a login when claude reports none' {
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq $script:claude } { Get-CommandResult -ExitCode 1 -Output '{"loggedIn": false}' }

        $check = (Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath $claude).Checks | Where-Object Check -EQ 'Login'

        $check.Status | Should -Be 'Action'
    }

    It 'reports the login as unknown over SSH on macOS, where the Keychain is out of reach' {
        $env:SSH_CONNECTION = '192.0.2.1 50000 192.0.2.2 22'
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq $script:claude } { Get-CommandResult -ExitCode 1 -Output '{"loggedIn": false}' }

        $check = (Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath $claude).Checks | Where-Object Check -EQ 'Login'

        $check.Status | Should -Be 'Unknown'
        $check.Detail | Should -BeLike '*Keychain*'
    }

    It 'reports a missing claude binary' {
        $check = (Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath (Join-Path $root 'missing')).Checks | Where-Object Check -EQ 'Claude binary'

        $check.Status | Should -Be 'Action'
    }

    It 'reports a systemd --user unit, its state and linger on Linux' {
        Mock Get-ClaudeRcPlatform -ModuleName PDS { 'Linux' }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'id' } { Get-CommandResult -Output 'michiel' }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'systemctl' } {
            Get-CommandResult -Output @('UnitFileState=enabled', 'ActiveState=active', 'MainPID=77')
        }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'loginctl' } { Get-CommandResult -Output 'no' }

        $status = Get-ClaudeRemoteControlStatus -WorkingDirectory $repo -ClaudePath $claude

        $status.ServiceFile | Should -Be (Join-Path $env:HOME '.config/systemd/user/claude-remote-control-vh-adlc.service')
        $status.Log | Should -Be 'journalctl --user -u claude-remote-control-vh-adlc.service'
        $status.Loaded | Should -BeTrue
        $status.Running | Should -BeTrue
        $status.ProcessId | Should -Be 77
        ($status.Checks | Where-Object Check -EQ 'Linger').Status | Should -Be 'Optional'
    }

    It 'refuses Windows' {
        Mock Get-ClaudeRcPlatform -ModuleName PDS { 'Windows' }

        { Get-ClaudeRemoteControlStatus -WorkingDirectory $repo } | Should -Throw '*macOS*Linux*'
    }
}
