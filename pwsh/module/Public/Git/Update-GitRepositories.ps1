function Update-GitRepositories {
    <#
    .SYNOPSIS
        Updates all Git repositories in immediate subdirectories by performing a git pull operation.

    .DESCRIPTION
        This function searches for all immediate subdirectories containing a .git folder in the specified root directory
        (or the current directory by default), and performs a simple git pull operation in each one.

    .PARAMETER RootDirectory
        The root directory containing the Git repositories to update. Defaults to the current directory.

    .EXAMPLE
        Update-GitRepositories
        Updates all Git repositories in the immediate subdirectories of the current directory.

    .EXAMPLE
        Update-GitRepositories -RootDirectory "C:\Projects"
        Updates all Git repositories in the immediate subdirectories of the C:\Projects directory.

    .NOTES
        Requires Git to be installed and available in your PATH.

        Author: Michiel VH

    .LINK
        https://git-scm.com/docs/git-pull
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [string]$RootDirectory = (Get-Location)
    )

    # Save the original location to return to it at the end
    $originalLocation = Get-Location
    
    try {
        # Ensure the root directory exists
        if (-not (Test-Path -Path $RootDirectory)) {
            Write-Error "The specified root directory '$RootDirectory' does not exist."
            return
        }

        # Set location to the root directory
        Set-Location -Path $RootDirectory

        # Find all Git repositories (directories that contain a .git subfolder)
        # Simple approach to just search one level down - include hidden items with -Hidden
        $dirs = Get-ChildItem -Path $RootDirectory -Directory
        $gitDirs = @()
        
        foreach ($dir in $dirs) {
            # Look specifically for hidden .git directories
            $gitFolder = Get-ChildItem -Path $dir.FullName -Directory -Hidden -Filter ".git" -ErrorAction SilentlyContinue
            if ($gitFolder) {
                $gitDirs += $gitFolder
            }
        }

        Write-Host "Found $($gitDirs.Count) Git repositories to update." -ForegroundColor Cyan
        
        # Initialize progress bar
        $progressParams = @{
            Activity = "Updating Git Repositories"
            Status = "Starting updates..."
            PercentComplete = 0
        }
        Write-Progress @progressParams
        
        # Process each repository
        $currentRepo = 0
        $totalRepos = $gitDirs.Count
        
        foreach ($gitDir in $gitDirs) {
            $currentRepo++
            $repoPath = $gitDir.Parent.FullName
            $repoName = $gitDir.Parent.Name
            
            # Update progress bar
            $progressParams.Status = "Processing $currentRepo of $totalRepos - $repoName"
            $progressParams.PercentComplete = ($currentRepo / $totalRepos) * 100
            Write-Progress @progressParams

            Write-Host "`nUpdating repository: $repoName [$currentRepo/$totalRepos]" -ForegroundColor Yellow
            Write-Host "Repository path: $repoPath" -ForegroundColor Gray

            # Navigate to the repository
            Set-Location -Path $repoPath

            try {
                # Simple git pull operation
                Write-Host "Running git pull..." -ForegroundColor Gray
                
                # Perform git pull
                $pullResult = git pull 2>&1
                
                # Show the result
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Success" -ForegroundColor Green
                    
                    # Format the output in a more structured way
                    if ($pullResult -match "Already up to date") {
                        Write-Host "  Status: Already up to date" -ForegroundColor Cyan
                    } else {
                        Write-Host "  Status: Changes pulled successfully" -ForegroundColor Cyan
                        
                        # Parse and display changes in a structured format
                        $changes = $pullResult -split "`n" | Where-Object { $_ -match "\s+\d+\s+\w+\(\+\)" -or $_ -match "\s+\d+\s+files?\s+changed" -or $_ -match "^\s+(create mode|rename|delete mode)" }
                        
                        if ($changes) {
                            Write-Host "  Changes:" -ForegroundColor Cyan
                            foreach ($change in $changes) {
                                Write-Host "    $($change.Trim())" -ForegroundColor White
                            }
                        }
                    }
                } else {
                    Write-Host "Failed: $pullResult" -ForegroundColor Red
                }
            } catch {
                Write-Host "Error updating repository $repoName : $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    } finally {
        # Complete the progress bar
        Write-Progress -Activity "Updating Git Repositories" -Completed
        
        # Return to the original location
        Set-Location -Path $originalLocation
    }
}
