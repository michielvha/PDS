function Install-WSTerminal {
<#
.SYNOPSIS
    Installs Windows Terminal if it is not already installed on the system.

.DESCRIPTION
    The `Install-WSTerminal` function checks if Windows Terminal is installed on the system by querying installed AppX packages. If Windows Terminal is not installed, the function will automatically fetch the latest version from the Microsoft Terminal GitHub repository, download the necessary prerequisites (VCLibs and Microsoft.UI.Xaml.2.8 framework), and install Windows Terminal using the MSIX bundle. If Windows Terminal is already installed, it outputs the current installed version.

.EXAMPLE
    Install-WSTerminal

    This example checks if Windows Terminal is installed on the system. If it is not, the function installs the latest version of Windows Terminal. If it is already installed, it prints the installed version.

.NOTES
    Author: Michiel VH
    Requires: Internet connection for downloading Windows Terminal if it is not already installed.
    Requires: Administrator privileges may be required for installing AppX packages.
    This function downloads and installs the Visual C++ Runtime (VCLibs) and Microsoft.UI.Xaml.2.8 framework as prerequisites.

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
        # Fetch latest release from GitHub API
        Write-Output "Fetching latest version from GitHub..."
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/terminal/releases/latest" -ErrorAction Stop

        # Find the MSIX bundle asset (typically contains "WindowsTerminal" and ends with .msixbundle)
        $msixAsset = $release.assets | Where-Object { 
            $_.name -like "*WindowsTerminal*" -and $_.name -like "*.msixbundle" 
        } | Select-Object -First 1

        if (-not $msixAsset) {
            throw "Could not find MSIX bundle in the latest release assets"
        }

        Write-Output "Found version: $($release.tag_name)"
        Write-Output "Downloading: $($msixAsset.name)"

        # Download paths
        $vclibsPath = Join-Path -Path $env:USERPROFILE -ChildPath "Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $msixPath = Join-Path -Path $env:USERPROFILE -ChildPath $msixAsset.name

        # Download and install prerequisites (VCLibs)
        Write-Output "Downloading Visual C++ Runtime prerequisites..."
        try {
            Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile $vclibsPath -ErrorAction Stop
            Write-Output "Installing Visual C++ Runtime prerequisites..."
            Add-AppxPackage -Path $vclibsPath -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to install VCLibs prerequisites (may already be installed): $_"
        }
        finally {
            # Clean up VCLibs file
            if (Test-Path $vclibsPath) {
                Remove-Item -Path $vclibsPath -Force -ErrorAction SilentlyContinue
            }
        }

        # Check and install Microsoft.UI.Xaml.2.8 framework (required dependency)
        Write-Output "Checking for Microsoft.UI.Xaml.2.8 framework..."
        $xamlFramework = Get-AppxPackage -Name "Microsoft.UI.Xaml.2.8" -ErrorAction SilentlyContinue
        
        if (-not $xamlFramework) {
            Write-Output "Microsoft.UI.Xaml.2.8 framework not found. Installing Windows App Runtime..."
            $warPath = Join-Path -Path $env:USERPROFILE -ChildPath "Microsoft.WindowsAppRuntime.1.5_x64.msix"
            
            try {
                # Download Windows App Runtime 1.5 (includes Microsoft.UI.Xaml.2.8)
                Write-Output "Downloading Windows App Runtime..."
                $warUrl = "https://aka.ms/Microsoft.WindowsAppRuntime.1.5_x64.msix"
                Invoke-WebRequest -Uri $warUrl -OutFile $warPath -ErrorAction Stop
                
                Write-Output "Installing Windows App Runtime..."
                Add-AppxPackage -Path $warPath -ErrorAction Stop
                Write-Output "Windows App Runtime installed successfully."
            }
            catch {
                Write-Warning "Failed to download Windows App Runtime from primary source. Trying alternative method..."
                
                # Try using winget if available
                $wingetAvailable = Get-Command -Name "winget" -ErrorAction SilentlyContinue
                if ($wingetAvailable) {
                    try {
                        Write-Output "Attempting to install via winget..."
                        winget install --id Microsoft.WindowsAppRuntime.1.5 --exact --silent --accept-source-agreements --accept-package-agreements
                        Write-Output "Windows App Runtime installation initiated via winget."
                    }
                    catch {
                        Write-Warning "winget installation failed: $_"
                    }
                }
                
                if (-not $wingetAvailable) {
                    Write-Warning "Windows App Runtime installation failed. Please install it manually:"
                    Write-Warning "1. Visit: https://apps.microsoft.com/store/detail/windows-app-runtime/9P9TQF7MRM4R"
                    Write-Warning "2. Or run: winget install Microsoft.WindowsAppRuntime.1.5"
                    Write-Warning "Error details: $_"
                }
            }
            finally {
                # Clean up Windows App Runtime file
                if (Test-Path $warPath) {
                    Remove-Item -Path $warPath -Force -ErrorAction SilentlyContinue
                }
            }
            
            # Verify installation
            Start-Sleep -Seconds 2
            $xamlFramework = Get-AppxPackage -Name "Microsoft.UI.Xaml.2.8" -ErrorAction SilentlyContinue
            if (-not $xamlFramework) {
                Write-Warning "Microsoft.UI.Xaml.2.8 framework may still not be installed. Installation may continue anyway."
            }
        } else {
            Write-Output "Microsoft.UI.Xaml.2.8 framework is already installed."
        }

        # Download Windows Terminal MSIX bundle
        Write-Output "Downloading Windows Terminal..."
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
        if (Test-Path $msixPath) {
            Remove-Item -Path $msixPath -Force -ErrorAction SilentlyContinue
        }
    }
}

