function Enable-WindowsSandbox {
<#
.SYNOPSIS
    Enables Windows Sandbox if it is not already enabled on the system.

.DESCRIPTION
    The `Enable-WindowsSandbox` function checks if Windows Sandbox is enabled on the system by querying the Windows optional feature status. If Windows Sandbox is not enabled, the function will enable it using the Windows Optional Features API. If Windows Sandbox is already enabled, it outputs a confirmation message.

    Windows Sandbox provides a lightweight desktop environment to safely run applications in isolation. Each time Windows Sandbox runs, it's a clean, brand-new installation.

.EXAMPLE
    Enable-WindowsSandbox

    This example checks if Windows Sandbox is enabled on the system. If it is not, the function enables Windows Sandbox. If it is already enabled, it prints a confirmation message.

.NOTES
    Author: Michiel VH
    Requires: Administrative privileges to enable Windows features.
    Requires: Windows 10 Pro, Enterprise, or Education (version 1903 or later), or Windows 11.
    Requires: Hardware virtualization support must be enabled in BIOS/UEFI.
    A system restart may be required for changes to take effect.

.LINK
    https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-overview
    Learn more about Windows Sandbox and its requirements.
#>

    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This function requires administrative privileges to enable Windows features. Please run PowerShell as an administrator."
        return
    }

    try {
        # Check if Windows Sandbox is already enabled
        $sandboxFeature = Get-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -ErrorAction Stop
        
        if ($sandboxFeature.State -eq "Enabled") {
            Write-Output "Windows Sandbox is already enabled."
            return
        }

        # Enable Windows Sandbox
        Write-Output "Enabling Windows Sandbox feature..."
        $result = Enable-WindowsOptionalFeature -Online -FeatureName "Containers-DisposableClientVM" -NoRestart -ErrorAction Stop
        
        if ($result.RestartNeeded) {
            Write-Output "Windows Sandbox has been enabled."
            Write-Warning "A system restart is required for changes to take effect. Please restart your computer when convenient."
        } else {
            Write-Output "Windows Sandbox has been successfully enabled."
        }
    }
    catch {
        Write-Error "Failed to enable Windows Sandbox: $_"
        throw
    }
}

