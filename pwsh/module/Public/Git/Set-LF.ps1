function Set-LF {
    <#
    .SYNOPSIS
        Converts line endings to LF (Unix-style) for files in specified paths.
    
    .DESCRIPTION
        This function converts CRLF and CR line endings to LF for files in the specified paths.
        It supports multiple methods including Git normalization and direct file conversion.
        By default, it processes shell script files (.sh) only.
    
    .PARAMETER Path
        One or more paths to process. Can be files or directories. Defaults to current directory.
    
    .PARAMETER Method
        The method to use for conversion:
        - 'Git': Uses Git's normalization feature (requires Git repository)
        - 'Direct': Direct file content replacement (works anywhere)
    
    .PARAMETER FileTypes
        Array of file extensions to process. Defaults to .sh files only.
    
    .PARAMETER Recurse
        Process subdirectories recursively. Default is $true.
    
    .EXAMPLE
        Set-LF -Path "bash", "packaging"
        Converts line endings for all .sh files in bash and packaging folders.
    
    .EXAMPLE
        Set-LF -Path "." -Method Direct
        Converts line endings using direct method for .sh files in current directory.
    
    .EXAMPLE
        Set-LF -Path "script.sh"
        Converts line endings for a specific shell script file.
    #>
    param (
        [string[]]$Path = @("."),                                           # Default to current directory
        [ValidateSet("Git", "Direct")]
        [string]$Method = "Direct",                                         # Default to Direct method
        [string[]]$FileTypes = @(".sh"),                                       # Shell script files only by default
        [bool]$Recurse = $true                                             # Process subdirectories by default
    )

    Write-Host "Converting line endings to LF for paths: $($Path -join ', ')" -ForegroundColor Yellow
    Write-Host "Method: $Method" -ForegroundColor Cyan
    Write-Host "File types: $($FileTypes -join ', ')" -ForegroundColor Cyan

    try {
        if ($Method -eq "Git") {
            # Git method: Disable autocrlf and use Git's normalization
            Write-Host "Disabling Git autocrlf..." -ForegroundColor Yellow
            git config core.autocrlf false
            
            Write-Host "Using Git normalization method..." -ForegroundColor Yellow
            foreach ($currentPath in $Path) {
                if (-not (Test-Path $currentPath)) {
                    Write-Warning "Path does not exist: $currentPath"
                    continue
                }
                
                $files = Get-ChildItem -Path $currentPath -Recurse:$Recurse -File | 
                    Where-Object { $_.Extension -in $FileTypes -or ($FileTypes -contains "" -and $_.Extension -eq "") }
                
                foreach ($file in $files) {
                    Write-Host "Processing: $($file.FullName)" -ForegroundColor Gray
                    git add $file.FullName
                    git reset $file.FullName
                }
            }
        }
        else {
            # Direct method: Read and write files with LF line endings
            Write-Host "Using direct file conversion method..." -ForegroundColor Yellow
            $fileCount = 0
            
            foreach ($currentPath in $Path) {
                if (-not (Test-Path $currentPath)) {
                    Write-Warning "Path does not exist: $currentPath"
                    continue
                }
                
                $files = Get-ChildItem -Path $currentPath -Recurse:$Recurse -File | 
                    Where-Object { $_.Extension -in $FileTypes -or ($FileTypes -contains "" -and $_.Extension -eq "") }
                
                foreach ($file in $files) {
                    Write-Host "Converting: $($file.FullName)" -ForegroundColor Gray
                    
                    try {
                        # Read file content preserving encoding
                        $content = Get-Content $file.FullName -Raw -Encoding UTF8
                        
                        if ($null -ne $content -and $content.Length -gt 0) {
                            # Convert CRLF to LF, then CR to LF (handles all cases)
                            $content = $content -replace "`r`n", "`n"
                            $content = $content -replace "`r", "`n"
                            
                            # Write back with UTF8 encoding and LF line endings
                            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
                            $fileCount++
                        }
                    }
                    catch {
                        Write-Warning "Failed to process file: $($file.FullName) - $($_.Exception.Message)"
                    }
                }
            }
            
            Write-Host "Conversion complete. Processed $fileCount files." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "An error occurred during line ending conversion: $($_.Exception.Message)"
    }
}

# Usage examples:
# Set-LF -Path "bash", "packaging"
# Set-LF -Path "." -Method Git
# Set-LF -Path "script.sh"
