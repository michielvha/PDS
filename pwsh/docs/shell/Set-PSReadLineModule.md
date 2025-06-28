---
external help file: PDS-help.xml
Module Name: PDS
online version: https://www.powershellgallery.com/packages/PSReadLine/2.2.6
Learn more about `PSReadline Module` and how it is used to manage powershell.

https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption?view=powershell-7.4
Learn about all the different parameters that can be used to configure the module.
schema: 2.0.0
---

# Set-PSReadLineModule

## SYNOPSIS
Configures the PSReadLine module for all users by installing and importing the module, setting PSReadLine options, and appending commands to the global profile.

## SYNTAX

```
Set-PSReadLineModule
```

## DESCRIPTION
The \`Set-PSReadLineModule\` function automates the installation and configuration of the PSReadLine module for all users.
It installs the PSReadLine module, imports it into the session, initializes Starship with PowerShell, and sets the \`PredictionViewStyle\` to \`ListView\`.
The configuration commands are appended to the global PowerShell profile, ensuring that these settings apply to all users across all hosts.

## EXAMPLES

### EXAMPLE 1
```
Set-PSReadLineModule
```

This command installs and configures the PSReadLine module for all users, initializes Starship, and sets the PSReadLine prediction style to \`ListView\`.
It appends these configurations to the global profile, making them available to all users.

### EXAMPLE 2
```
$commands = @"
Install-Module -Name PSReadLine -Force -SkipPublisherCheck -Scope CurrentUser
Import-Module -Name PSReadLine
Invoke-Expression (&starship init powershell)
Set-PSReadLineOption -PredictionViewStyle ListView
"@
Set-PSReadLineModule
```

In this example, the same commands are written to the global profile to ensure PSReadLine and Starship are properly configured for all users in PowerShell.

## PARAMETERS

## INPUTS

## OUTPUTS

## NOTES
Author: MKTHEPLUGG
Requires: PowerShell 5.1 or higher and Starship CLI installed.
This function modifies the global profile located at \`$PROFILE.AllUsersAllHosts\`, and administrative privileges are required to make these changes.

## RELATED LINKS

[https://www.powershellgallery.com/packages/PSReadLine/2.2.6
Learn more about `PSReadline Module` and how it is used to manage powershell.

https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption?view=powershell-7.4
Learn about all the different parameters that can be used to configure the module.](https://www.powershellgallery.com/packages/PSReadLine/2.2.6
Learn more about `PSReadline Module` and how it is used to manage powershell.

https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption?view=powershell-7.4
Learn about all the different parameters that can be used to configure the module.)

[https://www.powershellgallery.com/packages/PSReadLine/2.2.6
Learn more about `PSReadline Module` and how it is used to manage powershell.

https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption?view=powershell-7.4
Learn about all the different parameters that can be used to configure the module.]()

