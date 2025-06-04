# -- Environment --
# -- **Fully Deprecated - functions are not reflective of current module, retained for if we want to revisit the concept** --

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

# insert step here for cleaning up w11 build.
# 1. Debloat windows => Use tiny11builder to clean windows image.

# 2. Install package manager
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


# 3. Configure psreadline module for all users
# https://www.powershellgallery.com/packages/PSReadLine/2.2.6
function Set-PSReadLineModule {
$commands = @"
Install-Module -Name PSReadLine -Force -SkipPublisherCheck
Import-Module -Name PSReadLine
Invoke-Expression (&starship init powershell)
Set-PSReadLineOption -PredictionViewStyle ListView
"@

# Append the commands to the global profile using tee
$commands | Out-File -FilePath $PROFILE.AllUsersAllHosts -Encoding utf8

}
Set-PSReadLineModule

# 4. Install & Configure kubectl/login
$KubectlVer = kubectl version 2>$null
$KubeloginVer = kubelogin --version  2>$null
if (!$KubectlVer -or !$KubeloginVer) {
 Write-Host "kubectl & kubelogin will be installed via az cli"
 az aks install-cli
} else {
 Write-Host "Kubectl and kubelogin are already installed:"
 $KubectlVer
 $KubeloginVer
}

# 5. shell customizations with the startship
# Define the content of the starship.toml file (modify as needed)
$configContent = @"
[azure]
disabled = false
format = 'on [$symbol($subscription)]($style) '
symbol = '󰠅 '
style = 'blue bold'

[aws]
format = 'on [$symbol($profile )(\($region\) )]($style)'
style = 'bold blue'
symbol = '🅰 '

[git_branch]
symbol = '🌱 '
truncation_length = 4
truncation_symbol = ''

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
    # loop through all users
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
Set-StarshipConfigForAllUsers

# 6.
# ...
# 8. package with cicd pipeline into exe (done)
# 9. Add logging and error handeling.
