function Install-RSAT {
    <#
    .SYNOPSIS
        Installs Remote Server Administration Tools (RSAT) features on Windows 10 version 1809 or later.

    .DESCRIPTION
        The Install-RSAT function installs Remote Server Administration Tools (RSAT) features on Windows 10
        version 1809 or later where RSAT is available as optional features. The function can install
        specific RSAT features or all available RSAT features.
        
        The function checks if the current Windows version and edition support RSAT features, and
        provides appropriate feedback if installation is not possible.

    .PARAMETER Feature
        Specifies which RSAT feature(s) to install. Valid values include:
        - All (default): Installs all available RSAT features
        - AD: Installs Active Directory management tools
        - DNS: Installs DNS management tools
        - DHCP: Installs DHCP management tools
        - GroupPolicy: Installs Group Policy management tools
        - ServerManager: Installs Server Manager
        - FileServices: Installs File Services management tools
        - HyperV: Installs Hyper-V management tools

    .PARAMETER Force
        Forces reinstallation even if the feature is already installed.

    .EXAMPLE
        Install-RSAT
        
        Installs all available RSAT features.

    .EXAMPLE
        Install-RSAT -Feature AD
        
        Installs only Active Directory management tools.

    .EXAMPLE
        Install-RSAT -Feature AD,DNS,DHCP
        
        Installs Active Directory, DNS, and DHCP management tools.

    .NOTES
        - Requires Windows 10 version 1809 or later
        - Requires administrative privileges
        - Not available on Windows 10 Home edition
        - On Windows 10, RSAT is installed as optional features
        - Internet connection may be required for installation
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [ValidateSet('All', 'AD', 'DNS', 'DHCP', 'GroupPolicy', 'ServerManager', 'FileServices', 'HyperV')]
        [string[]]$Feature = @('All'),
        
        [Parameter()]
        [switch]$Force
    )

    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This function requires administrative privileges. Please run PowerShell as Administrator."
        return
    }

    # Check Windows version
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $osVersion = [Version](($osInfo.Version -split '\.')[0..1] -join '.')
    $osCaption = $osInfo.Caption
    $minVersion = [Version]"10.0"

    # Check if Windows 10/11
    if ($osVersion -lt $minVersion -or (-not $osCaption.Contains("Windows 10") -and -not $osCaption.Contains("Windows 11"))) {
        Write-Error "This function requires Windows 10 version 1809 or later, or Windows 11. Current OS: $osCaption $($osInfo.Version)"
        return
    }

    # Check if Windows 10 Home edition (which doesn't support RSAT)
    if ($osCaption -match "Home") {
        Write-Error "RSAT is not available for Windows Home editions. Current edition: $osCaption"
        return
    }

    # Define mapping of feature names to their corresponding Windows optional feature names
    $featureMapping = @{
        'AD' = @('Rsat.ActiveDirectory.DS-LDS.Tools*')
        'DNS' = @('Rsat.Dns.Tools*')
        'DHCP' = @('Rsat.DHCP.Tools*')
        'GroupPolicy' = @('Rsat.GroupPolicy.Management.Tools*')
        'ServerManager' = @('Rsat.ServerManager.Tools*')
        'FileServices' = @('Rsat.FileServices.Tools*')
        'HyperV' = @('Rsat.HyperV.Tools*')
    }

    # If All is specified, use all RSAT features
    if ($Feature -contains 'All') {
        $featuresToInstall = 'Rsat.*'
    }
    else {
        $featuresToInstall = @()
        foreach ($f in $Feature) {
            if ($featureMapping.ContainsKey($f)) {
                $featuresToInstall += $featureMapping[$f]
            }
        }
    }

    Write-Host "Checking for available RSAT features..." -ForegroundColor Cyan
    
    # Get list of all available optional features
    $availableFeatures = Get-WindowsCapability -Online | Where-Object { $_.Name -like "Rsat*" }
    
    if (-not $availableFeatures) {
        Write-Warning "No RSAT features found. This could be due to network connectivity issues or Windows edition limitations."
        return
    }

    # Filter the features based on what was requested
    $selectedFeatures = $availableFeatures | Where-Object { 
        foreach ($pattern in $featuresToInstall) {
            if ($_.Name -like $pattern) {
                return $true
            }
        }
        return $false
    }

    if (-not $selectedFeatures) {
        Write-Warning "No matching RSAT features found for the specified criteria."
        Write-Host "Available RSAT features:" -ForegroundColor Yellow
        $availableFeatures | ForEach-Object {
            Write-Host "  $($_.Name)" -ForegroundColor Yellow
        }
        return
    }

    # Install each selected feature
    $installCount = 0
    $skipCount = 0
    $errorCount = 0

    foreach ($rsatFeature in $selectedFeatures) {
        # Check if already installed
        if ($rsatFeature.State -eq "Installed" -and -not $Force) {
            Write-Host "Skipping $($rsatFeature.Name) - already installed" -ForegroundColor Gray
            $skipCount++
            continue
        }

        Write-Host "Installing $($rsatFeature.Name)..." -ForegroundColor Cyan
        try {
            $result = Add-WindowsCapability -Online -Name $rsatFeature.Name -ErrorAction Stop
            if ($result.RestartNeeded) {
                Write-Warning "A system restart is required to complete the installation of $($rsatFeature.Name)"
            }
            Write-Host "Successfully installed $($rsatFeature.Name)" -ForegroundColor Green
            $installCount++
        }
        catch {
            Write-Error "Failed to install $($rsatFeature.Name): $_"
            $errorCount++
        }
    }

    # Summary
    Write-Host "`nInstallation Summary:" -ForegroundColor Cyan
    Write-Host "  Features installed: $installCount" -ForegroundColor Green
    Write-Host "  Features skipped (already installed): $skipCount" -ForegroundColor Yellow
    Write-Host "  Features failed: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
    
    if ($installCount -gt 0 -or $errorCount -gt 0) {
        Write-Host "`nNote: You may need to restart your computer to complete the installation." -ForegroundColor Yellow
    }
}