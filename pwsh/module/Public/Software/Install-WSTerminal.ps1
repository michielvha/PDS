function Install-WSTerminal {
<#
.SYNOPSIS
    Installs Windows Terminal if it is not already installed on the system.

.DESCRIPTION
    The `Install-WSTerminal` function checks if Windows Terminal is installed on the system by querying installed AppX packages. If Windows Terminal is not installed, the function will automatically fetch the latest version from the Microsoft Terminal GitHub repository, download the necessary prerequisites (VCLibs), and install Windows Terminal using the MSIX bundle. If Windows Terminal is already installed, it outputs the current installed version.

.EXAMPLE
    Install-WSTerminal

    This example checks if Windows Terminal is installed on the system. If it is not, the function installs the latest version of Windows Terminal. If it is already installed, it prints the installed version.

.NOTES
    Author: Michiel VH
    Requires: Internet connection for downloading Windows Terminal if it is not already installed.
    Requires: Administrator privileges may be required for installing AppX packages.
    This function downloads and installs the Visual C++ Runtime (VCLibs) as a prerequisite.

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

        # Download prerequisites (VCLibs)
        Write-Output "Downloading Visual C++ Runtime prerequisites..."
        try {
            Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile $vclibsPath -ErrorAction Stop
            Write-Output "Installing Visual C++ Runtime prerequisites..."
            Add-AppxPackage -Path $vclibsPath -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to install prerequisites: $_"
            # Continue anyway as VCLibs might already be installed
        }
        finally {
            # Clean up VCLibs file
            if (Test-Path $vclibsPath) {
                Remove-Item -Path $vclibsPath -Force -ErrorAction SilentlyContinue
            }
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

