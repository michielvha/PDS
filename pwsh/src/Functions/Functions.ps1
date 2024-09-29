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
    Write-Host $packagesToInstall

    foreach ($packageName in $packagesToInstall) {
        Write-Host "`nAttempting to install $packageName..."
        choco install $packageName -y
    }
}
