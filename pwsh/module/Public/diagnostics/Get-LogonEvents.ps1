function Get-LogonEvents {
    <#
    .SYNOPSIS
        Retrieves and displays user logon events from the Windows Security log.

    .DESCRIPTION
        The Get-LogonEvents function retrieves logon events (EventID 4624) from the Security log
        for a specified time period. It filters out system accounts and displays the results in 
        a grid view with detailed information including timestamp, account name, logon type (with
        description), and source IP/computer.
        
        This function is useful for security auditing and monitoring user access to systems.

    .PARAMETER Days
        Specifies the number of days to look back for logon events.
        Default is 1 day.

    .PARAMETER ShowGridView
        If specified, displays the results in a grid view window.
        Default is $true.

    .PARAMETER IncludeSystemAccounts
        If specified, includes system accounts in the results.
        Default is $false.

    .EXAMPLE
        Get-LogonEvents
        
        Retrieves all user logon events from the past day and displays them in a grid view.

    .EXAMPLE
        Get-LogonEvents -Days 7 -ShowGridView $false
        
        Retrieves logon events from the past week and returns them as objects without displaying the grid view.

    .EXAMPLE
        Get-LogonEvents -Days 3 | Where-Object {$_.LogonTypeDescription -eq "Remote Desktop"}
        
        Retrieves logon events from the past 3 days and filters for just Remote Desktop connections.

    .NOTES
        Logon Types:
        2 = Interactive (Local logon)
        3 = Network (Connection to shared folder)
        4 = Batch (Scheduled task)
        5 = Service (Service startup)
        7 = Unlock (Unlocking a previously locked session)
        8 = NetworkCleartext (Most often indicates a logon to IIS with "basic authentication")
        9 = NewCredentials (A process ran using RunAs)
        10 = RemoteInteractive (Terminal Services, Remote Desktop or Remote Assistance)
        11 = CachedInteractive (Logon using cached domain credentials when a DC is not available)
    #>
    
    param (
        [int]$Days = 1,
        [bool]$ShowGridView = $true,
        [switch]$IncludeSystemAccounts = $false
    )

    $before = Get-Date
    $after = (Get-Date).AddDays(-$Days)
    $result = @()

    Write-Host "Retrieving logon events from $after to $before..." -ForegroundColor Cyan

    # Build the filter for system accounts
    $filter = {$true}
    if (-not $IncludeSystemAccounts) {
        $filter = {
            ($_.ReplacementStrings[5] -notmatch '\$') -and 
            ($_.ReplacementStrings[5] -notmatch 'ANONYMOUS LOGON') -and 
            ($_.ReplacementStrings[5] -notmatch 'SYSTEM')
        }
    }

    # EventID 4624 = logon
    $audit = Get-EventLog Security -InstanceId 4624 -Before $before -After $after | Where-Object $filter

    if (-not $audit) {
        Write-Host "No logon events found for the specified period." -ForegroundColor Yellow
        return $null
    }

    Write-Host "Processing $($audit.Count) logon events..." -ForegroundColor Cyan

    foreach ($event in $audit) {
        $time = $event.TimeGenerated | Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $account = $event.ReplacementStrings[5]
        $domain = $event.ReplacementStrings[6]
        $logonTypeCode = $event.ReplacementStrings[8]
        $sourceIP = $event.ReplacementStrings[18]
        
        # Translate logon type code to a description
        $logonTypeDescription = switch ($logonTypeCode) {
            2 { "Interactive (Local logon)" }
            3 { "Network (Shared folder)" }
            4 { "Batch (Scheduled task)" }
            5 { "Service" }
            7 { "Unlock" }
            8 { "NetworkCleartext" }
            9 { "NewCredentials (RunAs)" }
            10 { "Remote Desktop" }
            11 { "Cached Domain Logon" }
            default { "Type $logonTypeCode (Unknown)" }
        }
        
        # Create and add the result object
        $obj = [PSCustomObject]@{
            Time = $time
            Account = "$domain\$account"
            LogonType = $logonTypeCode
            LogonTypeDescription = $logonTypeDescription
            SourceIP = if ($sourceIP -and $sourceIP -ne "-") { $sourceIP } else { "Local" }
        }
        
        $result += $obj
    }

    # Output the results
    if ($ShowGridView) {
        $result | Sort-Object -Property Time -Descending | Out-GridView -Title "Logon Events: Past $Days Day(s)"
    }
    
    return $result
}
