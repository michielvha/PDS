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

Describe 'Get-RDSActiveSession' {
    BeforeAll {
        Mock Write-Host -ModuleName PDS
        Mock Start-Transcript -ModuleName PDS
        Mock Stop-Transcript -ModuleName PDS
        Mock Get-RDUserSession -ModuleName PDS {
            [pscustomobject]@{
                UserName        = 'alice'
                CreateTime      = [datetime]'2026-11-20 08:00'
                SessionState    = 'STATE_ACTIVE'
                DisconnectTime  = $null
                IdleTime        = 5 * 60000
                ServerName      = 'rdsh01'
                ServerIPAddress = '10.0.0.11'
            }
            [pscustomobject]@{
                UserName        = 'bob'
                CreateTime      = [datetime]'2026-11-20 06:00'
                SessionState    = 'STATE_DISCONNECTED'
                DisconnectTime  = [datetime]'2026-11-20 07:00'
                IdleTime        = 120 * 60000
                ServerName      = 'rdsh02'
                ServerIPAddress = '10.0.0.12'
            }
        }
    }

    BeforeEach {
        $script:logPath = Join-Path $TestDrive 'logs' 'monitor.csv'
        $script:transcriptPath = Join-Path $TestDrive 'transcripts' 'monitor.txt'
        Remove-Item -Path $logPath -ErrorAction SilentlyContinue
    }

    It 'returns every session with -QuickMode without logging' {
        $result = Get-RDSActiveSession -QuickMode -LogPath $logPath -TranscriptPath $transcriptPath

        $result.UserName | Should -Be @('alice', 'bob')
        $result[0].PSObject.Properties.Name | Should -Be @('UserName', 'IdleTime', 'ServerIPAddress', 'ServerName')
        Should -Invoke Write-Host -ModuleName PDS -ParameterFilter { $Object -eq 'Number of active RDS sessions: 2' }
        Should -Invoke Start-Transcript -ModuleName PDS -Times 0 -Exactly
        Test-Path -Path $logPath | Should -BeFalse
    }

    It 'returns and logs the sessions below the idle threshold' {
        $result = Get-RDSActiveSession -LogPath $logPath -TranscriptPath $transcriptPath

        $result.UserName | Should -Be 'alice'
        Get-Content -Path $logPath | Should -Match ' : alice,5,rdsh01,'
        Should -Invoke Start-Transcript -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Path -like '*monitor.txt' -and $Append }
        Should -Invoke Stop-Transcript -ModuleName PDS -Times 1 -Exactly
    }

    It 'honours -IdleThresholdMinutes' {
        $result = Get-RDSActiveSession -LogPath $logPath -TranscriptPath $transcriptPath -IdleThresholdMinutes 180

        $result.UserName | Should -Be @('alice', 'bob')
    }

    It 'logs that there is no active session' {
        Mock Get-RDUserSession -ModuleName PDS { }

        $result = Get-RDSActiveSession -LogPath $logPath -TranscriptPath $transcriptPath

        $result | Should -BeNullOrEmpty
        Get-Content -Path $logPath | Should -Match 'No active user sessions found'
    }
}
