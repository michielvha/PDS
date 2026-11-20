BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The test machine has no RSAT, so the ActiveDirectory commands are stubbed in module scope
    # and mocked per test. The stubs are created from a string so the analyzer does not report
    # their unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Get-ADUser { [CmdletBinding()] param($Filter, $Identity, $Properties, $SearchBase) }
function script:Set-ADUser { [CmdletBinding()] param($Identity, $Add) }
'@))
    }
}

Describe 'Set-ProxyAddress' {
    BeforeAll {
        Mock Import-Module -ModuleName PDS -ParameterFilter { $Name -contains 'ActiveDirectory' }
        Mock Get-Module -ModuleName PDS
        Mock Write-Host -ModuleName PDS
        Mock Set-ADUser -ModuleName PDS
        Mock Get-ADUser -ModuleName PDS -ParameterFilter { $null -ne $Filter } {
            [pscustomobject]@{ SamAccountName = 'jdoe'; UserPrincipalName = 'jdoe@contoso.com'; proxyAddresses = @('SMTP:john.doe@contoso.com') }
            [pscustomobject]@{ SamAccountName = 'asmith'; UserPrincipalName = 'asmith@contoso.com'; proxyAddresses = @('smtp:asmith@contoso.com') }
            [pscustomobject]@{ SamAccountName = 'svc-backup'; UserPrincipalName = ''; proxyAddresses = @() }
        }
        Mock Get-ADUser -ModuleName PDS -ParameterFilter { $null -ne $Identity } {
            [pscustomobject]@{ SamAccountName = $Identity; proxyAddresses = @('smtp:updated') }
        }
    }

    It 'adds the UPN as an smtp proxy address only where it is missing' {
        Set-ProxyAddress -Confirm:$false -WarningAction SilentlyContinue

        Should -Invoke Set-ADUser -ModuleName PDS -Times 1 -Exactly
        Should -Invoke Set-ADUser -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Identity -eq 'jdoe' -and $Add.proxyAddresses -ceq 'smtp:jdoe@contoso.com'
        }
    }

    It 'warns about a user without a UPN' {
        Set-ProxyAddress -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue

        "$warnings" | Should -Match "Skipping user 'svc-backup'"
    }

    It 'passes the filter and search base to Get-ADUser' {
        Set-ProxyAddress -Confirm:$false -SearchBase 'OU=Staff,DC=contoso,DC=com' -Filter "Department -eq 'IT'" -WarningAction SilentlyContinue

        Should -Invoke Get-ADUser -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Filter -eq "Department -eq 'IT'" -and $SearchBase -eq 'OU=Staff,DC=contoso,DC=com' -and $Properties -contains 'proxyAddresses'
        }
    }

    It 'changes nothing with -WhatIf' {
        Set-ProxyAddress -WhatIf -WarningAction SilentlyContinue

        Should -Invoke Set-ADUser -ModuleName PDS -Times 0 -Exactly
    }

    It 'returns the updated user with -PassThru' {
        $result = Set-ProxyAddress -Confirm:$false -PassThru -WarningAction SilentlyContinue

        $result.SamAccountName | Should -Be 'jdoe'
    }

    It 'warns when no user matches' {
        Mock Get-ADUser -ModuleName PDS -ParameterFilter { $null -ne $Filter } { }

        Set-ProxyAddress -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue

        "$warnings" | Should -Match 'No users found'
        Should -Invoke Set-ADUser -ModuleName PDS -Times 0 -Exactly
    }
}
