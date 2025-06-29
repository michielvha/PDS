Function New-VSCodeShortcut {
    <#
    .SYNOPSIS
        Creates a desktop shortcut that opens a specific file in Visual Studio Code.

    .DESCRIPTION
        This function creates a Windows shortcut (.lnk file) on the user's desktop 
        that will open the specified file in Visual Studio Code when clicked.

    .PARAMETER FilePath
        The path to the file that should be opened in VS Code when the shortcut is clicked.
        This parameter is mandatory.

    .EXAMPLE
        New-VSCodeShortcut -FilePath "C:\Projects\myproject\app.js"
        Creates a shortcut on the desktop named "app.js - VS Code.lnk" that opens app.js in VS Code.

    .NOTES
        This function requires Visual Studio Code to be installed on the system.
        The shortcut is placed on the desktop of the user running the function.

        Author: Michiel VH

    .LINK
        https://code.visualstudio.com/

    #>

    # Parameters
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [string]$FilePath
    )

    # Get absolute path if relative path is provided
    $FilePath = (Resolve-Path -Path $FilePath).Path
    
    # Get the filename from the path for the shortcut name
    $fileName = Split-Path -Path $FilePath -Leaf
    
    # Define shortcut path on user's desktop
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path -Path $desktopPath -ChildPath "$fileName - VS Code.lnk"
    
    # Create WScript.Shell COM Object
    $WScriptShell = New-Object -ComObject WScript.Shell
    
    # Create the shortcut
    $Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    
    # Find VS Code executable path
    $vscodePath = "C:\Program Files\Microsoft VS Code\Code.exe"
    if (-not (Test-Path -Path $vscodePath)) {
        # Try alternative locations if the primary location doesn't exist
        $alternativePaths = @(
            "${env:ProgramFiles}\Microsoft VS Code\Code.exe",
            "${env:LocalAppData}\Programs\Microsoft VS Code\Code.exe"
        )
        
        foreach ($path in $alternativePaths) {
            if (Test-Path -Path $path) {
                $vscodePath = $path
                break
            }
        }
        
        # Last resort, try to get from command
        if (-not (Test-Path -Path $vscodePath)) {
            $commandPath = Get-Command -Name code -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
            if ($commandPath) {
                $vscodePath = $commandPath
            }
        }
    }
    
    # Set VS Code as the target and use its icon
    $Shortcut.TargetPath = $vscodePath
    $Shortcut.Arguments = "`"$FilePath`""
    $Shortcut.IconLocation = $vscodePath
    $Shortcut.Description = "Open $fileName in Visual Studio Code"
    
    # Save the shortcut
    $Shortcut.Save()
    
    # Output success message with shortcut path
    Write-Output "VS Code shortcut created at: $shortcutPath"
}