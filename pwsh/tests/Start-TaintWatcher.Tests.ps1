BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stub, so kubectl can be mocked whether or not it is installed; no cluster is needed.
    InModuleScope PDS { function script:kubectl { } }

    $script:nodesJson = @{
        items = @(
            @{
                metadata = @{ name = 'node-a' }
                spec     = @{ taints = @(@{ key = 'node-role.kubernetes.io/control-plane'; value = ''; effect = 'NoSchedule' }) }
            }
            @{
                metadata = @{ name = 'node-b' }
                spec     = @{ }
            }
        )
    } | ConvertTo-Json -Depth 6
}

Describe 'Start-TaintWatcher' {
    BeforeEach {
        # The log is written to the current directory, so run in a fresh TestDrive folder.
        $script:workDir = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -Path $script:workDir -ItemType Directory | Out-Null
        Push-Location -LiteralPath $script:workDir

        $script:sleeps = 0
        $script:maxSleeps = 1
        Mock -ModuleName PDS kubectl { $script:nodesJson }
        # The watcher loops forever; the mocked sleep ends it after the wanted number of rounds.
        Mock -ModuleName PDS Start-Sleep {
            $script:sleeps++
            if ($script:sleeps -ge $script:maxSleeps) {
                throw 'stop watcher'
            }
        }
    }

    AfterEach {
        Pop-Location
    }

    It 'logs the taints of every node to taint_watch.log' {
        { Start-TaintWatcher } | Should -Throw 'stop watcher'

        $log = Get-Content -LiteralPath (Join-Path $script:workDir 'taint_watch.log')
        $log | Where-Object { $_ -like '===== * =====' } | Should -HaveCount 1
        $log | Should -Contain '[node-a] has taints:'
        $log | Should -Contain 'node-role.kubernetes.io/control-plane=:NoSchedule'
        $log | Should -Contain '[node-b] has no taints.'
        Should -Invoke -ModuleName PDS kubectl -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'get nodes -o json' }
    }

    It 'checks again every 2 seconds' {
        $script:maxSleeps = 3

        { Start-TaintWatcher } | Should -Throw 'stop watcher'

        $log = Get-Content -LiteralPath (Join-Path $script:workDir 'taint_watch.log')
        $log | Where-Object { $_ -like '===== * =====' } | Should -HaveCount 3
        Should -Invoke -ModuleName PDS kubectl -Times 3 -Exactly
        Should -Invoke -ModuleName PDS Start-Sleep -Times 3 -Exactly -ParameterFilter { $Seconds -eq 2 }
    }

    It 'changes nothing under -WhatIf' {
        Mock -ModuleName PDS Add-Content { }

        Start-TaintWatcher -WhatIf

        Should -Invoke -ModuleName PDS Add-Content -Times 0 -Exactly
        Should -Invoke -ModuleName PDS Start-Sleep -Times 0 -Exactly
        Join-Path $script:workDir 'taint_watch.log' | Should -Not -Exist
    }
}
