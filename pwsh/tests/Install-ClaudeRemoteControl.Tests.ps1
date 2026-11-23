BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    function Get-CommandResult {
        param ([int]$ExitCode = 0, [string[]]$Output = @())
        [pscustomobject]@{ ExitCode = $ExitCode; Output = $Output }
    }
}

Describe 'Install-ClaudeRemoteControl' {
    BeforeEach {
        $script:oldHome = $env:HOME
        $script:root = Join-Path $TestDrive ([guid]::NewGuid())
        $env:HOME = Join-Path $root 'home'
        $script:repo = (New-Item -ItemType Directory -Path (Join-Path $root 'code/vh-adlc') -Force).FullName
        $script:claude = (New-Item -ItemType File -Path (Join-Path $root 'bin/claude') -Force).FullName
        $script:plist = Join-Path $env:HOME 'Library/LaunchAgents/pro.vhco.claude-remote-control.vh-adlc.plist'
        $script:unit = Join-Path $env:HOME '.config/systemd/user/claude-remote-control-vh-adlc.service'
        $script:loaded = $false

        Mock Get-ClaudeRcPlatform -ModuleName PDS { 'macOS' }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS { Get-CommandResult }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'id' } { Get-CommandResult -Output '501' }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'print' } {
            if ($script:loaded) { Get-CommandResult -Output "`tpid = 10" } else { Get-CommandResult -ExitCode 113 }
        }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'bootout' } {
            $script:loaded = $false
            Get-CommandResult
        }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq $script:claude } { Get-CommandResult -Output '{"loggedIn": true}' }
        Mock Write-Host -ModuleName PDS
        Mock Start-Sleep -ModuleName PDS
    }

    AfterEach {
        $env:HOME = $script:oldHome
    }

    It 'writes a LaunchAgent that keeps claude remote-control running and loads it into the GUI domain' {
        Install-ClaudeRemoteControl -WorkingDirectory $repo -Name 'macbook-vh-adlc' -ClaudePath $claude -SearchPath '/opt/homebrew/bin:/usr/bin' | Out-Null

        [xml]$xml = Get-Content -LiteralPath $plist -Raw
        $dict = $xml.plist.dict
        $values = @{}
        for ($i = 0; $i -lt $dict.ChildNodes.Count; $i += 2) {
            $values[$dict.ChildNodes[$i].InnerText] = $dict.ChildNodes[$i + 1]
        }
        $values['Label'].InnerText | Should -Be 'pro.vhco.claude-remote-control.vh-adlc'
        @($values['ProgramArguments'].string) | Should -Be @($claude, 'remote-control', '--spawn=worktree', '--name', 'macbook-vh-adlc')
        $values['WorkingDirectory'].InnerText | Should -Be $repo
        $values['RunAtLoad'].Name | Should -Be 'true'
        $values['KeepAlive'].Name | Should -Be 'true'
        $values['ThrottleInterval'].InnerText | Should -Be '60'
        $values['ProcessType'].InnerText | Should -Be 'Interactive'
        $values['StandardOutPath'].InnerText | Should -Be (Join-Path $env:HOME 'Library/Logs/claude-remote-control-vh-adlc.log')
        $values['EnvironmentVariables'].string[0] | Should -Be '/opt/homebrew/bin:/usr/bin'

        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'bootstrap' -and $ArgumentList[1] -eq 'gui/501' -and $ArgumentList[2] -eq $script:plist
        }
    }

    It 'escapes XML in the bridge name' {
        Install-ClaudeRemoteControl -WorkingDirectory $repo -Name 'a&b <c>' -ClaudePath $claude | Out-Null

        [xml]$xml = Get-Content -LiteralPath $plist -Raw
        @($xml.plist.dict.array.string)[-1] | Should -Be 'a&b <c>'
    }

    It 'changes nothing on a second run with the same parameters' {
        Install-ClaudeRemoteControl -WorkingDirectory $repo -Name 'mac' -ClaudePath $claude -SearchPath '/usr/bin' | Out-Null
        $script:loaded = $true
        $before = (Get-Item -LiteralPath $plist).LastWriteTimeUtc

        Install-ClaudeRemoteControl -WorkingDirectory $repo -Name 'mac' -ClaudePath $claude -SearchPath '/usr/bin' | Out-Null

        (Get-Item -LiteralPath $plist).LastWriteTimeUtc | Should -Be $before
        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'bootstrap' }
        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'bootout' }
    }

    It 'reloads a loaded LaunchAgent when the parameters change' {
        Install-ClaudeRemoteControl -WorkingDirectory $repo -Name 'old' -ClaudePath $claude | Out-Null
        $script:loaded = $true

        Install-ClaudeRemoteControl -WorkingDirectory $repo -Name 'new' -ClaudePath $claude | Out-Null

        (Get-Content -LiteralPath $plist -Raw) | Should -BeLike '*<string>new</string>*'
        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'bootout' -and $ArgumentList[1] -eq 'gui/501/pro.vhco.claude-remote-control.vh-adlc'
        }
        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 2 -Exactly -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'bootstrap' }
    }

    It 'never records trust or consent, and tells the owner to do both' {
        Install-ClaudeRemoteControl -WorkingDirectory $repo -ClaudePath $claude | Out-Null

        Join-Path $env:HOME '.claude.json' | Should -Not -Exist
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { "$Object" -like '*accept the workspace trust dialog*' }
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { "$Object" -like "*answer y to 'Enable Remote Control?'*" }
    }

    It 'tells the owner to stop a terminal bridge that serves the same folder' {
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'ps' } { Get-CommandResult -Output '  77240 claude remote-control' }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'lsof' } { Get-CommandResult -Output @('p77240', 'fcwd', "n$script:repo") }

        Install-ClaudeRemoteControl -WorkingDirectory $repo -ClaudePath $claude | Out-Null

        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { "$Object" -like '*Terminal bridge: Action*PID 77240*' }
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { "$Object" -like '*Stop the terminal bridge with Ctrl+C*' }
    }

    It 'changes nothing with -WhatIf' {
        Install-ClaudeRemoteControl -WorkingDirectory $repo -ClaudePath $claude -WhatIf | Out-Null

        $plist | Should -Not -Exist
        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -ne 'print' }
    }

    It 'stops when claude cannot be found' {
        { Install-ClaudeRemoteControl -WorkingDirectory $repo -ClaudePath (Join-Path $root 'missing') } | Should -Throw '*Claude Code was not found*'
        $plist | Should -Not -Exist
    }

    It 'stops when the working directory does not exist' {
        { Install-ClaudeRemoteControl -WorkingDirectory (Join-Path $root 'nowhere') -ClaudePath $claude } | Should -Throw '*Working directory not found*'
    }

    It 'writes, enables and restarts a systemd --user unit on Linux, with linger on request' {
        Mock Get-ClaudeRcPlatform -ModuleName PDS { 'Linux' }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'id' } { Get-CommandResult -Output 'michiel' }

        Install-ClaudeRemoteControl -WorkingDirectory $repo -Name 'fedora 43' -ClaudePath $claude -SearchPath '/usr/bin' -SpawnMode same-dir -EnableLinger | Out-Null

        $content = Get-Content -LiteralPath $unit -Raw
        $content | Should -BeLike "*WorkingDirectory=$repo*"
        $content | Should -BeLike "*ExecStart=`"$($claude -replace '\\', '\\')`" `"remote-control`" `"--spawn=same-dir`" `"--name`" `"fedora 43`"*"
        $content | Should -BeLike '*Environment="PATH=/usr/bin"*'
        $content | Should -BeLike '*Restart=always*RestartSec=60*WantedBy=default.target*'
        foreach ($action in 'daemon-reload', 'enable', 'restart') {
            Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'systemctl' -and $ArgumentList[1] -eq $action }
        }
        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'loginctl' -and $ArgumentList[0] -eq 'enable-linger' -and $ArgumentList[1] -eq 'michiel'
        }
    }

    It 'only starts an unchanged systemd unit' {
        Mock Get-ClaudeRcPlatform -ModuleName PDS { 'Linux' }
        Install-ClaudeRemoteControl -WorkingDirectory $repo -Name 'f' -ClaudePath $claude | Out-Null

        Install-ClaudeRemoteControl -WorkingDirectory $repo -Name 'f' -ClaudePath $claude | Out-Null

        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'systemctl' -and $ArgumentList[1] -eq 'restart' }
        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'systemctl' -and $ArgumentList[1] -eq 'start' }
        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $FilePath -eq 'loginctl' -and $ArgumentList[0] -eq 'enable-linger' }
    }

    It 'escapes systemd specifiers and variables in the command line' {
        Mock Get-ClaudeRcPlatform -ModuleName PDS { 'Linux' }

        Install-ClaudeRemoteControl -WorkingDirectory $repo -Name '100%$HOME' -ClaudePath $claude | Out-Null

        (Get-Content -LiteralPath $unit -Raw) | Should -BeLike '*"100%%$$HOME"*'
    }

    It 'refuses Windows' {
        Mock Get-ClaudeRcPlatform -ModuleName PDS { 'Windows' }

        { Install-ClaudeRemoteControl -WorkingDirectory $repo -ClaudePath $claude } | Should -Throw '*macOS*Linux*'
    }
}
