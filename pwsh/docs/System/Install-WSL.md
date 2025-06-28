---
external help file: PDS-help.xml
Module Name: PDS
online version: https://docs.microsoft.com/en-us/windows/wsl/install
Learn more about installing and configuring WSL.
schema: 2.0.0
---

# Install-WSL

## SYNOPSIS
Installs WSL (Windows Subsystem for Linux) distributions.

## SYNTAX

```
Install-WSL [[-distros] <String[]>]
```

## DESCRIPTION
The \`Install-WSL\` function provides a wrapper for installing WSL distributions on Windows.
It optionally accepts an array of distro names to install.
If no parameters are passed,
it simply lists available distributions online.
If distributions are passed as parameters,
it will attempt to install each one using the \`wsl --install\` command.

## EXAMPLES

### EXAMPLE 1
```
$distros = @("Ubuntu", "Debian")
Install-WSL -d $distros
```

This example installs the \`Ubuntu\` and \`Debian\` distributions using WSL.

### EXAMPLE 2
```
Install-WSL -d(istros) Alpine, Kali-Linux, Debian
```

This example installs the distribution if it is available in the online list.

## PARAMETERS

### -distros
An optional array of WSL distro names that you wish to install.
Each distro name should
match one of the names listed by \`wsl --list --online\`.
If not provided, the function
will only list the available distros.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: d

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES
Author: MKTHEPLUGG
Requires: WSL to be enabled on the system.
Is enabled by default on any newer windows build (w11+)
This function uses the \`wsl --install\` command to install the specified distributions.

## RELATED LINKS

[https://docs.microsoft.com/en-us/windows/wsl/install
Learn more about installing and configuring WSL.](https://docs.microsoft.com/en-us/windows/wsl/install
Learn more about installing and configuring WSL.)

[https://docs.microsoft.com/en-us/windows/wsl/install
Learn more about installing and configuring WSL.]()

