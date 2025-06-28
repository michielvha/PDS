---
external help file: PDS-help.xml
Module Name: PDS
online version: https://support.microsoft.com/en-us/help/324737/how-to-turn-on-automatic-logon-in-windows
Microsoft support article on configuring auto-logon in Windows.
schema: 2.0.0
---

# Set-AutoAdminLogin

## SYNOPSIS
Sets the system to automatically log in with a specified user account.
This is especially useful in development environments where auto-login is needed for testing purposes.

## SYNTAX

```
Set-AutoAdminLogin [[-Username] <String>] [[-Password] <SecureString>]
```

## DESCRIPTION
The \`Set-AutoAdminLogin\` function configures the Windows system to automatically log in to a specified user account upon boot.
It achieves this by modifying the necessary registry keys (\`DefaultUserName\`, \`DefaultPassword\`, and \`AutoAdminLogon\`) to enable the auto-login feature.
This function is particularly useful for development builds where manual login is unnecessary and auto-login streamlines the process.

**Note:** The password is currently stored in plain text, so make sure to use this function in secure environments or find an encryption mechanism
for storing the password securely.

## EXAMPLES

### EXAMPLE 1
```
Set-AutoAdminLogin -Username "devUser" -Password "devPass123"
```

This example configures the system to automatically log in to the account \`devUser\` with the password \`devPass123\`.
The system will bypass the login screen and log in to this account after rebooting.

## PARAMETERS

### -Username
The username of the account that should be automatically logged in on system startup.

```yaml
Type: String
Parameter Sets: (All)
Aliases: u

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Password
The password of the user account.
**Important**: Currently, the password is stored in plain text in the registry.
Consider using a method to securely encrypt the password.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases: p

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES
Author: MKTHEPLUGG
This function modifies registry keys to configure auto-login, so it must be run with elevated (Administrator) privileges.

## RELATED LINKS

[https://support.microsoft.com/en-us/help/324737/how-to-turn-on-automatic-logon-in-windows
Microsoft support article on configuring auto-logon in Windows.](https://support.microsoft.com/en-us/help/324737/how-to-turn-on-automatic-logon-in-windows
Microsoft support article on configuring auto-logon in Windows.)

[https://support.microsoft.com/en-us/help/324737/how-to-turn-on-automatic-logon-in-windows
Microsoft support article on configuring auto-logon in Windows.]()

