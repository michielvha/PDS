BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # az is an external executable the test machine may not have and must never run for
    # real; a module-scope stub lets Pester mock it.
    InModuleScope PDS { function script:az { } }
}

Describe 'Set-AzureCLI' {
    BeforeEach {
        Mock az -ModuleName PDS { }
    }

    It 'disables the WAM broker and adds the aks-preview and ssh extensions' {
        Set-AzureCLI 6>$null

        Should -Invoke az -ModuleName PDS -Times 3 -Exactly
        Should -Invoke az -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq 'config set core.enable_broker_on_windows=false'
        }
        Should -Invoke az -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq 'extension add --name aks-preview'
        }
        Should -Invoke az -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq 'extension add --name ssh'
        }
    }

    It 'changes nothing under -WhatIf' {
        Set-AzureCLI -WhatIf 6>$null

        Should -Invoke az -ModuleName PDS -Times 0 -Exactly
    }
}
