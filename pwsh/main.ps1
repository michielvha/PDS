# install chocolatey package manager

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# close and reopen shell if needed

#choco install nmap `
#              git `
#              azure-cli `
#              terraform `
#              pycharm-community `
#              angryip `                 # fast port scans ?
#              unxutils `                # a bunch of common unix utils like grep etc (look into overwriting aliases)
#             # raspberry pi imager / rufus

# Read the file and install each package
# Get-Content ".\packages.env" | ForEach-Object {
#    choco install $_ -y
#}


# te


# once azure cli is installed use it to install kubectl

# shell customizations with the startship and config file thing

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

    # Loop through each package and check if it is installed
    foreach ($packageName in $packagesToInstall) {
        if ($installedPackagesList -contains $packageName) {
            Write-Host "$packageName is already installed."
        } else {
            Write-Host "$packageName is not installed. Installing..."
            choco install $packageName -y
        }
    }
}

# Example usage of the function
Install-ChocoPackagesFromFile -packageFilePath ".\packages.env"

