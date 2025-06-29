---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Install-RSAT

## SYNOPSIS
Installs Remote Server Administration Tools (RSAT) features on Windows 10 version 1809 or later.

## SYNTAX

```
Install-RSAT [[-Feature] <String[]>] [-Force] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Install-RSAT function installs Remote Server Administration Tools (RSAT) features on Windows 10
version 1809 or later where RSAT is available as optional features.
The function can install
specific RSAT features or all available RSAT features.

The function checks if the current Windows version and edition support RSAT features, and
provides appropriate feedback if installation is not possible.

## EXAMPLES

### EXAMPLE 1
```
Install-RSAT
```

Installs all available RSAT features.

### EXAMPLE 2
```
Install-RSAT -Feature AD
```

Installs only Active Directory management tools.

### EXAMPLE 3
```
Install-RSAT -Feature AD,DNS,DHCP
```

Installs Active Directory, DNS, and DHCP management tools.

## PARAMETERS

### -Feature
Specifies which RSAT feature(s) to install.
Valid values include:
- All (default): Installs all available RSAT features
- AD: Installs Active Directory management tools
- DNS: Installs DNS management tools
- DHCP: Installs DHCP management tools
- GroupPolicy: Installs Group Policy management tools
- ServerManager: Installs Server Manager
- FileServices: Installs File Services management tools
- HyperV: Installs Hyper-V management tools

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: @('All')
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Forces reinstallation even if the feature is already installed.

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
- Requires Windows 10 version 1809 or later
- Requires administrative privileges
- Not available on Windows 10 Home edition
- On Windows 10, RSAT is installed as optional features
- Internet connection may be required for installation

Author: Michiel VH

## RELATED LINKS
