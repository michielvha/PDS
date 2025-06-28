---
external help file: PDS-help.xml
Module Name: PDS
online version: https://learn.microsoft.com/en-us/powershell/scripting/setup/starting-with-profiles
Learn more about PowerShell profiles and their usage.
schema: 2.0.0
---

# Set-DefaultProfile

## SYNOPSIS
Adds specified commands to the global PowerShell profile for all users.

## SYNTAX

```
Set-DefaultProfile [-Commands] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The \`Set-DefaultProfile\` function allows the user to pass in commands to be appended to the global PowerShell profile, located at \`$PROFILE.AllUsersAllHosts\`.
This function is useful for automating configuration changes, setting up environments, and making sure that certain settings apply system-wide across all users.

The function requires administrative privileges to modify the global profile.
Any valid PowerShell commands passed to the function will be appended to the profile file.

## EXAMPLES

### EXAMPLE 1
```
$commands = @"
Install-Module -Name PSReadLine -Force -SkipPublisherCheck
Import-Module -Name PSReadLine
Invoke-Expression (&starship init powershell)
Set-PSReadLineOption -PredictionViewStyle ListView
"@
Set-DefaultProfile -Commands $commands
```

This example appends the commands to install and configure the PSReadLine module and initialize the Starship prompt to the global profile.

### EXAMPLE 2
```
$customCommands = 'Set-Alias ll Get-ChildItem'
Set-DefaultProfile -Commands $customCommands
```

This example appends a custom alias definition for 'll' to the global profile, making it available for all users.

## PARAMETERS

### -Commands
A string containing the PowerShell commands to append to the global profile for all users.

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
Author: MKTHEPLUGG
Requires: PowerShell 5.1 or higher.
This function modifies the global profile located at \`$PROFILE.AllUsersAllHosts\`, and administrative privileges are required to make these changes.

## RELATED LINKS

[https://learn.microsoft.com/en-us/powershell/scripting/setup/starting-with-profiles
Learn more about PowerShell profiles and their usage.](https://learn.microsoft.com/en-us/powershell/scripting/setup/starting-with-profiles
Learn more about PowerShell profiles and their usage.)

[https://learn.microsoft.com/en-us/powershell/scripting/setup/starting-with-profiles
Learn more about PowerShell profiles and their usage.]()

