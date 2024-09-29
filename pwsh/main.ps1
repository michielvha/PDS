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
Import-Module -Name "$scriptPath\src\Functions\Functions.psd1"

# Check if already installed before installing chocolatey
$chocoVersion = choco --version 2>$null
if (!$chocoVersion) {
 Write-Output "Chocolatey will be installed"
 Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
} else {
 Write-Output "Chocolatey is already installed. Version: $chocoVersion"
}


# install all the packages in the .env file, adjust as required
Install-ChocoPackagesFromFile -packageFilePath "$ScriptPath\packages.env"

# configure psreadline module for all users
# https://www.powershellgallery.com/packages/PSReadLine/2.2.6
Set-PSReadLineModule

# Use azure cli to configure kubectl / kubelogin
Install-Kubectl

# 3. shell customizations with the startship and config file thing

# 4. package with cicd pipeline into exe that can easily be ran as admin

# 5. Add logging and error handeling.

# function check to put in seperate module





start-sleep 50