<#
.SYNOPSIS
Updates the markdown documentation for the PDS module.

.DESCRIPTION
This script uses PlatyPS to generate or update markdown documentation for all functions in the PDS module.
It's designed to be run manually during development or triggered by Git hooks.

.PARAMETER ModulePath
The path to the module. Defaults to the parent directory of this script's location.

.PARAMETER DocsPath
The path where documentation should be stored. Defaults to [ModulePath]/docs.

.PARAMETER ForceRegenerate
When specified, recreates all documentation from scratch instead of updating existing files.

.EXAMPLE
.\Update-ModuleDocumentation.ps1

# Updates all documentation for the module

.EXAMPLE
.\Update-ModuleDocumentation.ps1 -ForceRegenerate

# Regenerates all documentation from scratch

.NOTES
Requires platyPS module to be installed.
#>

[CmdletBinding()]
param(
    [string]$ModulePath = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
    [string]$DocsPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "docs"),
    [switch]$ForceRegenerate
)

# Display the paths for debugging
Write-Host "Using Module Path: $ModulePath"
Write-Host "Using Docs Path: $DocsPath"

# Check if platyPS is installed, install if not
if (-not (Get-Module -ListAvailable -Name platyPS)) {
    Write-Host "platyPS module not found. Installing..."
    Install-Module -Name platyPS -Scope CurrentUser -Force
}

# Import the module
Import-Module platyPS -Force

# Ensure docs directory exists
if (-not (Test-Path -Path $DocsPath)) {
    New-Item -ItemType Directory -Path $DocsPath | Out-Null
    Write-Host "Created docs directory at $DocsPath"
}

# Import the PDS module to ensure latest functions are available
$moduleName = "PDS"
$moduleRootPath = Join-Path $ModulePath "pwsh\module"
$moduleFilePath = Join-Path $moduleRootPath "$moduleName.psm1"

# Check if module exists
if (-not (Test-Path -Path $moduleFilePath)) {
    Write-Error "Module file not found at: $moduleFilePath"
    exit 1
}

# Remove module if it's already loaded
if (Get-Module -Name $moduleName) {
    Remove-Module -Name $moduleName -Force
}

# Import the module
Import-Module $moduleFilePath -Force -Verbose

# Get all public functions in the module
$publicFunctionsPath = Join-Path $moduleRootPath "Public"
if (Test-Path $publicFunctionsPath) {
    $publicFunctions = Get-ChildItem -Path $publicFunctionsPath -Recurse -Filter "*.ps1" | 
        Where-Object { $_.Name -notlike "*.Tests.ps1" } |
        ForEach-Object { $_.BaseName }
    Write-Host "Found $($publicFunctions.Count) public functions."
} else {
    Write-Warning "Public functions directory not found at: $publicFunctionsPath"
    $publicFunctions = @()
    Write-Host "No public functions found."
}

# Function to create directory structure that matches Public folder structure
function New-DirectoryStructure {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )
    
    # Get all subdirectories from the Public folder
    $directories = Get-ChildItem -Path $SourcePath -Directory -Recurse
    
    # Create matching structure in docs folder
    foreach ($dir in $directories) {
        $relativePath = $dir.FullName.Substring($SourcePath.Length)
        $newPath = Join-Path $TargetPath $relativePath
        
        if (-not (Test-Path -Path $newPath)) {
            New-Item -ItemType Directory -Path $newPath | Out-Null
            Write-Host "Created directory: $newPath"
        }
    }
}

# Create directory structure in docs that matches Public folder structure
if (Test-Path $publicFunctionsPath) {
    New-DirectoryStructure -SourcePath $publicFunctionsPath -TargetPath $DocsPath
}

