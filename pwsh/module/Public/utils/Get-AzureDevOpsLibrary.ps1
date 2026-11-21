<#
.SYNOPSIS
    Clones or updates all Git repositories from an Azure DevOps project.

.DESCRIPTION
    The Get-AzureDevOpsLibrary function retrieves all repositories from a specified Azure DevOps
    project and clones them to a local directory. If repositories already exist locally, it will
    pull the latest changes instead. This provides a complete local backup of your Azure DevOps
    repository library.

.PARAMETER Organization
    The Azure DevOps organization name (from the URL: dev.azure.com/YOUR_ORGANIZATION).

.PARAMETER Project
    The name of the Azure DevOps project containing the repositories.

.PARAMETER Username
    Your Azure DevOps username or email address used for authentication.

.PARAMETER PersonalAccessToken
    A Personal Access Token (PAT) with at least 'Code (Read)' permissions.
    To create a PAT: User Settings → Personal Access Tokens → New Token

.PARAMETER DestinationPath
    The local directory path where repositories will be cloned. Defaults to
    "C:\AzureDevOps\<ProjectName>". The directory will be created if it doesn't exist.

.PARAMETER Force
    If specified, will re-clone repositories even if they already exist locally.

.EXAMPLE
    Get-AzureDevOpsLibrary -Organization "contoso" -Project "MyProject" -Username "john@contoso.com" -PersonalAccessToken "abc123..."

    Clones all repositories from the MyProject project to C:\AzureDevOps\MyProject

.EXAMPLE
    Get-AzureDevOpsLibrary -Organization "your-org" -Project "your-project" -Username "your-email@domain.com" -PersonalAccessToken "your-pat" -DestinationPath "D:\Repos"

    Clones all repositories to the specified destination path D:\Repos

.EXAMPLE
    Get-AzureDevOpsLibrary -Organization "contoso" -Project "MyProject" -Username "john@contoso.com" -PersonalAccessToken "abc123..." -Force

    Re-clones all repositories even if they already exist locally

.NOTES
    Author: Azure DevOps Repository Manager
    Requires: Git must be installed and available in PATH
    API Version: 7.0

.LINK
    https://learn.microsoft.com/en-us/rest/api/azure/devops/git/repositories/list
#>

