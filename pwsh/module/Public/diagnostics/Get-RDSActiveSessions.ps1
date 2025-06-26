Function Get-RDSActiveSessions {
    <#
    .SYNOPSIS
        Retrieves and logs active Remote Desktop Services (RDS) user sessions.

    .DESCRIPTION
        The Get-RDSActiveSessions function retrieves all active RDS user sessions that have not been 
        idle for more than 1 hour (configurable). It displays details about each session including
        the username, idle time, server name, creation time, disconnect time, and session state.
        
        The function provides two modes:
        1. Quick mode: Simply counts and displays the number of active sessions
        2. Detailed mode: Provides comprehensive information about each session and logs it to a file

        All activity is also logged to a transcript file for auditing purposes.

    .PARAMETER LogPath
        Specifies the path where the session log file will be created.
        Default is "C:\Logs\rdsUserMonitor.csv"

    .PARAMETER TranscriptPath
        Specifies the path where the transcript file will be created.
        Default is "C:\Logs\RdsMonitorTranscript.txt"

    .PARAMETER IdleThresholdMinutes
        Specifies the idle time threshold in minutes. Sessions with idle time exceeding this
        threshold will not be considered active.
        Default is 60 (1 hour).

    .PARAMETER QuickMode
        If specified, only displays the total count of active RDS sessions without detailed logging.

    .EXAMPLE
        Get-RDSActiveSessions
        
        Retrieves all RDS sessions that haven't been idle for more than 1 hour, displays details,
        and logs the information to the default log files.

    .EXAMPLE
        Get-RDSActiveSessions -QuickMode
        
        Quickly displays only the total count of active RDS sessions without detailed logging.

    .EXAMPLE
        Get-RDSActiveSessions -IdleThresholdMinutes 30 -LogPath "D:\Logs\rds_sessions.csv"
        
        Retrieves RDS sessions that haven't been idle for more than 30 minutes and logs
        the information to the specified log file.

    .NOTES
        - Requires the Remote Desktop Services module
        - Created originally by: Michiel Van Haegenborgh
        - For scheduled execution, consider using the non-QuickMode to maintain logs
    #>
    
    param (
        [string]$LogPath = "C:\Logs\rdsUserMonitor.csv",
        [string]$TranscriptPath = "C:\Logs\RdsMonitorTranscript.txt",
        [int]$IdleThresholdMinutes = 60,
        [switch]$QuickMode
    )

    # If QuickMode is enabled, just do a quick count and return
    if ($QuickMode) {
        $activeSessions = Get-RDUserSession | Select-Object -Property UserName, IdleTime, ServerIPAddress, ServerName
        $numberOfUsers = $activeSessions.Count
        Write-Host "Number of active RDS sessions: $numberOfUsers"
        return $activeSessions
    }

    # Start transcript logging
    $transcriptDir = Split-Path -Path $TranscriptPath -Parent
    if (-not (Test-Path -Path $transcriptDir)) {
        New-Item -Path $transcriptDir -ItemType Directory -Force | Out-Null
    }
    Start-Transcript -Path $TranscriptPath -Append

    # Create log directory if it doesn't exist
    $logDir = Split-Path -Path $LogPath -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    function Set-Log {
        param (
            [string]$Message
        )

        $timestamp = Get-Date -Format "yyyy-MM-dd | HH:mm:ss"
        $logEntry = "$timestamp : $Message"

        try {
            Add-Content -Path $LogPath -Value $logEntry -ErrorAction Stop
        } catch {
            Write-Host "An error occurred while adding the log entry: $_"
        }
    }

    # Convert minutes to milliseconds for the idle time threshold
    $idleThreshold = $IdleThresholdMinutes * 60 * 1000

    $activeSessions = Get-RDUserSession | Where-Object { $_.IdleTime -lt $idleThreshold }

    if ($activeSessions) {
        foreach ($session in $activeSessions) {
            $userName = $session.UserName
            $createTime = $session.CreateTime
            $sessionState = $session.SessionState
            $disconnectTime = $session.DisconnectTime
            $idleTimeSeconds = [math]::Round($session.IdleTime / 1000)
            $idleTimeMinutes = [math]::Round($idleTimeSeconds / 60)
            $serverName = $session.ServerName

            Write-Host "User: $userName | Idle Time: $idleTimeMinutes minutes | Server Name: $serverName | Create Time: $createTime | Disconnect Time: $disconnectTime | Session State: $sessionState" 
            Set-Log "$username,$idleTimeMinutes,$serverName,$createTime,$disconnectTime,$sessionState"
        }
    } else {
        Write-Host "No active user sessions found that haven't been idle for more than $IdleThresholdMinutes minutes"
        Set-Log "No active user sessions found that haven't been idle for more than $IdleThresholdMinutes minutes"
    }

    Stop-Transcript
    return $activeSessions
}
