function Install-Scoop {
<#
.SYNOPSIS
    Installs Scoop if it is not already installed on the system.

.DESCRIPTION
    The `Install-Scoop` function checks whether Scoop is available by attempting to locate the `scoop` command and retrieve its version. If Scoop is not installed, the function sets the execution policy for the current user to `RemoteSigned` and runs the official installer from `get.scoop.sh`. If Scoop is already installed, it outputs the current installed version.

.EXAMPLE
    Install-Scoop

    Installs Scoop if it is missing; otherwise prints the installed version of Scoop.

.NOTES
    Author: Michiel VH
    Requires: Internet connection to download Scoop if it is not already installed.
    This function may modify the execution policy (CurrentUser scope) to allow installation.

.LINK
    https://scoop.sh/
    Learn more about Scoop and how it is used for package management.
#>
  $Command = Get-Command -Name scoop -ErrorAction SilentlyContinue
  if (!$Command) {
    Write-Output "Scoop will be installed"
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
  } else {
    $Version = scoop --version
    Write-Output "Scoop is already installed. Version: $Version"
  }
}