function Get-AzureDevOpsLibrary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "Azure DevOps organization name")]
        [ValidateNotNullOrEmpty()]
        [string]$Organization,

        [Parameter(Mandatory = $true, HelpMessage = "Azure DevOps project name")]
        [ValidateNotNullOrEmpty()]
        [string]$Project,

        [Parameter(Mandatory = $true, HelpMessage = "Your Azure DevOps username/email")]
        [ValidateNotNullOrEmpty()]
        [string]$Username,

        [Parameter(Mandatory = $true, HelpMessage = "Personal Access Token with Code (Read) permissions")]
        [ValidateNotNullOrEmpty()]
        [string]$PersonalAccessToken,

        [Parameter(Mandatory = $false, HelpMessage = "Local destination path for cloned repositories")]
        [string]$DestinationPath = "C:\AzureDevOps\$Project",

        [Parameter(Mandatory = $false, HelpMessage = "Force re-clone of existing repositories")]
        [switch]$Force
    )

    begin {
        # Load System.Web assembly for URL encoding
        Add-Type -AssemblyName System.Web

        # Verify Git is available
        try {
            $null = git --version
        }
        catch {
            throw "Git is not installed or not available in PATH. Please install Git first."
        }

        # Create destination directory if it doesn't exist
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            Write-Host "Created directory: $DestinationPath" -ForegroundColor Green
        }

        # Encode PAT for Basic Authentication
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))

        # Git gets the credential as an HTTP header through GIT_CONFIG_* environment variables,
        # set only around each clone or pull, so the token never lands in .git/config or on a
        # command line.
        $gitAuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:$PersonalAccessToken"))
        function Invoke-AuthenticatedGit {
            param ([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgument)
            $env:GIT_CONFIG_COUNT = '1'
            $env:GIT_CONFIG_KEY_0 = 'http.extraHeader'
            $env:GIT_CONFIG_VALUE_0 = "Authorization: Basic $gitAuthInfo"
            try {
                git @GitArgument 2>&1
            }
            finally {
                Remove-Item -Path Env:GIT_CONFIG_COUNT, Env:GIT_CONFIG_KEY_0, Env:GIT_CONFIG_VALUE_0 -ErrorAction SilentlyContinue
            }
        }

        # API endpoint
        $uri = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories?api-version=7.0"
    }

    process {
        Write-Host "Fetching repository list from Azure DevOps..." -ForegroundColor Cyan
        Write-Host "Organization: $Organization" -ForegroundColor Gray
        Write-Host "Project: $Project" -ForegroundColor Gray
        Write-Host ""

        try {
            # Get list of repositories
            $headers = @{
                Authorization = "Basic $base64AuthInfo"
            }

            $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
            $repos = $response.value

            if ($repos.Count -eq 0) {
                Write-Warning "No repositories found in project '$Project'"
                return
            }

            Write-Host "Found $($repos.Count) repositories" -ForegroundColor Green
            Write-Host ""

            $successCount = 0
            $failCount = 0

            # Clone each repository
            foreach ($repo in $repos) {
                $repoName = $repo.name
                # The remote URL without any user name in it
                $cleanUrl = $repo.remoteUrl -replace "https://[^@]*@", "https://"
                $repoPath = Join-Path $DestinationPath $repoName

                Write-Host "Processing: $repoName" -ForegroundColor Yellow

                if ((Test-Path $repoPath) -and -not $Force) {
                    Write-Host "  Repository already exists. Pulling latest changes..." -ForegroundColor Gray
                    Push-Location $repoPath
                    try {
                        # A clone made by an earlier version kept the token in its remote URL.
                        git remote set-url origin $cleanUrl 2>&1 | Out-Null
                        $gitOutput = Invoke-AuthenticatedGit pull
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  ✓ Updated successfully" -ForegroundColor Green
                            $successCount++
                        }
                        else {
                            Write-Host "  ✗ Failed to update: $gitOutput" -ForegroundColor Red
                            $failCount++
                        }
                    }
                    catch {
                        Write-Host "  ✗ Failed to update: $_" -ForegroundColor Red
                        $failCount++
                    }
                    finally {
                        Pop-Location
                    }
                }
                else {
                    if ((Test-Path $repoPath) -and $Force) {
                        Write-Host "  Removing existing repository (Force mode)..." -ForegroundColor Gray
                        Remove-Item -Path $repoPath -Recurse -Force
                    }

                    Write-Host "  Cloning repository..." -ForegroundColor Gray

                    try {
                        $gitOutput = Invoke-AuthenticatedGit clone $cleanUrl $repoPath
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  ✓ Cloned successfully" -ForegroundColor Green
                            $successCount++
                        }
                        else {
                            Write-Host "  ✗ Failed to clone: $gitOutput" -ForegroundColor Red
                            $failCount++
                        }
                    }
                    catch {
                        Write-Host "  ✗ Failed to clone: $_" -ForegroundColor Red
                        $failCount++
                    }
                }
                Write-Host ""
            }

            # Summary
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "Summary:" -ForegroundColor Cyan
            Write-Host "  Total repositories: $($repos.Count)" -ForegroundColor White
            Write-Host "  Successful: $successCount" -ForegroundColor Green
            if ($failCount -gt 0) {
                Write-Host "  Failed: $failCount" -ForegroundColor Red
            }
            Write-Host "  Location: $DestinationPath" -ForegroundColor White
            Write-Host "========================================" -ForegroundColor Cyan
        }
        catch {
            Write-Error "Failed to retrieve repositories: $_"
            Write-Host "Please verify:" -ForegroundColor Yellow
            Write-Host "  - Your PAT has 'Code (Read)' permissions" -ForegroundColor Yellow
            Write-Host "  - Organization and Project names are correct" -ForegroundColor Yellow
            Write-Host "  - Your PAT has not expired" -ForegroundColor Yellow
        }
    }
}
