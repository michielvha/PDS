function New-AzSession {
    <#
    .SYNOPSIS
        Sets up and establishes a new Azure PowerShell session.

    .DESCRIPTION
        This function performs the following actions to establish a working Azure PowerShell session:
        1. Sets the PowerShell execution policy to RemoteSigned for the current user
        2. Installs the Az PowerShell module if not already installed
        3. Connects to an Azure account using Connect-AzAccount

        Use this function when you need to quickly set up a new Azure PowerShell environment
        or reconnect to Azure.

    .EXAMPLE
        New-AzSession

        Sets up the PowerShell environment and connects to an Azure account.
        This will prompt for credentials to log into Azure.

    .NOTES
        Author: Michiel VH
        This function requires an internet connection and valid Azure credentials.

        If you're behind a corporate proxy or have Zscaler or similar security software,
        you may need to add a certificate authority (CA) certificate.

    .LINK
        https://docs.microsoft.com/en-us/powershell/azure/install-azure-powershell
        https://docs.microsoft.com/en-us/powershell/module/az.accounts/connect-azaccount
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param()


    Write-Host "Setting up Azure session..."
    if ($PSCmdlet.ShouldProcess('CurrentUser', 'Set execution policy to RemoteSigned')) {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    }

    if ($PSCmdlet.ShouldProcess('Az', 'Install module for the current user')) {
        Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
    }

    if ($PSCmdlet.ShouldProcess('Azure account', 'Connect')) {
        Connect-AzAccount
    }

    # Dont forget to add any CA cert (zscaler) if needed
}
