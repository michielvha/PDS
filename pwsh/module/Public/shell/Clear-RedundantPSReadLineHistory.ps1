Function Clear-RedundantPSReadLineHistory {
    <#
    .SYNOPSIS
    
    Removes duplicate entries from the PowerShell command history file.

    .DESCRIPTION

    This function reads the PowerShell command history file (ConsoleHost_history.txt), 
    identifies duplicate entries, and removes them while maintaining the original order.
    It works with the default PSReadLine history file located at:
    %APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt 

    .PARAMETER BackupFile

    When set to true, creates a backup of the original history file before making changes.

    .PARAMETER Force

    When set to true, skips confirmation before applying changes.

    .EXAMPLE

    Clear-PSReadLineHistory
    
    # Removes all duplicate entries from the history file after confirmation

    .EXAMPLE

    Clear-PSReadLineHistory -BackupFile -Force
    
    # Creates a backup and removes duplicates without asking for confirmation

    .NOTES

    Date: June 28, 2025

    .LINK

    about_PSReadLine

    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$BackupFile,
        
        [Parameter(Mandatory=$false)]
        [switch]$Force
    )

    begin {
        # Define the history file path
        $historyFilePath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
        
        # Check if file exists
        if (-not (Test-Path -Path $historyFilePath)) {
            Write-Error "History file not found at: $historyFilePath"
            return
        }
        
        Write-Verbose "Processing history file: $historyFilePath"
    }

    process {
        try {
            # Read all lines from the history file
            $historyLines = Get-Content -Path $historyFilePath -Encoding UTF8
            $originalCount = $historyLines.Count
            
            Write-Verbose "Read $originalCount lines from history file"
            
            # Create a backup if requested
            if ($BackupFile) {
                $backupPath = "$historyFilePath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item -Path $historyFilePath -Destination $backupPath
                Write-Verbose "Created backup at: $backupPath"
            }
            
            # Remove duplicates while maintaining order
            $uniqueLines = @()
            $duplicateCount = 0
            $seen = @{}
            
            foreach ($line in $historyLines) {
                if (-not $seen.ContainsKey($line)) {
                    $seen[$line] = $true
                    $uniqueLines += $line
                }
                else {
                    $duplicateCount++
                    Write-Verbose "Found duplicate: $line"
                }
            }
            
            $newCount = $uniqueLines.Count
            
            # Show summary and confirm before proceeding
            $message = "Found $duplicateCount duplicate entries. Will reduce history from $originalCount to $newCount lines."
            
            if ($Force -or $PSCmdlet.ShouldProcess($historyFilePath, $message)) {
                # Write the unique lines back to the file
                $uniqueLines | Set-Content -Path $historyFilePath -Encoding UTF8
                Write-Output "Successfully removed $duplicateCount duplicate entries from history file."
                Write-Verbose "History file now contains $newCount unique commands."
            }
            else {
                Write-Output "Operation cancelled. No changes made to history file."
            }
        }
        catch {
            Write-Error "Error processing history file: $_"
        }
    }

    end {
        Write-Verbose "Operation completed"
    }
}
