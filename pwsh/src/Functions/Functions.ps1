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
    $packagesToInstall = Get-Content -Path $packageFilePath
    Write-Host "The following packages will be installed if not already present:"
    $packagesToInstall

    foreach ($packageName in $packagesToInstall) {
        Write-Host "`nAttempting to install $packageName..."
        choco install $packageName -y
    }
}

function Set-PSReadLineModule {
    # Define the commands you want to append to the profile
$commands = @"
Install-Module -Name PSReadLine -Force -SkipPublisherCheck
Import-Module -Name PSReadLine
Invoke-Expression (&starship init powershell)
Set-PSReadLineOption -PredictionViewStyle ListView
"@

# Append the commands to the global profile using tee
$commands | Out-File -Append -FilePath $PROFILE.AllUsersAllHosts -Encoding utf8

}

function Install-Kubectl {
    # using azure cli to auto configure kubectl / kubelogin etc
    az aks install-cli
}