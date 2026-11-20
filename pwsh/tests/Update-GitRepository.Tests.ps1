BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # git may be absent on the test machine and must never run for real; a module-scope
    # stub lets Pester mock it.
    InModuleScope PDS { function script:git { } }
}

Describe 'Update-GitRepository' {
    BeforeEach {
        # Two repositories and one plain folder under a fresh root. Windows marks .git hidden,
        # and the function only looks for hidden .git folders, so mark them the same way.
        $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        foreach ($repo in 'repo-a', 'repo-b') {
            $gitDir = New-Item -ItemType Directory -Path (Join-Path $script:root $repo '.git')
            $gitDir.Attributes = $gitDir.Attributes -bor [System.IO.FileAttributes]::Hidden
        }
        $null = New-Item -ItemType Directory -Path (Join-Path $script:root 'not-a-repo')

        # The function moves the session location; keep the test session where it is.
        Mock Set-Location -ModuleName PDS { }
        Mock Write-Progress -ModuleName PDS { }
        Mock git -ModuleName PDS {
            Set-Variable -Name LASTEXITCODE -Value 0 -Scope Global
            'Already up to date.'
        }
    }

    AfterEach {
        Set-Variable -Name LASTEXITCODE -Value 0 -Scope Global
    }

    It 'pulls every repository one level below the root' {
        $messages = Update-GitRepository -RootDirectory $script:root 6>&1 | ForEach-Object { "$_" }

        $messages | Should -Contain 'Found 2 Git repositories to update.'
        $messages | Should -Contain '  Status: Already up to date'
        Should -Invoke git -ModuleName PDS -Times 2 -Exactly -ParameterFilter { ($args -join ' ') -eq 'pull' }
        Should -Invoke Set-Location -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Path -like '*\repo-a' }
        Should -Invoke Set-Location -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Path -like '*\repo-b' }
        Should -Invoke Set-Location -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Path -like '*\not-a-repo' }
    }

    It 'returns to the original location afterwards' {
        $here = (Get-Location).Path

        Update-GitRepository -RootDirectory $script:root 6>$null

        Should -Invoke Set-Location -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Path -eq $here }
    }

    It 'reports a failed pull' {
        Mock git -ModuleName PDS {
            Set-Variable LASTEXITCODE -Value 1 -Scope Global
            'fatal: unable to access the remote'
        }

        $messages = Update-GitRepository -RootDirectory $script:root 6>&1 | ForEach-Object { "$_" }

        @($messages | Where-Object { $_ -eq 'Failed: fatal: unable to access the remote' }).Count | Should -Be 2
    }

    It 'writes an error and pulls nothing when the root does not exist' {
        Update-GitRepository -RootDirectory (Join-Path $TestDrive 'missing') -ErrorAction SilentlyContinue -ErrorVariable updateError 6>$null

        $updateError[0].Exception.Message | Should -BeLike "The specified root directory '*missing' does not exist."
        Should -Invoke git -ModuleName PDS -Times 0 -Exactly
    }

    It 'still runs under its old name' {
        $command = Get-Command 'Update-GitRepositories' -Module PDS
        $command.CommandType | Should -Be 'Alias'
        $command.ResolvedCommandName | Should -Be 'Update-GitRepository'

        & $command -RootDirectory $script:root 6>$null

        Should -Invoke git -ModuleName PDS -Times 2 -Exactly -ParameterFilter { ($args -join ' ') -eq 'pull' }
    }
}
