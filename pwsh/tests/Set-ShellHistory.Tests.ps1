BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    $script:originalAppData = $env:APPDATA
    $env:APPDATA = $TestDrive

    # notepad.exe exists on Windows, but a stub keeps the mock possible on any host.
    InModuleScope PDS { function script:notepad.exe { } }
}

AfterAll {
    $env:APPDATA = $script:originalAppData
}

Describe 'Set-ShellHistory' {
    It 'opens the PSReadLine history file in notepad' {
        Mock -ModuleName PDS notepad.exe { }

        Set-ShellHistory

        $expected = "$TestDrive\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
        Should -Invoke -ModuleName PDS notepad.exe -Times 1 -Exactly -ParameterFilter { $args[0] -eq $expected }
    }

    It 'changes nothing under -WhatIf' {
        Mock -ModuleName PDS notepad.exe { }

        Set-ShellHistory -WhatIf

        Should -Invoke -ModuleName PDS notepad.exe -Times 0 -Exactly
    }
}
