Function Install-WSL {
    <#
    .SYNOPSIS
        Installs WSL (Windows Subsystem for Linux) distributions.

    .DESCRIPTION
        The `Install-WSL` function provides a wrapper for installing WSL distributions on Windows.
        It optionally accepts an array of distro names to install. If no parameters are passed,
        it simply lists available distributions online. If distributions are passed as parameters,
        it will attempt to install each one using the `wsl --install` command.

    .PARAMETER distros
        An optional array of WSL distro names that you wish to install. Each distro name should
        match one of the names listed by `wsl --list --online`. If not provided, the function
        will only list the available distros.

    .EXAMPLE
        $distros = @("Ubuntu", "Debian")
        Install-WSL -d $distros

        This example installs the `Ubuntu` and `Debian` distributions using WSL.

    .EXAMPLE
        Install-WSL -d(istros) Alpine, Kali-Linux, Debian

        This example installs the distribution if it is available in the online list.

    .NOTES
        Author: Michiel VH
        Requires: WSL to be enabled on the system. Is enabled by default on any newer windows build (w11+)
        This function uses the `wsl --install` command to install the specified distributions.

    .LINK
        https://docs.microsoft.com/en-us/windows/wsl/install
        Learn more about installing and configuring WSL.
    #>

    param (
        [Alias("d")]
        [string[]]$distros  # Accepts an array of distro names
    )



    Write-Output "This function is a wrapper for installing WSL. Call it with any distro listed below."
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warning "This function requires administrative privileges to enable Windows features. Please run PowerShell as an administrator."
        return
    }
    
    # Check if Virtual Machine Platform feature is enabled
    $vmPlatformEnabled = (Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State -eq "Enabled"
    
    if (-not $vmPlatformEnabled) {
        Write-Output "Enabling Virtual Machine Platform feature, which is required for WSL..."
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
            Write-Output "Virtual Machine Platform feature has been enabled."
            
            # Check if WSL feature is enabled
            $wslEnabled = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq "Enabled"
            if (-not $wslEnabled) {
                Write-Output "Enabling Windows Subsystem for Linux feature..."
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
                Write-Output "Windows Subsystem for Linux feature has been enabled."
            }
            
            Write-Output "A system restart may be required for changes to take effect. Please restart your computer if prompted."
        } catch {
            Write-Error "Failed to enable Virtual Machine Platform: $_"
            return
        }
    }
    
    # List available distributions
    wsl --list --online

    if ($distros) {
        foreach ($distro in $distros) {
            try {
                Write-Output "`nAttempting to install $distro..."
                wsl --install -d $distro
            } catch {
                Write-Output "An error occurred while installing ${distro}: $_"
            }
        }
    }
}

