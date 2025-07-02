function Get-WinDefExcludedPath {
    <#
    .SYNOPSIS
        Retrieves the paths excluded from Windows Defender scanning.
    
    .DESCRIPTION
        This function returns a list of all file paths that are currently excluded from 
        Windows Defender real-time and scheduled scanning. These exclusions can be 
        security risks if not properly monitored and managed.
    
    .EXAMPLE
        Get-WinDefExcludedPath
        
        # Returns all paths excluded from Windows Defender scanning

    .EXAMPLE
        Get-WinDefExcludedPath | Where-Object { $_ -like "*temp*" }
        
        # Returns only excluded paths that contain "temp"

    .NOTES
        This function requires administrative privileges to access Windows Defender settings.
        
        Author: Michiel VH
    .LINK
        https://docs.microsoft.com/en-us/powershell/module/defender/get-mppreference
    #>
    

    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "⚠️ This function needs to be ran as admin please rerun it with the proper rights."
    start-sleep 5
    exit
    } else {
        Write-Output "🛡️ Listing all Windows Defender excluded paths..."
        Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
    }

    # add new entry with : Add-MpPreference -ExclusionPath "C:\Path\To\Ignore"
    
}
