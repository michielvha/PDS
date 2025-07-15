function Install-OhMyPosh {
    <#
    .SYNOPSIS
        Installs Oh My Posh prompt engine and essential PowerShell modules for enhanced terminal experience.

    .DESCRIPTION
        The `Install-OhMyPosh` function installs and configures Oh My Posh along with complementary PowerShell modules to create a rich terminal experience. The function performs the following operations:
        
        1. **Oh My Posh Installation**: Installs Oh My Posh via winget if not already present
        2. **Terminal-Icons Module**: Installs the Terminal-Icons module for enhanced file/folder icons in directory listings
        3. **Posh-Git Module**: Installs posh-git for Git repository status integration in the prompt
        4. **Theme Customization**: Modifies the powerlevel10k_rainbow theme to remove console title override, allowing custom window titles
        5. **Profile Configuration**: Automatically configures the PowerShell profile with:
           - Oh My Posh initialization with powerlevel10k_rainbow theme
           - Custom window title logic that shows PowerShell version (pwsh/PowerShell) and admin status
           - Module imports for Terminal-Icons and posh-git
           - PDS module auto-loading
           - Chocolatey profile integration for refreshenv functionality
        6. **Profile Creation**: Creates the PowerShell profile file if it doesn't exist
        
        The function ensures all components are installed with CurrentUser scope and appends the necessary configuration to the PowerShell profile for immediate use. Window titles will display as "pwsh (Administrator)" for PowerShell 7+ running as admin, "pwsh" for regular PowerShell 7+, "PowerShell (Administrator)" for PowerShell 5.1 as admin, or "PowerShell" for regular PowerShell 5.1.

    .EXAMPLE
        Install-OhMyPosh
        
        Installs Oh My Posh with the powerlevel10k_rainbow theme, Terminal-Icons, and posh-git modules. 
        Modifies the theme file to remove console title override and configures the PowerShell profile 
        to load these components automatically with custom window title logic. Creates the profile file 
        if it doesn't exist and appends all necessary configurations.

    .NOTES
        Author: Michiel VH

    .LINK
        install:        https://ohmyposh.dev/docs/installation/windows
        customize:      https://ohmyposh.dev/docs/installation/customize
        themes:         https://ohmyposh.dev/docs/themes
        custom theme:   https://ohmyposh.dev/docs/configuration/general
    #>


    # Install Oh My Posh if not already installed
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Oh My Posh..."
        Write-Verbose "Using winget to install Oh My Posh.`nThis will fetch the exe and latest themes from the official repository.`nThe installation is user scoped"
        winget install JanDeDobbeleer.OhMyPosh -s winget
    }

    if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
        Write-Host "Installing Terminal-Icons..."
        Install-Module Terminal-Icons -Force # -Scope CurrentUser
    }

    if (-not (Get-Module -ListAvailable -Name posh-git)) {
        Write-Host "Installing posh-git..."
        Install-Module posh-git -Force # -Scope CurrentUser
    }

    # Remove console_title_template from powerlevel10k_rainbow theme to allow PowerShell default window title behavior
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        $themeFile = "$env:POSH_THEMES_PATH\powerlevel10k_rainbow.omp.json"
        if (Test-Path $themeFile) {
            Write-Host "Modifying Oh My Posh theme to remove console title override..."
            $themeContent = Get-Content $themeFile -Raw
            
            # Check if console_title_template exists
            if ($themeContent -match '"console_title_template"') {
                Write-Host "Found console_title_template, removing it..."
                # More flexible regex - handles different line endings and spacing
                $modifiedContent = $themeContent -replace '(?m)^\s*"console_title_template"\s*:\s*"[^"]*"\s*,?\s*$\r?\n?', ''
                $modifiedContent | Set-Content $themeFile -Encoding UTF8
                Write-Host "Console title template removed successfully"
            } else {
                Write-Host "Console title template not found in theme file"
            }
        } else {
            Write-Host "Theme file not found at: $themeFile"
        }
    }

    # TODO: Check to enable quake mode for windows terminal
    # https://youtu.be/4GASGO0go5I?si=C2jEFteGInNTOCoK&t=628   

    # TODO: check to implement this UnixCompleters, verify if usefull
    # # 3. Unix completions
    # if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.UnixCompleters)) {
    #     Install-Module Microsoft.PowerShell.UnixCompleters -Scope CurrentUser -Force
    # }
    # Import-Module Microsoft.PowerShell.UnixCompleters


    # TODO: Only add these commands if they are not already in the profile
    $commands = @"
# load powerlevel10k_rainbow theme
oh-my-posh init pwsh --config "`$env:POSH_THEMES_PATH\powerlevel10k_rainbow.omp.json" | Invoke-Expression

# Set custom window title with admin status and PowerShell version (since we removed console_title_template from theme)
`$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
`$psVersion = if (`$PSVersionTable.PSVersion.Major -ge 7) { "pwsh" } else { "PowerShell" }
`$adminSuffix = if (`$isAdmin) { " (Administrator)" } else { "" }
`$Host.UI.RawUI.WindowTitle = "`$psVersion`$adminSuffix"

Import-Module -Name PDS                                                               # Load PDS module
Import-Module Terminal-Icons                                                          # Load Terminal-Icons module for icons in ls/dir
Import-Module posh-git                                                                # Load posh-git module for git status segments

`$ChocolateyProfile = "`$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"        # Load Chocolatey profile if it exists, for refreshenv
if (Test-Path(`$ChocolateyProfile)) {
Import-Module "`$ChocolateyProfile"
}

"@

    if (-not (Test-Path $PROFILE)) {
        Write-Host "Creating PowerShell profile at $PROFILE"
        New-Item -Path $PROFILE.AllUsersAllHosts -ItemType File -Force | Out-Null
    }

    # Append the commands to the global profile using tee
    $commands | Out-File -FilePath $PROFILE.AllUsersAllHosts -Encoding utf8 -Append
}