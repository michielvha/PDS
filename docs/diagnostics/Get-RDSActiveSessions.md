---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Get-RDSActiveSessions

## SYNOPSIS
Retrieves and logs active Remote Desktop Services (RDS) user sessions.

## SYNTAX

```
Get-RDSActiveSessions [[-LogPath] <String>] [[-TranscriptPath] <String>] [[-IdleThresholdMinutes] <Int32>]
 [-QuickMode]
```

## DESCRIPTION
The Get-RDSActiveSessions function retrieves all active RDS user sessions that have not been 
idle for more than 1 hour (configurable).
It displays details about each session including
the username, idle time, server name, creation time, disconnect time, and session state.

The function provides two modes:
1.
Quick mode: Simply counts and displays the number of active sessions
2.
Detailed mode: Provides comprehensive information about each session and logs it to a file

All activity is also logged to a transcript file for auditing purposes.

## EXAMPLES

### EXAMPLE 1
```
Get-RDSActiveSessions
```

Retrieves all RDS sessions that haven't been idle for more than 1 hour, displays details,
and logs the information to the default log files.

### EXAMPLE 2
```
Get-RDSActiveSessions -QuickMode
```

Quickly displays only the total count of active RDS sessions without detailed logging.

### EXAMPLE 3
```
Get-RDSActiveSessions -IdleThresholdMinutes 30 -LogPath "D:\Logs\rds_sessions.csv"
```

Retrieves RDS sessions that haven't been idle for more than 30 minutes and logs
the information to the specified log file.

## PARAMETERS

### -LogPath
Specifies the path where the session log file will be created.
Default is "C:\Logs\rdsUserMonitor.csv"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: C:\Logs\rdsUserMonitor.csv
Accept pipeline input: False
Accept wildcard characters: False
```

### -TranscriptPath
Specifies the path where the transcript file will be created.
Default is "C:\Logs\RdsMonitorTranscript.txt"

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: C:\Logs\RdsMonitorTranscript.txt
Accept pipeline input: False
Accept wildcard characters: False
```

### -IdleThresholdMinutes
Specifies the idle time threshold in minutes.
Sessions with idle time exceeding this
threshold will not be considered active.
Default is 60 (1 hour).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 60
Accept pipeline input: False
Accept wildcard characters: False
```

### -QuickMode
If specified, only displays the total count of active RDS sessions without detailed logging.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES
- Requires the Remote Desktop Services module
- Created originally by: Michiel Van Haegenborgh
- For scheduled execution, consider using the non-QuickMode to maintain logs

## RELATED LINKS
