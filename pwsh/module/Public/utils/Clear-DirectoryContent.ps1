function Clear-DirectoryContent {
    <#
    .SYNOPSIS
        Clears all content from a target directory using robocopy mirror technique.

    .DESCRIPTION
        This function uses robocopy with the /MIR switch to mirror an empty directory with the target directory,
        effectively clearing all contents. This method is often more reliable than Remove-Item for large directories
        or when dealing with long path names.

    .PARAMETER Path
        The path to the directory that should be cleared. Can be a local path or UNC path.

    .PARAMETER TempPath
        Optional. The path where the temporary empty directory will be created. Default is $env:USERPROFILE\EmptyFolder.

    .EXAMPLE
        Clear-DirectoryContent -Path "\\Server\Share\ProblemFolder"

        Clears all content from the specified network folder.

    .EXAMPLE
        Clear-DirectoryContent -Path "C:\SomeFolder" -TempPath "C:\Temp\EmptyDir"

        Clears all content from C:\SomeFolder using C:\Temp\EmptyDir as the temporary empty directory.

    .NOTES
        Author: Michiel VH
        Requires robocopy (available on Windows Vista/2008 and later)
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string]$TempPath = "$env:USERPROFILE\EmptyFolder"
    )

    try {
        # Create empty directory to use with robocopy
        Write-Host "Creating temporary empty directory at $TempPath..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $TempPath -Force | Out-Null

        # Use robocopy to mirror empty directory with target
        Write-Host "Clearing content from $Path using robocopy mirror..." -ForegroundColor Yellow
        robocopy $TempPath $Path /MIR | Out-Null

        # Check robocopy exit code (0-7 are success codes for robocopy)
        if ($LASTEXITCODE -le 7) {
            Write-Host "Directory content cleared successfully." -ForegroundColor Green
        } else {
            Write-Warning "Robocopy returned exit code $LASTEXITCODE. Some files may not have been processed."
        }

        # Remove the temporary empty directory
        Write-Host "Cleaning up temporary directory..." -ForegroundColor Yellow
        Remove-Item -Path $TempPath -Recurse -Force
    }
    catch {
        Write-Host "Error clearing directory content: $_" -ForegroundColor Red
        # Clean up temp directory if it exists
        if (Test-Path $TempPath) {
            Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}
