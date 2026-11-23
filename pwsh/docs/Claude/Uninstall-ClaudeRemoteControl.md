---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Uninstall-ClaudeRemoteControl

## SYNOPSIS
Stops and removes the Claude Code Remote Control service that Install-ClaudeRemoteControl created.

## SYNTAX

```
Uninstall-ClaudeRemoteControl [[-WorkingDirectory] <String>] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
On macOS, unloads the LaunchAgent from the gui/\<uid\> domain and deletes its plist.
On Linux, disables
and stops the systemd --user unit, deletes it and reloads systemd.

It leaves the log file, linger, workspace trust, Remote Control consent and the Claude login as they
are: other services and sessions may rely on them.

## EXAMPLES

### EXAMPLE 1
```
Uninstall-ClaudeRemoteControl -WorkingDirectory ~/code/vh-adlc
```

Removes the bridge service for ~/code/vh-adlc.

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

### -WorkingDirectory
The directory the bridge serves, as given to Install-ClaudeRemoteControl.
Defaults to the current location.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: (Get-Location).Path
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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Supported on macOS and Linux.
Requires PowerShell 7.

Author: Michiel VH

## RELATED LINKS
