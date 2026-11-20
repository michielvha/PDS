BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # scoop is an external command the test machine may not have; Pester can only mock
    # a command that exists, so give the module a stub to mock.
    InModuleScope PDS { function script:scoop { } }
}

Describe 'Install-Scoop' {
    BeforeEach {
        # The installer path must never run for real, whichever branch a test takes.
        Mock Set-ExecutionPolicy -ModuleName PDS { }
        Mock Invoke-RestMethod -ModuleName PDS { '# scoop installer' }
        Mock Invoke-Expression -ModuleName PDS { }
    }

    Context 'when Scoop is already installed' {
        BeforeEach {
            Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'scoop' } {
                [pscustomobject]@{ Name = 'scoop' }
            }
            Mock scoop -ModuleName PDS { 'v0.5.2' }
        }

        It 'reports the installed version and does not run the installer' {
            $output = Install-Scoop

            $output | Should -Be 'Scoop is already installed. Version: v0.5.2'
            Should -Invoke scoop -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $args[0] -eq '--version' }
            Should -Invoke Invoke-RestMethod -ModuleName PDS -Times 0 -Exactly
            Should -Invoke Invoke-Expression -ModuleName PDS -Times 0 -Exactly
            Should -Invoke Set-ExecutionPolicy -ModuleName PDS -Times 0 -Exactly
        }
    }

    Context 'when Scoop is missing' {
        BeforeEach {
            Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'scoop' } { }
        }

        It 'downloads get.scoop.sh and runs it under a RemoteSigned user policy' {
            $output = Install-Scoop

            $output | Should -Be 'Scoop will be installed'
            Should -Invoke Set-ExecutionPolicy -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                $ExecutionPolicy -eq 'RemoteSigned' -and $Scope -eq 'CurrentUser'
            }
            Should -Invoke Invoke-RestMethod -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                "$Uri".TrimEnd('/') -eq 'https://get.scoop.sh'
            }
            Should -Invoke Invoke-Expression -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                $Command -eq '# scoop installer'
            }
        }
    }
}
