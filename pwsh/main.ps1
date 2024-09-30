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
# => Figure out a way to copy default config to all users files, do it like a bove to make script portable in psreadlinemodule
# Define the content of the starship.toml file (modify as needed)
$configContent = @"
[azure]
disabled = false
format = 'on [$symbol($subscription)]($style) '
symbol = '󰠅 '
style = 'blue bold'

[git_branch]
symbol = '🌱 '
truncation_length = 4
truncation_symbol = ''
ignore_branches = ['master', 'main']

[git_commit]
commit_hash_length = 4
tag_symbol = '🔖 '

[git_state]
format = '[\($state( $progress_current of $progress_total)\)]($style) '
cherry_pick = '[🍒 PICKING](bold red)'

[kubernetes]
format = 'on [⛵ ($user on )($cluster in )$context \($namespace\)](dimmed green) '
disabled = false
contexts = [
  { context_pattern = "dev.local.cluster.k8s", style = "green", symbol = "💔 " },
]

[terraform]
format = '[🏎💨 $workspace]($style) '
"@

# Function to create the .config directory and add the starship.toml file
function Set-StarshipConfigForAllUsers {
    # Get all user profile directories
    $userProfiles = Get-WmiObject Win32_UserProfile | Where-Object { $_.Special -eq $false }

    foreach ($profile in $userProfiles) {
        $userConfigDir = Join-Path $profile.LocalPath ".config"
        $starshipFile = Join-Path $userConfigDir "starship.toml"

        # Check if .config directory exists, create it if not
        if (-Not (Test-Path $userConfigDir)) {
            Write-Host "Creating .config directory for user: $($profile.LocalPath)"
            New-Item -Path $userConfigDir -ItemType Directory -Force
        }

        # Write the starship.toml configuration file
        if (-Not (Test-Path $starshipFile)) {
            Write-Host "Creating starship.toml for user: $($profile.LocalPath)"
            $configContent | Out-File -FilePath $starshipFile -Encoding utf8
        } else {
            Write-Host "starship.toml already exists for user: $($profile.LocalPath)"
        }
    }
}

# Run the function to create starship.toml for all users
Create-StarshipConfigForAllUsers

# 4. package with cicd pipeline into exe that can easily be ran as admin
# 5. Add logging and error handeling.
