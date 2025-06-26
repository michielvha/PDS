function New-Branch {
    param (
        [string]$RepoPath = (Get-Location), # Default to the current directory if no path is provided
        [string]$BranchPrefix = "dev-"      # Default branch prefix
    )

    # Navigate to the repository
    if (Test-Path $RepoPath) {
        Set-Location -Path $RepoPath
    } else {
        Write-Host "The specified repository path does not exist: $RepoPath" -ForegroundColor Red
        return
    }

    # Ensure the repository is clean before proceeding
    if ((git status --porcelain).Length -gt 0) {
        Write-Host "The repository has uncommitted changes. Commit or stash them before proceeding." -ForegroundColor Red
        return
    }

    # Pull the latest changes from the main branch
    Write-Host "Switching to 'main' and pulling the latest changes..." -ForegroundColor Yellow
    git checkout main
    git pull origin main

    # Generate a unique branch name with an incrementing number
    Write-Host "Generating a unique branch name..." -ForegroundColor Yellow
    $existingBranches = git branch --list | ForEach-Object { $_.Trim() }
    $increment = 0
    do {
        $newBranchName = "${BranchPrefix}${increment}"
        $increment++
    } while ($existingBranches -contains $newBranchName)

    # Create and switch to the new branch
    git checkout -b $newBranchName
    Write-Host "New branch '$newBranchName' created and checked out." -ForegroundColor Green
}
# New-Branch
# To make it available in the current session, dot source the script or add it to your profile:
# . .\New-Branch.ps1
