function Get-LogonActivity {
    <#
    .SYNOPSIS
        Retrieves and displays system logon and logoff events from the past 24 hours.

    .DESCRIPTION
        The Get-LogonActivity function retrieves all logon (Event ID 4624) and logoff (Event ID 4647) events
        from the Windows Security event log for the past 24 hours. It provides detailed information about
        each event including user name, domain, logon type, IP address (for remote connections), and timestamp.

        The function displays a summary of connection events including total counts and unique users,
        followed by a detailed table of all events sorted chronologically.

        This function can be useful for system administrators to monitor login activity and
        identify potential security concerns or unusual access patterns.

    .EXAMPLE
        Get-LogonActivity

        Displays a summary of logon/logoff activity in the past 24 hours, followed by a detailed
        chronological table of all events with user, type, and source information.

    .EXAMPLE
        $events = Get-LogonActivity
        $events | Where-Object {$_.LogonType -eq "RemoteInteractive"} | Format-Table

        Captures the returned events in a variable and filters to show only Remote Desktop (RDP) logons.

    .NOTES
        - Requires access to the Security event log (typically requires administrative privileges)
        - Uses Event ID 4624 for logon events and Event ID 4647 for logoff events
        - May return a large number of events on busy systems
        - Logon types are translated to human-readable format:
          * Type 2: Interactive (local logon)
          * Type 3: Network (e.g., connecting to shared folder)
          * Type 10: RemoteInteractive (RDP)
    #>
    [Alias('Get-AllConnections')]
    param ()


    # Get today's date
    $date = Get-Date

    # Get yesterday's date by subtracting 24 hours
    $yesterday = $date.AddHours(-24)

    # Specify the event IDs for logon and logoff events
    $logonEventID = 4624
    $logoffEventID = 4647

    # Get the logon and logoff events from the Security log. Get-WinEvent reports an empty
    # result as a NoMatchingEventsFound error, which means there are no events; any other
    # error (such as access denied without elevation) is passed on.
    $query = @{
        LogName   = 'Security'
        Id        = $logonEventID, $logoffEventID
        StartTime = $yesterday
    }
    try {
        $events = Get-WinEvent -FilterHashtable $query -ErrorAction Stop
    }
    catch {
        if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') {
            throw
        }
        $events = @()
    }

    # Split the logon events from the logoff events
    $logonEvents = $events | Where-Object { $_.Id -eq $logonEventID }
    $logoffEvents = $events | Where-Object { $_.Id -eq $logoffEventID }

    # Create an array to store all connection events
    $allEvents = @()

    # Process logon events
    if ($logonEvents) {
        foreach ($logonEvent in $logonEvents) {
            # Extract useful information from the event
            $userName = $logonEvent.Properties[5].Value
            $domainName = $logonEvent.Properties[6].Value
            $logonType = $logonEvent.Properties[8].Value
            $ipAddress = $logonEvent.Properties[18].Value

            # Convert logon type number to descriptive text
            $logonTypeText = switch ($logonType) {
                2 { "Interactive" }
                3 { "Network" }
                4 { "Batch" }
                5 { "Service" }
                7 { "Unlock" }
                8 { "NetworkCleartext" }
                9 { "NewCredentials" }
                10 { "RemoteInteractive" }
                11 { "CachedInteractive" }
                default { "Type $logonType" }
            }

            # Add to our collection
            $allEvents += [PSCustomObject]@{
                Time      = $logonEvent.TimeCreated
                Type      = "Logon"
                User      = "$domainName\$userName"
                LogonType = $logonTypeText
                IPAddress = if ($ipAddress -and $ipAddress -ne "-") { $ipAddress } else { "Local" }
                EventID   = $logonEvent.Id
            }
        }
    }

    # Process logoff events
    if ($logoffEvents) {
        foreach ($logoffEvent in $logoffEvents) {
            # Extract useful information from the event
            $userName = $logoffEvent.Properties[1].Value
            $domainName = $logoffEvent.Properties[2].Value

            # Add to our collection
            $allEvents += [PSCustomObject]@{
                Time      = $logoffEvent.TimeCreated
                Type      = "Logoff"
                User      = "$domainName\$userName"
                LogonType = "N/A"
                IPAddress = "N/A"
                EventID   = $logoffEvent.Id
            }
        }
    }

    # Output summary information
    Write-Host "`n=== Connection Summary ===`n" -ForegroundColor Cyan
    Write-Host "Time Period: $yesterday to $date"
    Write-Host "Total Logon Events:  $($logonEvents.Count)"
    Write-Host "Total Logoff Events: $($logoffEvents.Count)`n"

    # Output unique users who logged in
    $uniqueUsers = $allEvents | Where-Object { $_.Type -eq "Logon" } | Select-Object -ExpandProperty User -Unique
    Write-Host "Unique Users Who Logged In ($($uniqueUsers.Count)):" -ForegroundColor Cyan
    $uniqueUsers | ForEach-Object { Write-Host "  - $_" }

    # Output detailed event information
    Write-Host "`n=== Detailed Connection Events ===`n" -ForegroundColor Cyan

    # Return the event data for potential further processing
    return $allEvents | Sort-Object Time | Format-Table -AutoSize
}
