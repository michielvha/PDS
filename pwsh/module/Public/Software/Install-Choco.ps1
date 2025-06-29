function Install-Choco {
<#
.SYNOPSIS
    Installs Chocolatey if it is not already installed on the system.

.DESCRIPTION
    The `Install-Choco` function checks if Chocolatey is installed on the system by attempting to retrieve its version. If Chocolatey is not installed, the function will download and execute the official installation script from the Chocolatey website. If Chocolatey is already installed, it outputs the current version.

.EXAMPLE
    Install-Choco

    This example checks if Chocolatey is installed on the system. If it is not, the function installs Chocolatey. If it is already installed, it prints the installed version of Chocolatey.

.NOTES
    Author: Michiel VH
    Requires: Internet connection for downloading Chocolatey if it is not already installed.
    This function modifies the execution policy temporarily to allow Chocolatey to be installed.

.LINK
    https://chocolatey.org/
    Learn more about Chocolatey and how it is used for package management.
#>
  $chocoVersion = choco --version 2>$null
  if (!$chocoVersion) {
   Write-Output "Chocolatey will be installed"
   Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  } else {
   Write-Output "Chocolatey is already installed. Version: $chocoVersion"
  }
}
