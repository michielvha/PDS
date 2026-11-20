BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Get-EventLog does not exist in PowerShell 7, and the tests must not read the real Security
    # log, so it is stubbed in module scope and mocked per test. The stub is created from a
    # string so the analyzer does not report its unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Get-EventLog { [CmdletBinding()] param([Parameter(Position = 0)]$LogName, $After, $Before, $InstanceId) }
'@))
    }
}

Describe 'Get-LogonActivity' {
    BeforeAll {
        Mock Write-Host -ModuleName PDS
        Mock Get-EventLog -ModuleName PDS {
            $remote = [string[]]::new(20)
            $remote[5] = 'alice'
            $remote[6] = 'CONTOSO'
            $remote[8] = '10'
            $remote[18] = '10.0.0.5'
            $network = [string[]]::new(20)
            $network[5] = 'bob'
            $network[6] = 'CONTOSO'
            $network[8] = '3'
            $network[18] = '-'
            $logoff = [string[]]::new(20)
            $logoff[1] = 'alice'
            $logoff[2] = 'CONTOSO'
            [pscustomobject]@{ EventID = 4624; TimeGenerated = (Get-Date).AddHours(-3); ReplacementStrings = $remote }
            [pscustomobject]@{ EventID = 4624; TimeGenerated = (Get-Date).AddHours(-2); ReplacementStrings = $network }
            [pscustomobject]@{ EventID = 4647; TimeGenerated = (Get-Date).AddHours(-1); ReplacementStrings = $logoff }
        }
    }

    It 'reads the last 24 hours of the Security log' {
        $null = Get-LogonActivity

        Should -Invoke Get-EventLog -ModuleName PDS -Times 2 -Exactly -ParameterFilter {
            $LogName -eq 'Security' -and
            $After -gt (Get-Date).AddHours(-24).AddMinutes(-5) -and
            $After -lt (Get-Date).AddHours(-24).AddMinutes(5)
        }
    }

    It 'reports logons and logoffs with their user, logon type and address' {
        $text = Get-LogonActivity | Out-String -Width 400

        $text | Should -Match 'CONTOSO\\alice'
        $text | Should -Match 'RemoteInteractive'
        $text | Should -Match '10\.0\.0\.5'
        $text | Should -Match 'CONTOSO\\bob\s+Network\s+Local'
        $text | Should -Match 'Logoff'
    }

    It 'prints a summary of the events and the users who logged on' {
        $null = Get-LogonActivity

        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'Total Logon Events:  2' }
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'Total Logoff Events: 1' + "`n" }
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'Unique Users Who Logged In (2):' }
    }

    It 'still runs under its old name' {
        $old = Get-Command 'Get-AllConnections' -Module PDS
        $old.CommandType | Should -Be 'Alias'
        $old.ResolvedCommand.Name | Should -Be 'Get-LogonActivity'

        $text = & $old | Out-String -Width 400

        $text | Should -Match 'CONTOSO\\alice'
    }
}
