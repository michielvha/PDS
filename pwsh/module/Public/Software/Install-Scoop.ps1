function Install-Scoop {
    <#
.SYNOPSIS
    Installs Scoop if it is not already installed on the system.

.DESCRIPTION
    The `Install-Scoop` function checks whether Scoop is available by attempting to locate the `scoop` command and retrieve its version. If Scoop is not installed, the function sets the execution policy for the current user to `RemoteSigned` and runs the official installer from `get.scoop.sh`, with `-RunAsAdmin` in an elevated session, and writes an error when Scoop is still not available afterwards. If Scoop is already installed, it outputs the current installed version.

.EXAMPLE
    Install-Scoop

    Installs Scoop if it is missing; otherwise prints the installed version of Scoop.

.NOTES
    Author: Michiel VH
    Requires: Internet connection to download Scoop if it is not already installed.
    This function may modify the execution policy (CurrentUser scope) to allow installation.

.LINK
    https://scoop.sh/
    Learn more about Scoop and how it is used for package management.
#>
    $Command = Get-Command -Name scoop -ErrorAction SilentlyContinue
    if (!$Command) {
        Write-Output "Scoop will be installed"
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
        # Scoop's documented file install: download the installer, then run the file.
        $installer = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "scoop-install-$([guid]::NewGuid()).ps1"
        # The installer aborts in an elevated session unless it is told to run as administrator.
        $installerArgs = @{}
        if (Test-Admin) {
            $installerArgs['RunAsAdmin'] = $true
        }
        try {
            Invoke-RestMethod -Uri 'https://get.scoop.sh' -OutFile $installer
            & $installer @installerArgs
        }
        finally {
            Remove-Item -Path $installer -Force -ErrorAction SilentlyContinue
        }
        # The installer reports a failure with Write-Host and exit, so check the result.
        if (-not (Get-Command -Name scoop -ErrorAction SilentlyContinue)) {
            Write-Error "Scoop was not installed. The installer output above gives the reason."
        }
    }
    else {
        $Version = scoop --version
        Write-Output "Scoop is already installed. Version: $Version"
    }
}
