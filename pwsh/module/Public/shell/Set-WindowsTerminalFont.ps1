function Set-WindowsTerminalFont {
    <#
    .SYNOPSIS
        Sets the default font for Windows Terminal to a specified font face.

    .DESCRIPTION
        The `Set-WindowsTerminalFont` function modifies the Windows Terminal settings.json file
        to set the default font face for all profiles. It ensures that the profiles.defaults 
        structure exists and properly configures the font setting.

        The function automatically locates the Windows Terminal settings file and safely modifies
        the JSON configuration while preserving existing settings.

    .PARAMETER FontName
        The name of the font to set as the default for Windows Terminal.
        Default value is "MesloLGM Nerd Font".

    .EXAMPLE
        Set-WindowsTerminalFont
        
        Sets the Windows Terminal default font to "MesloLGM Nerd Font".

    .EXAMPLE
        Set-WindowsTerminalFont -FontName "JetBrainsMono Nerd Font Mono"
        
        Sets the Windows Terminal default font to "JetBrains Mono".

    .OUTPUTS
        None. The function modifies the Windows Terminal settings file and displays a confirmation message.

    .NOTES
        - Requires Windows Terminal to be installed
        - The function will create the profiles.defaults structure if it doesn't exist
        - Changes take effect immediately in new Windows Terminal instances
        - Existing terminal sessions may need to be restarted to see the font change

        Author: Michiel VH

    .LINK
        https://ohmyposh.dev/docs/installation/fonts
        https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-general
    #>

    param (
        [Parameter(Mandatory=$false)]
        [string]$FontName = "MesloLGM Nerd Font"
    )

    # Install Oh My Posh if not already installed
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        Write-Host "📦 Installing Oh My Posh..."
        Write-Verbose "Using winget to install Oh My Posh.`nThis will fetch the exe and latest themes from the official repository.`nThe installation is user scoped"
        winget install JanDeDobbeleer.OhMyPosh -s winget
    }

    # install the fonts
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Write-Host "📦 Installing Nerd fonts"
        oh-my-posh font install meslo
        oh-my-posh font install JetBrainsMono
    }

    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    if (-Not (Test-Path $settingsPath)) {
        Write-Error "Windows Terminal settings.json not found at: $settingsPath"
        Write-Error "Please ensure Windows Terminal is installed and has been run at least once."
        return
    }

    try {
        Write-Host "Reading Windows Terminal settings..." -ForegroundColor Cyan
        $json = Get-Content $settingsPath -Raw | ConvertFrom-Json

        # Ensure profiles.defaults exists
        if (-not $json.profiles.defaults) {
            Write-Host "Creating profiles.defaults structure..." -ForegroundColor Yellow
            $json.profiles | Add-Member -MemberType NoteProperty -Name "defaults" -Value ([PSCustomObject]@{})
        }

        # Set the font
        if (-not $json.profiles.defaults.font) {
            Write-Host "Creating font configuration..." -ForegroundColor Yellow
            $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name "font" -Value ([PSCustomObject]@{})
        }
        
        $json.profiles.defaults.font | Add-Member -MemberType NoteProperty -Name "face" -Value $FontName -Force

        # Write back the modified config
        Write-Host "Saving updated settings..." -ForegroundColor Cyan
        $json | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding utf8

        Write-Host "Font successfully set to '$FontName' in Windows Terminal settings." -ForegroundColor Green
        Write-Host "Please restart any existing Windows Terminal sessions to see the changes." -ForegroundColor Yellow
    }
    catch {
        Write-Error "Failed to update Windows Terminal settings: $($_.Exception.Message)"
        return
    }
}
