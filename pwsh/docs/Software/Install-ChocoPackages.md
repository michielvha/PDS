---
external help file: PDS-help.xml
Module Name: PDS
online version: https://chocolatey.org/
Learn more about Chocolatey and package management.
schema: 2.0.0
---

# Install-ChocoPackages

## SYNOPSIS
Installs a list of Chocolatey packages from an array, if they are not already installed.

## SYNTAX

```
Install-ChocoPackages [[-packagesToInstall] <String[]>]
```

## DESCRIPTION
The \`Install-ChocoPackagesFromFile\` function takes an array of package names and attempts to install each one using Chocolatey.
If the package is already installed, Chocolatey will skip reinstallation.
The function outputs the packages to be installed and provides status updates as it processes each package.

## EXAMPLES

### EXAMPLE 1
```
$packages = @("git", "nodejs", "python")
Install-ChocoPackagesFromFile -packagesToInstall $packages
```

This example installs the \`git\`, \`nodejs\`, and \`python\` packages using Chocolatey.
If any of the packages are already installed, Chocolatey will skip them.

### EXAMPLE 2
```
Install-ChocoPackagesFromFile -packagesToInstall @("docker", "vscode")
```

This command installs \`docker\` and \`vscode\` if they are not already present on the system.

## PARAMETERS

### -packagesToInstall
An array of package names that you wish to install via Chocolatey.
Each package name should correspond to a valid Chocolatey package.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: p

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
Requires: Chocolatey to be installed on the system.
This function uses the \`choco install\` command and runs it with the \`-y\` flag to bypass prompts.

## RELATED LINKS

[https://chocolatey.org/
Learn more about Chocolatey and package management.](https://chocolatey.org/
Learn more about Chocolatey and package management.)

[https://chocolatey.org/
Learn more about Chocolatey and package management.]()

