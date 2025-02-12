Function Get-WlanPass {
    <#
    .SYNOPSIS
    
    Provide a brief summary of what the function does. This should be a concise description, typically one or two sentences, that gives an overview of the function's purpose and functionality.

    .DESCRIPTION

    Provide a description for the function

    .PARAMETER EXAMPLE

    provide info about the parameter

    .EXAMPLE

    Give an example of how the function can be used

    .NOTES

    extra notes

    .LINK

    extra links

    #>

    # Parameters if any
#        param (
#        [Parameter(Mandatory=$true)]
#        [string]$Example
#    )

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

#(netsh wlan show profile name="YourWiFiSSID" key=clear) | Select-String "Key Content"
#((netsh wlan show profile name="YourWiFiSSID" key=clear) -match "Key Content") -split ":" | Select-Object -Last 1 | ForEach-Object { $_.Trim() }
