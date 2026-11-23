function Get-ClaudeRemoteControlStatus {
    <#
    .SYNOPSIS
        Reports the Claude Code Remote Control service for a working directory and what still stops it from starting.

    .DESCRIPTION
        Finds the service that Install-ClaudeRemoteControl writes for the working directory: a LaunchAgent on
        macOS or a systemd --user unit on Linux. Returns whether it is installed, loaded and running, where it
        logs, and one check per known trap:

        - Claude binary: the claude command exists.
        - Nonessential traffic: no Claude settings file sets CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC. Remote
          Control needs feature-flag evaluation, which that setting turns off. Settings env overrides the shell.
        - Login: claude auth status reports a login. Over SSH on macOS the Keychain is out of reach, so the
          answer is Unknown there.
        - Workspace trust: the owner accepted the trust dialog for the directory or a parent.
        - Remote Control consent: the owner answered y to "Enable Remote Control?" once.
        - Terminal bridge: no claude remote-control started at a terminal serves the same directory. While
          one does, the service fails with "This folder is already served by a terminal claude remote-control
          on this device". The one left running after answering the consent prompt is the usual cause.
        - Linger (Linux only): the user's systemd instance keeps running after logout.

        Each check has a Status of Ready, Action, Unknown or Optional, and a Step that says what to do.
        The function only reads. It never records trust or consent.

    .PARAMETER WorkingDirectory
        The directory the bridge serves. The service name is derived from its last path segment.
        Defaults to the current location.

    .PARAMETER ClaudePath
        The claude binary to check. Defaults to the claude command on PATH.

    .EXAMPLE
        Get-ClaudeRemoteControlStatus -WorkingDirectory ~/code/vh-adlc

        Shows the service state for ~/code/vh-adlc.

    .EXAMPLE
        (Get-ClaudeRemoteControlStatus).Checks | Where-Object Status -NE 'Ready'

        Lists what still needs doing for the bridge in the current directory.

    .NOTES
        Supported on macOS and Linux. Requires PowerShell 7.

        Author: Michiel VH
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [string]$WorkingDirectory = (Get-Location).Path,
        [string]$ClaudePath
    )

    $service = Get-ClaudeRcService -WorkingDirectory $WorkingDirectory
    if (-not $ClaudePath) {
        $ClaudePath = Resolve-ClaudeRcBinary
    }
    $state = Get-ClaudeRcServiceState -Service $service

    [pscustomobject]@{
        Platform         = $service.Platform
        WorkingDirectory = $service.WorkingDirectory
        Service          = $service.Name
        ServiceFile      = $service.ServiceFile
        Installed        = Test-Path -LiteralPath $service.ServiceFile -PathType Leaf
        Loaded           = $state.Loaded
        Running          = $state.Running
        ProcessId        = $state.ProcessId
        Log              = $service.Log
        Checks           = @(Get-ClaudeRcCheck -Service $service -ClaudePath $ClaudePath -ServiceProcessId $state.ProcessId)
    }
}

# The helpers below are module-private: the loader exports only the function named after the file.
# Install-ClaudeRemoteControl and Uninstall-ClaudeRemoteControl use them too.

function Get-ClaudeRcPlatform {
    if ($IsMacOS) {
        'macOS'
    }
    elseif ($IsLinux) {
        'Linux'
    }
    else {
        'Windows'
    }
}

function Get-ClaudeRcHome {
    if ($env:HOME) {
        $env:HOME
    }
    else {
        [Environment]::GetFolderPath('UserProfile')
    }
}

function Invoke-ClaudeRcCommand {
    param (
        [string]$FilePath,
        [string[]]$ArgumentList = @()
    )

    try {
        $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { "$_" })
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    }
    catch {
        [pscustomobject]@{ ExitCode = 127; Output = @("$_") }
    }
}

function Resolve-ClaudeRcBinary {
    $command = Get-Command -Name claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) {
        $command.Source
    }
}

function Get-ClaudeRcUserId {
    (Invoke-ClaudeRcCommand -FilePath 'id' -ArgumentList '-u').Output | Select-Object -First 1
}

function Get-ClaudeRcUserName {
    (Invoke-ClaudeRcCommand -FilePath 'id' -ArgumentList '-un').Output | Select-Object -First 1
}

