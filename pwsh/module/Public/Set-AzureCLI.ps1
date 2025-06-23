function Set-AzureCLI {
    <#
    .SYNOPSIS
    Installs Azure CLI extensions.

    .DESCRIPTION
    This function installs the 'aks-preview' and 'ssh' Azure CLI extensions.

    .EXAMPLE
    Set-AzureCLI

    Installs 'aks-preview' and 'ssh' Azure CLI extensions.

    .NOTES
    Author: Michiel VH
    This function is intended to ensure specific Azure CLI extensions are installed.
    #>

    param()



    Write-Host "Installing Azure CLI extension 'aks-preview'..."
    az extension add --name aks-preview
    Write-Host "'aks-preview' extension installation process completed."

    Write-Host "Installing Azure CLI extension 'ssh'..."
    az extension add --name ssh
    Write-Host "'ssh' extension installation process completed."

    # Dont forget to add any CA cert (zscaler) if needed
}
