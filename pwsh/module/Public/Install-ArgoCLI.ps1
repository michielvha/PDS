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
    Author: itmvha
    Requires: Internet connection for downloading ArgoCD CLI if it is not already installed.


.LINK
    https://argocd-readthedocs.io/
    Learn more about ArgoCD CLI and how it is used for package management.
#>

# 1. Check if installed
$installedVersion = argocd version --client | out-null

# 2. if not installed
  if (!$installedVersion) {
   Write-Output "Fetching latest version"
   $version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
   $url = "https://github.com/argoproj/argo-cd/releases/download/" + $version + "/argocd-windows-amd64.exe"
   $output = "$env:USERPROFILE\sys"

   if (!(Test-Path $output)) {
            Write-Output "sys directory doesn't yet exist in user's profile, creating..."
            New-Item -ItemType Directory -Path $output # | Out-Null
   }

   Invoke-WebRequest -Uri $url -OutFile $output

    # Determine which PATH to modify (User or System) based on admin rights
    if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -match "S-1-5-32-544") {
        # User is an Administrator - modify System PATH
        $path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
        if ($path -notlike "*$output*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$path;$output", [System.EnvironmentVariableTarget]::Machine)
            Write-Output "Added $output to the System PATH. Please restart your terminal or log off for changes to take effect."
        }
    } else {
        # User is not an Administrator - modify User PATH
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
        if ($userPath -notlike "*$output*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$output", [System.EnvironmentVariableTarget]::User)
            Write-Output "Added $output to the User PATH. Please restart your terminal for changes to take effect."
        }
    }

  } else {
   Write-Output "ArgoCD CLI is already installed. Version: $installedVersion"
  }
}
