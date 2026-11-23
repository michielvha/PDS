function Uninstall-ClaudeRemoteControl {
    <#
    .SYNOPSIS
        Stops and removes the Claude Code Remote Control service that Install-ClaudeRemoteControl created.

    .DESCRIPTION
        On macOS, unloads the LaunchAgent from the gui/<uid> domain and deletes its plist. On Linux, disables
        and stops the systemd --user unit, deletes it and reloads systemd.

        It leaves the log file, linger, workspace trust, Remote Control consent and the Claude login as they
        are: other services and sessions may rely on them.

    .PARAMETER WorkingDirectory
        The directory the bridge serves, as given to Install-ClaudeRemoteControl. Defaults to the current location.

    .EXAMPLE
        Uninstall-ClaudeRemoteControl -WorkingDirectory ~/code/vh-adlc

        Removes the bridge service for ~/code/vh-adlc.

    .NOTES
        Supported on macOS and Linux. Requires PowerShell 7.

        Author: Michiel VH
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$WorkingDirectory = (Get-Location).Path
    )

    $service = Get-ClaudeRcService -WorkingDirectory $WorkingDirectory
    $state = Get-ClaudeRcServiceState -Service $service
    $installed = Test-Path -LiteralPath $service.ServiceFile -PathType Leaf

    if (-not $installed -and -not $state.Loaded -and -not $state.Running) {
        Write-Host "No Remote Control service is installed for $($service.WorkingDirectory)." -ForegroundColor Cyan
        return
    }

    if ($service.Platform -eq 'macOS') {
        $target = "gui/$(Get-ClaudeRcUserId)/$($service.Name)"
        if ($state.Loaded -and $PSCmdlet.ShouldProcess($target, 'Unload the LaunchAgent')) {
            $result = Invoke-ClaudeRcCommand -FilePath 'launchctl' -ArgumentList 'bootout', $target
            if ($result.ExitCode -ne 0) {
                Write-Error "launchctl bootout $target failed: $($result.Output -join ' ')"
            }
        }
    }
    elseif (($state.Loaded -or $state.Running) -and $PSCmdlet.ShouldProcess($service.Name, 'Disable and stop the systemd --user unit')) {
        $result = Invoke-ClaudeRcCommand -FilePath 'systemctl' -ArgumentList '--user', 'disable', '--now', $service.Name
        if ($result.ExitCode -ne 0) {
            Write-Error "systemctl --user disable --now $($service.Name) failed: $($result.Output -join ' ')"
        }
    }

    if ($installed -and $PSCmdlet.ShouldProcess($service.ServiceFile, 'Delete the service definition')) {
        Remove-Item -LiteralPath $service.ServiceFile -Force
        if ($service.Platform -eq 'Linux') {
            Invoke-ClaudeRcCommand -FilePath 'systemctl' -ArgumentList '--user', 'daemon-reload' | Out-Null
        }
        Write-Host "Removed $($service.ServiceFile)" -ForegroundColor Green
    }
    Write-Host "Kept the log ($($service.Log)), linger, workspace trust, Remote Control consent and the Claude login."
}
