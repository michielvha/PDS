# -- Environment --

# Set $ScriptPath to current directory compatible with PS2EXE
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}
else {
    $ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    if (!$ScriptPath) {
        $ScriptPath = "."
    }
}

# Import the required Functions from src
# Import-Module -Name "$scriptPath\src\Functions\Functions.psd1"

# Check if already installed before installing chocolatey
$chocoVersion = choco --version 2>$null
if (!$chocoVersion) {
 Write-Output "Chocolatey will be installed"
 Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
} else {
 Write-Output "Chocolatey is already installed. Version: $chocoVersion"
}

# Define an array of package names
$packagesToInstall = @(
    "nmap",
    "git",
    "azure-cli",
    "terraform",
    "pycharm-community",
    "angryip",
    "unxutils",
    "mobaxterm",
    "starship",
    "rpi-imager",
    "openlens",
    "grep"
)
# Function to install the packages (same as before)
function Install-ChocoPackagesFromFile {
    param (
        [string[]]$packagesToInstall  # Change to accept an array
    )

    Write-Host "The following packages will be installed if not already present:"
    $packagesToInstall

    foreach ($packageName in $packagesToInstall) {
        Write-Host "`nAttempting to install $packageName..."
        choco install $packageName -y
    }
}
Install-ChocoPackagesFromFile -packagesToInstall $packagesToInstall

start-sleep 20

# configure psreadline module for all users
# https://www.powershellgallery.com/packages/PSReadLine/2.2.6
function Set-PSReadLineModule {
$commands = @"
Install-Module -Name PSReadLine -Force -SkipPublisherCheck
Import-Module -Name PSReadLine
Invoke-Expression (&starship init powershell)
Set-PSReadLineOption -PredictionViewStyle ListView
"@

# Append the commands to the global profile using tee
$commands | Out-File -Append -FilePath $PROFILE.AllUsersAllHosts -Encoding utf8

}
Set-PSReadLineModule

# using azure cli to auto configure kubectl / kubelogin etc
az aks install-cli

# 3. shell customizations with the startship and config file thing
# => Figure out a way to copy default config to all users files

# 4. package with cicd pipeline into exe that can easily be ran as admin
# 5. Add logging and error handeling.
