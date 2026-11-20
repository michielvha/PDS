BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Enable-BGInfoAtStartup' {
    BeforeEach {
        # A stand-in for the WScript.Shell COM object, so no shortcut is written.
        $shortcut = [pscustomobject]@{
            TargetPath = $null
            Arguments  = $null
            Saved      = $false
        }
        $shortcut | Add-Member -MemberType ScriptMethod -Name Save -Value { $this.Saved = $true }
        $script:fakeShell = [pscustomobject]@{
            ShortcutPath = $null
            Shortcut     = $shortcut
        }
        $script:fakeShell | Add-Member -MemberType ScriptMethod -Name CreateShortcut -Value {
            $this.ShortcutPath = $args[0]
            $this.Shortcut
        }
        $shell = $script:fakeShell
        Mock New-Object -ModuleName PDS -ParameterFilter { $ComObject -eq 'WScript.Shell' } -MockWith ({ $shell }.GetNewClosure())
    }

    It 'creates a BGInfo shortcut in the startup folder' {
        Enable-BGInfoAtStartup

        Should -Invoke New-Object -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $ComObject -eq 'WScript.Shell' }
        $expected = Join-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" 'BGInfo.lnk'
        $script:fakeShell.ShortcutPath | Should -Be $expected
        $script:fakeShell.Shortcut.Saved | Should -BeTrue
    }

    It 'points the shortcut at Bginfo64 with the module bgi file and no timer' {
        Enable-BGInfoAtStartup

        $script:fakeShell.Shortcut.TargetPath | Should -Be 'C:\ProgramData\chocolatey\lib\bginfo\tools\Bginfo64.exe'
        $script:fakeShell.Shortcut.Arguments | Should -BeLike '"*default.bgi" /timer:0'
    }
}
