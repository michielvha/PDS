---
external help file: PDS-help.xml
Module Name: PDS
online version: https://learn.microsoft.com/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon
schema: 2.0.0
---

# Set-AutoAdminLogin

## SYNOPSIS
Signs a Windows account in automatically at startup, or turns that off again.
Meant for test machines and kiosks.

## SYNTAX

### Enable (Default)
```
Set-AutoAdminLogin -Username <String> [-Password <SecureString>] [-Domain <String>] [-WhatIf] [-Confirm]
```

### Disable
```
Set-AutoAdminLogin -Disable [-WhatIf] [-Confirm]
```

## DESCRIPTION
`Set-AutoAdminLogin` turns on Windows automatic sign-in for one account.
It first checks the password against the account, so a typo never leaves the machine stuck at the sign-in screen after a restart.
Then it sets `DefaultUserName`, `DefaultDomainName` and `AutoAdminLogon` under the Winlogon key and stores the password as the LSA secret Winlogon reads (`DefaultPassword`), the way Sysinternals Autologon does.
The password is never written to the registry in plain text, and a plain-text `DefaultPassword` value left by an earlier version or another tool is removed.
On Windows 11 it also allows password sign-in when only Windows Hello sign-in is allowed, because automatic sign-in is ignored in that mode.

`-Disable` turns automatic sign-in off and deletes the stored password.

Run it elevated.
The change takes effect at the next startup.

## EXAMPLES

### EXAMPLE 1
```
Set-AutoAdminLogin -Username 'tester' -Password (Read-Host -AsSecureString -Prompt 'Password')
```

Signs the local account `tester` in automatically from the next startup on.

### EXAMPLE 2
```
Set-AutoAdminLogin -Disable
```

Turns automatic sign-in off and removes the stored password.

## PARAMETERS

### -Username
The account that signs in automatically.

```yaml
Type: String
Parameter Sets: Enable
Aliases: u

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Password
The account's password.
Leave it out for an account without a password.

```yaml
Type: SecureString
Parameter Sets: Enable
Aliases: p

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Domain
The account's domain.
Defaults to this computer, for a local account.

```yaml
Type: String
Parameter Sets: Enable
Aliases:

Required: False
Position: Named
Default value: $env:COMPUTERNAME
Accept pipeline input: False
Accept wildcard characters: False
```

### -Disable
Turns automatic sign-in off and deletes the stored password.

```yaml
Type: SwitchParameter
Parameter Sets: Disable
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would change without changing it.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Asks for confirmation before changing anything.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES
Author: Michiel VH
Requires administrator rights: it writes HKLM and the LSA secret store.

## RELATED LINKS

[Turn on automatic logon in Windows](https://learn.microsoft.com/troubleshoot/windows-server/user-profiles-and-logon/turn-on-automatic-logon)
