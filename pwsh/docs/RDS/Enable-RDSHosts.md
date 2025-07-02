---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Enable-RDSHosts

## SYNOPSIS
Enables connections to specified Remote Desktop Session Hosts.

## SYNTAX

```
Enable-RDSHosts [[-ServerNames] <String[]>] [[-ConfigPath] <String>] [<CommonParameters>]
```

## DESCRIPTION
This function enables new connections on specified Remote Desktop Session Hosts.
It can accept:
1. An array of server names directly through the -ServerNames parameter
2. A path to a configuration file containing server names
3. Use default server names if neither parameter is provided

The function requires the Remote Desktop Services module, which will be imported
automatically if needed.

## EXAMPLES

### EXAMPLE 1
```
Enable-RDSHosts
```

Enables new connections on the default set of RDS hosts.

### EXAMPLE 2
```
Enable-RDSHosts -ServerNames "server1.domain.com", "server2.domain.com"
```

Enables new connections on the specified RDS servers.

### EXAMPLE 3
```
Enable-RDSHosts -ConfigPath "C:\Config\rds-servers.txt"
```

Enables new connections on RDS servers listed in the specified configuration file.

## PARAMETERS

### -ServerNames
An array of Remote Desktop Session Host server names where new connections should be allowed.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConfigPath
Path to a configuration file containing server names (one per line).
If both ServerNames and ConfigPath are provided, ServerNames takes precedence.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Michiel VH
This function requires the RemoteDesktop PowerShell module.

The default server list can be customized by modifying this function.

## RELATED LINKS

[https://docs.microsoft.com/en-us/powershell/module/remotedesktop/set-rdsessionhost](https://docs.microsoft.com/en-us/powershell/module/remotedesktop/set-rdsessionhost)
