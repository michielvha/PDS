BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Remove-WindowsBloat' {
    BeforeEach {
        # Only SysMain and the CDPUserSvc template with one per-user instance exist on this pretend machine.
        Mock Get-Service -ModuleName PDS
        Mock Get-Service -ModuleName PDS -ParameterFilter { $Name -contains 'SysMain' } -MockWith {
            [pscustomobject]@{ Name = 'SysMain' }
        }
        Mock Get-Service -ModuleName PDS -ParameterFilter { $Name -contains 'CDPUserSvc' } -MockWith {
            [pscustomobject]@{ Name = 'CDPUserSvc' }
        }
        Mock Get-Service -ModuleName PDS -ParameterFilter { $Name -contains 'CDPUserSvc_*' } -MockWith {
            [pscustomobject]@{ Name = 'CDPUserSvc_1a2b3' }
        }
        Mock Stop-Service -ModuleName PDS
        Mock Set-Service -ModuleName PDS
        Mock Set-ItemProperty -ModuleName PDS
        Mock Write-Host -ModuleName PDS
    }

    It 'stops and disables the listed services that exist' {
        $result = Remove-WindowsBloat

        Should -Invoke Stop-Service -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Name -contains 'SysMain' -and $Force
        }
        Should -Invoke Set-Service -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'SysMain' -and $StartupType -eq 'Disabled'
        }
        $result | Should -Be @(
            'Disabling service: SysMain'
            'Disabling per-user service template: CDPUserSvc'
            'Stopping per-user service instance: CDPUserSvc_1a2b3'
        )
    }

    It 'disables a per-user service through its template registry value and only stops its instances' {
        $null = Remove-WindowsBloat

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc' -and $Name -eq 'Start' -and $Value -eq 4
        }
        Should -Invoke Set-Service -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Name -like 'CDPUserSvc*' }
        Should -Invoke Stop-Service -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Name -contains 'CDPUserSvc_1a2b3' -and $Force -and $PesterBoundParameters.ErrorAction -eq 'SilentlyContinue'
        }
    }

    It 'leaves services alone that are not installed' {
        $null = Remove-WindowsBloat

        Should -Invoke Set-Service -ModuleName PDS -Times 1 -Exactly
        Should -Invoke Set-Service -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Name -eq 'WSearch' }
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Path -like '*\OneSyncSvc' }
        Should -Invoke Get-Service -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Name -contains 'OneSyncSvc_*' }
    }

    It 'looks up every service and per-user template on the list by its exact name' {
        $null = Remove-WindowsBloat

        $names = 'SysMain', 'WSearch', 'DiagTrack', 'Fax', 'XblGameSave', 'PhoneSvc', 'OneSyncSvc', 'MessagingService', 'PrintWorkflowUserSvc', 'CDPUserSvc'
        foreach ($service in $names) {
            Should -Invoke Get-Service -ModuleName PDS -ParameterFilter { $Name -contains $service }
        }
        # A wildcard such as OneSyncSvc* only matches the instances, whose startup type cannot be changed.
        Should -Invoke Get-Service -ModuleName PDS -Times 0 -Exactly -ParameterFilter {
            @($Name | Where-Object { $_ -like '*`**' -and $_ -notlike '*_`*' }).Count -gt 0
        }
    }

    It 'never touches SSH, WinRM, networking or the firewall' {
        # Every lookup finds a service, so the whole list is processed.
        Mock Get-Service -ModuleName PDS -MockWith {
            foreach ($serviceName in $Name) {
                [pscustomobject]@{ Name = $serviceName.Replace('*', '1a2b3') }
            }
        }
        $protected = '^(sshd|ssh-agent|WinRM|MpsSvc|BFE|Dhcp|Dnscache|NlaSvc|netprofm|nsi|LanmanWorkstation|LanmanServer|WlanSvc)$'

        $null = Remove-WindowsBloat

        Should -Invoke Stop-Service -ModuleName PDS -Times 0 -Exactly -ParameterFilter { @($Name) -match $protected }
        Should -Invoke Set-Service -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Name -match $protected }
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 0 -Exactly -ParameterFilter {
            ($Path -split '\\')[-1] -match $protected
        }
    }

    It 'reminds the user to reboot' {
        $null = Remove-WindowsBloat

        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Object -like '*reboot*' }
    }

    It 'changes nothing under -WhatIf' {
        $null = Remove-WindowsBloat -WhatIf

        Should -Invoke Stop-Service -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Set-Service -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Write-Host -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Object -like '*reboot*' }
    }
}
