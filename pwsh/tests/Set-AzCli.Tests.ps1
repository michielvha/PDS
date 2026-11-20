BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # az is an external executable the test machine may not have and must never run for
    # real; a module-scope stub lets Pester mock it.
    InModuleScope PDS { function script:az { } }
}

Describe 'Set-AzCli' {
    BeforeEach {
        Mock az -ModuleName PDS { }
    }

    It 'adds the ssh, aks-preview, mesh, terraform and storage extensions in one az call' {
        Set-AzCli

        # Flatten the arguments: PowerShell hands the comma list to az as separate words.
        Should -Invoke az -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            (($args | ForEach-Object { $_ }) -join ' ') -eq 'extension add --name ssh aks-preview mesh terraform storage'
        }
    }

    It 'changes nothing under -WhatIf' {
        Set-AzCli -WhatIf

        Should -Invoke az -ModuleName PDS -Times 0 -Exactly
    }
}
