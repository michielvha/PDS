function Install-WSTerminal {
<#
.SYNOPSIS
    Installs Windows Terminal if it is not already installed on the system.

.DESCRIPTION
    The `Install-WSTerminal` function checks if Windows Terminal is installed on the system by querying installed AppX packages. If Windows Terminal is not installed, the function will automatically fetch the latest version from the Microsoft Terminal GitHub repository, ensure Windows App Runtime is installed (which includes Microsoft.UI.Xaml.2.8), and install Windows Terminal using the MSIX bundle. If Windows Terminal is already installed, it outputs the current installed version.

.EXAMPLE
    Install-WSTerminal

    This example checks if Windows Terminal is installed on the system. If it is not, the function installs the latest version of Windows Terminal. If it is already installed, it prints the installed version.

.NOTES
    Author: Michiel VH
    Requires: Internet connection for downloading Windows Terminal if it is not already installed.
    Requires: Administrator privileges may be required for installing AppX packages.
    This function uses winget to install Windows App Runtime 1.8, which includes Microsoft.UI.Xaml.2.8 framework.

.LINK
    https://github.com/microsoft/terminal
    Learn more about Windows Terminal and its releases.
#>

    # Check if Windows Terminal is already installed
    $installedPackage = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue

    if ($installedPackage) {
        $version = $installedPackage.Version
        Write-Output "Windows Terminal is already installed. Version: $version"
        return
    }

    Write-Output "Windows Terminal will be installed"

    try {
        # Check and install Microsoft.UI.Xaml.2.8 framework (required dependency)
        Write-Output "Checking for Microsoft.UI.Xaml.2.8 framework..."
        $xamlFramework = Get-AppxPackage | Where-Object { $_.Name -like "*Microsoft.UI.Xaml.2.8*" } | Select-Object -First 1
        
        if (-not $xamlFramework) {
            Write-Output "Microsoft.UI.Xaml.2.8 framework not found. Installing Windows App Runtime 1.8 via winget..."
            
            # Use winget to install Windows App Runtime 1.8 (includes Microsoft.UI.Xaml.2.8)
            $wingetAvailable = Get-Command -Name "winget" -ErrorAction SilentlyContinue
            if (-not $wingetAvailable) {
                throw "winget is not available. Please install winget first or install Windows App Runtime 1.8 manually from: https://apps.microsoft.com/store/detail/windows-app-runtime/9P9TQF7MRM4R"
            }

            Write-Output "Installing Windows App Runtime 1.8 via winget..."
            $wingetOutput = winget install --id Microsoft.WindowsAppRuntime.1.8 --exact --accept-source-agreements --accept-package-agreements 2>&1
            Write-Output $wingetOutput
            
            # Wait for installation to complete
            Start-Sleep -Seconds 5
            
            # Verify installation
            $xamlFramework = Get-AppxPackage | Where-Object { $_.Name -like "*Microsoft.UI.Xaml.2.8*" } | Select-Object -First 1
            if (-not $xamlFramework) {
                throw "Windows App Runtime 1.8 installation failed or Microsoft.UI.Xaml.2.8 framework was not installed. Please install manually."
            }
            
            Write-Output "Windows App Runtime 1.8 installed successfully."
        }
        else {
            Write-Output "Microsoft.UI.Xaml.2.8 framework is already installed (version: $($xamlFramework.Version))."
        }

        # Download and install VCLibs (if needed)
        Write-Output "Checking for Visual C++ Runtime prerequisites..."
        $vclibs = Get-AppxPackage | Where-Object { $_.Name -like "*Microsoft.VCLibs*" } | Select-Object -First 1
        
        if (-not $vclibs) {
            Write-Output "Installing Visual C++ Runtime prerequisites..."
            $vclibsPath = Join-Path -Path $env:TEMP -ChildPath "Microsoft.VCLibs.x64.14.00.Desktop.appx"
            try {
                Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile $vclibsPath -ErrorAction Stop
                Add-AppxPackage -Path $vclibsPath -ErrorAction Stop
                Write-Output "Visual C++ Runtime installed successfully."
            }
            catch {
                Write-Warning "Failed to install VCLibs (may not be required): $_"
            }
            finally {
                if (Test-Path $vclibsPath) {
                    Remove-Item -Path $vclibsPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Write-Output "Visual C++ Runtime is already installed."
        }

        # Fetch latest release from GitHub API
        Write-Output "Fetching latest Windows Terminal version from GitHub..."
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/terminal/releases/latest" -ErrorAction Stop

        # Find the MSIX bundle asset
        $msixAsset = $release.assets | Where-Object { 
            $_.name -like "*WindowsTerminal*" -and $_.name -like "*.msixbundle" 
        } | Select-Object -First 1

        if (-not $msixAsset) {
            throw "Could not find MSIX bundle in the latest release assets"
        }

        Write-Output "Found version: $($release.tag_name)"
        Write-Output "Downloading: $($msixAsset.name)"

        # Download Windows Terminal MSIX bundle
        $msixPath = Join-Path -Path $env:USERPROFILE -ChildPath $msixAsset.name
        Invoke-WebRequest -Uri $msixAsset.browser_download_url -OutFile $msixPath -ErrorAction Stop

        # Install Windows Terminal
        Write-Output "Installing Windows Terminal..."
        Add-AppxPackage -Path $msixPath -ErrorAction Stop

        Write-Output "Windows Terminal has been successfully installed."
    }
    catch {
        Write-Error "Failed to install Windows Terminal: $_"
        throw
    }
    finally {
        # Clean up downloaded MSIX file
        if ($msixPath -and (Test-Path $msixPath)) {
            Remove-Item -Path $msixPath -Force -ErrorAction SilentlyContinue
        }
    }
}
