Function Set-FirewallRule {
    <#
    .SYNOPSIS
        Creates inbound and outbound firewall rules for a specified TCP port.

    .DESCRIPTION
        This function creates two Windows Firewall rules:
        - An inbound rule to allow incoming traffic on the specified port
        - An outbound rule to allow outgoing traffic on the specified port

        Both rules are created for TCP protocol by default.

    .PARAMETER Port
        The TCP port number to open in the firewall.

    .PARAMETER DisplayName
        Optional. The base name to use for the firewall rules. If not specified,
        a generic name with the port number will be used.

    .PARAMETER Protocol
        Optional. The protocol to use for the firewall rule. Default is TCP.

    .EXAMPLE
        Set-FirewallRule -Port 6040

        Creates inbound and outbound rules for TCP port 6040:
        - "Allow 6040 in" (Inbound)
        - "Allow 6040 out" (Outbound)

    .EXAMPLE
        Set-FirewallRule -Port 8080 -DisplayName "My Web App"

        Creates inbound and outbound rules for TCP port 8080:
        - "My Web App - In" (Inbound)
        - "My Web App - Out" (Outbound)

    .EXAMPLE
        Set-FirewallRule -Port 53 -Protocol UDP -DisplayName "DNS Traffic"

        Creates inbound and outbound rules for UDP port 53:
        - "DNS Traffic - In" (Inbound)
        - "DNS Traffic - Out" (Outbound)

    .NOTES
        - This function requires administrator privileges to create firewall rules.
        - Use the -DisplayName parameter to give more descriptive names to your rules.

        Author: Michiel VH

    .LINK
        Microsoft Documentation on Windows Firewall cmdlets:
        https://docs.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 65535)]
        [int]$Port,

        [Parameter(Mandatory = $false)]
        [string]$DisplayName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("TCP", "UDP")]
        [string]$Protocol = "TCP"
    )

    # Check for admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This function requires administrator privileges. Please run PowerShell as Administrator."
        return
    }

    # Set the display name
    $inboundName = $outboundName = ""
    if ([string]::IsNullOrEmpty($DisplayName)) {
        $inboundName = "Allow $Port in"
        $outboundName = "Allow $Port out"
    } else {
        $inboundName = "$DisplayName - In"
        $outboundName = "$DisplayName - Out"
    }

    try {
        # Create inbound rule
        Write-Host "Creating inbound rule for port $Port ($Protocol)..." -ForegroundColor Cyan
        New-NetFirewallRule -DisplayName $inboundName -Direction Inbound -Action Allow -LocalPort $Port -Protocol $Protocol

        # Create outbound rule
        Write-Host "Creating outbound rule for port $Port ($Protocol)..." -ForegroundColor Cyan
        New-NetFirewallRule -DisplayName $outboundName -Direction Outbound -Action Allow -LocalPort $Port -Protocol $Protocol

        Write-Host "`nFirewall rules successfully created:" -ForegroundColor Green
        Write-Host " - $inboundName (Inbound, $Protocol port $Port)" -ForegroundColor Green
        Write-Host " - $outboundName (Outbound, $Protocol port $Port)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create firewall rules: $_"
    }
}