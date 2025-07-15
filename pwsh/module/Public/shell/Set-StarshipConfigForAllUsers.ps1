function Set-StarshipConfigForAllUsers {
<#
.SYNOPSIS
    This function sets the Starship configuration for all users on the system.

.DESCRIPTION
    The `Set-StarshipConfigForAllUsers` function searches for the user profiles on the system,
    creates a `.config` directory in each profile (if it doesn't exist), and then writes the
    Starship configuration (`starship.toml`) to that directory. If the file already exists, the
    function does not overwrite it.

.PARAMETER configContent
    The content to be written to each user's `starship.toml` file. This can be provided either
    as a parameter or defined as a global variable in the session.

.EXAMPLE
    $configContent = @"
    [character]
    symbol = "❯"
    color = "blue"
    "@

    Set-StarshipConfigForAllUsers

    This will set the Starship configuration for all users on the system using the specified content.

.EXAMPLE
    Set-StarshipConfigForAllUsers -configContent @"
    [character]
    symbol = "❯"
    color = "blue"
    "@

    This will set the Starship configuration for all users by passing the config content directly as a parameter.

.NOTES
    Author: Michiel VH
    This function requires administrative privileges to access other user profiles.
#>

    # TODO: add a step that checks if starship is already installed installed, if not install it with choco

    [CmdletBinding()]
    param (
        # Define a string parameter for the starship configuration content
        [Parameter(Mandatory=$true, HelpMessage="Provide the content for the starship.toml configuration.")]
        [string]$configContent
    )
    # Get all user profile directories
    $userProfiles = Get-WmiObject Win32_UserProfile | Where-Object { $_.Special -eq $false }
    # loop through all users
    foreach ($uprofile in $userProfiles) {
        $userConfigDir = Join-Path $uprofile.LocalPath ".config"
        $starshipFile = Join-Path $userConfigDir "starship.toml"
        # Check if .config directory exists, create it if not
        if (-Not (Test-Path $userConfigDir)) {
            Write-Host "Creating .config directory for user: $($uprofile.LocalPath)"
            New-Item -Path $userConfigDir -ItemType Directory -Force
        }
        # Write the starship.toml configuration file
        if (-Not (Test-Path $starshipFile)) {
            Write-Host "Creating starship.toml for user: $($uprofile.LocalPath)"
            $configContent | Out-File -FilePath $starshipFile -Encoding utf8
        } else {
            Write-Host "starship.toml already exists for user: $($uprofile.LocalPath)"
        }
    }
}