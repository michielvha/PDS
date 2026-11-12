Function Enable-SshServer {
    <#
    .SYNOPSIS
        Installs and enables the Windows OpenSSH server and authorizes one or more public keys.

    .DESCRIPTION
        Configures a Windows machine for key-based SSH access:
        - Installs the OpenSSH.Server Windows capability if it is missing
        - Starts sshd and sets it to start automatically
        - Ensures an inbound firewall rule exists for the SSH port
        - Adds the given public key(s) to the correct authorized keys file:
            * Members of the local Administrators group use
              C:\ProgramData\ssh\administrators_authorized_keys (default sshd_config Match rule)
            * Other users use C:\Users\<user>\.ssh\authorized_keys
        - Applies the strict ACLs sshd requires on that file

        Optionally changes the SSH port, sets the default shell and disables password authentication.
        The function is idempotent; keys that are already present are not added twice.

    .PARAMETER PublicKey
        One or more public key strings, e.g. "ssh-ed25519 AAAA... user@host".

    .PARAMETER PublicKeyPath
        Path to a public key file (e.g. id_ed25519.pub). Every key line in the file is added.

    .PARAMETER UserName
        Local user the keys are authorized for. Defaults to the current user.

    .PARAMETER Port
        TCP port sshd listens on. Defaults to 22.

    .PARAMETER DefaultShell
        Optional path to the shell used for SSH sessions, e.g.
        "C:\Program Files\PowerShell\7\pwsh.exe". Defaults to cmd.exe when not set.

    .PARAMETER DisablePasswordAuthentication
        Disables password authentication in sshd_config so only key-based logins are accepted.

    .EXAMPLE
        Enable-SshServer -PublicKey "ssh-ed25519 AAAAC3Nza... me@laptop"

        Installs and starts sshd and authorizes the key for the current user.

    .EXAMPLE
        Enable-SshServer -PublicKeyPath .\id_ed25519.pub -DefaultShell "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -DisablePasswordAuthentication

        Authorizes every key in the file, uses Windows PowerShell as login shell and disables password logins.

    .NOTES
        - Requires administrator privileges.
        - Installing the OpenSSH.Server capability requires access to Windows Update / Features on Demand.

        Author: Michiel VH

    .LINK
        https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse
        https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement
    #>

    [CmdletBinding(DefaultParameterSetName = 'Key')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Key')]
        [string[]]$PublicKey,

        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string]$PublicKeyPath,

        [Parameter(Mandatory = $false)]
        [string]$UserName = $env:USERNAME,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 65535)]
        [int]$Port = 22,

        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string]$DefaultShell,

        [Parameter(Mandatory = $false)]
        [switch]$DisablePasswordAuthentication
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This function requires administrator privileges. Please run PowerShell as Administrator."
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $PublicKey = Get-Content -LiteralPath $PublicKeyPath
    }
    $keyPattern = '^(ssh-(rsa|ed25519|dss)|ecdsa-sha2-nistp\d+|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com)\s+\S+'
    $keys = @($PublicKey | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
    $invalid = @($keys | Where-Object { $_ -notmatch $keyPattern })
    if ($keys.Count -eq 0 -or $invalid.Count -gt 0) {
        Write-Error "No valid OpenSSH public key provided. Invalid entries: $($invalid -join '; ')"
        return
    }

    try {
        $account = New-Object System.Security.Principal.NTAccount($UserName)
        $userSid = $account.Translate([System.Security.Principal.SecurityIdentifier]).Value
    }
    catch {
        Write-Error "User '$UserName' could not be resolved: $_"
        return
    }

    $sshDataDir = Join-Path $env:ProgramData 'ssh'
    $sshdConfig = Join-Path $sshDataDir 'sshd_config'

    try {
        # 1. Install OpenSSH server
        $capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1
        if (-not $capability) {
            throw "OpenSSH.Server capability is not available on this Windows edition."
        }
        if ($capability.State -ne 'Installed') {
            Write-Host "Installing $($capability.Name)..." -ForegroundColor Cyan
            Add-WindowsCapability -Online -Name $capability.Name -ErrorAction Stop | Out-Null
        }
        else {
            Write-Host "OpenSSH server already installed." -ForegroundColor Green
        }

        # 2. Start sshd once so it generates host keys and the default sshd_config
        Set-Service -Name sshd -StartupType Automatic
        Start-Service -Name sshd
        if (-not (Test-Path -LiteralPath $sshdConfig)) {
            throw "sshd_config not found at $sshdConfig after starting sshd."
        }

        # 3. sshd_config changes
        $config = Get-Content -LiteralPath $sshdConfig -Raw
        $originalConfig = $config
        $config = Set-SshdConfigOption -Config $config -Name 'Port' -Value $Port
        $config = Set-SshdConfigOption -Config $config -Name 'PubkeyAuthentication' -Value 'yes'
        if ($DisablePasswordAuthentication) {
            $config = Set-SshdConfigOption -Config $config -Name 'PasswordAuthentication' -Value 'no'
        }
        if ($config -ne $originalConfig) {
            Copy-Item -LiteralPath $sshdConfig -Destination "$sshdConfig.bak" -Force
            [System.IO.File]::WriteAllText($sshdConfig, $config, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "Updated $sshdConfig (backup: $sshdConfig.bak)" -ForegroundColor Cyan
        }

        # 4. Default shell
        if ($DefaultShell) {
            New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
            New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value $DefaultShell -PropertyType String -Force | Out-Null
            Write-Host "Default SSH shell set to $DefaultShell" -ForegroundColor Cyan
        }

        # 5. Firewall
        $existingRule = Get-NetFirewallPortFilter -Protocol TCP -ErrorAction SilentlyContinue |
            Where-Object { $_.LocalPort -contains "$Port" } |
            Get-NetFirewallRule -ErrorAction SilentlyContinue |
            Where-Object { $_.Direction -eq 'Inbound' -and $_.Enabled -eq 'True' -and $_.Action -eq 'Allow' } |
            Select-Object -First 1
        if ($existingRule) {
            Write-Host "Firewall rule '$($existingRule.DisplayName)' already allows TCP $Port." -ForegroundColor Green
        }
        else {
            New-NetFirewallRule -Name "PDS-OpenSSH-Server-In-TCP-$Port" -DisplayName "OpenSSH Server (sshd) TCP $Port" `
                -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort $Port | Out-Null
            Write-Host "Created inbound firewall rule for TCP $Port." -ForegroundColor Cyan
        }

        # 6. Authorized keys - administrators use a shared file because of the default 'Match Group administrators' block
        $adminGroupSid = 'S-1-5-32-544'
        $isTargetAdmin = $false
        try {
            $isTargetAdmin = [bool](Get-LocalGroupMember -SID $adminGroupSid -ErrorAction Stop | Where-Object { $_.SID.Value -eq $userSid })
        }
        catch {
            # Get-LocalGroupMember fails on orphaned domain SIDs; the elevated current user is an admin by definition
            $isTargetAdmin = $userSid -eq [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            Write-Warning "Could not enumerate local Administrators; assuming '$UserName' is $(if (-not $isTargetAdmin) { 'not ' })an administrator."
        }

        $usesAdminKeysFile = $isTargetAdmin -and ($config -match '(?mi)^\s*Match\s+Group\s+administrators')
        if ($usesAdminKeysFile) {
            $authorizedKeysFile = Join-Path $sshDataDir 'administrators_authorized_keys'
        }
        else {
            $profilePath = (Get-CimInstance -ClassName Win32_UserProfile -Filter "SID = '$userSid'" -ErrorAction SilentlyContinue).LocalPath
            if (-not $profilePath) {
                $profilePath = Join-Path (Split-Path $env:PUBLIC -Parent) $UserName
                Write-Warning "No profile found for '$UserName'; using $profilePath. Log in once as this user first if Windows creates a different profile folder."
            }
            $userSshDir = Join-Path $profilePath '.ssh'
            if (-not (Test-Path -LiteralPath $userSshDir)) {
                New-Item -ItemType Directory -Path $userSshDir -Force | Out-Null
            }
            $authorizedKeysFile = Join-Path $userSshDir 'authorized_keys'
        }

        $existingKeys = @()
        if (Test-Path -LiteralPath $authorizedKeysFile) {
            $existingKeys = @(Get-Content -LiteralPath $authorizedKeysFile | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }
        $newKeys = @($keys | Where-Object { $existingKeys -notcontains $_ } | Select-Object -Unique)
        if ($newKeys.Count -gt 0) {
            [System.IO.File]::WriteAllLines($authorizedKeysFile, [string[]]($existingKeys + $newKeys), (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "Added $($newKeys.Count) key(s) to $authorizedKeysFile" -ForegroundColor Cyan
        }
        else {
            Write-Host "All keys already present in $authorizedKeysFile" -ForegroundColor Green
        }

        # sshd rejects key files writable by anyone other than SYSTEM, Administrators or the owning user
        $grants = @('/grant', '*S-1-5-18:F', '/grant', "*${adminGroupSid}:F")
        if (-not $usesAdminKeysFile) {
            $grants += @('/grant', "*${userSid}:F")
        }
        & icacls.exe $authorizedKeysFile /inheritance:r @grants | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set ACLs on $authorizedKeysFile"
        }

        Restart-Service -Name sshd -Force

        $ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
            Select-Object -ExpandProperty IPAddress)
        $portArg = if ($Port -ne 22) { " -p $Port" } else { "" }
        Write-Host "`nOpenSSH server is running with key-based access for '$UserName'." -ForegroundColor Green
        foreach ($ip in $ips) {
            Write-Host "  ssh$portArg $UserName@$ip" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to configure OpenSSH server: $_"
    }
}

function Set-SshdConfigOption {
    # Sets a global sshd_config option, replacing an existing (or commented) entry before any Match block.
    param(
        [string]$Config,
        [string]$Name,
        [string]$Value
    )

    $matchIndex = [regex]::Match($Config, '(?mi)^\s*Match\s').Index
    $globalPart = if ($matchIndex -gt 0) { $Config.Substring(0, $matchIndex) } else { $Config }
    $rest = if ($matchIndex -gt 0) { $Config.Substring($matchIndex) } else { '' }

    $pattern = "(?mi)^[ \t]*#?[ \t]*$Name[ \t]+\S+[ \t]*(?=\r?$)"
    if ([regex]::IsMatch($globalPart, $pattern)) {
        $globalPart = ([regex]$pattern).Replace($globalPart, "$Name $Value", 1)
    }
    else {
        $globalPart = "$Name $Value`r`n" + $globalPart
    }
    return $globalPart + $rest
}
