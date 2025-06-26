function Set-DefaultProfile {
    <#
    .SYNOPSIS
        Adds specified commands to the global PowerShell profile for all users.

    .DESCRIPTION
        The `Set-DefaultProfile` function allows the user to pass in commands to be appended to the global PowerShell profile, located at `$PROFILE.AllUsersAllHosts`.
        This function is useful for automating configuration changes, setting up environments, and making sure that certain settings apply system-wide across all users.

        The function requires administrative privileges to modify the global profile. Any valid PowerShell commands passed to the function will be appended to the profile file.

    .PARAMETER Commands
        A string containing the PowerShell commands to append to the global profile for all users.

    .EXAMPLE
        $commands = @"
        Install-Module -Name PSReadLine -Force -SkipPublisherCheck
        Import-Module -Name PSReadLine
        Invoke-Expression (&starship init powershell)
        Set-PSReadLineOption -PredictionViewStyle ListView
        "@
        Set-DefaultProfile -Commands $commands

        This example appends the commands to install and configure the PSReadLine module and initialize the Starship prompt to the global profile.

    .EXAMPLE
        $customCommands = 'Set-Alias ll Get-ChildItem'
        Set-DefaultProfile -Commands $customCommands

        This example appends a custom alias definition for 'll' to the global profile, making it available for all users.

    .NOTES
        Author: MKTHEPLUGG
        Requires: PowerShell 5.1 or higher.
        This function modifies the global profile located at `$PROFILE.AllUsersAllHosts`, and administrative privileges are required to make these changes.

    .LINK
        https://learn.microsoft.com/en-us/powershell/scripting/setup/starting-with-profiles
        Learn more about PowerShell profiles and their usage.
    #>

    param (
        [Parameter(Mandatory=$true)]
        [string]$Commands
    )

    # Append the specified commands to the global profile
    $Commands | Out-File -FilePath $PROFILE.AllUsersAllHosts -Encoding utf8 -Append
}