function Get-ClaudeRcService {
    param ([string]$WorkingDirectory)

    $platform = Get-ClaudeRcPlatform
    if ($platform -eq 'Windows') {
        throw 'Claude Remote Control services are supported on macOS (LaunchAgent) and Linux (systemd --user) only.'
    }

    $directory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkingDirectory).TrimEnd('/', '\')
    $id = ((Split-Path -Path $directory -Leaf).ToLowerInvariant() -replace '[^a-z0-9.-]+', '-').Trim('-')
    if (-not $id) {
        throw "Cannot derive a service name from '$WorkingDirectory'."
    }
    $userHome = Get-ClaudeRcHome

    if ($platform -eq 'macOS') {
        $label = "pro.vhco.claude-remote-control.$id"
        [pscustomobject]@{
            Platform         = $platform
            Id               = $id
            WorkingDirectory = $directory
            Name             = $label
            ServiceFile      = Join-Path $userHome "Library/LaunchAgents/$label.plist"
            Log              = Join-Path $userHome "Library/Logs/claude-remote-control-$id.log"
        }
    }
    else {
        $unit = "claude-remote-control-$id.service"
        [pscustomobject]@{
            Platform         = $platform
            Id               = $id
            WorkingDirectory = $directory
            Name             = $unit
            ServiceFile      = Join-Path $userHome ".config/systemd/user/$unit"
            Log              = "journalctl --user -u $unit"
        }
    }
}

function Get-ClaudeRcServiceState {
    param ($Service)

    if ($Service.Platform -eq 'macOS') {
        $result = Invoke-ClaudeRcCommand -FilePath 'launchctl' -ArgumentList 'print', "gui/$(Get-ClaudeRcUserId)/$($Service.Name)"
        $loaded = $result.ExitCode -eq 0
        $processId = $null
        if ($loaded) {
            $match = $result.Output | Select-String -Pattern '^\s*pid = (\d+)' | Select-Object -First 1
            if ($match) {
                $processId = [int]$match.Matches[0].Groups[1].Value
            }
        }
        return [pscustomobject]@{ Loaded = $loaded; Running = $null -ne $processId; ProcessId = $processId }
    }

    $result = Invoke-ClaudeRcCommand -FilePath 'systemctl' -ArgumentList '--user', 'show', $Service.Name, '--property=UnitFileState,ActiveState,MainPID'
    $properties = @{}
    foreach ($line in $result.Output) {
        $key, $value = $line -split '=', 2
        $properties[$key] = $value
    }
    $processId = if ([int]::TryParse("$($properties['MainPID'])", [ref]$null) -and [int]$properties['MainPID'] -gt 0) { [int]$properties['MainPID'] }
    [pscustomobject]@{
        Loaded    = $properties['UnitFileState'] -eq 'enabled'
        Running   = $properties['ActiveState'] -eq 'active'
        ProcessId = $processId
    }
}

function Read-ClaudeRcJson {
    param ([string]$Path)

    # Returns $null for a missing file and throws for one that cannot be parsed.
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
}

function ConvertTo-ClaudeRcCheck {
    param ([string]$Check, [string]$Status, [string]$Detail, [string]$Step)

    [pscustomobject]@{ Check = $Check; Status = $Status; Detail = $Detail; Step = $Step }
}

