BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    function Get-CommandResult {
        param ([int]$ExitCode = 0, [string[]]$Output = @())
        [pscustomobject]@{ ExitCode = $ExitCode; Output = $Output }
    }
}

Describe 'Uninstall-ClaudeRemoteControl' {
    BeforeEach {
        $script:oldHome = $env:HOME
        $script:root = Join-Path $TestDrive ([guid]::NewGuid())
        $env:HOME = Join-Path $root 'home'
        $script:repo = (New-Item -ItemType Directory -Path (Join-Path $root 'code/vh-adlc') -Force).FullName
        $script:plist = Join-Path $env:HOME 'Library/LaunchAgents/pro.vhco.claude-remote-control.vh-adlc.plist'
        $script:unit = Join-Path $env:HOME '.config/systemd/user/claude-remote-control-vh-adlc.service'

        Mock Get-ClaudeRcPlatform -ModuleName PDS { 'macOS' }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS { Get-CommandResult }
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'id' } { Get-CommandResult -Output '501' }
        Mock Write-Host -ModuleName PDS
    }

    AfterEach {
        $env:HOME = $script:oldHome
    }

    It 'unloads a loaded LaunchAgent and deletes its plist' {
        New-Item -ItemType File -Path $plist -Force | Out-Null
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'print' } { Get-CommandResult -Output "`tpid = 10" }

        Uninstall-ClaudeRemoteControl -WorkingDirectory $repo

        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'bootout' -and $ArgumentList[1] -eq 'gui/501/pro.vhco.claude-remote-control.vh-adlc'
        }
        $plist | Should -Not -Exist
    }

    It 'disables and stops the systemd unit, deletes it and reloads systemd on Linux' {
        Mock Get-ClaudeRcPlatform -ModuleName PDS { 'Linux' }
        New-Item -ItemType File -Path $unit -Force | Out-Null
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'systemctl' -and $ArgumentList[1] -eq 'show' } {
            Get-CommandResult -Output @('UnitFileState=enabled', 'ActiveState=active', 'MainPID=77')
        }

        Uninstall-ClaudeRemoteControl -WorkingDirectory $repo

        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'systemctl' -and ($ArgumentList -join ' ') -eq '--user disable --now claude-remote-control-vh-adlc.service'
        }
        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $FilePath -eq 'systemctl' -and $ArgumentList[1] -eq 'daemon-reload' }
        $unit | Should -Not -Exist
    }

    It 'does nothing when no service is installed' {
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'print' } { Get-CommandResult -ExitCode 113 }

        Uninstall-ClaudeRemoteControl -WorkingDirectory $repo

        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'bootout' }
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { "$Object" -like 'No Remote Control service is installed*' }
    }

    It 'changes nothing with -WhatIf' {
        New-Item -ItemType File -Path $plist -Force | Out-Null
        Mock Invoke-ClaudeRcCommand -ModuleName PDS -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'print' } { Get-CommandResult -Output "`tpid = 10" }

        Uninstall-ClaudeRemoteControl -WorkingDirectory $repo -WhatIf

        Should -Invoke Invoke-ClaudeRcCommand -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $FilePath -eq 'launchctl' -and $ArgumentList[0] -eq 'bootout' }
        $plist | Should -Exist
    }
}
