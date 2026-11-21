BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Get-ListeningPort' {
    BeforeEach {
        Mock -ModuleName PDS Get-NetTCPConnection {
            [pscustomobject]@{ LocalAddress = '0.0.0.0'; LocalPort = 135; OwningProcess = 1100 }
            [pscustomobject]@{ LocalAddress = '0.0.0.0'; LocalPort = 22; OwningProcess = 2200 }
        }
        Mock -ModuleName PDS Get-NetUDPEndpoint {
            [pscustomobject]@{ LocalAddress = '0.0.0.0'; LocalPort = 5353; OwningProcess = 3300 }
        }
        Mock -ModuleName PDS Get-Process {
            switch ($Id) {
                1100 { [pscustomobject]@{ ProcessName = 'svchost' } }
                2200 { [pscustomobject]@{ ProcessName = 'sshd' } }
                3300 { [pscustomobject]@{ ProcessName = 'dnscache' } }
            }
        }
    }

    It 'lists listening TCP and UDP ports with their owning process' {
        $output = Get-ListeningPort | Out-String

        $output | Should -Match '(?m)^TCP\s+0\.0\.0\.0:135\s+1100\s+svchost\s*$'
        $output | Should -Match '(?m)^TCP\s+0\.0\.0\.0:22\s+2200\s+sshd\s*$'
        $output | Should -Match '(?m)^UDP\s+0\.0\.0\.0:5353\s+3300\s+dnscache\s*$'
    }

    It 'lists a single TCP listener with the UDP endpoints' {
        Mock -ModuleName PDS Get-NetTCPConnection {
            [pscustomobject]@{ LocalAddress = '0.0.0.0'; LocalPort = 22; OwningProcess = 2200 }
        }

        $output = Get-ListeningPort | Out-String

        $output | Should -Match '(?m)^TCP\s+0\.0\.0\.0:22\s+2200\s+sshd\s*$'
        $output | Should -Match '(?m)^UDP\s+0\.0\.0\.0:5353\s+3300\s+dnscache\s*$'
    }

    It 'asks only for TCP connections in the Listen state' {
        Get-ListeningPort | Out-Null

        Should -Invoke -ModuleName PDS Get-NetTCPConnection -Times 1 -Exactly -ParameterFilter { $State -eq 'Listen' }
        Should -Invoke -ModuleName PDS Get-NetUDPEndpoint -Times 1 -Exactly
        Should -Invoke -ModuleName PDS Get-Process -Times 3 -Exactly
    }

    It 'still runs under its old name' {
        $command = Get-Command 'Get-Ports' -Module PDS

        $command.CommandType | Should -Be 'Alias'
        $command.ResolvedCommandName | Should -Be 'Get-ListeningPort'
        Get-Ports | Out-String | Should -Match 'sshd'
    }
}
