BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stub, so netsh can be mocked on any host.
    InModuleScope PDS { function script:netsh { } }
}

Describe 'Get-NetProfile' {
    BeforeEach {
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS netsh {
            if ($args[0] -eq 'lan') {
                'Profile on interface Ethernet: OfficeLAN'
            }
            else {
                '    All User Profile     : HomeWiFi'
            }
        }
    }

    It 'lists the wired and the wireless profiles' {
        $output = Get-NetProfile

        $output | Should -Be @('Profile on interface Ethernet: OfficeLAN', '    All User Profile     : HomeWiFi')
        Should -Invoke -ModuleName PDS netsh -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'lan show profiles' }
        Should -Invoke -ModuleName PDS netsh -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'wlan show profiles' }
    }

    It 'prints a heading for each profile type' {
        Get-NetProfile | Out-Null

        Should -Invoke -ModuleName PDS Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Wired Network Profiles:*' }
        Should -Invoke -ModuleName PDS Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Wireless Network Profiles:*' }
    }
}
