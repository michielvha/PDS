BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The test machine has no RSAT, so the ActiveDirectory commands are stubbed in module scope
    # and mocked per test. The stubs are created from a string so the analyzer does not report
    # their unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Get-ADComputer { [CmdletBinding()] param($Filter, $Properties) }
function script:Remove-ADComputer { [CmdletBinding(SupportsShouldProcess)] param($Identity) }
'@))
    }
}

Describe 'Remove-StaleADComputer' {
    BeforeAll {
        Mock Import-Module -ModuleName PDS -ParameterFilter { $Name -contains 'ActiveDirectory' }
        Mock Write-Host -ModuleName PDS
        # Set-Log appends to a file in the user profile, so it is mocked as well.
        Mock Set-Log -ModuleName PDS
        Mock Remove-ADComputer -ModuleName PDS
        Mock Get-ADComputer -ModuleName PDS {
            [pscustomobject]@{ Name = 'PC-RECENT'; DistinguishedName = 'CN=PC-RECENT,DC=contoso,DC=com'; LastLogonDate = (Get-Date).AddMonths(-2) }
            [pscustomobject]@{ Name = 'PC-STALE'; DistinguishedName = 'CN=PC-STALE,DC=contoso,DC=com'; LastLogonDate = (Get-Date).AddMonths(-18) }
            [pscustomobject]@{ Name = 'PC-ANCIENT'; DistinguishedName = 'CN=PC-ANCIENT,DC=contoso,DC=com'; LastLogonDate = (Get-Date).AddYears(-5) }
        }
    }

    It 'removes only computers not seen within the default year' {
        Remove-StaleADComputer

        Should -Invoke Get-ADComputer -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Filter -eq '*' -and $Properties -contains 'LastLogonDate' }
        Should -Invoke Remove-ADComputer -ModuleName PDS -Times 2 -Exactly
        Should -Invoke Remove-ADComputer -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Identity -eq 'CN=PC-STALE,DC=contoso,DC=com' }
        Should -Invoke Remove-ADComputer -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Identity -eq 'CN=PC-RECENT,DC=contoso,DC=com' }
        Should -Invoke Set-Log -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Message -like 'PC-ANCIENT - Removed*' }
    }

    It 'uses the cutoff given by -Years' {
        Remove-StaleADComputer -Years 3

        Should -Invoke Remove-ADComputer -ModuleName PDS -Times 1 -Exactly
        Should -Invoke Remove-ADComputer -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Identity -eq 'CN=PC-ANCIENT,DC=contoso,DC=com' }
    }

    It 'only logs what it would remove with -WhatIf' {
        Remove-StaleADComputer -WhatIf

        Should -Invoke Remove-ADComputer -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Set-Log -ModuleName PDS -Times 2 -Exactly -ParameterFilter { $Message -like '* - Would be removed - *' }
    }

    It 'changes nothing under -WhatIf' {
        Remove-StaleADComputer -Years 1 -WhatIf

        Should -Invoke Remove-ADComputer -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Set-Log -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Message -like '* - Removed - *' }
    }

    It 'logs a failed removal and carries on' {
        Mock Remove-ADComputer -ModuleName PDS -ParameterFilter { $Identity -like 'CN=PC-STALE*' } { throw 'insufficient rights' }

        Remove-StaleADComputer

        Should -Invoke Set-Log -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Message -like 'An error occurred while removing PC-STALE*insufficient rights*' }
        Should -Invoke Remove-ADComputer -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Identity -like 'CN=PC-ANCIENT*' }
    }
}
