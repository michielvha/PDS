BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Get-EventLog does not exist in PowerShell 7, and the tests must not read the real Security
    # log, so it is stubbed in module scope and mocked per test. Out-GridView is stubbed too, so
    # no test can open a window. The stubs are created from a string so the analyzer does not
    # report their unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Get-EventLog { [CmdletBinding()] param([Parameter(Position = 0)]$LogName, $After, $Before, $InstanceId) }
function script:Out-GridView { [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject, $Title) }
'@))
    }
}

Describe 'Get-LogonEvent' {
    BeforeAll {
        Mock Write-Host -ModuleName PDS
        Mock Out-GridView -ModuleName PDS
        Mock Get-EventLog -ModuleName PDS {
            foreach ($logon in @(
                    @{ Account = 'alice'; Type = '10'; Address = '10.0.0.5' }
                    @{ Account = 'bob'; Type = '3'; Address = '-' }
                    @{ Account = 'PC01$'; Type = '3'; Address = '10.0.0.9' }
                    @{ Account = 'SYSTEM'; Type = '5'; Address = '-' }
                    @{ Account = 'ANONYMOUS LOGON'; Type = '3'; Address = '10.0.0.7' }
                )) {
                $strings = [string[]]::new(20)
                $strings[5] = $logon.Account
                $strings[6] = 'CONTOSO'
                $strings[8] = $logon.Type
                $strings[18] = $logon.Address
                [pscustomobject]@{ TimeGenerated = [datetime]'2026-11-20 09:30'; ReplacementStrings = $strings }
            }
        }
    }

    It 'returns the user logons and leaves out system accounts' {
        $result = Get-LogonEvent -ShowGridView $false

        $result.Account | Should -Be @('CONTOSO\alice', 'CONTOSO\bob')
        $result[0].Time | Should -Be '2026-11-20 09:30:00'
        $result[0].LogonTypeDescription | Should -Be 'Remote Desktop'
        $result[0].SourceIP | Should -Be '10.0.0.5'
        $result[1].LogonTypeDescription | Should -Be 'Network (Shared folder)'
        $result[1].SourceIP | Should -Be 'Local'
    }

    It 'includes system accounts with -IncludeSystemAccounts' {
        $result = Get-LogonEvent -ShowGridView $false -IncludeSystemAccounts

        $result.Count | Should -Be 5
    }

    It 'queries logon events for the requested number of days' {
        $null = Get-LogonEvent -ShowGridView $false -Days 7

        Should -Invoke Get-EventLog -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $LogName -eq 'Security' -and
            $InstanceId -eq 4624 -and
            $After -gt (Get-Date).AddDays(-7).AddMinutes(-5) -and
            $After -lt (Get-Date).AddDays(-7).AddMinutes(5)
        }
    }

    It 'shows the events in a grid view by default' {
        $null = Get-LogonEvent

        Should -Invoke Out-GridView -ModuleName PDS -ParameterFilter { $Title -eq 'Logon Events: Past 1 Day(s)' }
    }

    It 'returns nothing when there is no logon event' {
        Mock Get-EventLog -ModuleName PDS { }

        $result = Get-LogonEvent -ShowGridView $false

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'No logon events found for the specified period.' }
    }

    It 'still runs under its old name' {
        $old = Get-Command 'Get-LogonEvents' -Module PDS
        $old.CommandType | Should -Be 'Alias'
        $old.ResolvedCommand.Name | Should -Be 'Get-LogonEvent'

        $result = & $old -ShowGridView $false

        $result.Account | Should -Be @('CONTOSO\alice', 'CONTOSO\bob')
    }
}
