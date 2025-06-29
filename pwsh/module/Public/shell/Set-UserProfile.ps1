function Set-UserProfile {
    <#
    .SYNOPSIS
        Adds persistent lines to a user's PowerShell profile script.

    .DESCRIPTION
        This function ensures that one or more specified lines are added to the user's PowerShell profile (e.g., `$PROFILE`).
        If the profile file doesn't exist, it will be created.
        The function checks for duplicate entries before appending, ensuring each line is added only once.

    .PARAMETER Lines
        An array of strings representing the lines you want to add to the user's PowerShell profile.
        Each line is checked to prevent duplication.

    .PARAMETER ProfilePath
        The full path to the profile file you want to update. Defaults to `$PROFILE`, which targets the current user's profile for the current host.

    .EXAMPLE
        Set-UserProfile

        Adds the default Chocolatey import line to the current user's PowerShell profile.

    .EXAMPLE
        Set-UserProfile -Lines @(
            'Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1',
            'Set-Alias ll Get-ChildItem'
        )

        Adds both the Chocolatey import and a custom alias to the current user's PowerShell profile.

    .EXAMPLE
        Set-UserProfile -ProfilePath "C:\Users\john\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Lines @(
            '# Custom profile for John',
            'Set-Alias gs git status'
        )

        Appends the specified lines to a custom profile path, useful when scripting for other users or hosts.

    .NOTES
        Author: Michiel VH
        This function is intended to be reusable and extensible for managing persistent shell customizations.

    .LINK
        https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles
    #>

    param(
        [string[]]$Lines = @(
            'Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1',
            'Import-Module PDS'
        ),
        [string]$ProfilePath = $PROFILE
    )

    if (-not (Test-Path $ProfilePath)) {
        New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
    }

    foreach ($line in $Lines) {
        $escapedPattern = [regex]::Escape($line)
        if (-not (Select-String -Path $ProfilePath -Pattern $escapedPattern -Quiet)) {
            Add-Content -Path $ProfilePath -Value $line
        }
    }
}
