---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Install-ClaudeRemoteControl

## SYNOPSIS
Runs claude remote-control as a per-user service, so the machine stays available as a Remote Control environment.

## SYNTAX

```
Install-ClaudeRemoteControl [[-WorkingDirectory] <String>] [[-Name] <String>] [[-ClaudePath] <String>]
 [[-SpawnMode] <String>] [[-SearchPath] <String>] [-EnableLinger] [-ProgressAction <ActionPreference>]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Writes and starts a service that runs claude remote-control in the working directory and restarts it
when it exits:

- macOS: a LaunchAgent at ~/Library/LaunchAgents/pro.vhco.claude-remote-control.\<id\>.plist, loaded
  into the gui/\<uid\> domain with launchctl bootstrap.
It runs at load, is kept alive with a 60 second
  throttle and logs to ~/Library/Logs/claude-remote-control-\<id\>.log.
The GUI domain can read the
  login from the Keychain, which an SSH session cannot.
- Linux: a systemd --user unit at ~/.config/systemd/user/claude-remote-control-\<id\>.service, enabled
  and started, restarting every 60 seconds.
It logs to the journal.
-EnableLinger keeps it running
  after logout, which a server needs.

\<id\> is the last segment of the working directory.
Running it again with the same parameters changes
nothing; changed parameters rewrite the file and restart the service.

It then checks the traps that stop Remote Control from starting and prints the steps that are left.
Two of them are the owner's decision and stay manual: accepting workspace trust and answering
"Enable Remote Control?" once.
This function never records either.
The service retries every minute,
so it starts by itself once the steps are done.

## EXAMPLES

### EXAMPLE 1
```
Install-ClaudeRemoteControl -WorkingDirectory ~/code/vh-adlc -Name macbook-vh-adlc
```

Installs and starts the bridge for ~/code/vh-adlc, shown as macbook-vh-adlc.

### EXAMPLE 2
```
Install-ClaudeRemoteControl -WorkingDirectory ~/code/vh-adlc -EnableLinger
```

On a Linux server, installs the bridge and keeps it running after logout.

## PARAMETERS

### -ClaudePath
The claude binary the service runs.
Defaults to the claude command on PATH, for example
/opt/homebrew/bin/claude from the Homebrew cask claude-code@latest.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnableLinger
Linux only.
Runs loginctl enable-linger for the current user, so the service runs without a login session.

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

### -Name
The name the bridge shows in claude.ai/code.
Defaults to \<short host name\>-\<id\>.

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

### -SearchPath
The PATH the service and the sessions it starts get.
Defaults to the current PATH.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: $env:PATH
Accept pipeline input: False
Accept wildcard characters: False
```

### -SpawnMode
How the bridge starts sessions: same-dir (default), worktree or session.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: Same-dir
Accept pipeline input: False
Accept wildcard characters: False
```

### -WorkingDirectory
The directory the bridge serves.
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

### System.Management.Automation.PSObject
## NOTES
Supported on macOS and Linux.
Requires PowerShell 7.
Get-ClaudeRemoteControlStatus repeats the checks; Uninstall-ClaudeRemoteControl removes the service.

Author: Michiel VH

## RELATED LINKS
