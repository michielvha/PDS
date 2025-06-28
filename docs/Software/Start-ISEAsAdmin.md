---
external help file: PDS-help.xml
Module Name: PDS
online version: https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/ise/introducing-the-windows-powershell-ise
schema: 2.0.0
---

# Start-ISEAsAdmin

## SYNOPSIS
Opens PowerShell ISE with administrative privileges.

## SYNTAX

```
Start-ISEAsAdmin [[-FilePath] <String>] [-Wait] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Start-ISEAsAdmin function launches a new instance of the PowerShell Integrated
Scripting Environment (ISE) with elevated administrative privileges.
This is useful for editing and running scripts that require administrative access.

## EXAMPLES

### EXAMPLE 1
```
Start-ISEAsAdmin
```

Opens PowerShell ISE with administrative privileges.

### EXAMPLE 2
```
Start-ISEAsAdmin -FilePath "C:\Scripts\MyAdminScript.ps1"
```

Opens PowerShell ISE with administrative privileges and loads the specified script file.

### EXAMPLE 3
```
Start-ISEAsAdmin -Wait
```

Opens PowerShell ISE with administrative privileges and waits for the ISE to be closed before returning.

## PARAMETERS

### -FilePath
Specifies a script file to open in the ISE window.
If not specified, ISE will open without any files loaded.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Wait
If specified, waits for the ISE process to exit before returning control.
By default, the function returns immediately after launching ISE.

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
- This function requires User Account Control (UAC) prompt acceptance to elevate privileges
- Windows PowerShell ISE is not included in PowerShell 7 or above, this function is for Windows PowerShell 5.1 and below
- Windows PowerShell ISE may not be available in future versions of Windows

## RELATED LINKS

[https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/ise/introducing-the-windows-powershell-ise](https://docs.microsoft.com/en-us/powershell/scripting/windows-powershell/ise/introducing-the-windows-powershell-ise)

