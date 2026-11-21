BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # choco is an external executable the test machine may not have; Pester can only mock
    # a command that exists, so give the module a stub to mock.
    InModuleScope PDS { function script:choco { } }

    # The fake installer records the path it ran from here.
    $script:marker = Join-Path $TestDrive 'installer-ran.txt'
}

Describe 'Install-Choco' {
    BeforeEach {
        # The installer is downloaded to the temp folder, so point it at TestDrive for this process.
        $script:savedTmp = $env:TMP
        $script:savedTemp = $env:TEMP
        $env:TMP = $TestDrive
        $env:TEMP = $TestDrive
        Remove-Item -Path $script:marker -ErrorAction SilentlyContinue

        # The installer path must never run for real, whichever branch a test takes: the download
        # is mocked and writes a fake installer that only records that it ran.
        Mock Set-ExecutionPolicy -ModuleName PDS { }
        Mock Invoke-Expression -ModuleName PDS { }
        Mock Invoke-WebRequest -ModuleName PDS {
            Set-Content -Path $OutFile -Value "Set-Content -LiteralPath '$script:marker' -Value `$PSCommandPath"
        }
    }

    AfterEach {
        $env:TMP = $script:savedTmp
        $env:TEMP = $script:savedTemp
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
            Should -Invoke Invoke-WebRequest -ModuleName PDS -Times 0 -Exactly
            Should -Invoke Invoke-Expression -ModuleName PDS -Times 0 -Exactly
            Should -Invoke Set-ExecutionPolicy -ModuleName PDS -Times 0 -Exactly
            $script:marker | Should -Not -Exist
        }
    }

    Context 'when Chocolatey is missing' {
        BeforeEach {
            Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'choco' } { }
        }

        It 'downloads the official install script to a file and runs that file' {
            $output = Install-Choco

            $output | Should -Be 'Chocolatey will be installed'
            Should -Invoke Set-ExecutionPolicy -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                $ExecutionPolicy -eq 'Bypass' -and $Scope -eq 'Process' -and $Force
            }
            Should -Invoke Invoke-WebRequest -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://community.chocolatey.org/install.ps1' -and $UseBasicParsing -and
                $OutFile -like (Join-Path $TestDrive 'choco-install-*.ps1')
            }
            Should -Invoke Invoke-Expression -ModuleName PDS -Times 0 -Exactly

            $ranFrom = Get-Content -Path $script:marker
            $ranFrom | Should -BeLike (Join-Path $TestDrive 'choco-install-*.ps1')
            $ranFrom | Should -Not -Exist
        }

        It 'removes the downloaded installer when it fails' {
            Mock Invoke-WebRequest -ModuleName PDS { Set-Content -Path $OutFile -Value "throw 'installer failed'" }

            { Install-Choco } | Should -Throw 'installer failed'

            Get-ChildItem -Path $TestDrive -Filter 'choco-install-*.ps1' | Should -BeNullOrEmpty
        }
    }
}
