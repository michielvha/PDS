function Start-RemoteADSyncCycle {
    <#
    .SYNOPSIS
        Triggers AD Connect synchronization on remote domain controllers.

    .DESCRIPTION
        The Start-RemoteADSyncCycle function initiates an AD Connect synchronization cycle on one or more remote servers.
        It supports both Delta (default) and Initial sync types and includes verification of PowerShell remoting
        availability and connectivity to target servers before attempting to run the sync command.

        This function helps automate the process of synchronizing Active Directory changes to Azure AD or
        other connected directory services, making it useful for identity management automation tasks.

    .PARAMETER ComputerName
        Specifies one or more remote servers where AD Connect is installed. You can provide an array of server names
        or a single server name.

    .PARAMETER SyncType
        Specifies the type of synchronization to run. Valid values are 'Delta' (incremental sync, default) or 
        'Initial' (full sync).

    .PARAMETER ConfigPath
        Optional. Path to a configuration file containing a list of server names, one per line.
        If specified, servers from this file will be used in addition to any specified in ComputerName.

    .EXAMPLE
        Start-RemoteADSyncCycle -ComputerName "ADSyncServer01"

        Triggers a delta synchronization cycle on the server named ADSyncServer01.

    .EXAMPLE
        Start-RemoteADSyncCycle -ComputerName "ADSyncServer01","ADSyncServer02" -SyncType Initial

        Triggers a full initial synchronization cycle on two different servers.

    .EXAMPLE
        Start-RemoteADSyncCycle -ConfigPath "C:\Scripts\ADServers.txt"

        Triggers a delta synchronization cycle on all servers listed in the specified configuration file.

    .NOTES
        Author: Michiel VH
        Requirements: PowerShell Remoting must be enabled on local and remote machines
        The account running this function must have appropriate permissions on the remote servers
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
        [string[]]$ComputerName,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Delta', 'Initial')]
        [string]$SyncType = 'Delta',
        
        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ConfigPath
    )

    begin {
        # Check if PSRemoting is available on the local machine
        if (-not (Get-Command Enter-PSSession -ErrorAction SilentlyContinue)) {
            Write-Error "PowerShell Remoting isn't supported on this machine."
            return
        }

        # Initialize the server list
        $servers = @()
        
        # Add servers from ComputerName parameter
        if ($ComputerName) {
            $servers += $ComputerName
        }
        
        # Add servers from config file if specified
        if ($ConfigPath) {
            try {
                $fileServers = Get-Content -Path $ConfigPath -ErrorAction Stop
                $servers += $fileServers
            }
            catch {
                Write-Error "Failed to read server list from configuration file: $_"
                return
            }
        }
        
        # Ensure we have at least one server
        if ($servers.Count -eq 0) {
            Write-Error "No target servers specified. Use either -ComputerName or -ConfigPath parameter."
            return
        }
        
        # Create the appropriate script block based on sync type
        $ScriptBlock = {
            try {
                if ($using:SyncType -eq 'Initial') {
                    Start-ADSyncSyncCycle -PolicyType Initial
                }
                else {
                    Start-ADSyncSyncCycle -PolicyType Delta
                }
                Write-Output "AD sync cycle ($using:SyncType) successfully initiated."
            }
            catch {
                throw "Failed to start AD sync cycle: $_"
            }
        }
    }

    process {
        foreach ($server in $servers) {
            Write-Verbose "Processing server: $server"
            
            # Check if we can contact the remote computer
            if (-not (Test-Connection -ComputerName $server -Quiet -Count 1)) {
                Write-Error "Can't contact $server. Check your network connection."
                continue
            }
            
            # Attempt to run the script block on the remote machine
            try {
                Write-Verbose "Initiating $SyncType sync on $server..."
                $result = Invoke-Command -ComputerName $server -ScriptBlock $ScriptBlock -ErrorAction Stop
                Write-Output "$server : $result"
            }
            catch {
                Write-Error "Failed to run commands on $server. Error: $_"
            }
        }
    }

    end {
        Write-Verbose "AD sync operation completed."
    }
}