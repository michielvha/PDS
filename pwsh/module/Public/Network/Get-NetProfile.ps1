Function Get-NetProfile {
    <#
    .SYNOPSIS
        Retrieves all saved network profiles for both wired (LAN) and wireless (Wi-Fi) connections.

    .DESCRIPTION
        This function uses the `netsh` command to list all saved network profiles on the system.
        It displays both:
        - Wired (LAN) network profiles.
        - Wireless (Wi-Fi) network profiles.

        This is useful for quickly identifying stored network configurations.

    .EXAMPLE
        Get-NetProfile

        Lists all stored wired (LAN) and wireless (Wi-Fi) network profiles.

        Example Output:

        Wired Network Profiles:
        ----------------------
        Profile Name : Ethernet 1
        Profile Name : OfficeLAN

        Wireless Network Profiles:
        ----------------------
        Profile Name : HomeWiFi
        Profile Name : GuestWiFi

    .NOTES
        - This function does not require administrator privileges.
        - It simply queries stored network profiles without modifying any settings.

        Author: Michiel VH

    .LINK
        Microsoft Documentation on netsh:
        https://docs.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-wlan
    #>

    # Retrieve LAN (wired) network profiles
    Write-Host "`nWired Network Profiles:`n----------------------" -ForegroundColor Cyan
    netsh lan show profiles

    # Retrieve Wi-Fi (wireless) network profiles
    Write-Host "`nWireless Network Profiles:`n----------------------" -ForegroundColor Cyan
    netsh wlan show profiles
}