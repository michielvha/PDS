function Set-AzureCLI {
    <#
    .SYNOPSIS
        Installs Azure CLI extensions and applies preferred configuration.

    .DESCRIPTION
        This function installs the 'aks-preview' and 'ssh' Azure CLI extensions and
        disables the Web Account Manager (WAM) broker so that 'az login' uses the
        browser-based authentication flow instead of the Windows account picker.

    .EXAMPLE
        Set-AzureCLI

        Installs 'aks-preview' and 'ssh' Azure CLI extensions and disables WAM.

    .NOTES
        Author: Michiel VH
        This function is intended to ensure specific Azure CLI extensions are installed.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Disable the Windows Web Account Manager (WAM) broker. This is Windows-only;
    # other platforms always use browser-based auth. Reverting to the browser flow
    # avoids the "User cancelled the Accounts Control Operation" account picker.
    if ($PSCmdlet.ShouldProcess('core.enable_broker_on_windows', 'Set Azure CLI config to false')) {
        Write-Host "Disabling Azure CLI WAM broker (core.enable_broker_on_windows=false)..."
        az config set core.enable_broker_on_windows=false
        Write-Host "WAM broker disabled. Browser-based authentication will be used."
    }

    if ($PSCmdlet.ShouldProcess('aks-preview', 'Add Azure CLI extension')) {
        Write-Host "Installing Azure CLI extension 'aks-preview'..."
        az extension add --name aks-preview
        Write-Host "'aks-preview' extension installation process completed."
    }

    if ($PSCmdlet.ShouldProcess('ssh', 'Add Azure CLI extension')) {
        Write-Host "Installing Azure CLI extension 'ssh'..."
        az extension add --name ssh
        Write-Host "'ssh' extension installation process completed."
    }

    # Dont forget to add any CA cert (zscaler) if needed
}
