Function New-DefaultAwsProfile {
    <#
    .SYNOPSIS
    Generates or modifies a default entry in the AWS configuration file using the provided parameters.

    .DESCRIPTION
    This function sets the default configuration in AWS configuration file with the specified profile, region, and various predefined settings.

    .PARAMETER region
    The region of your preferred profile

    .PARAMETER profile
    The name of your preferred profile.

    .EXAMPLE
    ew-DefaultAwsProfile  -region "ue-west-1" -profile "default"

    .NOTES
    Ensure that the AWS CLI is installed and configured on your system.

    .LINK
    https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
    #>

    param (
        [Parameter(Mandatory=$true)]
        [string]$region,
        [Parameter(Mandatory=$true)]
        [string]$profile,
        [Parameter()]
        [string]$caBundle = "$HOME\.aws\cacert.pem"
    )

    # Define the path to the AWS config file
    $awsConfigPath = "$HOME\.aws\config"

    # Ensure the .aws directory exists
    if (-not (Test-Path -Path "$HOME\.aws")) {
        New-Item -ItemType Directory -Path "$HOME\.aws" -Force | Out-Null
    }

    # Read existing content if file exists, else initialize as empty
    $configContent = if (Test-Path -Path $awsConfigPath) {
        Get-Content -Path $awsConfigPath -Raw
    } else {
        ""
    }

    # Define the new `[default]` section
    $defaultConfig = @"
[default]
region = $region
profile = $profile
output = json
s3 =
    max_concurrent_requests = 20
ca_bundle = $caBundle
"@

    # Check if the `[default]` section exists
    if ($configContent -match "(?ms)\[default\].*?(?=\[\w+\]|\Z)") {
        # Replace the existing `[default]` section
        $configContent = $configContent -replace "(?ms)\[default\].*?(?=\[\w+\]|\Z)", $defaultConfig
    } else {
        # Append `[default]` if it doesn't exist
        $configContent = $configContent.Trim() + "`n`n" + $defaultConfig
    }

    # Write updated content back to the file
    Set-Content -Path $awsConfigPath -Value $configContent -Encoding utf8

    Write-Host "AWS config for profile '$profile' has been updated." -ForegroundColor Green
}