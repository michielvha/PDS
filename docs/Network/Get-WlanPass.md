---
external help file: PDS-help.xml
Module Name: PDS
online version:
schema: 2.0.0
---

# Get-WlanPass

## SYNOPSIS
Retrieves all saved WiFi profiles on the system and displays their passwords.

## SYNTAX

```
Get-WlanPass
```

## DESCRIPTION
This function fetches all stored WiFi SSIDs (network names) on the local Windows machine
and retrieves their associated passwords if available.
If a password is not found, it
returns "N/A".
This is useful for quickly accessing stored WiFi credentials.

## EXAMPLES

### EXAMPLE 1
```
Get-WlanPass
```

Retrieves all stored WiFi SSIDs and their passwords and displays them in a table format.

Example Output:

SSID             Password
----             --------
HomeWiFi         MySecurePass123
PublicWiFi       N/A

## PARAMETERS

## INPUTS

## OUTPUTS

## NOTES
- You must run this function as an account with local admin priveledges, elevated prompt is not required for it to retrieve passwords.
- If an SSID shows "N/A", it means the password is not stored locally.

## RELATED LINKS

[Microsoft Documentation on netsh:
https://docs.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-wlan]()

