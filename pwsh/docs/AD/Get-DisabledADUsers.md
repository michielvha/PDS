---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Get-DisabledADUsers

## SYNOPSIS
Retrieves and displays disabled Active Directory user accounts.

## SYNTAX

```
Get-DisabledADUsers [[-SearchBase] <String>] [[-Properties] <String[]>] [-ShowGridView] [[-Format] <String>]
```

## DESCRIPTION
The Get-DisabledADUsers function retrieves all disabled user accounts from Active Directory
with detailed information about each account.
Results can be displayed in various formats
including a grid view, formatted table, or as raw objects for further processing.

This function automatically imports the required ActiveDirectory module if it's not already loaded.

## EXAMPLES

### EXAMPLE 1
```
Get-DisabledADUsers
```

Retrieves all disabled AD users and displays them in a formatted table.

### EXAMPLE 2
```
Get-DisabledADUsers -ShowGridView
```

Retrieves all disabled AD users and displays them in a grid view.

### EXAMPLE 3
```
Get-DisabledADUsers -Format List
```

Retrieves all disabled AD users and displays them in a list format.

### EXAMPLE 4
```
Get-DisabledADUsers -SearchBase "OU=Users,OU=Company,DC=contoso,DC=com"
```

Retrieves disabled AD users from the specified organizational unit.

### EXAMPLE 5
```
$disabledUsers = Get-DisabledADUsers -Format None
$disabledUsers | Export-Csv -Path "C:\Reports\DisabledUsers.csv" -NoTypeInformation
```

Retrieves disabled AD users as objects and exports them to a CSV file.

## PARAMETERS

### -SearchBase
Specifies the distinguished name (DN) of the starting point for the search.
Default is to search the entire domain.

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

### -Properties
Specifies the user properties to retrieve. 
Default includes common properties like SamAccountName, DisplayName, DistinguishedName, etc.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: @(
            'SamAccountName', 'DisplayName', 'UserPrincipalName',
            'GivenName', 'Surname', 'Description', 'DistinguishedName',
            'Enabled', 'LastLogonDate', 'whenCreated', 'whenChanged',
            'Title', 'Department', 'Office', 'Manager'
        )
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowGridView
If specified, displays the results in a grid view window.
Default is $false.

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

### -Format
Specifies how to format the output.
Valid values are: 'Table', 'List', 'Grid', 'None'
Default is 'Table'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Table
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES
- Requires the ActiveDirectory module
- Make sure you have appropriate permissions to query AD
- You might want to run this on a domain controller or computer with the RSAT tools installed

## RELATED LINKS
