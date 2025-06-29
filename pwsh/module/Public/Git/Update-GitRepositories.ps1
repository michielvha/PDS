function Update-GitRepositories {
    <#
    .SYNOPSIS
        Updates all Git repositories in subdirectories by performing a git pull operation.

    .DESCRIPTION
        This function searches for all directories containing a .git folder in the specified root directory
        (or the current directory by default), and performs a git pull operation in each one to update them
        to the latest version of the current branch.

    .PARAMETER RootDirectory
        The root directory containing the Git repositories to update. Defaults to the current directory.

    .PARAMETER Recurse
        If specified, the function will search for Git repositories recursively in all subdirectories.

    .PARAMETER Branch
        The branch to checkout before pulling. If not specified, pulls the current branch.

    .EXAMPLE
        Update-GitRepositories
        Updates all Git repositories in the current directory.

    .EXAMPLE
        Update-GitRepositories -RootDirectory "C:\Projects"
        Updates all Git repositories in the C:\Projects directory.

    .EXAMPLE
        Update-GitRepositories -Recurse
        Updates all Git repositories in the current directory and all its subdirectories recursively.

    .EXAMPLE
        Update-GitRepositories -Branch main
        Updates all Git repositories in the current directory, checking out the main branch first.

    .NOTES
        Requires Git to be installed and available in your PATH.

        Author: Michiel VH

    .LINK
        https://git-scm.com/docs/git-pull
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [string]$RootDirectory = (Get-Location),

        [Parameter(Mandatory=$false)]
        [switch]$Recurse,

        [Parameter(Mandatory=$false)]
        [string]$Branch
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

        # Find all .git directories
        $gitDirs = Get-ChildItem -Path $RootDirectory -Filter ".git" -Directory -Depth $(if ($Recurse) { 100 } else { 1 })

        Write-Host "Found $($gitDirs.Count) Git repositories to update." -ForegroundColor Cyan

        # Process each repository
        foreach ($gitDir in $gitDirs) {
            $repoPath = $gitDir.Parent.FullName
            $repoName = $gitDir.Parent.Name

            Write-Host "`nUpdating repository: $repoName" -ForegroundColor Yellow
            Write-Host "Repository path: $repoPath" -ForegroundColor Gray

            # Navigate to the repository
            Set-Location -Path $repoPath

            # Check for local changes
            $status = git status --porcelain
            if ($status) {
                Write-Host "Repository has local changes. Skipping..." -ForegroundColor Red
                Write-Host "$status" -ForegroundColor Red
                continue
            }

            try {
                # Checkout specific branch if specified
                if ($Branch) {
                    Write-Host "Checking out branch: $Branch" -ForegroundColor Gray
                    git checkout $Branch 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "Failed to checkout branch $Branch. Skipping repository." -ForegroundColor Red
                        continue
                    }
                }

                # Get current branch name
                $currentBranch = git branch --show-current
                Write-Host "Pulling latest changes for branch: $currentBranch" -ForegroundColor Gray

                # Perform git pull
                $pullResult = git pull 2>&1
                if ($LASTEXITCODE -eq 0) {
                    if ($pullResult -match "Already up to date") {
                        Write-Host "Repository is already up to date." -ForegroundColor Green
                    } else {
                        Write-Host "Successfully updated repository." -ForegroundColor Green
                        Write-Host "$pullResult" -ForegroundColor Gray
                    }
                } else {
                    Write-Host "Failed to update repository." -ForegroundColor Red
                    Write-Host "$pullResult" -ForegroundColor Red
                }
            } catch {
                Write-Host "Error updating repository $repoName $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
    } finally {
        # Return to the original location
        Set-Location -Path $originalLocation
    }
}
