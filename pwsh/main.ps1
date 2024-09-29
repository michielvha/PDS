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

# Install Chocolatey
# TODO: check before trying to install
$chocoVersion = choco --version 2>$null
if (!$chocoVersion) {
 Write-Output "Chocolatey will be installed"
 Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
} else {
 Write-Output "Chocolatey is already installed. Version: $chocoVersion"
}

# close and reopen shell if needed



# 2. once azure cli is installed use it to install kubectl

# 3. shell customizations with the startship and config file thing

# 4. package with cicd pipeline into exe that can easily be ran as admin

# 5. Add logging and error handeling.

# function check to put in seperate module


# Example usage of the function
Install-ChocoPackagesFromFile -packageFilePath "$ScriptPath\packages.env"

start-sleep 50