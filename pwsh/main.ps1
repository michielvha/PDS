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



function Install-ChocoPackagesFromFile {
    param (
        [string]$packageFilePath
    )

    # Check if the file exists
    if (-Not (Test-Path $packageFilePath)) {
        Write-Host "The file $packageFilePath does not exist."
        return
    }

    # Get all installed package names (fetch the list of installed packages and extract only the names, skipping empty lines, lines starting with two numbers, a number followed by whitespace, or a hyphen)
    $installedPackages = choco list -i | ForEach-Object {
        $line = ($_ -split '\|')[0].Trim()  # Split on '|' and take the package name part, trimming spaces

        # Filter out any empty or whitespace lines and lines that start with two numbers, a number followed by whitespace, or a hyphen
        if (-not [string]::IsNullOrWhiteSpace($line) -and $line -notmatch '^\d{2}' -and $line -notmatch '^\d\s' -and $line -notmatch '^-') {
            $line
        }
    }



    # Convert installed packages to an array for easy lookup
    $installedPackagesList = $installedPackages | Sort-Object
    write-host "these packages are already installed:"
    $installedPackagesList



    # Read all package names from the file (packages you want to install)
    $packagesToInstall = Get-Content -Path $packageFilePath
    write-host "the following packages will be checked:"
    $packagesToInstall

    # works till here, now properly check packages against each other and install

    # Loop through each package in the file
    foreach ($packageName in $packagesToInstall) {
        # Check if the package is installed by comparing with each installed package
        $isInstalled = $false
        foreach ($installedPackage in $installedPackagesList) {
            if ($installedPackage -like $packageName) {
                write-host $installedPackage
                $isInstalled = $true
                break  # Exit inner loop as we found a match
            }
        }

        if ($isInstalled) {
            Write-Host "`n$packageName is already installed."
        } else {
            Write-Host "`n$packageName is not installed. Installing..."
            choco install $packageName -y
        }
    }
}

# Example usage of the function
Install-ChocoPackagesFromFile -packageFilePath ".\packages.env"

