function Install-Winget {
<#
.SYNOPSIS
    Installs winget (Windows Package Manager) if it is not already installed on the system.

.DESCRIPTION
    The `Install-Winget` function checks if winget is installed on the system by attempting to retrieve its version. If winget is not installed, the function will download and install the App Installer package from Microsoft. If winget is already installed, it outputs the current version.

.EXAMPLE
    Install-Winget

    This example checks if winget is installed on the system. If it is not, the function installs winget. If it is already installed, it prints the installed version of winget.

.NOTES
    Author: Michiel VH
    Requires: Internet connection for downloading App Installer if it is not already installed.
    Requires: Windows 10 version 1809 or later, or Windows 11.
    Note: The latest version of App Installer requires Windows App Runtime 1.8. If installation fails, install Windows App Runtime 1.8 from the Microsoft Store first, then retry.

.LINK
    https://learn.microsoft.com/en-us/windows/package-manager/winget/
    Learn more about winget and Windows Package Manager.
#>

    # Check if winget is already installed and working
    $wingetCommand = Get-Command -Name winget -ErrorAction SilentlyContinue
    
    if ($wingetCommand) {
        try {
            $wingetVersion = winget --version 2>&1
            if ($wingetVersion -and -not ($wingetVersion -match "error|Error|ERROR|not found")) {
                Write-Output "winget is already installed. Version: $wingetVersion"
                return
            }
        }
        catch {
            # Version check failed, but command exists - might need registration
        }
    }

    Write-Output "winget will be installed or registered"

    try {
        # Check Windows version (winget requires Windows 10 1809+ or Windows 11)
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $osVersion = [Version](($osInfo.Version -split '\.')[0..1] -join '.')
        
        if ($osVersion -lt [Version]"10.0") {
            throw "winget requires Windows 10 version 1809 or later, or Windows 11. Current OS version: $($osInfo.Version)"
        }

        # Try registration method first (App Installer might be installed but not registered)
        Write-Output "Attempting to register App Installer (if already installed)..."
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
            Start-Sleep -Seconds 2
            
            # Verify registration worked
            $wingetCommand = Get-Command -Name winget -ErrorAction SilentlyContinue
            if ($wingetCommand) {
                try {
                    $wingetVersion = winget --version 2>&1
                    if ($wingetVersion -and -not ($wingetVersion -match "error|Error|ERROR|not found")) {
                        Write-Output "winget registered successfully. Version: $wingetVersion"
                        return
                    }
                }
                catch {
                    # Registration didn't work, continue to download
                }
            }
        }
        catch {
            # Registration failed, App Installer probably not installed - continue to download
            Write-Output "App Installer not found via registration. Downloading from Microsoft..."
        }

        # Download App Installer package (includes winget) from official Microsoft source
        Write-Output "Downloading App Installer package from Microsoft..."
        $appInstallerPath = Join-Path -Path $env:TEMP -ChildPath "Microsoft.DesktopAppInstaller.msixbundle"
        $appInstallerUrl = "https://aka.ms/getwinget"
        
        Invoke-WebRequest -Uri $appInstallerUrl -OutFile $appInstallerPath -ErrorAction Stop

        # Install App Installer package
        Write-Output "Installing App Installer package..."
        Add-AppxPackage -Path $appInstallerPath -ErrorAction Stop

        Write-Output "winget has been successfully installed."
        
        # Verify installation
        Start-Sleep -Seconds 3
        $wingetCommand = Get-Command -Name winget -ErrorAction SilentlyContinue
        if ($wingetCommand) {
            try {
                $wingetVersion = winget --version 2>&1
                if ($wingetVersion -and -not ($wingetVersion -match "error|Error|ERROR|not found")) {
                    Write-Output "Verified: winget version $wingetVersion is now available."
                }
                else {
                    Write-Warning "winget was installed but version check failed. You may need to restart your terminal."
                }
            }
            catch {
                Write-Warning "winget was installed but version check failed. You may need to restart your terminal."
            }
        }
        else {
            Write-Warning "winget installation completed, but command not yet available. Please restart your terminal."
        }
    }
    catch {
        if ($_.Exception.Message -like "*80073CF3*" -or $_.Exception.Message -like "*Windows App Runtime*") {
            Write-Error "Installation failed because Windows App Runtime 1.8 is required."
            Write-Error "Please install Windows App Runtime 1.8 from the Microsoft Store first:"
            Write-Error "https://apps.microsoft.com/store/detail/windows-app-runtime/9P9TQF7MRM4R"
            throw "Windows App Runtime 1.8 must be installed before winget can be installed."
        }
        else {
            Write-Error "Failed to install winget: $_"
            throw
        }
    }
    finally {
        # Clean up downloaded file
        if ($appInstallerPath -and (Test-Path $appInstallerPath)) {
            Remove-Item -Path $appInstallerPath -Force -ErrorAction SilentlyContinue
        }
    }
}
