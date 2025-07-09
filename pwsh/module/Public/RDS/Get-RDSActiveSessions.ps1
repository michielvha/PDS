function Get-RDSActiveSessions {
    <#
    .SYNOPSIS
        Monitors and logs active Remote Desktop Services user sessions.

    .DESCRIPTION
        This function retrieves active RDS user sessions that haven't been idle for more than a specified threshold.
        It logs the session information to both a CSV log file and can optionally export to a separate CSV file.
        The function is designed to be used for monitoring user activity on RDS servers.

    .PARAMETER IdleThresholdMinutes
        The idle time threshold in minutes. Sessions idle longer than this will be excluded. Default is 60 minutes.

    .PARAMETER LogPath
        Path to the main log file. Default is "C:\Logs\rdsUserMonitor.csv".

    .PARAMETER ExportPath
        Path to export session data to a CSV file. If not specified, exports to ".\<hostname>-signIns.csv".

    .PARAMETER TranscriptPath
        Path to the transcript log file. Default is "C:\Logs\RdsMonitorTranscript.txt".

    .PARAMETER NoTranscript
        Switch to disable transcript logging.

    .EXAMPLE
        Get-RDSActiveSessions

        Monitors active RDS sessions using default settings (60-minute idle threshold).

    .EXAMPLE
        Get-RDSActiveSessions -IdleThresholdMinutes 30

        Monitors active RDS sessions with a 30-minute idle threshold.

    .EXAMPLE
        Get-RDSActiveSessions -LogPath "D:\Logs\rds.csv" -ExportPath "D:\Reports\sessions.csv"

        Monitors active RDS sessions with custom log and export paths.

    .EXAMPLE
        Get-RDSActiveSessions -NoTranscript

        Monitors active RDS sessions without creating a transcript log.

    .NOTES
        Author: Michiel VH
        This function requires the RemoteDesktop PowerShell module.
        
        The function creates log directories if they don't exist.

    .LINK
        https://docs.microsoft.com/en-us/powershell/module/remotedesktop/get-rdusersession
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$IdleThresholdMinutes = 60,

        [Parameter(Mandatory = $false)]
        [string]$LogPath = "C:\Logs\rdsUserMonitor.csv",

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [string]$TranscriptPath = "C:\Logs\RdsMonitorTranscript.txt",

        [Parameter(Mandatory = $false)]
        [switch]$NoTranscript
    )

    # Import the Remote Desktop module if not already loaded
    if (-not (Get-Module -Name RemoteDesktop -ErrorAction SilentlyContinue)) {
        try {
            Import-Module RemoteDesktop -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to import the RemoteDesktop module. Please ensure it is installed. Error: $_"
            return
        }
    }

    # Start transcript if not disabled
    if (-not $NoTranscript) {
        try {
            $transcriptDir = Split-Path -Path $TranscriptPath -Parent
            if (-not (Test-Path $transcriptDir)) {
                New-Item -ItemType Directory -Path $transcriptDir -Force | Out-Null
            }
            Start-Transcript -Path $TranscriptPath -Append -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to start transcript: $_"
        }
    }

    try {
        $hostname = $env:COMPUTERNAME
        
        # Set default export path if not provided
        if (-not $ExportPath) {
            $ExportPath = ".\$hostname-signIns.csv"
        }

        # Helper function for logging
        function Set-Log {
            param (
                [string]$Message,
                [string]$Path = $LogPath
            )

            $timestamp = Get-Date -Format "yyyy-MM-dd | HH:mm:ss"
            $logEntry = "$timestamp,$Message"

            try {
                $logDir = Split-Path -Path $Path -Parent
                if (-not (Test-Path $logDir)) {
                    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
                }
                Add-Content -Path $Path -Value $logEntry -ErrorAction Stop
            }
            catch {
                Write-Error "An error occurred while adding the log entry: $_"
            }
        }

        # Convert idle threshold to milliseconds
        $idleThreshold = $IdleThresholdMinutes * 60000

        Write-Verbose "Getting RDS user sessions with idle threshold of $IdleThresholdMinutes minutes"
        
        # Get active sessions that haven't been idle for more than the threshold
        $activeSessions = Get-RDUserSession | Where-Object { $_.IdleTime -lt $idleThreshold }

        if ($activeSessions) {
            Write-Host "Found $($activeSessions.Count) active user session(s)"
            
            foreach ($session in $activeSessions) {
                $timestamp = Get-Date -Format "HH:mm:ss"
                $signInData = New-Object PSObject -Property @{
                    logTime = $timestamp
                    userName = if($null -ne $session.UserName) { $session.UserName } else { "N/A" }
                    createTime = if($null -ne $session.CreateTime) { $session.CreateTime } else { "N/A" }
                    sessionState = if($null -ne $session.SessionState) { $session.SessionState } else { "N/A" }
                    disconnectTime = if($null -ne $session.DisconnectTime) { $session.DisconnectTime } else { "N/A" }
                    idleTimeMinutes = if($null -ne $session.IdleTime) { [math]::Round($session.IdleTime / 60000) } else { "N/A" }
                    serverName = if($null -ne $session.ServerName) { $session.ServerName } else { "N/A" }
                }

                # Log to main log file
                Set-Log "$($signInData.userName),$($signInData.idleTimeMinutes),$($signInData.serverName),$($signInData.createTime),$($signInData.disconnectTime),$($signInData.sessionState)"
                
                # Export to CSV
                $signInData | Export-Csv -Path $ExportPath -NoTypeInformation -Append
                
                Write-Host "Collected log entry for $($signInData.userName)" -ForegroundColor Green
            }
        }
        else {
            $message = "No active user sessions found that haven't been idle for more than $IdleThresholdMinutes minutes"
            Write-Host $message -ForegroundColor Yellow
            Set-Log $message
        }
    }
    catch {
        Write-Error "An error occurred while processing RDS sessions: $_"
    }
    finally {
        # Stop transcript if it was started
        if (-not $NoTranscript) {
            try {
                Stop-Transcript -ErrorAction SilentlyContinue
            }
            catch {
                # Transcript might not have been started successfully
            }
        }
    }
}
