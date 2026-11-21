Function Install-DotnetSdk {
    <#
    .SYNOPSIS
        Installs the latest .NET SDK of a release channel on Windows.

    .DESCRIPTION
        Installs the .NET SDK from the winget package Microsoft.DotNet.SDK.<Channel>, which tracks
        the newest SDK of that channel, or upgrades it when an older SDK of the channel is
        installed. The default channel is 10, the current long-term support release.

        It reuses Install-Winget when winget is missing, refreshes the session's environment with
        Update-Env, and checks that `dotnet --list-sdks` reports an SDK of the channel. The function
        is idempotent.

    .PARAMETER Channel
        The .NET major version to install, as in Microsoft.DotNet.SDK.10. Defaults to 10.

    .EXAMPLE
        Install-DotnetSdk

        Installs or upgrades the newest .NET 10 SDK.

    .EXAMPLE
        Install-DotnetSdk -Channel 11

        Installs or upgrades the newest .NET 11 SDK.

    .NOTES
        - Requires administrator privileges and an internet connection.
        - Open a new shell afterwards if other sessions need the updated PATH.

        Author: Michiel VH

    .LINK
        https://learn.microsoft.com/en-us/dotnet/core/install/windows
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d+$')]
        [string]$Channel = '10'
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This function requires administrator privileges. Please run PowerShell as Administrator."
        return
    }

    $id = "Microsoft.DotNet.SDK.$Channel"
    $wingetArguments = @('--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    # 0 is success; 0x8A15002B (-1978335189) means there is no newer applicable version.
    $noApplicableUpdate = -1978335189

    try {
        if (-not (Get-Command -Name winget -ErrorAction SilentlyContinue)) {
            Install-Winget
        }

        $installed = (Get-Command -Name dotnet -ErrorAction SilentlyContinue) -and
            ((dotnet --list-sdks 2>$null | Out-String) -match "(?m)^$Channel\.")
        $verb = if ($installed) { 'upgrade' } else { 'install' }
        Write-Output "Running winget $verb $id..."
        & winget $verb --id $id @wingetArguments
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $noApplicableUpdate) {
            throw "winget $verb $id failed with exit code $LASTEXITCODE."
        }

        Update-Env
        $sdks = (dotnet --list-sdks 2>&1 | Out-String)
        $match = [regex]::Match($sdks, "(?m)^($Channel\.\S+)")
        if (-not $match.Success) {
            throw "dotnet --list-sdks does not report a .NET $Channel SDK. It reported: $sdks"
        }
        Write-Output ".NET SDK ready: $($match.Groups[1].Value)"
    }
    catch {
        Write-Error "Install-DotnetSdk failed: $_"
    }
}
