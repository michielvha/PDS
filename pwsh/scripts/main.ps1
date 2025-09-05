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

# Import the required Functions from powershell gallery
if (-not (Get-Module -ListAvailable -Name PDS)) {
    Write-Host "PDS module not found. Installing PDS module..."
    Install-Module -Name PDS -Force
}
Import-Module -Name PDS

# insert step here for cleaning up w11 build.
# 1. Debloat windows => Use tiny11builder to clean windows image. I might add some extra cleanup steps later in script using Win11Debloat as inspiration.

# 2. Install package manager
# Check if already installed before installing chocolatey
Install-Choco

# Define an array of package names
$packagesToInstall = @(
    "nmap",
    "git",
    "curl",
    "azure-cli",
    "terraform",
    "pycharm-community",
    "angryip",
    "unxutils",
    "mobaxterm",
    "starship",
    "rpi-imager",
    "lens",
    "freelens",
    "grep",
    "bginfo",
    "gh",
    "docker",
    "docker-compose",
    "docker-desktop",
    "firefox",
    "awscli",
    "golang",
    "kubernetes-helm",
    "kubectl",
    "kustomize",
    "nodejs",
    "make",
    "golangci-lint",
    "zen-browser",
    "vscode",
    "rancher-desktop",
    "postman",
    "python3",
    "openssl",
    "pandoc",
    "openshift-cli",
    "argocd-cli",
    "nano-win",
    "pwsh",
    "jq",
    "yq",
    "powertoys",
    "ngrok",
    "awk",
    "bat"
)

# TODO: Evalute packages:
# - msys2: Unix-like shell & tools for Windows

Install-ChocoPackages -packagesToInstall $packagesToInstall


# 3. Configure psreadline module for all users
# https://www.powershellgallery.com/packages/PSReadLine/2.2.6
Set-PSReadLineModule

# 4. Install & Configure kubectl/login for K8S Cluster management
Install-AzureKubeCLI

# 5. shell customizations
# - Starship configuration
#   Define the content of the starship.toml file (modify as needed)
$configContent = @"
[azure]
disabled = false
format = 'on [$symbol($subscription)]($style) '
symbol = 'Azure ☁ '
style = 'blue bold'

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
# format = 'on [⛵ ($user on )($cluster in )$context \($namespace\)](dimmed green) '
disabled = false
contexts = [
  { context_pattern = "dev.local.cluster.k8s", style = "green", symbol = "💔 " },
]

[terraform]
format = '[🏎💨 $workspace]($style) '
"@

# Run the function to create starship.toml for all users
Set-StarshipConfigForAllUsers -configContent $configContent

# - ncurl alias
#   for powershell 5.1 we need a seperate alias for curl since it conflicts with the native curl binary
Register-NativeCurl

# - auto import PDS module & chocolatey profile
#    includes usefull functions like `refreshenv` from chocolatey profile and ofcourse giving access to the PDS module by default.
Set-UserProfile

# 6. Configuring WSL
Install-WSL -d Kali-Linux


# ...
# x. Add logging and error handeling.
