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

    # Read all package names from the file
    $packages = Get-Content -Path $packageFilePath

    # Loop through each package and check if it is installed
    foreach ($packageName in $packages) {
        if (-Not [string]::IsNullOrWhiteSpace($packageName)) {
            $packageName = $packageName.Trim()
            $installedPackages = choco list -l

            if ($installedPackages -match $packageName) {
                Write-Host "$packageName is already installed."
            } else {
                Write-Host "$packageName is not installed. Installing..."
                choco install $packageName -y
            }
        }
    }
}

Install-ChocoPackagesFromFile -packageFilePath ".\packages.env"

