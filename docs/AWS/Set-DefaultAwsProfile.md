---
external help file: PDS-help.xml
Module Name: PDS
online version: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
schema: 2.0.0
---

# Set-DefaultAwsProfile

## SYNOPSIS
Generates or modifies a default entry in the AWS configuration file using the provided parameters.

## SYNTAX

```
Set-DefaultAwsProfile [-region] <String> [-profile] <String> [[-sso_region] <String>]
 [[-sso_start_url] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This function sets the default configuration in AWS configuration file with the specified profile, region, and various predefined settings.

## EXAMPLES

### EXAMPLE 1
```
set-DefaultAwsProfile  -region "eu-west-1" -profile "main" -sso_start_url "https://d-93672f1b5f.awsapps.com/start" -sso_region "eu-west-1"
```

## PARAMETERS

### -region
The region of your preferred profile

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

### -profile
The name of your preferred profile.

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

### -sso_region
The AWS region where the SSO is configured.
If not specified it will default to the region parameter.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: "$region"
Accept pipeline input: False
Accept wildcard characters: False
```

### -sso_start_url
The SSO start URL for AWS SSO.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: Https://d-93672f1b5f.awsapps.com/start
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

