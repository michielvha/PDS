function Set-AzCli {
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
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    # az extension add takes one name per --name, so add each extension with its own call
    $extensions = 'ssh', 'aks-preview', 'mesh', 'terraform'
    foreach ($extension in $extensions) {
        if ($PSCmdlet.ShouldProcess('Azure CLI', "Add extension $extension")) {
            az extension add --name $extension
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Adding the Azure CLI extension '$extension' failed with exit code $LASTEXITCODE."
            }
        }
    }
}