function Get-ClaudeRcTerminalBridge {
    param ($Service, $ServiceProcessId)

    # Every claude remote-control process whose working directory is the service's, except the service itself.
    $processes = Invoke-ClaudeRcCommand -FilePath 'ps' -ArgumentList '-A', '-o', 'pid=,args='
    foreach ($line in $processes.Output) {
        if ($line -notmatch '^\s*(\d+)\s+(.*)$') {
            continue
        }
        $processId = [int]$Matches[1]
        if ($processId -eq $ServiceProcessId -or $Matches[2] -notmatch '(^|/)claude\s+remote-control(\s|$)') {
            continue
        }
        $cwd = if ($Service.Platform -eq 'macOS') {
            (Invoke-ClaudeRcCommand -FilePath 'lsof' -ArgumentList '-a', '-p', "$processId", '-d', 'cwd', '-Fn').Output |
                Where-Object { $_ -like 'n*' } | Select-Object -First 1 | ForEach-Object { $_.Substring(1) }
        }
        else {
            (Invoke-ClaudeRcCommand -FilePath 'readlink' -ArgumentList "/proc/$processId/cwd").Output | Select-Object -First 1
        }
        if ($cwd -and $cwd.TrimEnd('/', '\') -eq $Service.WorkingDirectory) {
            $processId
        }
    }
}

function Get-ClaudeRcCheck {
    param ($Service, [string]$ClaudePath, $ServiceProcessId)

    $userHome = Get-ClaudeRcHome
    $directory = $Service.WorkingDirectory
    $haveClaude = $ClaudePath -and (Test-Path -LiteralPath $ClaudePath -PathType Leaf)

    if ($haveClaude) {
        ConvertTo-ClaudeRcCheck -Check 'Claude binary' -Status 'Ready' -Detail $ClaudePath -Step ''
    }
    else {
        ConvertTo-ClaudeRcCheck -Check 'Claude binary' -Status 'Action' -Detail 'claude was not found.' -Step 'Install Claude Code (on macOS: brew install --cask claude-code@latest), or pass -ClaudePath.'
    }

    # Nonessential traffic. Every settings file Claude reads for this directory counts.
    $managed = if ($Service.Platform -eq 'macOS') { '/Library/Application Support/ClaudeCode/managed-settings.json' } else { '/etc/claude-code/managed-settings.json' }
    $settingsFiles = @(
        (Join-Path $userHome '.claude/settings.json')
        (Join-Path $directory '.claude/settings.json')
        (Join-Path $directory '.claude/settings.local.json')
        $managed
    )
    $blocking = @()
    $unreadable = @()
    foreach ($file in $settingsFiles) {
        try {
            $settings = Read-ClaudeRcJson -Path $file
        }
        catch {
            $unreadable += $file
            continue
        }
        if ($settings -is [hashtable] -and $settings['env'] -is [hashtable] -and $settings['env']['CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC']) {
            $blocking += $file
        }
    }
    if ($blocking) {
        ConvertTo-ClaudeRcCheck -Check 'Nonessential traffic' -Status 'Action' -Detail "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC is set in $($blocking -join ', ')." -Step "Remove CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC from the env block in $($blocking -join ', '). Remote Control needs feature-flag evaluation, which it turns off. Unsetting it in the shell does not help: settings env overrides the shell."
    }
    elseif ($unreadable) {
        ConvertTo-ClaudeRcCheck -Check 'Nonessential traffic' -Status 'Unknown' -Detail "Could not parse $($unreadable -join ', ')." -Step "Fix the JSON in $($unreadable -join ', ') and check it does not set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC."
    }
    else {
        ConvertTo-ClaudeRcCheck -Check 'Nonessential traffic' -Status 'Ready' -Detail 'No settings file disables nonessential traffic.' -Step ''
    }

    # Login. Only the loggedIn field is read; the rest of the output names the account and is ignored.
    $loggedIn = $null
    if ($haveClaude) {
        $result = Invoke-ClaudeRcCommand -FilePath $ClaudePath -ArgumentList 'auth', 'status', '--json'
        $text = $result.Output -join "`n"
        $start = $text.IndexOf('{')
        if ($start -ge 0) {
            try {
                $loggedIn = ($text.Substring($start) | ConvertFrom-Json).loggedIn
            }
            catch {
                $loggedIn = $null
            }
        }
    }
    $overSsh = $Service.Platform -eq 'macOS' -and ($env:SSH_CONNECTION -or $env:SSH_TTY)
    if ($loggedIn -eq $true) {
        ConvertTo-ClaudeRcCheck -Check 'Login' -Status 'Ready' -Detail 'claude auth status reports a login.' -Step ''
    }
    elseif ($overSsh) {
        ConvertTo-ClaudeRcCheck -Check 'Login' -Status 'Unknown' -Detail 'Over SSH the macOS Keychain is out of reach, so the CLI reports no login even when one exists.' -Step "The LaunchAgent runs in your GUI session and can read the Keychain. Check $($Service.Log), or run claude auth status at the Mac itself."
    }
    elseif ($loggedIn -eq $false) {
        ConvertTo-ClaudeRcCheck -Check 'Login' -Status 'Action' -Detail 'claude auth status reports no login.' -Step 'At a terminal on this machine, run claude and sign in.'
    }
    else {
        ConvertTo-ClaudeRcCheck -Check 'Login' -Status 'Unknown' -Detail 'Could not read claude auth status --json.' -Step 'At a terminal on this machine, run claude auth status and sign in if it asks.'
    }

    # Trust and consent live in the global config. Only the two keys are read.
    $configPath = Join-Path $userHome '.claude.json'
    $configReadable = $true
    try {
        $config = Read-ClaudeRcJson -Path $configPath
    }
    catch {
        $config = $null
        $configReadable = $false
    }
    $projects = if ($config -is [hashtable] -and $config['projects'] -is [hashtable]) { $config['projects'] }

    $trustedAt = $null
    $path = $directory
    while ($path -and $projects) {
        $entry = $projects[$path]
        if ($entry -is [hashtable] -and $entry['hasTrustDialogAccepted'] -eq $true) {
            $trustedAt = $path
            break
        }
        $parent = Split-Path -Path $path -Parent
        if ($parent -eq $path) {
            break
        }
        $path = $parent
    }
    $trustStep = "At a terminal, run claude in $directory and accept the workspace trust dialog. Trust is your decision; PDS never records it for you."
    if ($trustedAt) {
        ConvertTo-ClaudeRcCheck -Check 'Workspace trust' -Status 'Ready' -Detail "Trust accepted for $trustedAt." -Step ''
    }
    elseif (-not $configReadable) {
        ConvertTo-ClaudeRcCheck -Check 'Workspace trust' -Status 'Unknown' -Detail "Could not parse $configPath." -Step $trustStep
    }
    else {
        ConvertTo-ClaudeRcCheck -Check 'Workspace trust' -Status 'Action' -Detail "No trust recorded for $directory." -Step $trustStep
    }

    $consentStep = "At a terminal in $directory, run claude remote-control once and answer y to 'Enable Remote Control?'. Then stop that terminal bridge with Ctrl+C: while it runs, the service cannot serve the folder. A background service cannot answer the prompt itself."
    if ($config -is [hashtable] -and $config['remoteDialogSeen'] -eq $true) {
        ConvertTo-ClaudeRcCheck -Check 'Remote Control consent' -Status 'Ready' -Detail 'Remote Control was enabled once on this machine.' -Step ''
    }
    elseif (-not $configReadable) {
        ConvertTo-ClaudeRcCheck -Check 'Remote Control consent' -Status 'Unknown' -Detail "Could not parse $configPath." -Step $consentStep
    }
    else {
        ConvertTo-ClaudeRcCheck -Check 'Remote Control consent' -Status 'Action' -Detail 'Remote Control was never enabled on this machine.' -Step $consentStep
    }

    $terminal = @(Get-ClaudeRcTerminalBridge -Service $Service -ServiceProcessId $ServiceProcessId)
    if ($terminal) {
        ConvertTo-ClaudeRcCheck -Check 'Terminal bridge' -Status 'Action' -Detail "A terminal claude remote-control (PID $($terminal -join ', ')) already serves $directory, so the service cannot start: 'This folder is already served by a terminal claude remote-control on this device'." -Step "Stop the terminal bridge with Ctrl+C in its terminal, or kill $($terminal -join ' '). The service takes over within a minute."
    }
    else {
        ConvertTo-ClaudeRcCheck -Check 'Terminal bridge' -Status 'Ready' -Detail "No terminal claude remote-control serves $directory." -Step ''
    }

    if ($Service.Platform -eq 'Linux') {
        $user = Get-ClaudeRcUserName
        $linger = (Invoke-ClaudeRcCommand -FilePath 'loginctl' -ArgumentList 'show-user', $user, '--property=Linger', '--value').Output | Select-Object -First 1
        if ($linger -eq 'yes') {
            ConvertTo-ClaudeRcCheck -Check 'Linger' -Status 'Ready' -Detail "Linger is enabled for $user." -Step ''
        }
        else {
            ConvertTo-ClaudeRcCheck -Check 'Linger' -Status 'Optional' -Detail "Linger is off for $user, so the bridge stops when the last login session ends." -Step 'On a server, run Install-ClaudeRemoteControl again with -EnableLinger. A workstation you stay logged in to does not need it.'
        }
    }
}
