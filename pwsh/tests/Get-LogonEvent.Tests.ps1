BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Out-GridView is stubbed in module scope, so no test can open a window. The stub is created
    # from a string so the analyzer does not report its unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Out-GridView { [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject, $Title) }
'@))
    }

    # The tests must not read the real Security log, so every test runs against a Get-WinEvent
    # mock that returns objects shaped like EventLogRecord: an Id, a TimeCreated and the event's
    # insertion strings as Properties, each with a Value.
    function ConvertTo-TestErrorRecord {
        param ([System.Exception]$Exception, [string]$ErrorId)

        [System.Management.Automation.ErrorRecord]::new(
            $Exception, $ErrorId, [System.Management.Automation.ErrorCategory]::NotSpecified, $null)
    }

    $script:events = foreach ($logon in @(
            @{ Account = 'alice'; Type = 10; Address = '10.0.0.5' }
            @{ Account = 'bob'; Type = 3; Address = '-' }
            @{ Account = 'PC01$'; Type = 3; Address = '10.0.0.9' }
            @{ Account = 'SYSTEM'; Type = 5; Address = '-' }
            @{ Account = 'ANONYMOUS LOGON'; Type = 3; Address = '10.0.0.7' }
        )) {
        $values = @{ 5 = $logon.Account; 6 = 'CONTOSO'; 8 = [uint32]$logon.Type; 18 = $logon.Address }
        $properties = foreach ($index in 0..20) {
            [pscustomobject]@{ Value = $values[$index] }
        }
        [pscustomobject]@{ Id = 4624; TimeCreated = [datetime]'2026-11-20 09:30'; Properties = $properties }
    }
}

Describe 'Get-LogonEvent' {
    BeforeAll {
        Mock Write-Host -ModuleName PDS
        Mock Out-GridView -ModuleName PDS
        Mock Get-WinEvent -ModuleName PDS { $events }
    }

    It 'returns the user logons and leaves out system accounts' {
        $result = Get-LogonEvent -ShowGridView $false

        $result.Account | Should -Be @('CONTOSO\alice', 'CONTOSO\bob')
        $result[0].Time | Should -Be '2026-11-20 09:30:00'
        $result[0].LogonTypeDescription | Should -Be 'Remote Desktop'
        $result[0].LogonType | Should -BeExactly '10'
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

        Should -Invoke Get-WinEvent -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $FilterHashtable[0].LogName -eq 'Security' -and
            ($FilterHashtable[0].Id -join ',') -eq '4624' -and
            $FilterHashtable[0].StartTime -gt (Get-Date).AddDays(-7).AddMinutes(-5) -and
            $FilterHashtable[0].StartTime -lt (Get-Date).AddDays(-7).AddMinutes(5) -and
            $FilterHashtable[0].EndTime -gt (Get-Date).AddMinutes(-5) -and
            $FilterHashtable[0].EndTime -le (Get-Date)
        }
    }

    It 'shows the events in a grid view by default' {
        $null = Get-LogonEvent

        Should -Invoke Out-GridView -ModuleName PDS -ParameterFilter { $Title -eq 'Logon Events: Past 1 Day(s)' }
    }

    It 'returns nothing when there is no logon event' {
        Mock Get-WinEvent -ModuleName PDS { }

        $result = Get-LogonEvent -ShowGridView $false

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'No logon events found for the specified period.' }
    }

    It 'returns nothing when the Security log has no logon event for the period' {
        Mock Get-WinEvent -ModuleName PDS {
            throw (ConvertTo-TestErrorRecord -Exception ([System.Exception]::new('No events were found that match the specified selection criteria.')) -ErrorId 'NoMatchingEventsFound,Microsoft.PowerShell.Commands.GetWinEventCommand')
        }

        $result = Get-LogonEvent -ShowGridView $false

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'No logon events found for the specified period.' }
    }

    It 'passes on any other error from reading the Security log' {
        Mock Get-WinEvent -ModuleName PDS {
            throw (ConvertTo-TestErrorRecord -Exception ([System.UnauthorizedAccessException]::new('Attempted to perform an unauthorized operation.')) -ErrorId 'System.UnauthorizedAccessException,Microsoft.PowerShell.Commands.GetWinEventCommand')
        }

        { Get-LogonEvent -ShowGridView $false } | Should -Throw -ErrorId 'System.UnauthorizedAccessException,Microsoft.PowerShell.Commands.GetWinEventCommand'
    }

    It 'still runs under its old name' {
        $old = Get-Command 'Get-LogonEvents' -Module PDS
        $old.CommandType | Should -Be 'Alias'
        $old.ResolvedCommand.Name | Should -Be 'Get-LogonEvent'

        $result = & $old -ShowGridView $false

        $result.Account | Should -Be @('CONTOSO\alice', 'CONTOSO\bob')
    }
}
