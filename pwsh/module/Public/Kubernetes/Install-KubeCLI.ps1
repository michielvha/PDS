Function Install-AzureKubeCLI {
    <#
    .SYNOPSIS
        Installs `kubectl` and `kubelogin` if they are not already installed on the system.

    .DESCRIPTION
        The `Install-AzureKubeCLI` function checks if both `kubectl` and `kubelogin` are installed on the system by attempting to retrieve their version information. If either tool is missing, the function uses the Azure CLI (`az`) to install both tools via `az aks install-cli`. If both tools are already installed, their version information is displayed.

    .EXAMPLE
        Install-AzureKubeCLI

        This command checks for the installation of both `kubectl` and `kubelogin`. If they are not found, it installs them using the Azure CLI. If they are already installed, it prints their current version.

    .NOTES
        Author: Michiel VH
        Requires: Azure CLI (`az`) to be installed on the system for installing `kubectl` and `kubelogin`.
        This function assumes that `az aks install-cli` will be used to manage the Kubernetes CLI tools.

    .LINK
        https://kubernetes.io/docs/tasks/tools/
        Learn more about `kubectl` and how it is used to manage Kubernetes clusters.

    .LINK
        https://github.com/Azure/kubelogin
        Learn more about `kubelogin`, a tool for Azure Kubernetes Service (AKS) authentication.
    #>
    
    # TODO: Auto install az cli if not installed
    # Check if az command is available without producing an error if not found
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Host "Azure CLI is not installed. Please install Azure CLI before proceeding."
        return
    }

    $kubectlCmdExists = Get-Command kubectl -ErrorAction SilentlyContinue
    $kubeloginCmdExists = Get-Command kubelogin -ErrorAction SilentlyContinue

    if (-not $kubectlCmdExists -or -not $kubeloginCmdExists) {
        Write-Host "kubectl & kubelogin will be installed via az cli"
        az aks install-cli
    } else {
        Write-Host "Kubectl and kubelogin are already installed:"
        kubectl version 2>$null
        kubelogin --version 2>$null
    }
}
