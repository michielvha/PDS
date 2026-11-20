BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The function reads the history file under $env:APPDATA, so point it at TestDrive.
    $script:originalAppData = $env:APPDATA
    $env:APPDATA = $TestDrive
    $script:historyDir = Join-Path $TestDrive 'Microsoft' 'Windows' 'PowerShell' 'PSReadLine'
    $script:historyFile = Join-Path $script:historyDir 'ConsoleHost_history.txt'
}

AfterAll {
    $env:APPDATA = $script:originalAppData
}

Describe 'Clear-RedundantPSReadLineHistory' {
    BeforeEach {
        if (Test-Path -Path $script:historyDir) {
            Remove-Item -Path $script:historyDir -Recurse -Force
        }
        New-Item -Path $script:historyDir -ItemType Directory -Force | Out-Null
        Set-Content -Path $script:historyFile -Value @('git status', 'ls', 'git status', 'cd ..', 'ls') -Encoding UTF8
    }

    It 'removes duplicate lines and keeps the first occurrence order' {
        $output = Clear-RedundantPSReadLineHistory -Force

        Get-Content -Path $script:historyFile | Should -Be @('git status', 'ls', 'cd ..')
        $output | Should -Be 'Successfully removed 2 duplicate entries from history file.'
    }

    It 'creates a backup of the original file when -BackupFile is given' {
        Clear-RedundantPSReadLineHistory -BackupFile -Force | Out-Null

        $backup = Get-ChildItem -Path $script:historyDir -Filter 'ConsoleHost_history.txt.backup_*'
        $backup | Should -HaveCount 1
        Get-Content -Path $backup.FullName | Should -HaveCount 5
    }

    It 'makes no change under -WhatIf' {
        $output = Clear-RedundantPSReadLineHistory -WhatIf

        Get-Content -Path $script:historyFile | Should -HaveCount 5
        $output | Should -Be 'Operation cancelled. No changes made to history file.'
    }

    It 'reports an error and writes nothing when the history file is missing' {
        Remove-Item -Path $script:historyFile -Force
        Mock -ModuleName PDS Set-Content { }

        Clear-RedundantPSReadLineHistory -Force -ErrorAction SilentlyContinue -ErrorVariable errors

        ($errors | Select-Object -First 1).ToString() | Should -BeLike 'History file not found at:*'
        Should -Invoke -ModuleName PDS Set-Content -Times 0 -Exactly
    }
}
