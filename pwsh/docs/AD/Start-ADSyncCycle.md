---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Start-ADSyncCycle

## SYNOPSIS
Triggers AD Connect synchronization on remote domain controllers.

## SYNTAX

```
Start-ADSyncCycle [[-ComputerName] <String[]>] [-SyncType <String>] [-ConfigPath <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Start-ADSyncCycle function initiates an AD Connect synchronization cycle on one or more remote servers.
It supports both Delta (default) and Initial sync types and includes verification of PowerShell remoting
availability and connectivity to target servers before attempting to run the sync command.

This function helps automate the process of synchronizing Active Directory changes to Azure AD or
other connected directory services, making it useful for identity management automation tasks.

## EXAMPLES

### Example 1: Start a delta sync on a single server
```powershell
Start-ADSyncCycle -ComputerName "ADSyncServer01"
```

Triggers a delta synchronization cycle on the server named ADSyncServer01.

### Example 2: Start a full sync on multiple servers
```powershell
Start-ADSyncCycle -ComputerName "ADSyncServer01","ADSyncServer02" -SyncType Initial
```

Triggers a full initial synchronization cycle on two different servers.

### Example 3: Use a configuration file to specify servers
```powershell
Start-ADSyncCycle -ConfigPath "C:\Scripts\ADServers.txt"
```

Triggers a delta synchronization cycle on all servers listed in the specified configuration file.

## PARAMETERS

### -ComputerName
Specifies one or more remote servers where AD Connect is installed. You can provide an array of server names
or a single server name.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -SyncType
Specifies the type of synchronization to run. Valid values are 'Delta' (incremental sync, default) or 
'Initial' (full sync).

```yaml
Type: String
Parameter Sets: (All)
Aliases:
Accepted values: Delta, Initial

Required: False
Position: Named
Default value: Delta
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConfigPath
Optional. Path to a configuration file containing a list of server names, one per line.
If specified, servers from this file will be used in addition to any specified in ComputerName.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]
You can pipe server names to this function.

## OUTPUTS

### System.String
Returns status messages for each server processed.

## NOTES
Author: Michiel VH
Requirements: PowerShell Remoting must be enabled on local and remote machines
The account running this function must have appropriate permissions on the remote servers