# Check if we need to regenerate or update
if ($ForceRegenerate -or -not (Test-Path -Path (Join-Path $DocsPath "*.md"))) {
    # Generate new documentation
    Write-Host "Generating new documentation..."
    
    # Generate documentation for all functions, preserving directory structure
    foreach ($function in $publicFunctions) {
        # Skip the template file since it's not a real function
        if ($function -eq "template") {
            Write-Host "Skipping template file as it's not a function."
            continue
        }
        
        # Find the original script file to get its location
        $scriptFile = Get-ChildItem -Path $publicFunctionsPath -Recurse -Filter "$function.ps1" | 
            Where-Object { $_.Name -notlike "*.Tests.ps1" } | 
            Select-Object -First 1
        
        if ($scriptFile) {
            # Calculate the relative path from Public root
            $relativePath = Split-Path $scriptFile.FullName.Substring($publicFunctionsPath.Length + 1) -Parent
            
            # Create target folder for the docs
            $targetFolder = if ($relativePath) { 
                Join-Path $DocsPath $relativePath 
            } else { 
                $DocsPath 
            }
            
            # Ensure target folder exists
            if (-not (Test-Path -Path $targetFolder)) {
                New-Item -ItemType Directory -Path $targetFolder | Out-Null
            }
            
            try {
                Write-Host "Generating documentation for $function in $targetFolder"
                New-MarkdownHelp -Command $function -OutputFolder $targetFolder -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning "Could not generate documentation for $function. Function may not be properly exported."
            }
        }
        else {
            Write-Warning "Could not find script file for function: $function"
            # Skip generating documentation for functions without a script file
            # This prevents files from being created in the root directory
        }
    }
}
else {
    # Update existing documentation
    Write-Host "Updating existing documentation..."
    # Update all markdown files in the docs directory and subdirectories
    $markdownFiles = Get-ChildItem -Path $DocsPath -Filter "*.md" -Recurse
    foreach ($file in $markdownFiles) {
        Update-MarkdownHelp -Path $file.DirectoryName
    }
}

# Manually create the module page that references the functions in their appropriate subdirectories
Write-Host "Generating module index page..."

# Get all markdown files in subdirectories (excluding the root directory)
$markdownFiles = Get-ChildItem -Path $DocsPath -Filter "*.md" -Recurse | 
    Where-Object { $_.DirectoryName -ne $DocsPath }

# Create a hashtable to store the sorted functions
$functionSections = @{}

# Process each file and organize by directory
foreach ($file in $markdownFiles) {
    $relativePath = $file.DirectoryName.Substring($DocsPath.Length + 1)
    if (-not $functionSections.ContainsKey($relativePath)) {
        $functionSections[$relativePath] = @()
    }
    
    $functionSections[$relativePath] += $file
}

# Create the module page content
$modulePageContent = @"
---
Module Name: $moduleName
Module Guid: 7a40948a-3473-4b8c-a67a-ad063194f9f8 00000000-0000-0000-0000-000000000000
Download Help Link: {{ Update Download Link }}
Help Version: {{ Please enter version of help manually (X.X.X.X) format }}
Locale: en-US
---

# $moduleName Module
## Description
{{ Fill in the Description }}

"@

# Add each section to the module page content
foreach ($section in $functionSections.Keys | Sort-Object) {
    $modulePageContent += "## $section Cmdlets`n"
    
    # Add each function in this section
    foreach ($file in $functionSections[$section] | Sort-Object -Property Name) {
        $relativePath = "$section/$($file.Name)"
        $functionName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $modulePageContent += "### [$functionName]($relativePath)`n{{ Fill in the Description }}`n`n"
    }
}

# Write the module page
$modulePagePath = Join-Path -Path $DocsPath -ChildPath "$moduleName.md"
Set-Content -Path $modulePagePath -Value $modulePageContent

# Cleanup any leftover files in the root docs directory
$rootFiles = Get-ChildItem -Path $DocsPath -Filter "*.md" | 
    Where-Object { $_.Directory.FullName -eq $DocsPath -and $_.Name -ne "$moduleName.md" }
if ($rootFiles) {
    Write-Host "Cleaning up duplicate documentation files in root directory..."
    foreach ($file in $rootFiles) {
        Write-Host "Removing duplicate file: $($file.Name)"
        Remove-Item -Path $file.FullName -Force
    }
}

Write-Host "Documentation updated at $DocsPath"
