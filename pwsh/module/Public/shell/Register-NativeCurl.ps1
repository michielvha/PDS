Function Register-NativeCurl {
    <#
    .SYNOPSIS
    
    Creates an 'ncurl' function for the native curl binary.

    .DESCRIPTION

    This function creates an 'ncurl' function that calls the native curl binary installed via Chocolatey.
    The function is added to your PowerShell profile so it persists across sessions.

    This is useful in PowerShell 5.1 where the 'curl' command is aliased to Invoke-WebRequest.

    .EXAMPLE

    Register-NativeCurl
    
    # Creates the ncurl alias that points to the native curl.exe binary

    .NOTES

    Date: June 28, 2025

    PowerShell 7+ typically handles curl better, but this function helps in PowerShell 5.1
    where curl is aliased to Invoke-WebRequest.

    #>

    [CmdletBinding()]
    param ()

    # Path to the Chocolatey curl binary
    $curlPath = 'C:\ProgramData\chocolatey\bin\curl.exe'
    
    # If not found, try using the Windows built-in curl
    if (-not (Test-Path -Path $curlPath -PathType Leaf)) {
        $curlPath = 'C:\Windows\System32\curl.exe'
        
        if (-not (Test-Path -Path $curlPath -PathType Leaf)) {
            Write-Error "Could not find curl.exe. Please install it with: choco install curl"
            return
        }
    }
    
    # Create the ncurl function for the current session
    $functionDef = @"
function global:ncurl {
    param([Parameter(ValueFromRemainingArguments=`$true)]`$params)
    & '$curlPath' `$params
}
"@
    
    Invoke-Expression -Command $functionDef
    Write-Output "Created 'ncurl' function for: $curlPath"
    
    # Test that it works
    try {
        $testOutput = ncurl --version
        Write-Output "Success! Native curl is accessible via 'ncurl'. Version info:"
        Write-Output $testOutput[0]
    } catch {
        Write-Warning "Error testing the ncurl function: $_"
    }
    
    # Add to profile (always persist)
    $profileContent = @"
    
# Create ncurl function that uses the native curl binary
$functionDef
"@
    
    # Ensure profile exists
    if (-not (Test-Path -Path $PROFILE)) {
        $profileDir = Split-Path -Path $PROFILE -Parent
        if (-not (Test-Path -Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
        Write-Verbose "Created PowerShell profile at: $PROFILE"
    }
    
    # Add to profile if not already there
    $currentProfileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
    if (-not $currentProfileContent -or -not $currentProfileContent.Contains("function global:ncurl")) {
        Add-Content -Path $PROFILE -Value $profileContent
        Write-Output "Added ncurl function to your PowerShell profile at: $PROFILE"
    } else {
        Write-Output "Your PowerShell profile already contains a ncurl function."
    }
    
    Write-Output "Use 'ncurl' to access the native curl binary."
}
