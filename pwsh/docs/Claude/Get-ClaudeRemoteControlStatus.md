---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Get-ClaudeRemoteControlStatus

## SYNOPSIS
Reports the Claude Code Remote Control service for a working directory and what still stops it from starting.

## SYNTAX

```
Get-ClaudeRemoteControlStatus [[-WorkingDirectory] <String>] [[-ClaudePath] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Finds the service that Install-ClaudeRemoteControl writes for the working directory: a LaunchAgent on
macOS or a systemd --user unit on Linux.
Returns whether it is installed, loaded and running, where it
logs, and one check per known trap:

- Claude binary: the claude command exists.
- Nonessential traffic: no Claude settings file sets CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC.
Remote
  Control needs feature-flag evaluation, which that setting turns off.
Settings env overrides the shell.
- Login: claude auth status reports a login.
Over SSH on macOS the Keychain is out of reach, so the
  answer is Unknown there.
- Workspace trust: the owner accepted the trust dialog for the directory or a parent.
- Remote Control consent: the owner answered y to "Enable Remote Control?" once.
- Linger (Linux only): the user's systemd instance keeps running after logout.

Each check has a Status of Ready, Action, Unknown or Optional, and a Step that says what to do.
The function only reads.
It never records trust or consent.

## EXAMPLES

### EXAMPLE 1
```
Get-ClaudeRemoteControlStatus -WorkingDirectory ~/code/vh-adlc
```

Shows the service state for ~/code/vh-adlc.

### EXAMPLE 2
```
(Get-ClaudeRemoteControlStatus).Checks | Where-Object Status -NE 'Ready'
```

Lists what still needs doing for the bridge in the current directory.

## PARAMETERS

### -ClaudePath
The claude binary to check.
Defaults to the claude command on PATH.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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

### -WorkingDirectory
The directory the bridge serves.
The service name is derived from its last path segment.
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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Management.Automation.PSObject
## NOTES
Supported on macOS and Linux.
Requires PowerShell 7.

Author: Michiel VH

## RELATED LINKS
