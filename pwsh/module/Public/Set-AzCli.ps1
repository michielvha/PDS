Function Set-AzCli {
    <#
    .SYNOPSIS

    .DESCRIPTION


    .PARAMETER Username

    .PARAMETER Password

    .EXAMPLE

    .NOTES
        Author: MKTHEPLUGG
        This function modifies registry keys to configure auto-login, so it must be run with elevated (Administrator) privileges.

    .LINK

        List of available extensions:
        https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list

    #>

    az extension add --name ssh, aks-preview, mesh, terraform, storage
}
