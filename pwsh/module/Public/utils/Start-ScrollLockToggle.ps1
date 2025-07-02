function Start-ScrollLockToggle {
    <#
    .SYNOPSIS
        Toggles the ScrollLock key at regular intervals to prevent system idle or screen lock.

    .DESCRIPTION
        This function creates an endless loop that toggles the ScrollLock key on and off at defined intervals.
        Useful for keeping a system active without user interaction.

    .PARAMETER Interval
        The number of seconds to wait between toggle cycles. Default is 350 seconds.

    .PARAMETER ToggleDuration
        The duration in milliseconds for how long the ScrollLock stays toggled before toggling back. Default is 200 milliseconds.

    .EXAMPLE
        Start-ScrollLockToggle

        Starts toggling ScrollLock every 350 seconds.

    .EXAMPLE
        Start-ScrollLockToggle -Interval 60 -ToggleDuration 100

        Starts toggling ScrollLock every 60 seconds with a 100 millisecond toggle duration.

    .NOTES
        Author: Michiel VH
    #>

    param (
        [Parameter()]
        [int]$Interval = 350,

        [Parameter()]
        [int]$ToggleDuration = 200
    )

    Write-Host "Starting ScrollLock toggle every $Interval seconds..." -ForegroundColor Green
    $WShell = New-Object -com "Wscript.Shell" 
    
    try {
        while ($true) { 
            $WShell.sendkeys("{SCROLLLOCK}") 
            Start-Sleep -Milliseconds $ToggleDuration   
            $WShell.sendkeys("{SCROLLLOCK}") 
            Start-Sleep -Seconds $Interval 
        }
    }
    catch {
        Write-Host "ScrollLock toggle interrupted: $_" -ForegroundColor Yellow
    }
    finally {
        Write-Host "ScrollLock toggle stopped." -ForegroundColor Yellow
    }
}
