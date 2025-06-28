Function Get-CurlStatus {
    <#
    .SYNOPSIS
    
    Displays information about curl availability and aliases in the current PowerShell session.

    .DESCRIPTION

    This function checks for curl aliases and native curl binary availability
    to help diagnose curl command availability in PowerShell.

    .EXAMPLE

    Get-CurlStatus
    
    # Shows information about curl configuration in the current session

    .NOTES

    Date: June 28, 2025

    #>

    [CmdletBinding()]
    param ()
    
    Write-Host "===== PowerShell Curl Configuration Diagnostics =====" -ForegroundColor Cyan
    
    # Check for curl alias
    $curlAlias = Get-Alias -Name curl -ErrorAction SilentlyContinue
    if ($curlAlias) {
        Write-Host "curl alias exists:" -ForegroundColor Yellow
        Write-Host "  Points to: $($curlAlias.Definition)" -ForegroundColor Yellow
        Write-Host "  Options to fix:"
        Write-Host "   - Run Remove-CurlAlias"
        Write-Host "   - Manually remove with: Remove-Item -Path Alias:curl -Force"
    } else {
        Write-Host "No curl alias found in current session." -ForegroundColor Green
    }
    
    Write-Host "`nChecking for native curl binaries:" -ForegroundColor Cyan
    
    # Check common locations for curl.exe
    $possiblePaths = @(
        'C:\ProgramData\chocolatey\bin\curl.exe',
        'C:\Windows\System32\curl.exe',
        'C:\Program Files\Git\mingw64\bin\curl.exe',
        'C:\Program Files\Git\usr\bin\curl.exe'
    )
    
    $foundCurl = $false
    foreach ($path in $possiblePaths) {
        if (Test-Path -Path $path -PathType Leaf) {
            $foundCurl = $true
            $version = try { & $path --version 2>&1 } catch { "Error: $_" }
            Write-Host "  Found curl at: $path" -ForegroundColor Green
            if ($version -is [array] -and $version.Count -gt 0) {
                Write-Host "  Version: $($version[0])" -ForegroundColor Green
            } else {
                Write-Host "  Version info: $version"
            }
        }
    }
    
    if (-not $foundCurl) {
        Write-Host "  No curl binary found in common locations" -ForegroundColor Red
        Write-Host "  Consider installing curl via Chocolatey: choco install curl"
    }
    
    # Check PATH for curl directories
    Write-Host "`nChecking PATH environment variable:" -ForegroundColor Cyan
    $pathDirs = $env:PATH -split ';'
    $curlDirs = $pathDirs | Where-Object { Test-Path -Path (Join-Path -Path $_ -ChildPath 'curl.exe') -ErrorAction SilentlyContinue }
    
    if ($curlDirs.Count -gt 0) {
        Write-Host "  Found directories with curl.exe in PATH:" -ForegroundColor Green
        foreach ($dir in $curlDirs) {
            Write-Host "  - $dir"
        }
    } else {
        Write-Host "  No directories with curl.exe found in PATH" -ForegroundColor Yellow
    }
    
    # Check what happens when you try to run curl
    Write-Host "`nTesting curl command resolution:" -ForegroundColor Cyan
    $resolvedCommand = Get-Command curl -ErrorAction SilentlyContinue
    if ($resolvedCommand) {
        Write-Host "  curl resolves to: $($resolvedCommand.Source)" -ForegroundColor Green
        Write-Host "  Command Type: $($resolvedCommand.CommandType)"
    } else {
        Write-Host "  curl command not found in current session" -ForegroundColor Red
    }
    
    # Check if Invoke-WebRequest alias is the issue
    $iwrAlias = Get-Alias | Where-Object { $_.Definition -eq 'Invoke-WebRequest' -and $_.Name -eq 'curl' } -ErrorAction SilentlyContinue
    if ($iwrAlias) {
        Write-Host "`nFound Invoke-WebRequest alias for curl:" -ForegroundColor Yellow
        Write-Host "  This means curl is aliased to PowerShell's Invoke-WebRequest"
        Write-Host "  You should run Remove-CurlAlias to fix this"
    }
    
    # Check Windows PowerShell built-in aliases
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        Write-Host "`nRunning in Windows PowerShell, which has built-in curl alias" -ForegroundColor Yellow
        Write-Host "  Consider adding Remove-Item -Path Alias:curl -Force to your profile"
    } elseif ($PSVersionTable.PSEdition -eq 'Core') {
        Write-Host "`nRunning in PowerShell Core" -ForegroundColor Cyan
        Write-Host "  PowerShell Core may still create the curl alias depending on configuration"
    }
    
    Write-Host "`n===== End of Diagnostics =====" -ForegroundColor Cyan
}
