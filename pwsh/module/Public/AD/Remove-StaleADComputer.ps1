function Remove-StaleADComputer {
    <#
    .SYNOPSIS
        Removes stale Active Directory computer objects based on last logon date.

    .DESCRIPTION
        This function identifies and removes Active Directory computer objects that haven't logged on within a specified number of years.
        All removal actions are logged using Set-Log.

    .PARAMETER Years
        The number of years to look back for the last logon date. Computers that haven't logged on within this timeframe will be removed.
        Default is 1 year.

    .PARAMETER WhatIf
        Shows what would be removed without actually performing the removal.

    .EXAMPLE
        Remove-StaleADComputer

        Removes all AD computers that haven't logged on in the past year.

    .EXAMPLE
        Remove-StaleADComputer -Years 2

        Removes all AD computers that haven't logged on in the past 2 years.

    .EXAMPLE
        Remove-StaleADComputer -Years 1 -WhatIf

        Shows which computers would be removed without actually removing them.

    .NOTES
        Author: Michiel VH

        Requires ActiveDirectory PowerShell module and appropriate permissions to remove computer objects.
    #>

    param (
        [Parameter(Mandatory = $false)]
        [int]$Years = 1,

        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )

    Import-Module ActiveDirectory

    $computers = Get-ADComputer -Filter * -Properties Name, DistinguishedName, LastLogonDate

    $cutoffDate = (Get-Date).AddYears(-$Years)

    foreach ($computer in $computers) {
        if ($computer.LastLogonDate -lt $cutoffDate) {
            try {
                if ($WhatIf) {
                    Set-Log "$($computer.name) - Would be removed - Last Seen: $($computer.LastLogonDate)"
                    Write-Host "$($computer.name) - Would be removed - Last Seen: $($computer.LastLogonDate)"
                } else {
                    Remove-ADComputer -Identity $computer.DistinguishedName -Confirm:$false
                    Set-Log "$($computer.name) - Removed - Last Seen: $($computer.LastLogonDate)"
                    Write-Host "$($computer.name) - Removed - Last Seen: $($computer.LastLogonDate)"
                }
            } catch {
                Set-Log "An error occurred while removing $($computer.name): $_"
                Write-Host "An error occurred while removing $($computer.name): $_"
            }
        }
    }
}