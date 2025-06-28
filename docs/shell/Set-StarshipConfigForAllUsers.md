---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Set-StarshipConfigForAllUsers

## SYNOPSIS
This function sets the Starship configuration for all users on the system.

## SYNTAX

```
Set-StarshipConfigForAllUsers [-configContent] <String> [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
The \`Set-StarshipConfigForAllUsers\` function searches for the user profiles on the system,
creates a \`.config\` directory in each profile (if it doesn't exist), and then writes the
Starship configuration (\`starship.toml\`) to that directory.
If the file already exists, the
function does not overwrite it.

## EXAMPLES

### EXAMPLE 1
```
$configContent = @"
[character]
symbol = "❯"
color = "blue"
"@
```

Set-StarshipConfigForAllUsers

This will set the Starship configuration for all users on the system using the specified content.

### EXAMPLE 2
```
Set-StarshipConfigForAllUsers -configContent @"
[character]
symbol = "❯"
color = "blue"
"@
```

This will set the Starship configuration for all users by passing the config content directly as a parameter.

## PARAMETERS

### -configContent
The content to be written to each user's \`starship.toml\` file.
This can be provided either
as a parameter or defined as a global variable in the session.

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
This function requires administrative privileges to access other user profiles.

## RELATED LINKS
