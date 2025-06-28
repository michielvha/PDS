---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Get-WindowsKey

## SYNOPSIS
Retrieves the Windows product key and OS information from local or remote computers.

## SYNTAX

```
Get-WindowsKey [[-Targets] <String[]>] [-Credential <PSCredential>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
The Get-WindowsKey function retrieves the Windows product key by decoding the DigitalProductId
from the registry.
It also collects additional operating system information such as OS version,
build number, architecture, and registration details.

This function can target local or remote computers and returns comprehensive information
about each system's Windows installation.

## EXAMPLES

### EXAMPLE 1
```
Get-WindowsKey
```

Retrieves the Windows product key and OS information from the local computer.

### EXAMPLE 2
```
Get-WindowsKey -ComputerName "Server01", "Server02"
```

Retrieves the Windows product key and OS information from two remote servers.

### EXAMPLE 3
```
Get-WindowsKey -ComputerName "Server01" -Credential (Get-Credential)
```

Prompts for credentials and uses them to retrieve the Windows product key from a remote server.

### EXAMPLE 4
```
"Server01", "Server02" | Get-WindowsKey | Export-Csv -Path "C:\WindowsKeys.csv" -NoTypeInformation
```

Retrieves Windows product keys from multiple servers and exports the results to a CSV file.

## PARAMETERS

### -Targets
{{ Fill Targets Description }}

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Computer, ComputerName, HostName

Required: False
Position: 1
Default value: .
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Credential
Specifies the credential object to use for authentication when connecting to remote computers.
Not required for local computer access or when using current credentials.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Original concept by Jakob Bindslet (jakob@bindslet.dk)
Enhanced with modern PowerShell techniques and improved error handling
this makes the function faster and more robust.

The digital product key decoding algorithm works on Windows XP through Windows 11.
Remote access requires appropriate permissions and network connectivity.

## RELATED LINKS
