function Install-ArgoCLI {
<#
.SYNOPSIS
    Installs Chocolatey if it is not already installed on the system.

.DESCRIPTION
    The `Install-Choco` function checks if Chocolatey is installed on the system by attempting to retrieve its version. If Chocolatey is not installed, the function will download and execute the official installation script from the Chocolatey website. If Chocolatey is already installed, it outputs the current version.

.EXAMPLE
    Install-Choco

    This example checks if Chocolatey is installed on the system. If it is not, the function installs Chocolatey. If it is already installed, it prints the installed version of Chocolatey.

.NOTES
    Author: MKTHEPLUGG
    Requires: Internet connection for downloading Chocolatey if it is not already installed.
    This function modifies the execution policy temporarily to allow Chocolatey to be installed.

.LINK
    https://chocolatey.org/
    Learn more about Chocolatey and how it is used for package management.
#>

# 1. Check if installed
$installedVersion = argocd version --client | out-null

# 2. if not installed
  if (!$installedVersion) {
   Write-Output "Fetching latest version"
   $version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
   $url = "https://github.com/argoproj/argo-cd/releases/download/" + $version + "/argocd-windows-amd64.exe"
   $output = "C:\tools\argocd.exe"

   if (!(Test-Path $output)) {
            Write-Output "Tools directory doesn't yet exist on C:\, Creating..."
            New-Item -ItemType Directory -Path $output # | Out-Null
   }

   Invoke-WebRequest -Uri $url -OutFile $output

    # Add to system PATH if not already present
    $path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    if ($path -notlike "*$output*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$path;$output", [System.EnvironmentVariableTarget]::Machine)
        Write-Output "ArgoCD CLI path added to system PATH. Please restart your terminal or log off for changes to take effect."
    }

  } else {
   Write-Output "ArgoCD CLI is already installed. Version: $installedVersion"
  }
}
