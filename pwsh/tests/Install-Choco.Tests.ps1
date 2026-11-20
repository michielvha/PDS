BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # choco is an external executable the test machine may not have; Pester can only mock
    # a command that exists, so give the module a stub to mock.
    InModuleScope PDS { function script:choco { } }
}

Describe 'Install-Choco' {
    BeforeEach {
        # The installer path must never run for real, whichever branch a test takes.
        Mock Set-ExecutionPolicy -ModuleName PDS { }
        Mock Invoke-Expression -ModuleName PDS { }
        Mock New-Object -ModuleName PDS -ParameterFilter { $TypeName -eq 'System.Net.WebClient' } {
            $client = [pscustomobject]@{}
            $client | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                param($Uri)
                "# script from $Uri"
            }
            $client
        }
    }

    Context 'when Chocolatey is already installed' {
        BeforeEach {
            Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'choco' } {
                [pscustomobject]@{ Name = 'choco' }
            }
            Mock choco -ModuleName PDS { '2.4.1' }
        }

        It 'reports the installed version and does not run the installer' {
            $output = Install-Choco

            $output | Should -Be 'Chocolatey is already installed. Version: 2.4.1'
            Should -Invoke choco -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $args[0] -eq '--version' }
            Should -Invoke Invoke-Expression -ModuleName PDS -Times 0 -Exactly
            Should -Invoke Set-ExecutionPolicy -ModuleName PDS -Times 0 -Exactly
        }
    }

    Context 'when Chocolatey is missing' {
        BeforeEach {
            Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'choco' } { }
        }

        It 'runs the official install script with a process-scoped execution policy' {
            $output = Install-Choco

            $output | Should -Be 'Chocolatey will be installed'
            Should -Invoke Set-ExecutionPolicy -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                $ExecutionPolicy -eq 'Bypass' -and $Scope -eq 'Process' -and $Force
            }
            Should -Invoke Invoke-Expression -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                $Command -eq '# script from https://community.chocolatey.org/install.ps1'
            }
        }
    }
}
