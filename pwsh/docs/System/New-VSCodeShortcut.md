---
external help file: PDS-help.xml
Module Name: PDS
online version: https://code.visualstudio.com/
schema: 2.0.0
---

# New-VSCodeShortcut

## SYNOPSIS
Creates a desktop shortcut that opens a specific file in Visual Studio Code.

## SYNTAX

```
New-VSCodeShortcut [-FilePath] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function creates a Windows shortcut (.lnk file) on the user's desktop 
that will open the specified file in Visual Studio Code when clicked.

## EXAMPLES

### EXAMPLE 1
```
New-VSCodeShortcut -FilePath "C:\Projects\myproject\app.js"
Creates a shortcut on the desktop named "app.js - VS Code.lnk" that opens app.js in VS Code.
```

## PARAMETERS

### -FilePath
The path to the file that should be opened in VS Code when the shortcut is clicked.
This parameter is mandatory.

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
This function requires Visual Studio Code to be installed on the system.
The shortcut is placed on the desktop of the user running the function.

## RELATED LINKS

[https://code.visualstudio.com/](https://code.visualstudio.com/)

