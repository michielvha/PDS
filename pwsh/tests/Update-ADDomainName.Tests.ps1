BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The test machine has no RSAT, so the ActiveDirectory commands are stubbed in module scope
    # and mocked per test. The stubs are created from a string so the analyzer does not report
    # their unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Get-ADUser { [CmdletBinding()] param($Filter, $Properties) }
function script:Set-ADUser { [CmdletBinding()] param([Parameter(Position = 0)]$Identity, $Add, $UserPrincipalName) }
'@))
    }
}

Describe 'Update-ADDomainName' {
    BeforeAll {
        Mock Write-Host -ModuleName PDS
        Mock Get-Module -ModuleName PDS
        Mock Get-Module -ModuleName PDS -ParameterFilter { $ListAvailable -and $Name -contains 'ActiveDirectory' } {
            [pscustomobject]@{ Name = 'ActiveDirectory' }
        }
        Mock Set-ADUser -ModuleName PDS
        Mock Get-ADUser -ModuleName PDS {
            [pscustomobject]@{ SamAccountName = 'jdoe'; UserPrincipalName = 'jdoe@old.com'; ProxyAddresses = @() }
            [pscustomobject]@{ SamAccountName = 'asmith'; UserPrincipalName = 'asmith@old.com'; ProxyAddresses = @() }
        }
    }

    It 'keeps the old address as a proxy and moves each UPN to the new domain' {
        Update-ADDomainName -OldDomain 'old.com' -NewDomain '@new.com' -Confirm:$false

        Should -Invoke Set-ADUser -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Identity -eq 'jdoe' -and $Add.proxyAddresses -ceq 'smtp:jdoe@old.com'
        }
        Should -Invoke Set-ADUser -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Identity.SamAccountName -eq 'asmith' -and $UserPrincipalName -eq 'asmith@new.com'
        }
    }

    It 'builds the default user filter from the old domain' {
        Update-ADDomainName -OldDomain '@old.com' -NewDomain 'new.com' -Confirm:$false

        Should -Invoke Get-ADUser -ModuleName PDS -Times 3 -Exactly -ParameterFilter { $Filter -eq "UserPrincipalName -like '*old.com'" }
    }

    It 'uses a custom -UserFilter' {
        Update-ADDomainName -OldDomain 'old.com' -NewDomain 'new.com' -UserFilter "Department -eq 'Sales'" -Confirm:$false

        Should -Invoke Get-ADUser -ModuleName PDS -Times 3 -Exactly -ParameterFilter { $Filter -eq "Department -eq 'Sales'" }
    }

    It 'changes nothing with -WhatIf' {
        Update-ADDomainName -OldDomain 'old.com' -NewDomain 'new.com' -WhatIf

        Should -Invoke Set-ADUser -ModuleName PDS -Times 0 -Exactly
    }

    It 'warns when no user matches' {
        Mock Get-ADUser -ModuleName PDS { }

        Update-ADDomainName -OldDomain 'old.com' -NewDomain 'new.com' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue

        "$warnings" | Should -Match 'No users found matching filter'
        Should -Invoke Set-ADUser -ModuleName PDS -Times 0 -Exactly
    }

    It 'reports a missing ActiveDirectory module' {
        Mock Get-Module -ModuleName PDS -ParameterFilter { $ListAvailable -and $Name -contains 'ActiveDirectory' } { }
        Mock Get-ADUser -ModuleName PDS { }

        Update-ADDomainName -OldDomain 'old.com' -NewDomain 'new.com' -Confirm:$false -ErrorVariable errors -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        "$errors" | Should -Match 'requires the Active Directory module'
        Should -Invoke Set-ADUser -ModuleName PDS -Times 0 -Exactly
    }
}
