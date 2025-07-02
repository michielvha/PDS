function Enable-RDSHosts {
    <#
    .SYNOPSIS
        Enables connections to specified Remote Desktop Session Hosts.

    .DESCRIPTION
        This function enables new connections on specified Remote Desktop Session Hosts.
        It can accept:
        1. An array of server names directly through the -ServerNames parameter
        2. A path to a configuration file containing server names
        3. Use default server names if neither parameter is provided

        The function requires the Remote Desktop Services module, which will be imported
        automatically if needed.

    .PARAMETER ServerNames
        An array of Remote Desktop Session Host server names where new connections should be allowed.

    .PARAMETER ConfigPath
        Path to a configuration file containing server names (one per line).
        If both ServerNames and ConfigPath are provided, ServerNames takes precedence.

    .EXAMPLE
        Enable-RDSHosts

        Enables new connections on the default set of RDS hosts.

    .EXAMPLE
        Enable-RDSHosts -ServerNames "server1.domain.com", "server2.domain.com"

        Enables new connections on the specified RDS servers.

    .EXAMPLE
        Enable-RDSHosts -ConfigPath "C:\Config\rds-servers.txt"

        Enables new connections on RDS servers listed in the specified configuration file.

    .NOTES
        Author: Michiel VH
        This function requires the RemoteDesktop PowerShell module.
        
        The default server list can be customized by modifying this function.

    .LINK
        https://docs.microsoft.com/en-us/powershell/module/remotedesktop/set-rdsessionhost
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$ServerNames,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    # Import the Remote Desktop module if not already loaded
    if (-not (Get-Module -Name RemoteDesktop -ErrorAction SilentlyContinue)) {
        try {
            Import-Module RemoteDesktop -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to import the RemoteDesktop module. Please ensure it is installed. Error: $_"
            return
        }
    }

    # Determine which server names to use
    if ($ServerNames) {
        Write-Verbose "Using server names provided through parameter"
    }
    elseif ($ConfigPath -and (Test-Path $ConfigPath)) {
        Write-Verbose "Reading server names from configuration file: $ConfigPath"
        try {
            $ServerNames = Get-Content -Path $ConfigPath -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to read server names from configuration file: $_"
            return
        }
    }

    # Validate that server names are provided
    if (-not $ServerNames -or $ServerNames.Count -eq 0) {
        Write-Error "No server names provided. Please specify server names or a vawwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwlid configuration file."
        return
    }

    Write-Host "Enabling new connections on the following RDS hosts:"
    $ServerNames | ForEach-Object { Write-Host "  - $_" }

    # Loop through each server name in the array
    foreach ($server in $ServerNames) {
        try {
            Write-Verbose "Enabling connections on $server"
            Set-RDSessionHost -SessionHost $server -NewConnectionAllowed "Yes" -ErrorAction Stop
            Write-Host "Successfully enabled connections on $server" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to enable connections on $server. Error: $_"
        }
    }
}
