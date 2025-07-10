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

    # Check if AWS CLI is installed
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Error "AWS CLI is not installed. Please install it first."
        return
    }


    if (-not (Select-String -Path $PROFILE -Pattern '^\s*\$env:AWS_CA_BUNDLE=' -Quiet -ErrorAction SilentlyContinue)) { 
        $PATH = $env:USERPROFILE
        
        "`$env:AWS_CA_BUNDLE=`"$PATH\.aws\cacert.pem`"" | Add-Content $PROFILE
    } else {
        write-host "AWS_CA_BUNDLE already set in profile"
    }

}