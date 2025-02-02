Function New-AwsSession {
    <#
    .SYNOPSIS
    Generates an AWS configuration file using the provided parameters.

    .DESCRIPTION
    This function creates an AWS configuration file with the specified profile, region, and SSO settings.

    .PARAMETER sso_session
    The SSO session id.

    .PARAMETER sso_start_url
    The SSO start URL for AWS SSO.

    .PARAMETER sso_region
    The AWS region where the SSO is configured.

    .EXAMPLE
    Net-AwsSession  -sso_session "example" -sso_start_url "https://d-93672f1b5f.awsapps.com/start" -sso_region "eu-west-1"

    .NOTES
    Ensure that the AWS CLI is installed and configured on your system.

    .LINK
    https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
    #>

    param (
        [Parameter(Mandatory=$true)]
        [string]$sso_session,
        [Parameter(Mandatory=$true)]
        [string]$sso_start_url,
        [Parameter(Mandatory=$true)]
        [string]$sso_region
    )

    # Define the path to the AWS config file
    $awsConfigPath = "$HOME\.aws\config"

    # Create the config content
    $configContent = "`n`n" + @"
[sso-session $sso_session]
sso_start_url = $sso_start_url
sso_region = $sso_region
sso_registration_scopes=sso:account:access
"@

    # Ensure the .aws directory exists
    if (-not (Test-Path -Path "$HOME\.aws")) {
        New-Item -ItemType Directory -Path "$HOME\.aws"
    }

    # Write the config content to the file
    $configContent | Out-File -FilePath $awsConfigPath -Append -Encoding utf8

    Write-Host "New sso session '$sso_session' has been added to the aws config file: $configContent" -ForegroundColor Green
}