Function Enable-WinRmServer {
    <#
    .SYNOPSIS
        Enables WinRM over HTTP with NTLM authentication and optionally creates a local user for remote management.

    .DESCRIPTION
        Prepares a Windows test host for Ansible or other WinRM clients:
        - Starts WinRM, sets it to start automatically and creates an HTTP listener on TCP 5985 for
          every address. It configures these directly instead of through Enable-PSRemoting, whose
          firewall step refuses on networks classed Public even with -SkipNetworkProfileCheck when
          run over SSH
        - Keeps Negotiate (NTLM) authentication on and Basic authentication and unencrypted traffic off;
          NTLM clients such as pywinrm encrypt each message themselves
        - Ensures its own inbound firewall rule allows TCP 5985 on every network profile, from the
          addresses given in -RemoteAddress
        - When -UserName and -Password are given, creates or updates that local user and adds it to
          Remote Management Users, or to Administrators with -Administrator. For an administrator it
          also sets LocalAccountTokenFilterPolicy, so a remote local administrator gets a full token.
          For Remote Management Users it grants the group access to the WinRS shell that Ansible's
          winrm connection uses; WinRM refuses that change while a network is classed Public, so
          there the function warns and the user needs -Administrator for Ansible

        The function is idempotent. Disable-WinRmServer reverses it.

    .PARAMETER UserName
        Optional. Local user to create or update for remote sign-in. Requires -Password.

    .PARAMETER Password
        Password of -UserName as a SecureString.

    .PARAMETER Administrator
        Adds -UserName to the local Administrators group instead of Remote Management Users.

    .PARAMETER RemoteAddress
        Addresses the firewall rule accepts, as New-NetFirewallRule takes them. Defaults to LocalSubnet.

    .EXAMPLE
        Enable-WinRmServer

        Enables WinRM over HTTP for the local subnet. Existing administrators sign in with NTLM.

    .EXAMPLE
        $pw = Read-Host -AsSecureString
        Enable-WinRmServer -UserName winrmtest -Password $pw -RemoteAddress 192.168.10.0/24

        Also creates the local user winrmtest as a member of Remote Management Users.

    .NOTES
        - Requires administrator privileges.
        - HTTP with NTLM message encryption suits test hosts. Use an HTTPS listener with a trusted
          certificate for production hosts.

        Author: Michiel VH

    .LINK
        https://learn.microsoft.com/en-us/windows/win32/winrm/installation-and-configuration-for-windows-remote-management
        https://docs.ansible.com/ansible/latest/os_guide/windows_winrm.html
    #>

    [CmdletBinding(DefaultParameterSetName = 'NoUser')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'User')]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(Mandatory = $true, ParameterSetName = 'User')]
        [securestring]$Password,

        [Parameter(Mandatory = $false, ParameterSetName = 'User')]
        [switch]$Administrator,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$RemoteAddress = @('LocalSubnet')
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This function requires administrator privileges. Please run PowerShell as Administrator."
        return
    }

    $port = 5985
    $ruleName = "PDS-WinRM-HTTP-In-TCP-$port"

    try {
        # 1. Service and HTTP listener
        Set-Service -Name WinRM -StartupType Automatic
        Start-Service -Name WinRM
        $listener = Get-ChildItem -Path WSMan:\localhost\Listener |
            Where-Object { $_.Keys -contains 'Transport=HTTP' -and $_.Keys -contains 'Address=*' }
        if (-not $listener) {
            New-Item -Path WSMan:\localhost\Listener -Transport HTTP -Address * -Force | Out-Null
            Write-Host "Created the WinRM HTTP listener on port $port." -ForegroundColor Cyan
        }

        # 2. Authentication: NTLM through Negotiate; no Basic, no unencrypted traffic
        Set-Item -Path WSMan:\localhost\Service\Auth\Negotiate -Value $true
        Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $false
        # WinRM refuses any write to the service settings while a network is classed Public, so
        # AllowUnencrypted (false by default) is changed only when it is on.
        if ((Get-Item -Path WSMan:\localhost\Service\AllowUnencrypted).Value -eq 'true') {
            Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false
        }

        # 3. Firewall - our own rule for every profile. The built-in WinRM rule for Public networks
        #    is limited to the local subnet and may be disabled.
        if (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue) {
            Set-NetFirewallRule -Name $ruleName -Enabled True -Direction Inbound -Action Allow -Profile Any -RemoteAddress $RemoteAddress
        }
        else {
            New-NetFirewallRule -Name $ruleName -DisplayName "WinRM HTTP TCP $port (PDS)" `
                -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort $port `
                -Profile Any -RemoteAddress $RemoteAddress | Out-Null
        }
        Write-Host "Firewall rule '$ruleName' allows TCP $port on all profiles from $($RemoteAddress -join ', ')." -ForegroundColor Green

        # 4. Optional local user
        if ($PSCmdlet.ParameterSetName -eq 'User') {
            $user = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
            if ($user) {
                Set-LocalUser -Name $UserName -Password $Password -PasswordNeverExpires $true
                Enable-LocalUser -Name $UserName
                Write-Host "Updated the password of local user '$UserName'." -ForegroundColor Cyan
            }
            else {
                New-LocalUser -Name $UserName -Password $Password -PasswordNeverExpires -AccountNeverExpires `
                    -Description 'WinRM test user (PDS Enable-WinRmServer)' | Out-Null
                Write-Host "Created local user '$UserName'." -ForegroundColor Cyan
            }

            # Well-known SIDs, so this works on every display language
            $groupSid = if ($Administrator) { 'S-1-5-32-544' } else { 'S-1-5-32-580' }
            $member = Get-LocalGroupMember -SID $groupSid -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*\$UserName" }
            if (-not $member) {
                Add-LocalGroupMember -SID $groupSid -Member $UserName -ErrorAction Stop
            }
            $groupName = (Get-LocalGroup -SID $groupSid).Name
            if ($Administrator) {
                Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
                    -Name LocalAccountTokenFilterPolicy -Value 1 -Type DWord
            }
            else {
                # Remote Management Users reach the PowerShell endpoints by default, but the WinRS
                # shell (Ansible's winrm connection) only admits the groups in RootSDDL.
                $rmAce = '(A;;GXGR;;;S-1-5-32-580)'
                $sddl = (Get-Item -Path WSMan:\localhost\Service\RootSDDL).Value
                if ($sddl -notlike "*$rmAce*") {
                    try {
                        Set-Item -Path WSMan:\localhost\Service\RootSDDL -Value ($sddl -replace 'S:', "${rmAce}S:") -Force -ErrorAction Stop
                        Write-Host "Granted Remote Management Users access to the WinRS shell." -ForegroundColor Cyan
                    }
                    catch {
                        Write-Warning "WinRM refused to grant Remote Management Users shell access (it refuses service changes while a network is classed Public). '$UserName' can use PowerShell remoting but not Ansible's winrm connection; use -Administrator, or rerun on a Private network."
                    }
                }
            }
            Write-Host "'$UserName' is a member of '$groupName'." -ForegroundColor Green
        }

        $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
            Select-Object -ExpandProperty IPAddress)
        Write-Host "`nWinRM is listening on HTTP port $port with NTLM authentication." -ForegroundColor Green
        foreach ($ip in $ips) {
            Write-Host "  http://${ip}:$port/wsman" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to configure WinRM: $_"
    }
}
