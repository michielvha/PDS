---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Clear-RedundantPSReadLineHistory

## SYNOPSIS
Removes duplicate entries from the PowerShell command history file.

## SYNTAX

```
Clear-RedundantPSReadLineHistory [-BackupFile] [-Force] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function reads the PowerShell command history file (ConsoleHost_history.txt), 
identifies duplicate entries, and removes them while maintaining the original order.
It works with the default PSReadLine history file located at:
%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt

## EXAMPLES

### EXAMPLE 1
```
Clear-PSReadLineHistory
```

# Removes all duplicate entries from the history file after confirmation

### EXAMPLE 2
```
Clear-PSReadLineHistory -BackupFile -Force
```

# Creates a backup and removes duplicates without asking for confirmation

## PARAMETERS

### -BackupFile
When set to true, creates a backup of the original history file before making changes.

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

### -Force
When set to true, skips confirmation before applying changes.

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

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

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
Date: June 28, 2025
Author: Michiel VH

## RELATED LINKS
