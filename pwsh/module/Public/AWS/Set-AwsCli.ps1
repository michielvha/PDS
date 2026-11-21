function Set-AwsCli {
    <#
    .SYNOPSIS
    Sets up the AWS CLI environment variables.

    .DESCRIPTION
    This function configures the AWS CLI by setting the necessary environment variables.
    It checks if the AWS CLI is installed and sets the AWS_CA_BUNDLE variable to point to a custom CA bundle if it exists.

    .EXAMPLE
    Set-AwsCli

    This will set the AWS CLI environment variables in the current PowerShell session.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param()

    # Check if AWS CLI is installed
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Error "AWS CLI is not installed. Please install it first."
        return
    }


    # Select-String throws a terminating error on a missing path, so check that the profile exists first
    $profileExists = Test-Path -LiteralPath $PROFILE -PathType Leaf
    if (-not $profileExists -or -not (Select-String -LiteralPath $PROFILE -Pattern '^\s*\$env:AWS_CA_BUNDLE=' -Quiet)) {
        $PATH = $env:USERPROFILE

        if ($PSCmdlet.ShouldProcess($PROFILE, 'Add AWS_CA_BUNDLE')) {
            if (-not $profileExists) {
                # -Force also creates the profile's folder when it does not exist yet
                $null = New-Item -ItemType File -Path $PROFILE -Force
            }
            "`$env:AWS_CA_BUNDLE=`"$PATH\.aws\cacert.pem`"" | Add-Content -LiteralPath $PROFILE
        }
    }
    else {
        Write-Host "AWS_CA_BUNDLE already set in profile"
    }

}
