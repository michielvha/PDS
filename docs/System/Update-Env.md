---
external help file: PDS-help.xml
Module Name: PDS
online version: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setx
schema: 2.0.0
---

# Update-Env

## SYNOPSIS
Refreshes the current PowerShell session's environment variables from the Windows registry.

## SYNTAX

```
Update-Env
```

## DESCRIPTION
The Refresh-Env function reloads all environment variables from the Windows registry,
including system-wide (\`HKLM:\System\CurrentControlSet\Control\Session Manager\Environment\`)
and user-specific (\`HKCU:\Environment\`) variables. 

It also merges the \`Path\` environment variable from both system and user scopes to ensure
newly added directories are available without requiring a new shell session.

## EXAMPLES

### EXAMPLE 1
```
Refresh-Env
Refreshes the environment variables in the current PowerShell session, 
applying any recent changes made via registry modifications or external software installations.
```

### EXAMPLE 2
```
$env:MY_TEST_VAR = "OldValue"
Set-ItemProperty -Path "HKCU:\Environment" -Name "MY_TEST_VAR" -Value "NewValue" -Force
Refresh-Env
$env:MY_TEST_VAR
# Output: "NewValue"
# This example demonstrates how a registry change to an environment variable is applied immediately.
```

## PARAMETERS

## INPUTS

## OUTPUTS

### None. The function does not return any values, but it updates the session's environment variables.
## NOTES
Author: Michiel VHA
Date:   February 2025
Version: 1.0

- Requires administrative privileges if modifying system environment variables.
- This function does not permanently modify environment variables; it only updates the session.
- The function does not handle changes made via \`SetX\` or \`Environment.SetEnvironmentVariable\` with the \`Machine\` scope.

## RELATED LINKS

[https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setx](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/setx)

