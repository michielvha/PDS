BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stub, so netsh can be mocked on any host.
    InModuleScope PDS { function script:netsh { } }
}

Describe 'Get-WlanPass' {
    BeforeEach {
        Mock -ModuleName PDS netsh {
            $command = $args -join ' '
            if ($command -eq 'wlan show profiles') {
                'Profiles on interface Wi-Fi:'
                ''
                'User profiles'
                '-------------'
                '    All User Profile     : HomeWiFi'
                '    All User Profile     : PublicWiFi'
            }
            elseif ($command -eq 'wlan show profile name=HomeWiFi key=clear') {
                '    Security key           : Present'
                '    Key Content            : MySecurePass123'
            }
            else {
                '    Security key           : Absent'
            }
        }
    }

    It 'shows the stored password of each profile and N/A when none is stored' {
        $output = Get-WlanPass | Out-String

        $output | Should -Match '(?m)^HomeWiFi\s+MySecurePass123\s*$'
        $output | Should -Match '(?m)^PublicWiFi\s+N/A\s*$'
    }

    It 'asks netsh for the key of every profile' {
        Get-WlanPass | Out-Null

        Should -Invoke -ModuleName PDS netsh -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'wlan show profiles' }
        Should -Invoke -ModuleName PDS netsh -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'wlan show profile name=HomeWiFi key=clear' }
        Should -Invoke -ModuleName PDS netsh -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'wlan show profile name=PublicWiFi key=clear' }
    }

    It 'returns nothing when no profile is stored' {
        Mock -ModuleName PDS netsh { 'There is no wireless interface on the system.' }

        Get-WlanPass | Should -BeNullOrEmpty
        Should -Invoke -ModuleName PDS netsh -Times 1 -Exactly
    }
}
