<#
.SYNOPSIS
    Prints which public PDS functions must run for real on a Windows VM before a merge.

.DESCRIPTION
    Stubbed Pester tests miss real Windows behaviour, so a change to a function's code is proved
    on a disposable Windows 11 VM as well. The VM set is Enable-SshServer plus every public
    function whose file changed between the merge base and HEAD by more than whitespace, a
    byte-order mark or identifier casing. A renamed file is compared with its old path.

    A function in that set stays on its mocked tests when it needs a domain, a remote server,
    a cloud account or a cluster, or never terminates. A remote server is one the function
    manages or queries that a standalone, internet-connected Windows 11 VM lacks; downloading
    software does not count. Each mocked-only entry names its reason and the file:line of the
    dependency or the loop, so every reason can be checked.

    A function that does not run on Windows, such as the Claude Remote Control functions for macOS
    and Linux, is listed under other platforms with the platforms it runs on, and is proved there.

.PARAMETER Base
    The ref to compare with; the script uses its merge base with HEAD.

.EXAMPLE
    pwsh -File scripts/vm-set.ps1 -Base origin/main
#>
[CmdletBinding()]
param (
    [string]$Base = 'origin/main'
)

$ErrorActionPreference = 'Stop'

# Functions that cannot run on a standalone VM, with the reason and a pattern for the line
# that shows it. Help blocks are skipped when the line is searched.
$mockedOnly = [ordered]@{
    'Export-ComputerInfo'                     = @('needs a domain', 'Get-ADComputer')
    'Get-DisabledADUser'                      = @('needs a domain', 'Import-Module -Name ActiveDirectory')
    'Remove-DisabledUsersFromMailAddressList' = @('needs a domain', 'Get-ADUser')
    'Remove-StaleADComputer'                  = @('needs a domain', 'Import-Module ActiveDirectory')
    'Set-ProxyAddress'                        = @('needs a domain', 'Get-ADUser')
    'Update-ADDomainName'                     = @('needs a domain', 'Get-ADUser')
    'Start-RemoteADSyncCycle'                 = @('needs a remote server: an Azure AD Connect server', 'Invoke-Command -ComputerName')
    'Enable-RDSHost'                          = @('needs a remote server: RDS session hosts', 'Import-Module RemoteDesktop')
    'Get-RDSActiveSessionReport'              = @('needs a remote server: an RDS deployment', 'Import-Module RemoteDesktop')
    'Get-RDSActiveSession'                    = @('needs a remote server: an RDS deployment', 'Get-RDUserSession')
    'New-AzSession'                           = @('needs a cloud account: an Azure tenant', '^\s*Connect-AzAccount')
    'Show-AksInfo'                            = @('needs a cloud account: an Azure subscription with AKS', 'az aks list')
    'Get-AzureDevOpsLibrary'                  = @('needs a cloud account: an Azure DevOps organization', 'https://dev\.azure\.com')
    'Start-TaintWatcher'                      = @('needs a cluster and never terminates', 'while \(\$true\)')
    'Start-ScrollLockToggle'                  = @('never terminates', 'while \(\$true\)')
}

# Functions that do not run on Windows. A Windows VM proves nothing for them; each changed one
# runs for real on the platforms named here instead.
$otherPlatform = [ordered]@{
    'Get-ClaudeRemoteControlStatus' = 'macOS and Linux'
    'Install-ClaudeRemoteControl'   = 'macOS and Linux'
    'Uninstall-ClaudeRemoteControl' = 'macOS and Linux'
}

function Get-NormalizedToken {
    param ([string]$Text)
    # Whitespace, a byte-order mark and identifier casing do not count as a change, so the
    # code is compared token by token: lowercased, without line breaks, and with whitespace
    # inside comments collapsed. Moving a brace to the next line changes nothing; changing a
    # string's content does.
    $tokens = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($Text.TrimStart([char]0xFEFF), [ref]$tokens, [ref]$null)
    @($tokens |
            Where-Object { $_.Kind -notin 'NewLine', 'LineContinuation', 'EndOfInput' } |
            ForEach-Object {
                $value = $_.Text.ToLowerInvariant()
                if ($_.Kind -eq 'Comment') { $value = ($value -replace '\s+', ' ').Trim() }
                $value
            })
}

function Get-DependencyLine {
    param ([string[]]$Line, [string]$Pattern)
    $helpEnd = [array]::FindIndex($Line, [Predicate[string]] { param ($l) $l.Trim() -eq '#>' })
    for ($i = $helpEnd + 1; $i -lt $Line.Count; $i++) {
        if ($Line[$i] -match $Pattern -and $Line[$i].Trim() -notlike '#*') {
            return $i + 1
        }
    }
    throw "no line matches '$Pattern'"
}

$mergeBase = git merge-base $Base HEAD
if ($LASTEXITCODE -ne 0) { throw "git merge-base $Base HEAD failed" }

$oldPath = @{}
git diff --name-status -M50% --diff-filter=R $mergeBase HEAD -- pwsh/module/Public | ForEach-Object {
    $status, $from, $to = $_ -split "`t"
    $oldPath[$to] = $from
}

$vmSet = [System.Collections.Generic.List[object]]::new()
$mocked = [System.Collections.Generic.List[object]]::new()
$elsewhere = [System.Collections.Generic.List[object]]::new()
$files = git ls-tree -r --name-only HEAD -- pwsh/module/Public | Where-Object { $_ -like '*.ps1' -and $_ -notlike '*.Tests.ps1' }
foreach ($file in $files) {
    $name = [IO.Path]::GetFileNameWithoutExtension($file)
    $newText = (git show "HEAD:$file") -join "`n"
    $before = if ($oldPath.ContainsKey($file)) { $oldPath[$file] } else { $file }
    $oldText = (git show "${mergeBase}:$before" 2>$null) -join "`n"
    $isNew = $LASTEXITCODE -ne 0
    $changed = $isNew -or (Compare-Object (Get-NormalizedToken $oldText) (Get-NormalizedToken $newText) -SyncWindow 0)
    if (-not $changed -and $name -ne 'Enable-SshServer') { continue }

    if ($otherPlatform.Contains($name)) {
        $elsewhere.Add([pscustomobject]@{ Function = $name; Platform = $otherPlatform[$name]; File = $file })
    }
    elseif ($mockedOnly.Contains($name)) {
        $reason, $pattern = $mockedOnly[$name]
        $line = Get-DependencyLine -Line ($newText -split "`n") -Pattern $pattern
        $mocked.Add([pscustomobject]@{ Function = $name; Reason = $reason; Where = "${file}:$line" })
    }
    else {
        $vmSet.Add([pscustomobject]@{ Function = $name; File = $file })
    }
}

Write-Output "Merge base: $mergeBase"
Write-Output "VM set ($($vmSet.Count)): run each for real on the Windows 11 VM"
$vmSet | Sort-Object Function | ForEach-Object { Write-Output "  $($_.Function)  $($_.File)" }
Write-Output "Mocked-only ($($mocked.Count)): Pester tests only"
$mocked | Sort-Object Function | ForEach-Object { Write-Output "  $($_.Function)  $($_.Reason)  $($_.Where)" }
Write-Output "Other platforms ($($elsewhere.Count)): run each for real on the platforms named, not on Windows"
$elsewhere | Sort-Object Function | ForEach-Object { Write-Output "  $($_.Function)  $($_.Platform)  $($_.File)" }
