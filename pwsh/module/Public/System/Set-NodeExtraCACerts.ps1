function Set-NodeExtraCACerts {
    <#
    .SYNOPSIS
        Sets the NODE_EXTRA_CA_CERTS environment variable to the Azure CLI bundled CA certificate.

    .DESCRIPTION
        This function sets the `NODE_EXTRA_CA_CERTS` machine-level environment variable to point to the
        CA certificate bundle shipped with Azure CLI. This is useful when Node.js applications need to
        trust the same certificates as Azure CLI, for example behind a corporate proxy or with custom CAs.

        Optionally, a custom certificate path can be provided to override the default.

    .PARAMETER CertPath
        The path to the CA certificate file. Defaults to the Azure CLI bundled cacert.pem.

    .EXAMPLE
        Set-NodeExtraCACerts

        Sets the NODE_EXTRA_CA_CERTS system environment variable to the default Azure CLI cacert.pem path.

    .EXAMPLE
        Set-NodeExtraCACerts -CertPath "D:\certs\custom-ca.pem"

        Sets the NODE_EXTRA_CA_CERTS system environment variable to a custom certificate path.

    .NOTES
        Author: Michiel VH
        This function modifies a machine-level environment variable, so it must be run with elevated (Administrator) privileges.
    #>

    param (
        [string]$CertPath = "C:\Program Files\Microsoft SDKs\Azure\CLI2\Lib\site-packages\certifi\cacert.pem"
    )

    try {
        [System.Environment]::SetEnvironmentVariable("NODE_EXTRA_CA_CERTS", $CertPath, "Machine")
        Write-Host "NODE_EXTRA_CA_CERTS set to: $CertPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to set NODE_EXTRA_CA_CERTS: $_"
    }
}
