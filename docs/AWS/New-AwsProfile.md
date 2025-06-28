---
external help file: PDS-help.xml
Module Name: PDS
online version: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
schema: 2.0.0
---

# New-AwsProfile

## SYNOPSIS
Generates an AWS configuration file using the provided parameters.

## SYNTAX

```
New-AwsProfile [-sso_profile] <String> [-sso_session] <String> [-sso_account_id] <String>
 [-sso_role_name] <String> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function creates an AWS configuration file with the specified profile, region, and SSO settings.

## EXAMPLES

### EXAMPLE 1
```
New-AwsProfile -sso_profile "example"  -sso_session "example" -sso_account_id "123456789012" -sso_role_name "MyRole"
```

## PARAMETERS

### -sso_profile
The name of the SSO profile to configure.

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

### -sso_session
The SSO session id.

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

### -sso_account_id
The AWS account ID for SSO.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -sso_role_name
The role name for SSO.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
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
Ensure that the AWS CLI is installed and configured on your system.

## RELATED LINKS

[https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html)

