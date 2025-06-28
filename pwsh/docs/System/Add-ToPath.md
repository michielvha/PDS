---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Add-ToPath

## SYNOPSIS
Adds a path to the user or system PATH environment variable.

## SYNTAX

```
Add-ToPath [-PathToAdd] <String> [-SystemPath] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function adds a path to the user or system PATH environment variable.

## EXAMPLES

### EXAMPLE 1
```
Add-ToPath -PathToAdd "C:\MyCustomTools"
```

Adds "C:\MyCustomTools" to the user PATH environment variable.

### EXAMPLE 2
```
Add-ToPath -PathToAdd "C:\SystemWideTools" -SystemPath
```

Adds "C:\SystemWideTools" to the system PATH environment variable.

## PARAMETERS

### -PathToAdd
The path to add to the PATH environment variable.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SystemPath
If set, modifies the system PATH instead of the user PATH.

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

## RELATED LINKS
