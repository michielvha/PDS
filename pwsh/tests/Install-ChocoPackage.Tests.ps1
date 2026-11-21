BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # choco is an external executable the test machine may not have; Pester can only mock
    # a command that exists, so give the module a stub to mock.
    InModuleScope PDS { function script:choco { } }
}

Describe 'Install-ChocoPackage' {
    BeforeEach {
        Mock choco -ModuleName PDS { }
    }

    It 'installs every package with choco install -y' {
        Install-ChocoPackage -packagesToInstall 'git', 'nodejs' 6>$null

        Should -Invoke choco -ModuleName PDS -Times 2 -Exactly
        Should -Invoke choco -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq 'install git -y'
        }
        Should -Invoke choco -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq 'install nodejs -y'
        }
    }

    It 'returns the list of packages it is about to install' {
        $output = Install-ChocoPackage -p 'git', 'nodejs' 6>$null

        ($output -join ',') | Should -Be 'git,nodejs'
    }

    It 'does not call choco when no packages are given' {
        Install-ChocoPackage -packagesToInstall @() 6>$null

        Should -Invoke choco -ModuleName PDS -Times 0 -Exactly
    }

    It 'still runs under its old name' {
        $command = Get-Command 'Install-ChocoPackages' -Module PDS
        $command.CommandType | Should -Be 'Alias'
        $command.ResolvedCommandName | Should -Be 'Install-ChocoPackage'

        & $command -packagesToInstall 'git' 6>$null

        Should -Invoke choco -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq 'install git -y'
        }
    }
}
