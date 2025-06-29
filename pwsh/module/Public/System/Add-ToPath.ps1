function Add-ToPath {
    <#
    .SYNOPSIS
        Adds a path to the user or system PATH environment variable.

    .DESCRIPTION
        This function adds a path to the user or system PATH environment variable.

    .PARAMETER PathToAdd
        The path to add to the PATH environment variable.

    .PARAMETER SystemPath
        If set, modifies the system PATH instead of the user PATH.

    .EXAMPLE
        Add-ToPath -PathToAdd "C:\MyCustomTools"

        Adds "C:\MyCustomTools" to the user PATH environment variable.

    .EXAMPLE
        Add-ToPath -PathToAdd "C:\SystemWideTools" -SystemPath

        Adds "C:\SystemWideTools" to the system PATH environment variable.
    .NOTES
        Author: Michiel VH
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$PathToAdd,

        [switch]$SystemPath  # If set, modifies system PATH instead of user PATH
    )

    # Normalize path
    $PathToAdd = $PathToAdd -replace '\\$', ''  # Remove trailing backslash
    $CurrentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")

    if ($SystemPath) {
        $CurrentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    }

    # Check if path is already in PATH
    if ($CurrentPath -split ";" -contains $PathToAdd) {
        Write-Host "Path already exists in PATH variable." -ForegroundColor Yellow
    } else {
        # Append the new path
        $NewPath = "$CurrentPath;$PathToAdd"

        # Persist the change
        if ($SystemPath) {
            [System.Environment]::SetEnvironmentVariable("Path", $NewPath, "Machine")
            Write-Host "Added $PathToAdd to system PATH." -ForegroundColor Green
        } else {
            [System.Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
            Write-Host "Added $PathToAdd to user PATH." -ForegroundColor Green
        }
    }

    # Also update current session PATH
    $env:Path += ";$PathToAdd"
    Write-Host "Updated PATH for the current session."
}

# Usage:
# Add-ToPath -PathToAdd "C:\MyCustomTools"
# Add-ToPath -PathToAdd "C:\SystemWideTools" -SystemPath  # To modify system PATH
