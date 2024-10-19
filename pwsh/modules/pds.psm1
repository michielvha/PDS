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


