BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # winget is an external executable that is not on every machine; a module-scope stub
    # lets Pester mock it and keeps the real binary out of reach.
    InModuleScope PDS { function script:winget { } }
}

Describe 'Install-Winget' {
    BeforeEach {
        # Nothing may be downloaded, installed, removed or waited on.
        Mock Start-Sleep -ModuleName PDS { }
        Mock Add-AppxPackage -ModuleName PDS { }
        Mock Invoke-WebRequest -ModuleName PDS { }
        Mock Remove-Item -ModuleName PDS { }
        Mock Get-CimInstance -ModuleName PDS { [pscustomobject]@{ Version = '10.0.26100' } }
        Mock winget -ModuleName PDS { 'v1.9.25180' }
    }

    It 'reports the installed version when winget already works' {
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'winget' } {
            [pscustomobject]@{ Name = 'winget' }
        }

        $output = Install-Winget

        $output | Should -Be 'winget is already installed. Version: v1.9.25180'
        Should -Invoke Add-AppxPackage -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Invoke-WebRequest -ModuleName PDS -Times 0 -Exactly
    }

    It 'registers App Installer when it is present but not registered' {
        $script:wingetLookups = 0
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'winget' } {
            $script:wingetLookups++
            if ($script:wingetLookups -gt 1) {
                [pscustomobject]@{ Name = 'winget' }
            }
        }

        $output = Install-Winget

        $output | Should -Contain 'winget registered successfully. Version: v1.9.25180'
        Should -Invoke Add-AppxPackage -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $RegisterByFamilyName -and $MainPackage -eq 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
        }
        Should -Invoke Invoke-WebRequest -ModuleName PDS -Times 0 -Exactly
    }

    It 'downloads and installs App Installer when registration fails' {
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'winget' } { }
        Mock Add-AppxPackage -ModuleName PDS -ParameterFilter { $RegisterByFamilyName } {
            throw 'App Installer is not installed'
        }

        $output = Install-Winget 3>&1

        $output | Should -Contain 'winget has been successfully installed.'
        $warning = $output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
        $warning.Message | Should -BeLike '*Please restart your terminal.'
        Should -Invoke Invoke-WebRequest -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            "$Uri" -eq 'https://aka.ms/getwinget' -and $OutFile -like '*\Microsoft.DesktopAppInstaller.msixbundle'
        }
        Should -Invoke Add-AppxPackage -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -like '*\Microsoft.DesktopAppInstaller.msixbundle'
        }
    }

    It 'refuses to install on Windows versions older than 10' {
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'winget' } { }
        Mock Get-CimInstance -ModuleName PDS { [pscustomobject]@{ Version = '6.3.9600' } }

        { Install-Winget 2>$null } | Should -Throw '*requires Windows 10*'
        Should -Invoke Add-AppxPackage -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Invoke-WebRequest -ModuleName PDS -Times 0 -Exactly
    }

    It 'asks for Windows App Runtime when the install fails with 0x80073CF3' {
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'winget' } { }
        Mock Add-AppxPackage -ModuleName PDS -ParameterFilter { $RegisterByFamilyName } {
            throw 'App Installer is not installed'
        }
        Mock Add-AppxPackage -ModuleName PDS -ParameterFilter { $Path } {
            throw 'Deployment failed with HRESULT: 0x80073CF3'
        }

        { Install-Winget 2>$null } | Should -Throw 'Windows App Runtime 1.8 must be installed before winget can be installed.'
    }
}
