---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Get-LogonEvents

## SYNOPSIS
Retrieves and displays user logon events from the Windows Security log.

## SYNTAX

```
Get-LogonEvents [[-Days] <Int32>] [[-ShowGridView] <Boolean>] [-IncludeSystemAccounts]
```

## DESCRIPTION
The Get-LogonEvents function retrieves logon events (EventID 4624) from the Security log
for a specified time period.
It filters out system accounts and displays the results in 
a grid view with detailed information including timestamp, account name, logon type (with
description), and source IP/computer.

This function is useful for security auditing and monitoring user access to systems.

## EXAMPLES

### EXAMPLE 1
```
Get-LogonEvents
```

Retrieves all user logon events from the past day and displays them in a grid view.

### EXAMPLE 2
```
Get-LogonEvents -Days 7 -ShowGridView $false
```

Retrieves logon events from the past week and returns them as objects without displaying the grid view.

### EXAMPLE 3
```
Get-LogonEvents -Days 3 | Where-Object {$_.LogonTypeDescription -eq "Remote Desktop"}
```

Retrieves logon events from the past 3 days and filters for just Remote Desktop connections.

## PARAMETERS

### -Days
Specifies the number of days to look back for logon events.
Default is 1 day.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: 1
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowGridView
If specified, displays the results in a grid view window.
Default is $true.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeSystemAccounts
If specified, includes system accounts in the results.
Default is $false.

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
Logon Types:
2 = Interactive (Local logon)
3 = Network (Connection to shared folder)
4 = Batch (Scheduled task)
5 = Service (Service startup)
7 = Unlock (Unlocking a previously locked session)
8 = NetworkCleartext (Most often indicates a logon to IIS with "basic authentication")
9 = NewCredentials (A process ran using RunAs)
10 = RemoteInteractive (Terminal Services, Remote Desktop or Remote Assistance)
11 = CachedInteractive (Logon using cached domain credentials when a DC is not available)

## RELATED LINKS
