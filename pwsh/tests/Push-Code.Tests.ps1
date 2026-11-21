BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # git may be absent on the test machine and must never run for real; a module-scope
    # stub lets Pester mock it.
    InModuleScope PDS { function script:git { } }
}

Describe 'Push-Code' {
    BeforeEach {
        Mock git -ModuleName PDS { }
    }

    It 'stages, commits and pushes to main with the default message' {
        $messages = Push-Code 6>&1 | ForEach-Object { "$_" }

        Should -Invoke git -ModuleName PDS -Times 3 -Exactly
        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'add .' }
        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $args[0] -eq 'commit' -and $args[1] -eq '-m' -and $args[2] -eq 'Update: Code changes'
        }
        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'push -u origin main' }
        $messages | Should -Contain "Successfully pushed changes to 'main' branch."
    }

    It 'uses the given message and branch' {
        Push-Code -m 'fix: correct the typo' -b 'feature/typo' 6>$null

        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $args[0] -eq 'commit' -and $args[2] -eq 'fix: correct the typo'
        }
        Should -Invoke git -ModuleName PDS -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'push -u origin feature/typo' }
    }
}
