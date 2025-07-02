---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Update-ADDomainName

## SYNOPSIS
Changes the domain name for all users in Active Directory and configures email forwarding.

## SYNTAX

```
Update-ADDomainName [-OldDomain] <String> [-NewDomain] <String> [-UserFilter <String>] [-WhatIf] [-Confirm]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
The Update-ADDomainName function handles the domain name change process in Active Directory.
When an organization changes its domain name, this function performs the following tasks:

1. Sets the old email address as a secondary SMTP proxy address to maintain email continuity
2. Changes all user principal names (UPNs) from the old domain to the new domain
3. Sets the new email address as the primary SMTP address

This ensures a smooth transition during a domain name change while maintaining email
functionality throughout the process.

## EXAMPLES

### EXAMPLE 1
```
Update-ADDomainName -OldDomain "old-domain.com" -NewDomain "new-domain.com"
```

Updates all users' domain from old-domain.com to new-domain.com, preserving email continuity.

### EXAMPLE 2
```
Update-ADDomainName -OldDomain "contoso.local" -NewDomain "contoso.com" -UserFilter "Department -eq 'IT'"
```

Updates only IT department users from contoso.local to contoso.com domain.

## PARAMETERS

### -OldDomain
Specifies the old domain name (e.g., "contoso.com").
This is the domain being replaced.

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

### -NewDomain
Specifies the new domain name (e.g., "contoso.org").
This is the domain that will replace the old domain.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserFilter
Optional filter to specify which users to process.
By default, processes all users with UPNs containing the old domain.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet doesn't run.

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
Prompts you for confirmation before running the cmdlet.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
## OUTPUTS

### None
## NOTES
- Requires the Active Directory PowerShell module
- Requires Domain Admin privileges
- Should be run on a domain controller or system with proper permissions
- Internet connection may be required if Azure AD sync is enabled
- You should first register the new domain in local AD or Azure AD

## RELATED LINKS
