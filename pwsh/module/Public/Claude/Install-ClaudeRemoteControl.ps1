function Install-ClaudeRemoteControl {
    <#
    .SYNOPSIS
        Runs claude remote-control as a per-user service, so the machine stays available as a Remote Control environment.

    .DESCRIPTION
        Writes and starts a service that runs claude remote-control in the working directory and restarts it
        when it exits:

        - macOS: a LaunchAgent at ~/Library/LaunchAgents/pro.vhco.claude-remote-control.<id>.plist, loaded
          into the gui/<uid> domain with launchctl bootstrap. It runs at load, is kept alive with a 60 second
          throttle and logs to ~/Library/Logs/claude-remote-control-<id>.log. The GUI domain can read the
          login from the Keychain, which an SSH session cannot.
        - Linux: a systemd --user unit at ~/.config/systemd/user/claude-remote-control-<id>.service, enabled
          and started, restarting every 60 seconds. It logs to the journal. -EnableLinger keeps it running
          after logout, which a server needs.

        <id> is the last segment of the working directory. Running it again with the same parameters changes
        nothing; changed parameters rewrite the file and restart the service.

        It then checks the traps that stop Remote Control from starting and prints the steps that are left.
        Two of them are the owner's decision and stay manual: accepting workspace trust and answering
        "Enable Remote Control?" once. This function never records either. It also reports a terminal
        claude remote-control that already serves the directory, which keeps the service from starting. The service retries every minute,
        so it starts by itself once the steps are done.

    .PARAMETER WorkingDirectory
        The directory the bridge serves. Defaults to the current location.

    .PARAMETER Name
        The name the bridge shows in claude.ai/code. Defaults to <short host name>-<id>.

    .PARAMETER ClaudePath
        The claude binary the service runs. Defaults to the claude command on PATH, for example
        /opt/homebrew/bin/claude from the Homebrew cask claude-code@latest.

    .PARAMETER SpawnMode
        How the bridge starts sessions: worktree (default, a Git worktree per session), same-dir or session.

    .PARAMETER SearchPath
        The PATH the service and the sessions it starts get. Defaults to the current PATH.

    .PARAMETER EnableLinger
        Linux only. Runs loginctl enable-linger for the current user, so the service runs without a login session.

    .EXAMPLE
        Install-ClaudeRemoteControl -WorkingDirectory ~/code/vh-adlc -Name macbook-vh-adlc

        Installs and starts the bridge for ~/code/vh-adlc, shown as macbook-vh-adlc, with a worktree per session.

    .EXAMPLE
        Install-ClaudeRemoteControl -WorkingDirectory ~/code/vh-adlc -SpawnMode same-dir

        Starts every session in ~/code/vh-adlc itself instead of in a worktree.

    .EXAMPLE
        Install-ClaudeRemoteControl -WorkingDirectory ~/code/vh-adlc -EnableLinger

        On a Linux server, installs the bridge and keeps it running after logout.

    .NOTES
        Supported on macOS and Linux. Requires PowerShell 7.
        Get-ClaudeRemoteControlStatus repeats the checks; Uninstall-ClaudeRemoteControl removes the service.

        Author: Michiel VH
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param (
        [string]$WorkingDirectory = (Get-Location).Path,
        [string]$Name,
        [string]$ClaudePath,
        [ValidateSet('worktree', 'same-dir', 'session')]
        [string]$SpawnMode = 'worktree',
        [string]$SearchPath = $env:PATH,
        [switch]$EnableLinger
    )

    $service = Get-ClaudeRcService -WorkingDirectory $WorkingDirectory
    if (-not (Test-Path -LiteralPath $service.WorkingDirectory -PathType Container)) {
        throw "Working directory not found: $($service.WorkingDirectory)"
    }
    if (-not $ClaudePath) {
        $ClaudePath = Resolve-ClaudeRcBinary
    }
    if (-not $ClaudePath -or -not (Test-Path -LiteralPath $ClaudePath -PathType Leaf)) {
        throw 'Claude Code was not found. Install it (on macOS: brew install --cask claude-code@latest), or pass -ClaudePath.'
    }
    if ($EnableLinger -and $service.Platform -ne 'Linux') {
        Write-Warning '-EnableLinger applies to Linux only; ignoring it.'
    }
    if (-not $Name) {
        $Name = '{0}-{1}' -f [System.Net.Dns]::GetHostName().Split('.')[0].ToLowerInvariant(), $service.Id
    }

    $arguments = @($ClaudePath, 'remote-control', "--spawn=$SpawnMode", '--name', $Name)
    $content = if ($service.Platform -eq 'macOS') {
        ConvertTo-ClaudeRcLaunchAgent -Service $service -Argument $arguments -SearchPath $SearchPath
    }
    else {
        ConvertTo-ClaudeRcSystemdUnit -Service $service -Argument $arguments -SearchPath $SearchPath -BridgeName $Name
    }

    $current = if (Test-Path -LiteralPath $service.ServiceFile -PathType Leaf) { Get-Content -LiteralPath $service.ServiceFile -Raw }
    $changed = $current -cne $content
    if (-not $changed) {
        Write-Host "Service definition unchanged: $($service.ServiceFile)" -ForegroundColor Cyan
    }
    elseif ($PSCmdlet.ShouldProcess($service.ServiceFile, 'Write the Remote Control service definition')) {
        New-Item -ItemType Directory -Path (Split-Path -Path $service.ServiceFile -Parent) -Force | Out-Null
        Set-Content -LiteralPath $service.ServiceFile -Value $content -NoNewline -Encoding utf8NoBOM
        Write-Host "Wrote $($service.ServiceFile)" -ForegroundColor Green
    }

    if ($service.Platform -eq 'macOS') {
        $domain = "gui/$(Get-ClaudeRcUserId)"
        $state = Get-ClaudeRcServiceState -Service $service
        if ($state.Loaded -and $changed -and $PSCmdlet.ShouldProcess("$domain/$($service.Name)", 'Unload the old LaunchAgent')) {
            Invoke-ClaudeRcCommand -FilePath 'launchctl' -ArgumentList 'bootout', "$domain/$($service.Name)" | Out-Null
            # bootout returns before launchd has removed the job, and bootstrap fails until it has.
            for ($attempt = 0; $attempt -lt 20; $attempt++) {
                if ((Invoke-ClaudeRcCommand -FilePath 'launchctl' -ArgumentList 'print', "$domain/$($service.Name)").ExitCode -ne 0) {
                    break
                }
                Start-Sleep -Milliseconds 500
            }
        }
        if ((-not $state.Loaded -or $changed) -and $PSCmdlet.ShouldProcess($domain, "Load $($service.Name)")) {
            New-Item -ItemType Directory -Path (Split-Path -Path $service.Log -Parent) -Force | Out-Null
            $result = Invoke-ClaudeRcCommand -FilePath 'launchctl' -ArgumentList 'bootstrap', $domain, $service.ServiceFile
            if ($result.ExitCode -ne 0) {
                Write-Error "launchctl bootstrap $domain failed: $($result.Output -join ' ')"
            }
            else {
                Write-Host "Loaded $($service.Name) into $domain" -ForegroundColor Green
            }
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess($service.Name, 'Enable and start the systemd --user unit')) {
            if ($changed) {
                Invoke-ClaudeRcCommand -FilePath 'systemctl' -ArgumentList '--user', 'daemon-reload' | Out-Null
            }
            $steps = @(
                , @('--user', 'enable', $service.Name)
                , @('--user', $(if ($changed) { 'restart' } else { 'start' }), $service.Name)
            )
            foreach ($step in $steps) {
                $result = Invoke-ClaudeRcCommand -FilePath 'systemctl' -ArgumentList $step
                if ($result.ExitCode -ne 0) {
                    Write-Error "systemctl $($step -join ' ') failed: $($result.Output -join ' ')"
                }
            }
            Write-Host "Enabled and started $($service.Name)" -ForegroundColor Green
        }
        if ($EnableLinger) {
            $user = Get-ClaudeRcUserName
            if ($PSCmdlet.ShouldProcess($user, 'Enable linger')) {
                $result = Invoke-ClaudeRcCommand -FilePath 'loginctl' -ArgumentList 'enable-linger', $user
                if ($result.ExitCode -ne 0) {
                    Write-Error "loginctl enable-linger $user failed: $($result.Output -join ' ')"
                }
            }
        }
    }

    $status = Get-ClaudeRemoteControlStatus -WorkingDirectory $service.WorkingDirectory -ClaudePath $ClaudePath
    Write-ClaudeRcOwnerStep -Status $status -BridgeName $Name
    $status
}

