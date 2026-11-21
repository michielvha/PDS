BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The tests must not read the real Security log, so every test runs against a Get-WinEvent
    # mock that returns objects shaped like EventLogRecord: an Id, a TimeCreated and the event's
    # insertion strings as Properties, each with a Value.
    function ConvertTo-TestEventRecord {
        param ([int]$Id, [datetime]$TimeCreated, [hashtable]$Values)

        $properties = foreach ($index in 0..20) {
            [pscustomobject]@{ Value = $Values[$index] }
        }
        [pscustomobject]@{ Id = $Id; TimeCreated = $TimeCreated; Properties = $properties }
    }

    function ConvertTo-TestErrorRecord {
        param ([System.Exception]$Exception, [string]$ErrorId)

        [System.Management.Automation.ErrorRecord]::new(
            $Exception, $ErrorId, [System.Management.Automation.ErrorCategory]::NotSpecified, $null)
    }

    $script:events = @(
        ConvertTo-TestEventRecord -Id 4624 -TimeCreated (Get-Date).AddHours(-3) -Values @{
            5 = 'alice'; 6 = 'CONTOSO'; 8 = [uint32]10; 18 = '10.0.0.5'
        }
        ConvertTo-TestEventRecord -Id 4624 -TimeCreated (Get-Date).AddHours(-2) -Values @{
            5 = 'bob'; 6 = 'CONTOSO'; 8 = [uint32]3; 18 = '-'
        }
        ConvertTo-TestEventRecord -Id 4647 -TimeCreated (Get-Date).AddHours(-1) -Values @{
            1 = 'alice'; 2 = 'CONTOSO'
        }
    )
}

Describe 'Get-LogonActivity' {
    BeforeAll {
        Mock Write-Host -ModuleName PDS
        Mock Get-WinEvent -ModuleName PDS { $events }
    }

    It 'reads the logons and logoffs of the last 24 hours from the Security log' {
        $null = Get-LogonActivity

        Should -Invoke Get-WinEvent -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $FilterHashtable[0].LogName -eq 'Security' -and
            ($FilterHashtable[0].Id -join ',') -eq '4624,4647' -and
            $FilterHashtable[0].StartTime -gt (Get-Date).AddHours(-24).AddMinutes(-5) -and
            $FilterHashtable[0].StartTime -lt (Get-Date).AddHours(-24).AddMinutes(5)
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

    It 'reports no events when the Security log has none for the period' {
        Mock Get-WinEvent -ModuleName PDS {
            throw (ConvertTo-TestErrorRecord -Exception ([System.Exception]::new('No events were found that match the specified selection criteria.')) -ErrorId 'NoMatchingEventsFound,Microsoft.PowerShell.Commands.GetWinEventCommand')
        }

        { $null = Get-LogonActivity } | Should -Not -Throw

        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'Total Logon Events:  0' }
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'Total Logoff Events: 0' + "`n" }
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'Unique Users Who Logged In (0):' }
    }

    It 'passes on any other error from reading the Security log' {
        Mock Get-WinEvent -ModuleName PDS {
            throw (ConvertTo-TestErrorRecord -Exception ([System.UnauthorizedAccessException]::new('Attempted to perform an unauthorized operation.')) -ErrorId 'System.UnauthorizedAccessException,Microsoft.PowerShell.Commands.GetWinEventCommand')
        }

        { Get-LogonActivity } | Should -Throw -ErrorId 'System.UnauthorizedAccessException,Microsoft.PowerShell.Commands.GetWinEventCommand'
    }

    It 'still runs under its old name' {
        $old = Get-Command 'Get-AllConnections' -Module PDS
        $old.CommandType | Should -Be 'Alias'
        $old.ResolvedCommand.Name | Should -Be 'Get-LogonActivity'

        $text = & $old | Out-String -Width 400

        $text | Should -Match 'CONTOSO\\alice'
    }
}
