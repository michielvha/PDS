BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The test machine has no RSAT, so the ActiveDirectory command is stubbed in module scope and
    # mocked per test. Out-GridView is stubbed too, so no test can open a window. The stubs are
    # created from a string so the analyzer does not report their unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Get-ADUser { [CmdletBinding()] param($Filter, $Properties, $SearchBase, $Identity) }
function script:Out-GridView { [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject, $Title) }
'@))
    }
}

Describe 'Get-DisabledADUser' {
    BeforeAll {
        Mock Import-Module -ModuleName PDS -ParameterFilter { $Name -contains 'ActiveDirectory' }
        Mock Get-Module -ModuleName PDS
        Mock Write-Host -ModuleName PDS
        Mock Out-GridView -ModuleName PDS
        Mock Get-ADUser -ModuleName PDS -ParameterFilter { $null -ne $Filter } {
            [pscustomobject]@{
                SamAccountName    = 'jdoe'
                DisplayName       = 'John Doe'
                UserPrincipalName = 'jdoe@contoso.com'
                GivenName         = 'John'
                Surname           = 'Doe'
                Description       = 'Left the company'
                DistinguishedName = 'CN=John Doe,OU=Users,DC=contoso,DC=com'
                Enabled           = $false
                LastLogonDate     = (Get-Date).AddDays(-40)
                whenCreated       = (Get-Date).AddDays(-100)
                whenChanged       = (Get-Date).AddDays(-10)
                Title             = 'Engineer'
                Department        = 'IT'
                Office            = 'HQ'
                Manager           = 'CN=Jane Boss,OU=Users,DC=contoso,DC=com'
            }
            [pscustomobject]@{
                SamAccountName    = 'asmith'
                DisplayName       = 'Anna Smith'
                UserPrincipalName = 'asmith@contoso.com'
                GivenName         = 'Anna'
                Surname           = 'Smith'
                Description       = $null
                DistinguishedName = 'CN=Anna Smith,OU=Users,DC=contoso,DC=com'
                Enabled           = $false
                LastLogonDate     = $null
                whenCreated       = $null
                whenChanged       = $null
                Title             = $null
                Department        = $null
                Office            = $null
                Manager           = $null
            }
        }
        Mock Get-ADUser -ModuleName PDS -ParameterFilter { $null -ne $Identity } {
            [pscustomobject]@{ Name = 'Jane Boss' }
        }
    }

    It 'returns the disabled users with the calculated columns' {
        $result = @(Get-DisabledADUser -Format None)

        $result.Count | Should -Be 2
        $jdoe = $result | Where-Object SamAccountName -EQ 'jdoe'
        $jdoe.'Manager Name' | Should -Be 'Jane Boss'
        $jdoe.'Account Age (Days)' | Should -Be 100
        $jdoe.'Days Since Modified' | Should -Be 10
        $asmith = $result | Where-Object SamAccountName -EQ 'asmith'
        $asmith.'Manager Name' | Should -Be 'None'
        $asmith.'Account Age (Days)' | Should -Be 'Unknown'
    }

    It 'queries only disabled accounts and passes the search base' {
        $null = Get-DisabledADUser -Format None -SearchBase 'OU=Users,DC=contoso,DC=com'

        Should -Invoke Get-ADUser -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            "$Filter" -match 'Enabled -eq \$false' -and $SearchBase -eq 'OU=Users,DC=contoso,DC=com'
        }
        Should -Invoke Get-ADUser -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Identity -eq 'CN=Jane Boss,OU=Users,DC=contoso,DC=com'
        }
    }

    It 'sends the users to Out-GridView with -Format Grid' {
        $null = Get-DisabledADUser -Format Grid

        Should -Invoke Out-GridView -ModuleName PDS -ParameterFilter { $Title -eq 'Disabled AD Users (2 accounts)' }
    }

    It 'returns nothing when no disabled user exists' {
        Mock Get-ADUser -ModuleName PDS -ParameterFilter { $null -ne $Filter } { }

        $result = Get-DisabledADUser -Format None

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'No disabled AD users found.' }
    }

    It 'still runs under its old name' {
        $old = Get-Command 'Get-DisabledADUsers' -Module PDS
        $old.CommandType | Should -Be 'Alias'
        $old.ResolvedCommand.Name | Should -Be 'Get-DisabledADUser'

        $result = @(& $old -Format None)

        $result.Count | Should -Be 2
    }
}
