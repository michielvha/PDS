# Open PowerShell function defects

Conventions: `vhco-pro/docs@0e52f51f01b84eda75a976763c42d8ec0a07b544`; prose edited with `guides/humanize-prose.md`.

Writing a Pester test for every public function, and running each changed function on a Windows 11 VM, exposed defects that the PowerShell CI work did not fix. That work fixed only what blocked its checks or its VM runs (listed in `changelog.md` under Unreleased). The rest are recorded here so they are not lost. Each row was observed in a test or a VM run on PDS commit `2ef7345`; none has a test that pins the defect, so fixing one means changing the behaviour and its test together.

## Ends the caller's session

| Function | Defect |
| --- | --- |
| `Install-ShellCustomization`, `Set-PSReadLineModuleStarship`, `Get-WinDefExcludedPath` | Without admin rights they sleep, then call `exit`, which closes the caller's whole PowerShell session instead of returning an error. |
| `Show-AksInfo` | Calls `exit 1` when the Azure CLI is missing. |

## Wrong result or no effect

| Function | Defect |
| --- | --- |
| `Get-ListeningPort` | `$tcp + $udp` throws `op_Addition` when exactly one TCP port is listening. |
| `Get-WlanPass` | Splits each line on `:` and keeps the last part, so a password or SSID containing `:` is cut short. |
| `Enable-BGInfoAtStartup` | Builds the `.bgi` path under `Public/System/assets`; the file ships at `Public/Assets/default.bgi`. |
| `Set-LangReg` | Its comments say English (US), but it sets the system locale and language list to `nl-BE`. |
| `Update-ADDomainName` | Step 3 queries by the old UPN after step 2 changed it, so no user gets the new primary SMTP address. A `return` in `begin` does not stop `process` when the AD module is missing. |
| `Start-RemoteADSyncCycle` | Builds the server list in `begin`, so pipeline input for `-ComputerName` is ignored; a `return` in `begin` does not stop `process`. |
| `Install-ArgoCLI` | `argocd version --client \| Out-Null` is always empty, so it downloads again on every run. |
| `Push-Code` | Reports success whatever `git push` returns. |
| `Install-WSL` | The `try`/`catch` around `wsl --install` never sees a failure, because a native command does not throw. |
| `Set-DefaultAwsProfile` | Its `catch` calls `Write-Output -ForegroundColor`, which fails with a parameter error of its own. |
| `Set-DockerAlias` | Checks for `function d`, which also matches `dcu` and `dcd`; the aliases do not pass arguments through, so `d ps` runs plain `docker`. |
| `Install-OhMyPosh` | Tests `$PROFILE` but writes `$PROFILE.AllUsersAllHosts`; with Oh My Posh 33 no themes path is set, so its theme edits are skipped and the profile points at a missing theme. |
| `Update-GitRepository` | Finds only `.git` folders marked hidden. |
| `Remove-StaleADComputer` | Logs the "would be removed" line when `-Confirm` is answered No. |

## Repeats on every run

| Function | Defect |
| --- | --- |
| `Set-PSReadLineModule`, `Set-PSReadLineModuleStarship`, `Set-Kubectl`, `Install-OhMyPosh` | Append their profile block again on each run; `Set-PSReadLineModuleStarship` also reinstalls PSReadLine. |
| `Add-ToPath` | Adds the entry to the session's `$env:Path` even when it is already there. |
| `Update-Env` | Copies the `PSPath`, `PSParentPath`, `PSChildName`, `PSDrive` and `PSProvider` properties into environment variables and never removes a variable deleted from the registry. |

## Robustness and output

| Function | Defect |
| --- | --- |
| `Set-Log` | Its `catch` calls `Set-Log` again, so a persistent write failure recurses until the call depth overflows. |
| `Get-CurlStatus` | Throws when `$env:Path` has an empty entry, such as a trailing `;`. |
| `Clear-RedundantPSReadLineHistory` | The `return` in `begin` does not skip `process`; `-Force` overrides `-WhatIf`; its help examples name `Clear-PSReadLineHistory`. |
| `Get-DisabledADUser`, `Get-ListeningPort`, `Get-WlanPass`, `Get-LogonActivity` | Return `Format-Table` output, so the result cannot be piped or exported. |
| `Set-StarshipConfigForEveryUser`, `New-AwsProfile`, `New-AwsSession`, `Install-ArgoCLI` | Leak `New-Item` or `Write-Output` objects into their output. |
| `Enable-Sudo`, `Set-WindowsTerminalFont`, `Install-OhMyPosh` | Are not advanced functions, so they reject common parameters such as `-ErrorAction`. |
| `Start-ISEAsAdmin` | Prompts interactively when `-FilePath` does not exist; returns no process object although its help says it does. |
| `New-Branch` | Changes the session's location to the repository and does not restore it. |
| `Set-SshdConfigOption` (in `Enable-SshServer`) | Treats a `Match` block on the first line as no `Match` block. |
| `Export-ComputerInfo` | Passes the obsolete `-NoTypeInformation`, which warns on PowerShell 7. |
