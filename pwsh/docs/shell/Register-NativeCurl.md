---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Register-NativeCurl

## SYNOPSIS
Creates an 'ncurl' function for the native curl binary.

## SYNTAX

```
Register-NativeCurl [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function creates an 'ncurl' function that calls the native curl binary installed via Chocolatey.
The function is added to your PowerShell profile so it persists across sessions.

This is useful in PowerShell 5.1 where the 'curl' command is aliased to Invoke-WebRequest.

## EXAMPLES

### EXAMPLE 1
```
Register-NativeCurl
```

# Creates the ncurl alias that points to the native curl.exe binary

## PARAMETERS

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
Date: June 28, 2025
Author: Michiel VH

PowerShell 7+ typically handles curl better, but this function helps in PowerShell 5.1
where curl is aliased to Invoke-WebRequest.

IMPORTANT: Manual install of curl is not needed, it's installed by default in \`C:\Windows\System32\curl.exe\`.
If you want to use the Chocolatey version, install it with: \`choco install curl\`.
It might be a more recent version.

## RELATED LINKS
