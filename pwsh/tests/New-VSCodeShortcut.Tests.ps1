BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'New-VSCodeShortcut' {
    BeforeEach {
        $script:file = (New-Item -Path 'TestDrive:\app.js' -ItemType File -Force).FullName
        $script:desktop = [Environment]::GetFolderPath('Desktop')

        # A stand-in for the WScript.Shell COM object, so no shortcut is written.
        $shortcut = [pscustomobject]@{
            TargetPath   = $null
            Arguments    = $null
            IconLocation = $null
            Description  = $null
            Saved        = $false
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
        # The parameter validation also calls Test-Path, so other paths go to the real cmdlet.
        Mock Test-Path -ModuleName PDS -MockWith { Microsoft.PowerShell.Management\Test-Path @PesterBoundParameters }
        Mock Test-Path -ModuleName PDS -ParameterFilter { "$Path" -like '*Code.exe' } -MockWith { $false }
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'code' }
    }

    It 'creates a desktop shortcut that opens the file in VS Code' {
        Mock Test-Path -ModuleName PDS -ParameterFilter {
            "$Path" -eq 'C:\Program Files\Microsoft VS Code\Code.exe'
        } -MockWith { $true }

        $result = New-VSCodeShortcut -FilePath $script:file

        $expectedPath = Join-Path $script:desktop 'app.js - VS Code.lnk'
        $result | Should -Be "VS Code shortcut created at: $expectedPath"
        $script:fakeShell.ShortcutPath | Should -Be $expectedPath
        $shortcut = $script:fakeShell.Shortcut
        $shortcut.TargetPath | Should -Be 'C:\Program Files\Microsoft VS Code\Code.exe'
        $shortcut.IconLocation | Should -Be 'C:\Program Files\Microsoft VS Code\Code.exe'
        $shortcut.Arguments | Should -Be "`"$script:file`""
        $shortcut.Description | Should -Be 'Open app.js in Visual Studio Code'
        $shortcut.Saved | Should -BeTrue
    }

    It 'falls back to the per-user VS Code install' {
        $userInstall = "$env:LocalAppData\Programs\Microsoft VS Code\Code.exe"
        Mock Test-Path -ModuleName PDS -ParameterFilter { "$Path" -eq $userInstall } -MockWith { $true }

        $null = New-VSCodeShortcut -FilePath $script:file

        $script:fakeShell.Shortcut.TargetPath | Should -Be $userInstall
    }

    It 'falls back to the code command when no install folder is found' {
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'code' } -MockWith {
            [pscustomobject]@{ Source = 'C:\tools\code.cmd' }
        }

        $null = New-VSCodeShortcut -FilePath $script:file

        $script:fakeShell.Shortcut.TargetPath | Should -Be 'C:\tools\code.cmd'
        Should -Invoke Get-Command -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Name -eq 'code' }
    }

    It 'rejects a file that does not exist' {
        { New-VSCodeShortcut -FilePath 'TestDrive:\missing.js' } | Should -Throw
        Should -Invoke New-Object -ModuleName PDS -Times 0 -Exactly
    }
}
