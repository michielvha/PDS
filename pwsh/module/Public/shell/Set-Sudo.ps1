function Set-Sudo {
    <#
    .SYNOPSIS
        Enables sudo functionality for Windows by configuring the built-in sudo feature.

    .DESCRIPTION
        The `Set-Sudo` function enables sudo functionality on Windows 11 by enabling the built-in sudo feature through registry configuration. 
        
        This function:
        1. Checks Windows version compatibility (Windows 11 24H2 or later)
        2. Enables sudo through registry settings
        3. Configures sudo behavior (inline mode by default)
        4. Tests sudo functionality
        
        After enabling, users can use commands like:
        - `sudo Get-Process` - Run a command with elevated privileges
        - `sudo powershell` - Open an elevated PowerShell session
        - `sudo cmd` - Open an elevated Command Prompt

    .PARAMETER Mode
        Sets the sudo mode:
        - 'Normal' (default): Inline mode - runs in current window
        - 'NewWindow': Forces new window for elevated commands
        - 'DisableInput': Runs elevated but with input disabled

    .PARAMETER NoValidation
        Skips the validation test after enabling sudo.

    .EXAMPLE
        Set-Sudo
        
        Enables sudo with default inline mode and tests functionality.

    .EXAMPLE
        Set-Sudo -Mode NewWindow
        
        Enables sudo to run elevated commands in a new window.

    .EXAMPLE
        Set-Sudo -NoValidation
        
        Enables sudo but skips the validation test.

    .NOTES
        Author: Michiel VH
        
        Requirements:
        - Windows 11 24H2 (Build 26100) or later
        - Administrator privileges
        - PowerShell 5.1 or later

    .LINK
        Documentation: https://learn.microsoft.com/en-us/windows/sudo/
        GitHub: https://github.com/microsoft/sudo
    #>

    param (
        [Parameter()]
        [ValidateSet('Normal', 'NewWindow', 'DisableInput')]
        [string]$Mode = 'Normal',
        
        [Parameter()]
        [switch]$NoValidation
    )

    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Error "This function requires administrator privileges. Please run PowerShell as Administrator."
        return
    }

    # Check Windows version compatibility  
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $buildNumber = [int]$osInfo.BuildNumber
    
    # Windows 11 24H2 (Build 26100) or later required
    if ($osInfo.ProductType -eq 1) {  # Workstation
        if ($buildNumber -lt 26100) {
            Write-Error "Sudo for Windows requires Windows 11 24H2 (Build 26100) or later. Current build: $buildNumber"
            Write-Host "Please update Windows to the latest version." -ForegroundColor Yellow
            return
        }
    } else {
        Write-Warning "Sudo for Windows is primarily designed for Windows 11. Server support may be limited."
    }

    Write-Host "Enabling sudo for Windows..." -ForegroundColor Cyan

    try {
        # Convert mode to registry value
        $modeValue = switch ($Mode) {
            'NewWindow' { 1 }
            'DisableInput' { 2 }  
            'Normal' { 3 }
            default { 3 }
        }

        # Enable sudo via registry
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo"
        
        Write-Host "Setting sudo registry configuration..." -ForegroundColor Cyan
        
        # Create registry key if it doesn't exist
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
        }
        
        # Set the Enabled value
        Set-ItemProperty -Path $registryPath -Name "Enabled" -Value $modeValue -Type DWord
        
        Write-Host "Sudo enabled successfully with mode: $Mode" -ForegroundColor Green
        
        # Wait a moment for changes to take effect
        Start-Sleep -Seconds 2
        
        # Check if sudo command is available
        $sudoCommand = Get-Command sudo -ErrorAction SilentlyContinue
        
        if ($sudoCommand) {
            Write-Host "Sudo command is available at: $($sudoCommand.Source)" -ForegroundColor Green
            
            if (-not $NoValidation) {
                Write-Host "Testing sudo functionality..." -ForegroundColor Cyan
                try {
                    # Simple test that should work regardless of mode
                    $testResult = sudo powershell -Command "Write-Output 'Sudo test successful'"
                    if ($testResult -match "successful") {
                        Write-Host "Sudo validation: $testResult" -ForegroundColor Green
                    } else {
                        Write-Warning "Sudo test returned unexpected result: $testResult"
                    }
                }
                catch {
                    Write-Warning "Sudo test failed: $($_.Exception.Message)"
                    Write-Host "This may be expected if UAC prompts were cancelled." -ForegroundColor Yellow
                }
            }
            
            Write-Host "`nSudo is now ready to use! Examples:" -ForegroundColor Cyan
            Write-Host "  sudo Get-Process" -ForegroundColor Gray
            Write-Host "  sudo powershell" -ForegroundColor Gray  
            Write-Host "  sudo cmd" -ForegroundColor Gray
            
        } else {
            Write-Warning "Sudo command not found in PATH. It may require a system restart or Windows update."
            Write-Host "Try running 'sudo' in a new PowerShell session, or restart your computer." -ForegroundColor Yellow
        }
        
    }
    catch {
        Write-Error "Failed to enable sudo: $($_.Exception.Message)"
        Write-Host "Make sure you're running on a supported Windows version and have administrator privileges." -ForegroundColor Yellow
    }
}
}