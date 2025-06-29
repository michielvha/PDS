Function Set-DefaultAwsProfile {
    <#
    .SYNOPSIS
    Generates or modifies a default entry in the AWS configuration file using the provided parameters.

    .DESCRIPTION
    This function sets the default configuration in AWS configuration file with the specified profile, region, and various predefined settings.

    .PARAMETER region
    The region of your preferred profile

    .PARAMETER profile
    The name of your preferred profile.

    .PARAMETER sso_start_url
    The SSO start URL for AWS SSO.

    .PARAMETER sso_region
        The AWS region where the SSO is configured. If not specified it will default to the region parameter.

    .EXAMPLE
        set-DefaultAwsProfile  -region "eu-west-1" -profile "main" -sso_start_url "https://d-93672f1b5f.awsapps.com/start" -sso_region "eu-west-1"

    .NOTES
        Author: Michiel VH
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
        [string]$sso_region = "$region",
        [Parameter()]
        [string]$sso_start_url = "https://d-93672f1b5f.awsapps.com/start"
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
sso_region = $sso_region
sso_start_url= $sso_start_url
output = json
"@

    # Match and replace the entire `[default]` section, including its header
    $regex = "(?s)(\[default\].*?)(?=\n\[|\z)"

    if ($configContent -match "\[default\]") {
        # Replace only the `[default]` section, preserving everything else
        $configContent = $configContent -replace $regex, "$defaultConfig`n"
        Write-Output "Existing default profile found, replacing with new profile..."
    } else {
        # Append `[default]` section if not found
        $configContent = $configContent.Trim() + "`n`n" + $defaultConfig
        Write-Output "No existing default profile found, creating new profile..."
    }

    try
    {
        # Write updated content back to the file
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)  # Disable BOM
        [System.IO.File]::WriteAllBytes($awsConfigPath, $utf8NoBom.GetBytes($configContent))
        Write-Host "the default AWS config has been set to: `n$defaultConfig" -ForegroundColor Green
    }
    catch
    {
        Write-Output "An error occurred while trying to write to the AWS config file: $_" -ForegroundColor Red
    }

}