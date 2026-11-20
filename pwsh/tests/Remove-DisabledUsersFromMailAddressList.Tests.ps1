BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The test machine has no RSAT, so the ActiveDirectory commands are stubbed in module scope
    # and mocked per test. The stubs are created from a string so the analyzer does not report
    # their unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Get-ADUser { [CmdletBinding()] param($Filter, $Identity, $Properties) }
function script:Set-ADObject { [CmdletBinding()] param($Identity, $Replace) }
'@))
    }
}

Describe 'Remove-DisabledUsersFromMailAddressList' {
    BeforeAll {
        Mock Import-Module -ModuleName PDS -ParameterFilter { $Name -contains 'ActiveDirectory' }
        Mock Get-Module -ModuleName PDS
        Mock Write-Host -ModuleName PDS
        Mock Set-ADObject -ModuleName PDS
        Mock Get-ADUser -ModuleName PDS -ParameterFilter { $null -ne $Filter } {
            [pscustomobject]@{ SamAccountName = 'jdoe'; DistinguishedName = 'CN=John Doe,OU=Users,DC=contoso,DC=com' }
            [pscustomobject]@{ SamAccountName = 'asmith'; DistinguishedName = 'CN=Anna Smith,OU=Users,DC=contoso,DC=com' }
        }
        Mock Get-ADUser -ModuleName PDS -ParameterFilter { $null -ne $Identity } {
            [pscustomobject]@{ SamAccountName = $Identity; msExchHideFromAddressLists = $true }
        }
    }

    It 'hides every disabled user from the address lists' {
        Remove-DisabledUsersFromMailAddressList -Confirm:$false

        Should -Invoke Get-ADUser -ModuleName PDS -Times 1 -Exactly -ParameterFilter { "$Filter" -match 'Enabled -eq \$false' }
        Should -Invoke Set-ADObject -ModuleName PDS -Times 2 -Exactly
        Should -Invoke Set-ADObject -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Identity -eq 'CN=John Doe,OU=Users,DC=contoso,DC=com' -and $Replace.msExchHideFromAddressLists -eq $true
        }
    }

    It 'changes nothing with -WhatIf' {
        Remove-DisabledUsersFromMailAddressList -WhatIf

        Should -Invoke Set-ADObject -ModuleName PDS -Times 0 -Exactly
    }

    It 'returns the updated users with -PassThru' {
        $result = Remove-DisabledUsersFromMailAddressList -Confirm:$false -PassThru

        $result.SamAccountName | Should -Be @('jdoe', 'asmith')
        $result.msExchHideFromAddressLists | Should -Not -Contain $false
    }

    It 'reports a failed user and carries on with the others' {
        Mock Set-ADObject -ModuleName PDS -ParameterFilter { $Identity -like 'CN=John Doe*' } { throw 'access denied' }

        Remove-DisabledUsersFromMailAddressList -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue

        "$errors" | Should -Match "Failed to hide user 'jdoe'"
        Should -Invoke Set-ADObject -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Identity -like 'CN=Anna Smith*' }
    }

    It 'warns when there is no disabled user' {
        Mock Get-ADUser -ModuleName PDS -ParameterFilter { $null -ne $Filter } { }

        Remove-DisabledUsersFromMailAddressList -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue

        "$warnings" | Should -Match 'No disabled users found'
        Should -Invoke Set-ADObject -ModuleName PDS -Times 0 -Exactly
    }
}
