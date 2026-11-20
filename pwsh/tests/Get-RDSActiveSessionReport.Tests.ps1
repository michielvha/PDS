BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The test machine has no RemoteDesktop module, so its command is stubbed in module scope
    # and mocked per test. The stub is created from a string so the analyzer does not report its
    # unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Get-RDUserSession { [CmdletBinding()] param($CollectionName, $ConnectionBroker) }
'@))
    }
}

Describe 'Get-RDSActiveSessionReport' {
    BeforeAll {
        Mock Import-Module -ModuleName PDS -ParameterFilter { $Name -contains 'RemoteDesktop' }
        Mock Get-Module -ModuleName PDS
        Mock Write-Host -ModuleName PDS
        Mock Start-Transcript -ModuleName PDS
        Mock Stop-Transcript -ModuleName PDS
        Mock Get-RDUserSession -ModuleName PDS {
            [pscustomobject]@{
                UserName       = 'alice'
                CreateTime     = [datetime]'2026-11-20 08:00'
                SessionState   = 'STATE_ACTIVE'
                DisconnectTime = $null
                IdleTime       = 5 * 60000
                ServerName     = 'rdsh01'
            }
            [pscustomobject]@{
                UserName       = 'bob'
                CreateTime     = [datetime]'2026-11-20 06:00'
                SessionState   = 'STATE_DISCONNECTED'
                DisconnectTime = [datetime]'2026-11-20 07:00'
                IdleTime       = 120 * 60000
                ServerName     = 'rdsh02'
            }
        }
    }

    BeforeEach {
        $logPath = Join-Path $TestDrive 'logs' 'monitor.csv'
        $exportPath = Join-Path $TestDrive 'export.csv'
        Remove-Item -Path $logPath, $exportPath -ErrorAction SilentlyContinue
    }

    It 'exports and logs the sessions below the idle threshold' {
        Get-RDSActiveSessionReport -LogPath $logPath -ExportPath $exportPath -NoTranscript

        $rows = @(Import-Csv -Path $exportPath)
        $rows.Count | Should -Be 1
        $rows[0].userName | Should -Be 'alice'
        $rows[0].idleTimeMinutes | Should -Be '5'
        $rows[0].serverName | Should -Be 'rdsh01'
        $rows[0].disconnectTime | Should -Be 'N/A'
        Get-Content -Path $logPath | Should -Match ',alice,5,rdsh01,'
    }

    It 'honours -IdleThresholdMinutes' {
        Get-RDSActiveSessionReport -LogPath $logPath -ExportPath $exportPath -NoTranscript -IdleThresholdMinutes 180

        @(Import-Csv -Path $exportPath).userName | Should -Be @('alice', 'bob')
    }

    It 'logs that there is no active session and exports nothing' {
        Mock Get-RDUserSession -ModuleName PDS { }

        Get-RDSActiveSessionReport -LogPath $logPath -ExportPath $exportPath -NoTranscript

        Test-Path -Path $exportPath | Should -BeFalse
        Get-Content -Path $logPath | Should -Match 'No active user sessions found'
    }

    It 'records a transcript unless -NoTranscript is given' {
        $transcript = Join-Path $TestDrive 'transcript.txt'

        Get-RDSActiveSessionReport -LogPath $logPath -ExportPath $exportPath -TranscriptPath $transcript

        Should -Invoke Start-Transcript -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Path -eq $transcript -and $Append }
        Should -Invoke Stop-Transcript -ModuleName PDS -Times 1 -Exactly

        Get-RDSActiveSessionReport -LogPath $logPath -ExportPath $exportPath -NoTranscript

        Should -Invoke Start-Transcript -ModuleName PDS -Times 1 -Exactly
    }

    It 'still runs under its old name' {
        $old = Get-Command 'Get-RDSActiveSessions' -Module PDS
        $old.CommandType | Should -Be 'Alias'
        $old.ResolvedCommand.Name | Should -Be 'Get-RDSActiveSessionReport'

        & $old -LogPath $logPath -ExportPath $exportPath -NoTranscript

        @(Import-Csv -Path $exportPath).userName | Should -Be 'alice'
    }
}
