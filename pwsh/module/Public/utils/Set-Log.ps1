# Module-level variable for project name
if (-not $Script:LogProjectName) {
    $Script:LogProjectName = $env:COMPUTERNAME
}

function Set-LogProject {
    <#
    .SYNOPSIS
        Sets the project name for logging operations.

    .DESCRIPTION
        This function sets a module-level variable that determines the project name used in log file names. 
        Once set, all subsequent calls to Set-Log will use this project name unless explicitly overridden.

    .PARAMETER ProjectName
        The name of the project to use for logging. This will be used as part of the log file name.

    .EXAMPLE
        Set-LogProject -ProjectName "MyProject"

        Sets the project name to "MyProject". All subsequent log entries will be written to "$env:USERPROFILE\MyProject-log.txt".

    .EXAMPLE
        Set-LogProject "WebApp2024"

        Sets the project name to "WebApp2024" using positional parameter.

    .NOTES
        Author: Michiel VH

        The project name persists for the entire PowerShell session or until changed with another call to Set-LogProject.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$ProjectName
    )
    $Script:LogProjectName = $ProjectName
    Write-Host "Log project name set to: $ProjectName"
}

function Set-Log {
    <#
    .SYNOPSIS
        Writes a timestamped log entry to a project-specific log file.

    .DESCRIPTION
        This function writes a log message with a timestamp to a log file. The log file is named based on the current project name 
        and is stored in the user's profile directory. The project name can be set using Set-LogProject or overridden per call.

    .PARAMETER Message
        The message to write to the log file.

    .PARAMETER ProjectName
        Optional. The project name to use for this specific log entry. If not specified, uses the project name set by Set-LogProject 
        or defaults to the computer name.

    .EXAMPLE
        Set-Log -Message "Application started successfully"

        Writes a timestamped log entry using the current project name (default or set by Set-LogProject).

    .EXAMPLE
        Set-Log "User login attempt failed"

        Writes a log entry using positional parameter.

    .EXAMPLE
        Set-Log -Message "Database backup completed" -ProjectName "BackupSystem"

        Writes a log entry to the "BackupSystem" project log, overriding the current project setting for this entry only.

    .NOTES
        Author: Michiel VH

        Log files are created in the format: "$env:USERPROFILE\{ProjectName}-log.txt"
        If an error occurs while writing to the log file, it will attempt to log the error and display it to the console.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$ProjectName = $Script:LogProjectName
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd | HH:mm:ss"
    $logEntry = "$timestamp : $Message"

    try {
        Add-Content -Path "$env:USERPROFILE\$ProjectName-log.txt" -Value $logEntry -ErrorAction Stop
    } catch {
        Set-Log "An error occurred while adding the log entry: $_"
        Write-Host "An error occurred while adding the log entry: $_"
    }
}