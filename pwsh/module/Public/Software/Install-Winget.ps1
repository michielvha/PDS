function Install-Winget {
<#
.SYNOPSIS
    Installs winget (Windows Package Manager) if it is not already installed on the system.

.DESCRIPTION
    The `Install-Winget` function checks if winget is installed on the system by attempting to retrieve its version. If winget is not installed, the function will download and install the App Installer package from Microsoft, which includes winget. If winget is already installed, it outputs the current version.

.EXAMPLE
    Install-Winget

    This example checks if winget is installed on the system. If it is not, the function installs winget. If it is already installed, it prints the installed version of winget.

.NOTES
    Author: Michiel VH
    Requires: Internet connection for downloading App Installer if it is not already installed.
    Requires: Windows 10 version 1809 or later, or Windows 11.
    Administrator privileges may be required for installing AppX packages.

.LINK
    https://learn.microsoft.com/en-us/windows/package-manager/winget/
    Learn more about winget and Windows Package Manager.
#>

    # Check if winget is already installed
    $wingetCommand = Get-Command -Name winget -ErrorAction SilentlyContinue
    
    if ($wingetCommand) {
        try {
            $wingetVersion = winget --version 2>&1
            Write-Output "winget is already installed. Version: $wingetVersion"
            return
        }
        catch {
            # If version check fails, winget might be a stub, so continue with installation
            Write-Warning "winget command found but version check failed. Attempting installation..."
        }
    }

    Write-Output "winget will be installed"

    try {
        # Check Windows version (winget requires Windows 10 1809+ or Windows 11)
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $osVersion = [Version](($osInfo.Version -split '\.')[0..1] -join '.')
        
        if ($osVersion -lt [Version]"10.0") {
            throw "winget requires Windows 10 version 1809 or later, or Windows 11. Current OS version: $($osInfo.Version)"
        }

        # Check and install Windows App Runtime 1.8 (required dependency)
        Write-Output "Checking for Windows App Runtime 1.8..."
        $war18 = Get-AppxPackage | Where-Object { $_.Name -like "*Microsoft.WindowsAppRuntime*" -and $_.Version -like "1.8.*" } | Select-Object -First 1
        
        if (-not $war18) {
            Write-Output "Windows App Runtime 1.8 not found. Installing prerequisite..."
            $war18Path = Join-Path -Path $env:TEMP -ChildPath "Microsoft.WindowsAppRuntime.1.8_x64.msix"
            
            try {
                # Try direct download from Microsoft
                $war18Url = "https://aka.ms/Microsoft.WindowsAppRuntime.1.8_x64.msix"
                Write-Output "Downloading Windows App Runtime 1.8..."
                Invoke-WebRequest -Uri $war18Url -OutFile $war18Path -ErrorAction Stop
                
                Write-Output "Installing Windows App Runtime 1.8..."
                Add-AppxPackage -Path $war18Path -ErrorAction Stop
                Write-Output "Windows App Runtime 1.8 installed successfully."
            }
            catch {
                # Alternative: Try downloading from GitHub releases
                Write-Warning "Failed to download from primary source. Trying alternative method..."
                try {
                    $releasesUrl = "https://api.github.com/repos/microsoft/windowsappruntime/releases/latest"
                    $release = Invoke-RestMethod -Uri $releasesUrl -ErrorAction Stop
                    $msixAsset = $release.assets | Where-Object { 
                        $_.name -like "*WindowsAppRuntime*" -and $_.name -like "*1.8*" -and $_.name -like "*x64*" -and $_.name -like "*.msix" 
                    } | Select-Object -First 1
                    
                    if ($msixAsset) {
                        Write-Output "Downloading from GitHub releases..."
                        Invoke-WebRequest -Uri $msixAsset.browser_download_url -OutFile $war18Path -ErrorAction Stop
                        Add-AppxPackage -Path $war18Path -ErrorAction Stop
                        Write-Output "Windows App Runtime 1.8 installed successfully."
                    }
                    else {
                        throw "Could not find Windows App Runtime 1.8 package to download"
                    }
                }
                catch {
                    Write-Error "Failed to install Windows App Runtime 1.8: $_"
                    Write-Error "Please install it manually from: https://apps.microsoft.com/store/detail/windows-app-runtime/9P9TQF7MRM4R"
                    throw "Windows App Runtime 1.8 is required but could not be installed automatically."
                }
            }
            finally {
                if (Test-Path $war18Path) {
                    Remove-Item -Path $war18Path -Force -ErrorAction SilentlyContinue
                }
            }
            
            # Verify installation
            Start-Sleep -Seconds 3
            $war18 = Get-AppxPackage | Where-Object { $_.Name -like "*Microsoft.WindowsAppRuntime*" -and $_.Version -like "1.8.*" } | Select-Object -First 1
            if (-not $war18) {
                throw "Windows App Runtime 1.8 installation verification failed. Please install manually."
            }
        }
        else {
            Write-Output "Windows App Runtime 1.8 is already installed (version: $($war18.Version))."
        }

        # Download App Installer package (includes winget)
        Write-Output "Downloading App Installer package..."
        $appInstallerPath = Join-Path -Path $env:TEMP -ChildPath "Microsoft.DesktopAppInstaller.msixbundle"
        
        # Try the official Microsoft download link
        $appInstallerUrl = "https://aka.ms/getwinget"
        
        try {
            Invoke-WebRequest -Uri $appInstallerUrl -OutFile $appInstallerPath -ErrorAction Stop
        }
        catch {
            # Alternative: Download from GitHub releases if official link fails
            Write-Warning "Failed to download from official source. Trying alternative method..."
            $releasesUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
            $release = Invoke-RestMethod -Uri $releasesUrl -ErrorAction Stop
            $msixAsset = $release.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
            
            if ($msixAsset) {
                Write-Output "Downloading from GitHub releases..."
                Invoke-WebRequest -Uri $msixAsset.browser_download_url -OutFile $appInstallerPath -ErrorAction Stop
            }
            else {
                throw "Could not find App Installer package to download"
            }
        }

        # Install App Installer package
        Write-Output "Installing App Installer package..."
        Add-AppxPackage -Path $appInstallerPath -ErrorAction Stop

        Write-Output "winget has been successfully installed."
        
        # Verify installation
        Start-Sleep -Seconds 2
        $wingetCommand = Get-Command -Name winget -ErrorAction SilentlyContinue
        if ($wingetCommand) {
            try {
                $wingetVersion = winget --version 2>&1
                Write-Output "Verified: winget version $wingetVersion is now available."
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
        Write-Error "Failed to install winget: $_"
        throw
    }
    finally {
        # Clean up downloaded file
        if (Test-Path $appInstallerPath) {
            Remove-Item -Path $appInstallerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

