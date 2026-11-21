BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Add-ToPath persists a new entry with [Environment]::SetEnvironmentVariable, which cannot be
    # mocked. These tests only pass entries that are already present, so the persisting branch
    # never runs and the user and machine PATH stay unchanged.
    function Get-ExistingPathEntry {
        param ([string]$Scope)
        $value = [System.Environment]::GetEnvironmentVariable('Path', $Scope)
        @($value -split ';' | Where-Object { $_ -and $_ -notmatch '\\$' }) | Select-Object -First 1
    }
}

Describe 'Add-ToPath' {
    BeforeEach {
        $script:sessionPath = $env:Path
        $script:userPathBefore = [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $script:machinePathBefore = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
        Mock Write-Host -ModuleName PDS
    }

    AfterEach {
        $env:Path = $script:sessionPath
    }

    It 'reports an entry that is already in the user PATH and leaves it unchanged' {
        $existing = Get-ExistingPathEntry -Scope 'User'
        if (-not $existing) {
            Set-ItResult -Skipped -Because 'the user PATH has no entry to reuse'
            return
        }

        Add-ToPath -PathToAdd $existing

        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Object -eq 'Path already exists in PATH variable.'
        }
        Should -Invoke Write-Host -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Object -like 'Added *' }
        [System.Environment]::GetEnvironmentVariable('Path', 'User') | Should -Be $script:userPathBefore
    }

    It 'strips a trailing backslash before comparing' {
        $existing = Get-ExistingPathEntry -Scope 'User'
        if (-not $existing) {
            Set-ItResult -Skipped -Because 'the user PATH has no entry to reuse'
            return
        }

        Add-ToPath -PathToAdd "$existing\"

        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Object -eq 'Path already exists in PATH variable.'
        }
        [System.Environment]::GetEnvironmentVariable('Path', 'User') | Should -Be $script:userPathBefore
    }

    It 'checks the machine PATH when -SystemPath is set' {
        $existing = Get-ExistingPathEntry -Scope 'Machine'

        Add-ToPath -PathToAdd $existing -SystemPath

        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Object -eq 'Path already exists in PATH variable.'
        }
        Should -Invoke Write-Host -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Object -like 'Added *' }
        [System.Environment]::GetEnvironmentVariable('Path', 'Machine') | Should -Be $script:machinePathBefore
    }

    It 'updates the PATH of the current session' {
        $existing = Get-ExistingPathEntry -Scope 'Machine'

        Add-ToPath -PathToAdd $existing -SystemPath

        $env:Path | Should -BeLike "*;$existing"
        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Object -eq 'Updated PATH for the current session.'
        }
    }
}
