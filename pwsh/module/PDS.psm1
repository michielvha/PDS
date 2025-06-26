# PDS Module Loader Script
# This script loads all public functions for the module.

# Get the module path
$ModulePath = $PSScriptRoot

# Public functions - all scripts are public
$PublicFunctions = @(
    Get-ChildItem -Path "$ModulePath\Public" -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue
)

# Define module-wide variables or constants here if needed

# Load all public functions
foreach ($function in $PublicFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Imported function $($function.BaseName)"
    }
    catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

# Export all public functions
$PublicFunctions | ForEach-Object {
    $functionName = $_.BaseName
    Export-ModuleMember -Function $functionName
}

# If there are any aliases defined in public functions, export those as well
Export-ModuleMember -Alias *