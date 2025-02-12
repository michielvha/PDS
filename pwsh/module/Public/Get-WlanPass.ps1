Function Get-WlanPass {
    <#
    .SYNOPSIS
        Retrieves all saved WiFi profiles on the system and displays their passwords.

    .DESCRIPTION
        This function fetches all stored WiFi SSIDs (network names) on the local Windows machine
        and retrieves their associated passwords if available. If a password is not found, it
        returns "N/A". This is useful for quickly accessing stored WiFi credentials.

    .EXAMPLE
        Get-WlanPass

        Retrieves all stored WiFi SSIDs and their passwords and displays them in a table format.

        Example Output:

        SSID             Password
        ----             --------
        HomeWiFi         MySecurePass123
        PublicWiFi       N/A

    .NOTES
        - You must run this function as an account with local admin priveledges, elevated prompt is not required for it to retrieve passwords.
        - If an SSID shows "N/A", it means the password is not stored locally.

    .LINK
        Microsoft Documentation on netsh:
        https://docs.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-wlan

    #>

    # Get all WiFi profiles
    $profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { ($_ -split ":")[-1].Trim() }

    # Create an empty array to store credentials
    $wifiCredentials = @()

    # Iterate over each profile and fetch its password
    foreach ($profile in $profiles) {
        # Fetch password (key content)
        $passwordLine = netsh wlan show profile name="$profile" key=clear | Select-String "Key Content"

        # Extract password if found, otherwise set it to "N/A"
        if ($passwordLine) {
            $password = ($passwordLine -split ":")[-1].Trim()
        } else {
            $password = "N/A"
        }

        # Store SSID and password in an object
        $wifiCredentials += [PSCustomObject]@{
            SSID     = $profile
            Password = $password
        }
    }

    # Display in table format
    $wifiCredentials | Format-Table -AutoSize
}