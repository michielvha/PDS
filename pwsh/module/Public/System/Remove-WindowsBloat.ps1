function Remove-WindowsBloat {
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

        Per-user services (e.g. OneSyncSvc, CDPUserSvc) run as one instance per signed-in user, named <template>_<id>.
        Windows refuses to change an instance's startup type, so the function disables the template service through its
        registry Start value, which stops Windows creating the instances, and only stops the running instances.

    .PARAMETER None
        This function takes no parameters.

    .NOTES
        Author: Michiel VH
        Requires: PowerShell 5.1+ and Administrator privileges

    .EXAMPLE
        PS> Remove-WindowsBloat

        Disables unnecessary Windows services to reduce background CPU and memory usage.

    .LINK
        GitHub: https://github.com/michielvha/PDS
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param ()

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
        "PhoneSvc"                  # Mobile connectivity service
    )

    # --- Per-user service templates ---
    # Windows creates one instance of each per signed-in user (<template>_<id>) and refuses to change
    # an instance's startup type. Disabling the template stops the instances being created. Some
    # templates deny the change through the service manager (PrintWorkflowUserSvc), so the startup
    # type is set through the template's registry Start value, as Microsoft documents for per-user services.
    $perUserServiceTemplates = @(
        "OneSyncSvc",               # Contacts/calendar sync - useless unless using built-in Mail
        "MessagingService",         # SMS-related service
        "PrintWorkflowUserSvc",     # Part of print services you likely don't need
        "CDPUserSvc"                # Connected Devices Platform
    )

    # Disable each one safely
    foreach ($svc in $servicesToDisable) {
        Get-Service -Name $svc -ErrorAction SilentlyContinue | ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.Name, 'Stop and disable service')) {
                Disable-ServiceSafe $_.Name
            }
        }
    }

    foreach ($template in $perUserServiceTemplates) {
        if (-not (Get-Service -Name $template -ErrorAction SilentlyContinue)) {
            continue
        }
        if ($PSCmdlet.ShouldProcess($template, 'Disable per-user service template')) {
            Write-Output "Disabling per-user service template: $template"
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$template" -Name 'Start' -Value 4
        }
        # Stop the existing instances where Windows allows it; a refusal is expected and not an error
        Get-Service -Name "$($template)_*" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($PSCmdlet.ShouldProcess($_.Name, 'Stop per-user service instance')) {
                Write-Output "Stopping per-user service instance: $($_.Name)"
                Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
            }
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
    }
    else {
        Write-Output "Service $Name not found. Skipping..."
    }
}
