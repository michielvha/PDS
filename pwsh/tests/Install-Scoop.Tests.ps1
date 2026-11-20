BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # scoop is an external command the test machine may not have; Pester can only mock
    # a command that exists, so give the module a stub to mock.
    InModuleScope PDS { function script:scoop { } }

    # The fake installer records the path it ran from here.
    $script:marker = Join-Path $TestDrive 'installer-ran.txt'
}

Describe 'Install-Scoop' {
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
        Mock Invoke-RestMethod -ModuleName PDS {
            Set-Content -Path $OutFile -Value "Set-Content -LiteralPath '$script:marker' -Value `$PSCommandPath"
        }
    }

    AfterEach {
        $env:TMP = $script:savedTmp
        $env:TEMP = $script:savedTemp
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
            $script:marker | Should -Not -Exist
        }
    }

    Context 'when Scoop is missing' {
        BeforeEach {
            Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'scoop' } { }
        }

        It 'downloads get.scoop.sh to a file and runs it under a RemoteSigned user policy' {
            $output = Install-Scoop

            $output | Should -Be 'Scoop will be installed'
            Should -Invoke Set-ExecutionPolicy -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                $ExecutionPolicy -eq 'RemoteSigned' -and $Scope -eq 'CurrentUser'
            }
            Should -Invoke Invoke-RestMethod -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                "$Uri".TrimEnd('/') -eq 'https://get.scoop.sh' -and
                $OutFile -like (Join-Path $TestDrive 'scoop-install-*.ps1')
            }
            Should -Invoke Invoke-Expression -ModuleName PDS -Times 0 -Exactly

            $ranFrom = Get-Content -Path $script:marker
            $ranFrom | Should -BeLike (Join-Path $TestDrive 'scoop-install-*.ps1')
            $ranFrom | Should -Not -Exist
        }

        It 'removes the downloaded installer when it fails' {
            Mock Invoke-RestMethod -ModuleName PDS { Set-Content -Path $OutFile -Value "throw 'installer failed'" }

            { Install-Scoop } | Should -Throw 'installer failed'

            Get-ChildItem -Path $TestDrive -Filter 'scoop-install-*.ps1' | Should -BeNullOrEmpty
        }
    }
}
