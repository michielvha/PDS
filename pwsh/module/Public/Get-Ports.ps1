Function Get-Ports {
    <#
    .SYNOPSIS
        Lists all listening TCP and UDP ports with associated process information.

    .DESCRIPTION
        The Get-Ports function retrieves all currently listening TCP and UDP ports on the local system, similar to the 'netstat -tunlp' command on Linux. 
        For each port, it displays the protocol, local address and port, process ID (PID), and the name of the owning process. 
        This can be useful for troubleshooting, auditing, or monitoring network activity on a Windows machine.

    .EXAMPLE
        Get-Ports
        Lists all listening TCP and UDP ports with their associated process names and PIDs.

    .NOTES
        - You must run this function as an account with local administrator privileges to retrieve all process information.
        - Some system processes may not display a process name if access is restricted.
        - The function does not require an elevated prompt, but limited permissions may restrict process name visibility.

    #>

    $tcp = Get-NetTCPConnection -State Listen | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Protocol     = "TCP"
            LocalAddress = "$($_.LocalAddress):$($_.LocalPort)"
            PID          = $_.OwningProcess
            Process      = $proc.ProcessName
        }
    }

    $udp = Get-NetUDPEndpoint | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Protocol     = "UDP"
            LocalAddress = "$($_.LocalAddress):$($_.LocalPort)"
            PID          = $_.OwningProcess
            Process      = $proc.ProcessName
        }
    }

    $tcp + $udp | Sort-Object Protocol, LocalAddress | Format-Table -AutoSize

}