function ConvertTo-ClaudeRcLaunchAgent {
    param ($Service, [string[]]$Argument, [string]$SearchPath)

    $escape = { param ($Value) [System.Security.SecurityElement]::Escape($Value) }
    $programArguments = ($Argument | ForEach-Object { "    <string>$(& $escape $_)</string>" }) -join "`n"
    $userHome = Get-ClaudeRcHome

    @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$(& $escape $Service.Name)</string>
  <key>ProgramArguments</key>
  <array>
$programArguments
  </array>
  <key>WorkingDirectory</key><string>$(& $escape $Service.WorkingDirectory)</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$(& $escape $SearchPath)</string>
    <key>HOME</key><string>$(& $escape $userHome)</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>60</integer>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$(& $escape $Service.Log)</string>
  <key>StandardErrorPath</key><string>$(& $escape $Service.Log)</string>
</dict>
</plist>

"@ -replace "`r`n", "`n"
}

function ConvertTo-ClaudeRcSystemdUnit {
    param ($Service, [string[]]$Argument, [string]$SearchPath, [string]$BridgeName)

    # systemd expands % specifiers everywhere and $ variables in ExecStart; quoted words also need \ and " escaped.
    $quote = { param ($Value) '"' + ($Value -replace '\\', '\\' -replace '"', '\"' -replace '%', '%%' -replace '\$', '$$$$') + '"' }
    $execStart = ($Argument | ForEach-Object { & $quote $_ }) -join ' '

    @"
[Unit]
Description=Claude Code Remote Control bridge $($BridgeName -replace '%', '%%')
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=$($Service.WorkingDirectory -replace '%', '%%')
Environment=$(& $quote "PATH=$SearchPath")
ExecStart=$execStart
Restart=always
RestartSec=60

[Install]
WantedBy=default.target

"@ -replace "`r`n", "`n"
}

function Write-ClaudeRcOwnerStep {
    param ($Status, [string]$BridgeName)

    $open = @($Status.Checks | Where-Object Status -NE 'Ready')
    Write-Host ''
    Write-Host "Service: $($Status.Service) (loaded: $($Status.Loaded), running: $($Status.Running))"
    Write-Host "Log:     $($Status.Log)"
    if (-not $open) {
        Write-Host "Ready. The bridge appears as '$BridgeName' in claude.ai/code." -ForegroundColor Green
        return
    }

    Write-Host ''
    Write-Host 'Steps left for the owner, in this order:' -ForegroundColor Yellow
    $number = 1
    foreach ($check in $open) {
        Write-Host "  $number. [$($check.Check): $($check.Status)] $($check.Detail)" -ForegroundColor Yellow
        Write-Host "     $($check.Step)"
        $number++
    }
    Write-Host ''
    Write-Host 'The service retries every 60 seconds, so it starts by itself once these are done. Get-ClaudeRemoteControlStatus repeats the checks.'
}
