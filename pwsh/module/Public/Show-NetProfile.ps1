Function Show-NetProfile {
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

    # function definiton
    netsh lan show profiles
    netsh wlan show profiles
}

#(netsh wlan show profile name="YourWiFiSSID" key=clear) | Select-String "Key Content"
#((netsh wlan show profile name="YourWiFiSSID" key=clear) -match "Key Content") -split ":" | Select-Object -Last 1 | ForEach-Object { $_.Trim() }
