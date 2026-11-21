BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Start-ScrollLockToggle' {
    BeforeEach {
        $script:sentKeys = [System.Collections.Generic.List[string]]::new()
        $keys = $script:sentKeys
        $shell = [pscustomobject]@{ }
        $shell | Add-Member -MemberType ScriptMethod -Name sendkeys -Value { param($Key) $keys.Add($Key) }.GetNewClosure()
        $script:shell = $shell

        Mock -ModuleName PDS Write-Host { }
        # A fake WScript.Shell, so no key is pressed.
        Mock -ModuleName PDS New-Object { $script:shell }
        # The toggle loops forever; the mocked interval sleep ends it after one round.
        Mock -ModuleName PDS Start-Sleep {
            if ($Seconds -gt 0) {
                throw 'stop toggling'
            }
        }
    }

    It 'presses ScrollLock twice per round with the given duration and interval' {
        Start-ScrollLockToggle -Interval 60 -ToggleDuration 100

        $script:sentKeys | Should -Be @('{SCROLLLOCK}', '{SCROLLLOCK}')
        Should -Invoke -ModuleName PDS New-Object -Times 1 -Exactly -ParameterFilter { $ComObject -eq 'Wscript.Shell' }
        Should -Invoke -ModuleName PDS Start-Sleep -Times 1 -Exactly -ParameterFilter { $Milliseconds -eq 100 }
        Should -Invoke -ModuleName PDS Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 60 }
    }

    It 'uses a 350 second interval and a 200 millisecond toggle by default' {
        Start-ScrollLockToggle

        Should -Invoke -ModuleName PDS Start-Sleep -Times 1 -Exactly -ParameterFilter { $Milliseconds -eq 200 }
        Should -Invoke -ModuleName PDS Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 350 }
    }

    It 'reports that it stopped when the loop is interrupted' {
        Start-ScrollLockToggle -Interval 1

        Should -Invoke -ModuleName PDS Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like 'ScrollLock toggle interrupted:*stop toggling*' }
        Should -Invoke -ModuleName PDS Write-Host -Times 1 -Exactly -ParameterFilter { $Object -eq 'ScrollLock toggle stopped.' }
    }

    It 'changes nothing under -WhatIf' {
        Start-ScrollLockToggle -WhatIf

        $script:sentKeys | Should -BeNullOrEmpty
        Should -Invoke -ModuleName PDS New-Object -Times 0 -Exactly
        Should -Invoke -ModuleName PDS Start-Sleep -Times 0 -Exactly
    }
}
