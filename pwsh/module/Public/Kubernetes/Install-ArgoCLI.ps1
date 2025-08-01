function Install-ArgoCLI {
<#
.SYNOPSIS
    Installs ArgoCD CLI if it is not already installed on the system.

.DESCRIPTION
    The `Install-ArgoCLI` function checks if ArgoCD CLI is installed on the system by attempting to retrieve its version. If ArgoCD CLI is not installed, the function will download and execute the official installation script from the ArgoCD CLI website. If ArgoCD CLI is already installed, it outputs the current version.

.EXAMPLE
    Install-ArgoCLI

    This example checks if ArgoCD CLI is installed on the system. If it is not, the function installs ArgoCD CLI. If it is already installed, it prints the installed version of ArgoCD CLI.

.NOTES
    Author: Michiel VH
    Requires: Internet connection for downloading ArgoCD CLI if it is not already installed.


.LINK
    https://argocd-readthedocs.io/
    Learn more about ArgoCD CLI and how it is used for package management.
#>

$binDir = "$env:USERPROFILE\AppData\Local\bin"

# 1. Check if installed
$installedVersion = argocd version --client | out-null

# 2. verify if bin directory exists in user's profile
if (!(Test-Path $binDir)) {
    Write-Output "$binDir directory doesn't yet existe, creating..."
    New-Item -ItemType Directory -Path $binDir # | Out-Null
}

# 3. verify if bin directory is in the PATH, if not add it - TODO: check if we even want to add to systempath and not just current user no matter of admin rights
# maybe add a switch for full system install or user only
# Determine which PATH to modify (User or System) based on admin rights
if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -match "S-1-5-32-544") {
    # User is an Administrator - modify System PATH
    $path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    if ($path -notlike "*$binDir*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$path;$binDir", [System.EnvironmentVariableTarget]::Machine)
        Write-Output "Added $binDir to the System PATH. Please restart your terminal or log off for changes to take effect."
    }
} else {
    # User is not an Administrator - modify User PATH
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
    if ($userPath -notlike "*$binDir*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", [System.EnvironmentVariableTarget]::User)
        Write-Output "Added $binDir to the User PATH. Please restart your terminal for changes to take effect."
    }
}

# 4. install if needed
  if (!$installedVersion) {
   Write-Output "Fetching latest version"
   $version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
   $url = "https://github.com/argoproj/argo-cd/releases/download/" + $version + "/argocd-windows-amd64.exe"
   $output = "$binDir\argocd.exe"

   Invoke-WebRequest -Uri $url -OutFile $output
  } else {
   Write-Output "ArgoCD CLI is already installed. Version: $installedVersion"
  }
}
