Function Start-ISEAsAdmin {
    <#
    .SYNOPSIS
        Opens PowerShell ISE with administrative privileges.

    .DESCRIPTION
        The Start-ISEAsAdmin function launches a new instance of the PowerShell Integrated
        Scripting Environment (ISE) with elevated administrative privileges.
        This is useful for editing and running scripts that require administrative access.

    .PARAMETER FilePath
        Specifies a script file to open in the ISE window.
        If not specified, ISE will open without any files loaded.

    .PARAMETER Wait
        If specified, waits for the ISE process to exit before returning control.
        By default, the function returns immediately after launching ISE.

    .EXAMPLE
        Start-ISEAsAdmin
        
        Opens PowerShell ISE with administrative privileges.

    .EXAMPLE
        Start-ISEAsAdmin -FilePath "C:\Scripts\MyAdminScript.ps1"
        
        Opens PowerShell ISE with administrative privileges and loads the specified script file.

    .EXAMPLE
        Start-ISEAsAdmin -Wait
        
        Opens PowerShell ISE with administrative privileges and waits for the ISE to be closed before returning.

    .NOTES
        - This function requires User Account Control (UAC) prompt acceptance to elevate privileges
        - Windows PowerShell ISE is not included in PowerShell 7 or above, this function is for Windows PowerShell 5.1 and below
        - Windows PowerShell ISE may not be available in future versions of Windows

    .LINK
        https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/ise/introducing-the-windows-powershell-ise
    #>

    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [string]$FilePath,
        
        [Parameter()]
        [switch]$Wait
    )

    # Check if PowerShell ISE is available
    if (-not (Get-Command -Name powershell_ise.exe -ErrorAction SilentlyContinue)) {
        Write-Error "PowerShell ISE (powershell_ise.exe) not found. This may be because you're running PowerShell 7 or the ISE feature is not installed."
        return
    }

    # Build process arguments
    $processArgs = @{
        FilePath = "powershell_ise.exe"
        Verb = "runas"  # Run as administrator
        ErrorAction = "Stop"
    }

    # Add file path if specified
    if ($FilePath) {
        if (Test-Path -Path $FilePath) {
            $processArgs.ArgumentList = "`"$FilePath`""
        } else {
            Write-Warning "File not found: $FilePath"
            $confirmResult = $Host.UI.PromptForChoice(
                "File Not Found", 
                "The specified file doesn't exist. Do you want to open ISE anyway?", 
                @("&Yes", "&No"), 
                1)
            if ($confirmResult -eq 1) {
                return
            }
        }
    }

    # Add wait parameter if specified
    if ($Wait) {
        $processArgs.Wait = $true
    }

    try {
        Write-Verbose "Starting PowerShell ISE with administrative privileges..."
        $process = Start-Process @processArgs
        Write-Verbose "PowerShell ISE started successfully."
        
        if (-not $Wait) {
            # If we specified -Wait, Start-Process handles waiting
            # Otherwise, return the process object
            return $process
        }
    }
    catch {
        Write-Error "Failed to start PowerShell ISE: $_"
    }
}
