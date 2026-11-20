BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Start-RemoteADSyncCycle' {
    BeforeAll {
        Mock Test-Connection -ModuleName PDS { $true }
        Mock Invoke-Command -ModuleName PDS { 'AD sync cycle started.' }
    }

    It 'starts a sync on each named server and reports the result' {
        $servers = 'sync01', 'sync02'

        $result = Start-RemoteADSyncCycle -ComputerName $servers

        $result | Should -Be @('sync01 : AD sync cycle started.', 'sync02 : AD sync cycle started.')
        Should -Invoke Test-Connection -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'sync01' -and $Quiet }
        Should -Invoke Invoke-Command -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $ComputerName -eq 'sync02' -and "$ScriptBlock" -match 'Start-ADSyncSyncCycle'
        }
    }

    It 'reads additional servers from -ConfigPath' {
        $config = Join-Path $TestDrive 'servers.txt'
        Set-Content -Path $config -Value 'sync03', 'sync04'

        $server = 'sync01'

        $result = Start-RemoteADSyncCycle -ComputerName $server -ConfigPath $config

        $result.Count | Should -Be 3
        Should -Invoke Invoke-Command -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'sync04' }
    }

    It 'accepts the Initial sync type and rejects an unknown one' {
        $server = 'sync01'

        $null = Start-RemoteADSyncCycle -ComputerName $server -SyncType Initial

        Should -Invoke Invoke-Command -ModuleName PDS -Times 1 -Exactly
        { Start-RemoteADSyncCycle -ComputerName $server -SyncType Full } | Should -Throw
    }

    It 'skips a server it cannot reach' {
        Mock Test-Connection -ModuleName PDS -ParameterFilter { $ComputerName -eq 'offline01' } { $false }

        $servers = 'offline01', 'sync01'

        $result = Start-RemoteADSyncCycle -ComputerName $servers -ErrorVariable errors -ErrorAction SilentlyContinue

        "$errors" | Should -Match "Can't contact offline01"
        $result | Should -Be 'sync01 : AD sync cycle started.'
        Should -Invoke Invoke-Command -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $ComputerName -eq 'offline01' }
    }

    It 'reports a remote failure' {
        Mock Invoke-Command -ModuleName PDS { throw 'access denied' }

        $server = 'sync01'

        $result = Start-RemoteADSyncCycle -ComputerName $server -ErrorVariable errors -ErrorAction SilentlyContinue

        $result | Should -BeNullOrEmpty
        "$errors" | Should -Match 'Failed to run commands on sync01'
    }

    It 'changes nothing under -WhatIf' {
        $servers = 'sync01', 'sync02'

        $result = Start-RemoteADSyncCycle -ComputerName $servers -WhatIf

        $result | Should -BeNullOrEmpty
        Should -Invoke Invoke-Command -ModuleName PDS -Times 0 -Exactly
    }

    It 'errors when no server is given' {
        Start-RemoteADSyncCycle -ErrorVariable errors -ErrorAction SilentlyContinue

        "$errors" | Should -Match 'No target servers specified'
        Should -Invoke Invoke-Command -ModuleName PDS -Times 0 -Exactly
    }
}
