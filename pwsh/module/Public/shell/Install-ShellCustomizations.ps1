function Install-ShellCustomizations {
    <#
    .SYNOPSIS
        Installs and configures a comprehensive shell customization stack for PowerShell and Windows Terminal.
    
    .DESCRIPTION
        The `Install-ShellCustomizations` function sets up a complete shell environment by orchestrating the installation and configuration of multiple components:
        
        1. **Oh My Posh**: Installs Oh My Posh prompt engine with powerlevel10k_rainbow theme
        2. **PowerShell Modules**: Installs Terminal-Icons and posh-git modules for enhanced functionality
        3. **Nerd Fonts**: Installs MesloLGM and JetBrains Mono Nerd Fonts for proper icon rendering
        4. **Windows Terminal**: Configures Windows Terminal to use MesloLGM Nerd Font as default
        5. **Profile Integration**: Adds necessary imports and configurations to PowerShell profile
        
        This function serves as a convenient wrapper that calls `Install-OhMyPosh` and `Set-WindowsTerminalFont` to provide a complete, ready-to-use shell customization experience.
    
    
    .NOTES
        Author: Michiel VH
        
        Requirements:
        - Windows Terminal (for font configuration)
        - Internet connection (for downloading Oh My Posh and fonts)
        - PowerShell execution policy allowing module installation
        
        Components Installed:
        - Oh My Posh (via winget)
        - Terminal-Icons PowerShell module
        - posh-git PowerShell module  
        - MesloLGM Nerd Font
        - JetBrains Mono Nerd Font
        
        The function modifies:
        - PowerShell profile ($PROFILE)
        - Windows Terminal settings.json
        

    #>

    Install-OhMyPosh

    Set-WindowsTerminalFont -FontName "JetBrainsMono Nerd Font Mono"

    Set-PSReadLineModule
}