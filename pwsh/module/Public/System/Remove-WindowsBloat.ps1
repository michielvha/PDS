Function Remove-WindowsBloat {
    <#
    .SYNOPSIS
        Disables non-essential and resource-heavy Windows services to improve system performance.

    .DESCRIPTION
        The Remove-WindowsBloat function disables a curated list of background Windows services known to consume CPU, RAM, and disk bandwidth unnecessarily on modern machines.
        The script is safe for general use and avoids touching core system functionality or breaking essential features like networking or updates.

        Most of the services targeted are:
            - Legacy or obsolete (e.g. Fax, WAP Push)
            - Resource-intensive (e.g. SysMain, Windows Search)
            - Xbox or demo-related (e.g. RetailDemo, XblGameSave)
            - Rarely used by average users (e.g. PhoneSvc, MessagingService)

        The services are disabled using a helper function `Disable-ServiceSafe`, which ensures graceful shutdown and error handling.

    .PARAMETER None
        This function takes no parameters.

    .NOTES
        Author: itmvha
        Requires: PowerShell 5.1+ and Administrator privileges

    .EXAMPLE
        PS> Remove-WindowsBloat

        Disables unnecessary Windows services to reduce background CPU and memory usage.

    .LINK
        GitHub: https://github.com/michielvha/PDS
    #>
    # --- Disable services safely ---
    $servicesToDisable = @(
        "SysMain",                  # Superfetch - useless on SSDs, hogs disk/CPU
        "WSearch",                  # Windows Search Indexer
        "DiagTrack",                # Connected User Experiences and Telemetry
        "DmWapPushService",         # WAP Push Message Routing - useless
        "Fax",                      # Nobody uses fax
        "MapsBroker",               # Online maps support - pointless
        "XblGameSave",              # Xbox Game Save
        "XboxNetApiSvc",            # Xbox Networking
        "RetailDemo",               # Retail demo service
        "OneSyncSvc*",              # Contacts/calendar sync - useless unless using built-in Mail
        "PhoneSvc",                 # Mobile connectivity service
        "MessagingService",         # SMS-related service
        "PrintWorkflowUserSvc*",    # Part of print services you likely don't need
        "CDPUserSvc*"               # Connected Devices Platform
    )

    # Disable each one safely
    foreach ($svc in $servicesToDisable) {
        Get-Service -Name $svc -ErrorAction SilentlyContinue | ForEach-Object {
            Disable-ServiceSafe $_.Name
        }
    }

    Write-Host "`n✅ Done. You may want to reboot for all changes to take effect." -ForegroundColor Green

}

# --- Disable Windows services safely ---
function Disable-ServiceSafe {
    param (
        [string]$Name
    )
    if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
        Write-Output "Disabling service: $Name"
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $Name -StartupType Disabled
    } else {
        Write-Output "Service $Name not found. Skipping..."
    }
}
