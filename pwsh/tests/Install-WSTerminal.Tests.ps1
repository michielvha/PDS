BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # winget is an external executable that is not on every machine; a module-scope stub
    # lets Pester mock it and keeps the real binary out of reach.
    InModuleScope PDS { function script:winget { } }
}

Describe 'Install-WSTerminal' {
    BeforeEach {
        # Nothing may be downloaded, installed, removed or waited on.
        Mock Start-Sleep -ModuleName PDS { }
        Mock Add-AppxPackage -ModuleName PDS { }
        Mock Invoke-WebRequest -ModuleName PDS { }
        Mock Remove-Item -ModuleName PDS { }
        Mock winget -ModuleName PDS { 'Successfully installed' }
        Mock Get-AppxPackage -ModuleName PDS -ParameterFilter { $Name -eq 'Microsoft.WindowsTerminal' } { }
        Mock Get-AppxPackage -ModuleName PDS -ParameterFilter { -not $PesterBoundParameters.ContainsKey('Name') } {
            [pscustomobject]@{ Name = 'Microsoft.UI.Xaml.2.8'; Version = '8.2310.30001.0' }
            [pscustomobject]@{ Name = 'Microsoft.VCLibs.140.00.UWPDesktop'; Version = '14.0.33519.0' }
        }
        Mock Invoke-RestMethod -ModuleName PDS {
            [pscustomobject]@{
                tag_name = 'v1.21.2361.0'
                assets   = @(
                    [pscustomobject]@{
                        name                 = 'Microsoft.WindowsTerminal_1.21.2361.0_x64.zip'
                        browser_download_url = 'https://example.invalid/terminal.zip'
                    }
                    [pscustomobject]@{
                        name                 = 'Microsoft.WindowsTerminal_1.21.2361.0_8wekyb3d8bbwe.msixbundle'
                        browser_download_url = 'https://example.invalid/terminal.msixbundle'
                    }
                )
            }
        }
    }

    It 'reports the installed version and changes nothing when Windows Terminal is present' {
        Mock Get-AppxPackage -ModuleName PDS -ParameterFilter { $Name -eq 'Microsoft.WindowsTerminal' } {
            [pscustomobject]@{ Name = 'Microsoft.WindowsTerminal'; Version = '1.21.2361.0' }
        }

        $output = Install-WSTerminal

        $output | Should -Be 'Windows Terminal is already installed. Version: 1.21.2361.0'
        Should -Invoke Invoke-RestMethod -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Add-AppxPackage -ModuleName PDS -Times 0 -Exactly
    }

    It 'installs the msixbundle of the latest GitHub release when the prerequisites are present' {
        $output = Install-WSTerminal

        $output | Should -Contain 'Found version: v1.21.2361.0'
        $output | Should -Contain 'Windows Terminal has been successfully installed.'
        Should -Invoke Invoke-RestMethod -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            "$Uri" -eq 'https://api.github.com/repos/microsoft/terminal/releases/latest'
        }
        Should -Invoke Invoke-WebRequest -ModuleName PDS -Times 1 -Exactly
        Should -Invoke Invoke-WebRequest -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            "$Uri" -eq 'https://example.invalid/terminal.msixbundle' -and
            $OutFile -like '*\Microsoft.WindowsTerminal_1.21.2361.0_8wekyb3d8bbwe.msixbundle'
        }
        Should -Invoke Add-AppxPackage -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -like '*\Microsoft.WindowsTerminal_1.21.2361.0_8wekyb3d8bbwe.msixbundle'
        }
        Should -Invoke winget -ModuleName PDS -Times 0 -Exactly
    }

    It 'installs Windows App Runtime and VCLibs first when they are missing' {
        $script:frameworkLookups = 0
        Mock Get-AppxPackage -ModuleName PDS -ParameterFilter { -not $PesterBoundParameters.ContainsKey('Name') } {
            $script:frameworkLookups++
            if ($script:frameworkLookups -gt 1) {
                [pscustomobject]@{ Name = 'Microsoft.UI.Xaml.2.8'; Version = '8.2310.30001.0' }
            }
        }
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'winget' } {
            [pscustomobject]@{ Name = 'winget' }
        }

        $output = Install-WSTerminal

        $output | Should -Contain 'Windows App Runtime 1.8 installed successfully.'
        $output | Should -Contain 'Windows Terminal has been successfully installed.'
        Should -Invoke winget -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -like 'install --id Microsoft.WindowsAppRuntime.1.8 --exact *'
        }
        Should -Invoke Invoke-WebRequest -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            "$Uri" -eq 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'
        }
        Should -Invoke Add-AppxPackage -ModuleName PDS -Times 2 -Exactly
    }

    It 'stops when Windows App Runtime is missing and winget is not available' {
        Mock Get-AppxPackage -ModuleName PDS -ParameterFilter { -not $PesterBoundParameters.ContainsKey('Name') } { }
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'winget' } { }

        { Install-WSTerminal 2>$null } | Should -Throw '*winget is not available*'
        Should -Invoke Invoke-WebRequest -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Add-AppxPackage -ModuleName PDS -Times 0 -Exactly
    }

    It 'stops when the latest release has no msixbundle' {
        Mock Invoke-RestMethod -ModuleName PDS {
            [pscustomobject]@{
                tag_name = 'v1.21.2361.0'
                assets   = @([pscustomobject]@{ name = 'notes.txt'; browser_download_url = 'https://example.invalid/notes.txt' })
            }
        }

        { Install-WSTerminal 2>$null } | Should -Throw '*Could not find MSIX bundle*'
        Should -Invoke Add-AppxPackage -ModuleName PDS -Times 0 -Exactly
    }
}
