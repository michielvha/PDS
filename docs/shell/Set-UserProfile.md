---
external help file: PDS-help.xml
Module Name: PDS
online version: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles
schema: 2.0.0
---

# Set-UserProfile

## SYNOPSIS
Adds persistent lines to a user's PowerShell profile script.

## SYNTAX

```
Set-UserProfile [[-Lines] <String[]>] [[-ProfilePath] <String>]
```

## DESCRIPTION
This function ensures that one or more specified lines are added to the user's PowerShell profile (e.g., \`$PROFILE\`).
If the profile file doesn't exist, it will be created.
The function checks for duplicate entries before appending, ensuring each line is added only once.

## EXAMPLES

### EXAMPLE 1
```
Set-UserProfile
```

Adds the default Chocolatey import line to the current user's PowerShell profile.

### EXAMPLE 2
```
Set-UserProfile -Lines @(
    'Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1',
    'Set-Alias ll Get-ChildItem'
)
```

Adds both the Chocolatey import and a custom alias to the current user's PowerShell profile.

### EXAMPLE 3
```
Set-UserProfile -ProfilePath "C:\Users\john\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Lines @(
    '# Custom profile for John',
    'Set-Alias gs git status'
)
```

Appends the specified lines to a custom profile path, useful when scripting for other users or hosts.

## PARAMETERS

### -Lines
An array of strings representing the lines you want to add to the user's PowerShell profile.
Each line is checked to prevent duplication.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: @(
            'Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1',
            'Import-Module PDS'
        )
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProfilePath
The full path to the profile file you want to update.
Defaults to \`$PROFILE\`, which targets the current user's profile for the current host.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: $PROFILE
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES
Author: Michiel Van Haegenborgh
This function is intended to be reusable and extensible for managing persistent shell customizations.

## RELATED LINKS

[https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles)

