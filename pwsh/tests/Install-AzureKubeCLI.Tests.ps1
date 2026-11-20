BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stubs, so the CLIs can be mocked whether or not they are installed.
    InModuleScope PDS {
        function script:az { }
        function script:kubectl { }
        function script:kubelogin { }
    }
}

Describe 'Install-AzureKubeCLI' {
    BeforeEach {
        $script:installed = @('az', 'kubectl', 'kubelogin')

        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS Get-Command {
            if ($script:installed -contains $Name[0]) {
                [pscustomobject]@{ Name = $Name[0] }
            }
        }
        Mock -ModuleName PDS az { }
        Mock -ModuleName PDS kubectl { 'Client Version: v1.31.0' }
        Mock -ModuleName PDS kubelogin { 'kubelogin version v0.1.4' }
    }

    It 'stops when the Azure CLI is missing' {
        $script:installed = @()

        Install-AzureKubeCLI

        Should -Invoke -ModuleName PDS Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like 'Azure CLI is not installed*' }
        Should -Invoke -ModuleName PDS az -Times 0
    }

    It 'installs both tools through the Azure CLI when kubectl is missing' {
        $script:installed = @('az', 'kubelogin')

        Install-AzureKubeCLI

        Should -Invoke -ModuleName PDS az -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'aks install-cli' }
    }

    It 'installs both tools through the Azure CLI when kubelogin is missing' {
        $script:installed = @('az', 'kubectl')

        Install-AzureKubeCLI

        Should -Invoke -ModuleName PDS az -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'aks install-cli' }
    }

    It 'shows the versions and installs nothing when both tools are present' {
        $output = Install-AzureKubeCLI

        $output | Should -Be @('Client Version: v1.31.0', 'kubelogin version v0.1.4')
        Should -Invoke -ModuleName PDS az -Times 0
        Should -Invoke -ModuleName PDS kubectl -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'version' }
        Should -Invoke -ModuleName PDS kubelogin -Times 1 -Exactly -ParameterFilter { $args[0] -eq '--version' }
    }
}
