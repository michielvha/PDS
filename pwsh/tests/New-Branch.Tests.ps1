BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # git may be absent on the test machine and must never run for real; a module-scope
    # stub lets Pester mock it.
    InModuleScope PDS { function script:git { } }
}

Describe 'New-Branch' {
    BeforeEach {
        # The function changes the session location; keep the test session where it is.
        Mock Set-Location -ModuleName PDS { }
        Mock git -ModuleName PDS {
            switch ($args[0]) {
                'status' { '' }
                'branch' { '* main', '  dev-0', '  dev-1' }
            }
        }
    }

    It 'updates main and checks out the first free numbered branch' {
        New-Branch -RepoPath $TestDrive 6>$null

        Should -Invoke Set-Location -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Path -eq $TestDrive }
        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'checkout main' }
        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'pull origin main' }
        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'checkout -b dev-2' }
    }

    It 'uses a custom branch prefix' {
        New-Branch -RepoPath $TestDrive -BranchPrefix 'feature-' 6>$null

        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'checkout -b feature-0' }
    }

    It 'stops without switching branches when the repository has uncommitted changes' {
        Mock git -ModuleName PDS {
            if ($args[0] -eq 'status') {
                ' M README.md'
            }
        }

        $messages = New-Branch -RepoPath $TestDrive 6>&1 | ForEach-Object { "$_" }

        $messages | Should -Contain 'The repository has uncommitted changes. Commit or stash them before proceeding.'
        Should -Invoke git -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $args[0] -in 'checkout', 'pull' }
    }

    It 'does nothing when the repository path does not exist' {
        $missing = Join-Path $TestDrive 'missing-repo'

        $messages = New-Branch -RepoPath $missing 6>&1 | ForEach-Object { "$_" }

        $messages | Should -Contain "The specified repository path does not exist: $missing"
        Should -Invoke Set-Location -ModuleName PDS -Times 0 -Exactly
        Should -Invoke git -ModuleName PDS -Times 0 -Exactly
    }
}
