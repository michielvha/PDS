BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # az is an external executable the test machine may not have and must never run for
    # real; a module-scope stub lets Pester mock it.
    InModuleScope PDS { function script:az { } }
    $script:extensions = 'ssh', 'aks-preview', 'mesh', 'terraform'
}

Describe 'Set-AzCli' {
    BeforeEach {
        # A successful az call leaves exit code 0.
        Mock az -ModuleName PDS { Set-Variable -Name LASTEXITCODE -Value 0 -Scope Global }
    }

    It 'adds each extension with its own az call' {
        $result = Set-AzCli 2>&1

        Should -Invoke az -ModuleName PDS -Times 4 -Exactly
        foreach ($extension in $script:extensions) {
            Should -Invoke az -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                ($args -join ' ') -eq "extension add --name $extension"
            }
        }
        $result | Should -BeNullOrEmpty
    }

    It 'writes an error naming each extension that az fails to add and adds the rest' {
        Mock az -ModuleName PDS -ParameterFilter { $args[-1] -in 'mesh', 'terraform' } -MockWith {
            Set-Variable LASTEXITCODE -Value 1 -Scope Global
        }

        $result = Set-AzCli 2>&1

        $messages = $result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.Exception.Message }
        $messages | Should -Be @(
            "Adding the Azure CLI extension 'mesh' failed with exit code 1."
            "Adding the Azure CLI extension 'terraform' failed with exit code 1."
        )
        Should -Invoke az -ModuleName PDS -Times 4 -Exactly
    }

    It 'changes nothing under -WhatIf' {
        Set-AzCli -WhatIf

        Should -Invoke az -ModuleName PDS -Times 0 -Exactly
    }
}
