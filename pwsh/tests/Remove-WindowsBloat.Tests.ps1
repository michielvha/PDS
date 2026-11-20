BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Remove-WindowsBloat' {
    BeforeEach {
        # Only SysMain and one per-user CDPUserSvc instance exist on this pretend machine.
        Mock Get-Service -ModuleName PDS
        Mock Get-Service -ModuleName PDS -ParameterFilter { $Name -contains 'SysMain' } -MockWith {
            [pscustomobject]@{ Name = 'SysMain' }
        }
        Mock Get-Service -ModuleName PDS -ParameterFilter {
            $Name -contains 'CDPUserSvc*' -or $Name -contains 'CDPUserSvc_1a2b3'
        } -MockWith {
            [pscustomobject]@{ Name = 'CDPUserSvc_1a2b3' }
        }
        Mock Stop-Service -ModuleName PDS
        Mock Set-Service -ModuleName PDS
        Mock Write-Host -ModuleName PDS
    }

    It 'stops and disables the listed services that exist' {
        $result = Remove-WindowsBloat

        foreach ($service in 'SysMain', 'CDPUserSvc_1a2b3') {
            Should -Invoke Stop-Service -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                $Name -contains $service -and $Force
            }
            Should -Invoke Set-Service -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                $Name -eq $service -and $StartupType -eq 'Disabled'
            }
        }
        $result | Should -Be @('Disabling service: SysMain', 'Disabling service: CDPUserSvc_1a2b3')
    }

    It 'leaves services alone that are not installed' {
        $null = Remove-WindowsBloat

        Should -Invoke Set-Service -ModuleName PDS -Times 2 -Exactly
        Should -Invoke Set-Service -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Name -eq 'WSearch' }
    }

    It 'looks up every service on the list' {
        $null = Remove-WindowsBloat

        foreach ($service in 'SysMain', 'WSearch', 'DiagTrack', 'Fax', 'XblGameSave', 'OneSyncSvc*', 'CDPUserSvc*') {
            Should -Invoke Get-Service -ModuleName PDS -ParameterFilter { $Name -contains $service }
        }
    }

    It 'reminds the user to reboot' {
        $null = Remove-WindowsBloat

        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Object -like '*reboot*' }
    }
}
