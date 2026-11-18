Function Disable-WinRmServer {
    <#
    .SYNOPSIS
        Reverses Enable-WinRmServer: removes the WinRM listener and firewall rule, stops WinRM and optionally removes the test user.

    .DESCRIPTION
        - Removes the Remote Management Users shell access Enable-WinRmServer may have added
        - Removes every WinRM listener, then stops the WinRM service and sets it to manual start
        - Removes the PDS firewall rule for TCP 5985
        - Resets LocalAccountTokenFilterPolicy, which Enable-WinRmServer -Administrator sets, to 0
        - When -UserName is given, removes that local user

        The function is idempotent.

    .PARAMETER UserName
        Optional. Local user to remove, such as the one Enable-WinRmServer created.

    .EXAMPLE
        Disable-WinRmServer -UserName winrmtest

    .NOTES
        Requires administrator privileges.

        Author: Michiel VH
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This function requires administrator privileges. Please run PowerShell as Administrator."
        return
    }

    $ruleName = 'PDS-WinRM-HTTP-In-TCP-5985'

    try {
        if ((Get-Service -Name WinRM).Status -ne 'Running') {
            Start-Service -Name WinRM
        }
        $rmAce = '(A;;GXGR;;;S-1-5-32-580)'
        $sddl = (Get-Item -Path WSMan:\localhost\Service\RootSDDL).Value
        if ($sddl -like "*$rmAce*") {
            try {
                Set-Item -Path WSMan:\localhost\Service\RootSDDL -Value $sddl.Replace($rmAce, '') -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Could not remove the Remote Management Users shell access from RootSDDL: $_"
            }
        }
        Get-ChildItem -Path WSMan:\localhost\Listener -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
        Stop-Service -Name WinRM -Force
        Set-Service -Name WinRM -StartupType Manual
        Write-Host "WinRM is stopped and has no listener." -ForegroundColor Green

        Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
        Write-Host "Firewall rule '$ruleName' removed." -ForegroundColor Green

        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
            -Name LocalAccountTokenFilterPolicy -Value 0 -Type DWord

        if ($UserName) {
            if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
                Remove-LocalUser -Name $UserName
                Write-Host "Removed local user '$UserName'." -ForegroundColor Green
            }
            else {
                Write-Host "Local user '$UserName' does not exist." -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Error "Failed to disable WinRM: $_"
    }
}
