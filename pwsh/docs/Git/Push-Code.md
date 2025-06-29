---
external help file: PDS-help.xml
Module Name: PDS
online version: https://git-scm.com/docs
schema: 2.0.0
---

# Push-Code

## SYNOPSIS
Quickly stage, commit, and push code to a Git repository.

## SYNTAX

```
Push-Code [[-Message] <String>] [[-Branch] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function allows you to stage all changes, commit them with a provided message, 
and push to a specified branch of a Git repository (defaulting to 'main').

## EXAMPLES

### EXAMPLE 1
```
Push-Code -Message "Fix: Corrected typo in README" -Branch "main"
Push-Code -m "Fix: Corrected typo in README" -b "main"
This command will stage all changes, commit with the message "Fix: Corrected typo in README",
and push those changes to the 'main' branch.
```

## PARAMETERS

### -Message
The commit message to use when committing changes.

```yaml
Type: String
Parameter Sets: (All)
Aliases: m

Required: False
Position: 1
Default value: Update: Code changes
Accept pipeline input: False
Accept wildcard characters: False
```

### -Branch
The Git branch to push to.
Defaults to 'main'.

```yaml
Type: String
Parameter Sets: (All)
Aliases: b

Required: False
Position: 2
Default value: Main
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
Ensure you are in the correct repository folder before running this command.
Requires Git to be installed and available in your PATH.

Author: Michiel VH

## RELATED LINKS

[https://git-scm.com/docs](https://git-scm.com/docs)

