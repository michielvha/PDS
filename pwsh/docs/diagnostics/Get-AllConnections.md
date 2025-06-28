---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Get-AllConnections

## SYNOPSIS
Retrieves and displays system logon and logoff events from the past 24 hours.

## SYNTAX

```
Get-AllConnections
```

## DESCRIPTION
The Get-AllConnections function retrieves all logon (Event ID 4624) and logoff (Event ID 4647) events 
from the Windows Security event log for the past 24 hours.
It provides detailed information about
each event including user name, domain, logon type, IP address (for remote connections), and timestamp.

The function displays a summary of connection events including total counts and unique users,
followed by a detailed table of all events sorted chronologically.

This function can be useful for system administrators to monitor login activity and
identify potential security concerns or unusual access patterns.

## EXAMPLES

### EXAMPLE 1
```
Get-AllConnections
```

Displays a summary of logon/logoff activity in the past 24 hours, followed by a detailed
chronological table of all events with user, type, and source information.

### EXAMPLE 2
```
$events = Get-AllConnections
$events | Where-Object {$_.LogonType -eq "RemoteInteractive"} | Format-Table
```

Captures the returned events in a variable and filters to show only Remote Desktop (RDP) logons.

## PARAMETERS

## INPUTS

## OUTPUTS

## NOTES
- Requires access to the Security event log (typically requires administrative privileges)
- Uses Event ID 4624 for logon events and Event ID 4647 for logoff events
- May return a large number of events on busy systems
- Logon types are translated to human-readable format:
  * Type 2: Interactive (local logon)
  * Type 3: Network (e.g., connecting to shared folder)
  * Type 10: RemoteInteractive (RDP)

## RELATED LINKS
