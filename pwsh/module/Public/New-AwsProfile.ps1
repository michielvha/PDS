Function New-AwsProfile {
    <#
    .SYNOPSIS
    Generates an AWS configuration file using the provided parameters.

    .DESCRIPTION
    This function creates an AWS configuration file with the specified profile, region, and SSO settings.

    .PARAMETER sso_profile
    The name of the SSO profile to configure.

    .PARAMETER sso_session
    The SSO session id.

    .PARAMETER sso_account_id
    The AWS account ID for SSO.

    .PARAMETER sso_role_name
    The role name for SSO.

    .EXAMPLE
    Net-AwsProfile -sso_profile "example"  -sso_session "example" -sso_account_id "123456789012" -sso_role_name "MyRole"

    .NOTES
    Ensure that the AWS CLI is installed and configured on your system.

    .LINK
    https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
    #>

    param (
        [Parameter(Mandatory=$true)]
        [string]$sso_profile,
        [Parameter(Mandatory=$true)]
        [string]$sso_session,
        [Parameter(Mandatory=$true)]
        [string]$sso_account_id,
        [Parameter(Mandatory=$true)]
        [string]$sso_role_name
    )

    # Define the path to the AWS config file
    $awsConfigPath = "$HOME\.aws\config"

    # Create the config content
    $configContent = "`n`n" + @"
[profile $sso_profile]
sso_session = $sso_session
sso_account_id = $sso_account_id
sso_role_name = $sso_role_name
"@

    # Ensure the .aws directory exists
    if (-not (Test-Path -Path "$HOME\.aws")) {
        New-Item -ItemType Directory -Path "$HOME\.aws"
    }

    # Write the config content to the file
    $configContent | Out-File -FilePath $awsConfigPath -Append -Encoding utf8

    Write-Host "AWS config for profile '$sso_profile' has been created/updated." -ForegroundColor Green
}