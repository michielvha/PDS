function Set-PSReadLineModule {
    <#
    .SYNOPSIS
        Configures the PSReadLine module for all users by installing and importing the module, setting PSReadLine options, and appending commands to the global profile.

    .DESCRIPTION
        The `Set-PSReadLineModule` function automates the installation and configuration of the PSReadLine module for all users. It installs the PSReadLine module, imports it into the session, initializes Starship with PowerShell, and sets the `PredictionViewStyle` to `ListView`. The configuration commands are appended to the global PowerShell profile, ensuring that these settings apply to all users across all hosts.

    .EXAMPLE
        Set-PSReadLineModule

        This command installs and configures the PSReadLine module for all users, initializes Starship, and sets the PSReadLine prediction style to `ListView`. It appends these configurations to the global profile, making them available to all users.

    .EXAMPLE
        $commands = @"
        Install-Module -Name PSReadLine -Force -SkipPublisherCheck -Scope CurrentUser
        Import-Module -Name PSReadLine
        Invoke-Expression (&starship init powershell)
        Set-PSReadLineOption -PredictionViewStyle ListView
        "@
        Set-PSReadLineModule

        In this example, the same commands are written to the global profile to ensure PSReadLine and Starship are properly configured for all users in PowerShell.

    .NOTES
        Author: MKTHEPLUGG
        Requires: PowerShell 5.1 or higher and Starship CLI installed.
        This function modifies the global profile located at `$PROFILE.AllUsersAllHosts`, and administrative privileges are required to make these changes.

    .LINK
        https://www.powershellgallery.com/packages/PSReadLine/2.2.6
        Learn more about `PSReadline Module` and how it is used to manage powershell.

        https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption?view=powershell-7.4
        Learn about all the different parameters that can be used to configure the module.

    #>


    # TODO: Make this function more general by not hardcoding the values and just making this function about adding some to profile of all users.
$commands = @"
Import-Module -Name PSReadLine
Invoke-Expression (&starship init powershell)
Set-PSReadLineOption -PredictionViewStyle ListView
"@


if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "This function needs to be ran as admin please rerun it with the proper rights."
    exit
} else {
    Write-Output "PSReadLine Module will be installed"
    Install-Module -Name PSReadLine -Force -SkipPublisherCheck
}

# Append the commands to the global profile using tee
$commands | Out-File -FilePath $PROFILE.AllUsersAllHosts -Encoding utf8 -Append

}