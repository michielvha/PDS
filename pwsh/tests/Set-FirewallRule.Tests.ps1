BeforeDiscovery {
    # The function checks the real token, which cannot be mocked, so each branch runs only
    # where it can.
    $script:isAdmin = $IsWindows -and ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Set-FirewallRule' {
    BeforeEach {
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS New-NetFirewallRule { }
    }

    It 'rejects a port outside 1-65535' {
        { Set-FirewallRule -Port 0 } | Should -Throw
        Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 0
    }

    Context 'when elevated' -Skip:(-not $script:isAdmin) {
        It 'creates an inbound and an outbound TCP rule named after the port' {
            Set-FirewallRule -Port 6040

            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 2 -Exactly
            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 1 -Exactly -ParameterFilter {
                $DisplayName -eq 'Allow 6040 in' -and $Direction -eq 'Inbound' -and $Action -eq 'Allow' -and $LocalPort -eq 6040 -and $Protocol -eq 'TCP'
            }
            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 1 -Exactly -ParameterFilter {
                $DisplayName -eq 'Allow 6040 out' -and $Direction -eq 'Outbound' -and $LocalPort -eq 6040 -and $Protocol -eq 'TCP'
            }
        }

        It 'uses the display name and protocol given' {
            Set-FirewallRule -Port 53 -Protocol UDP -DisplayName 'DNS Traffic'

            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 1 -Exactly -ParameterFilter {
                $DisplayName -eq 'DNS Traffic - In' -and $Direction -eq 'Inbound' -and $Protocol -eq 'UDP'
            }
            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 1 -Exactly -ParameterFilter {
                $DisplayName -eq 'DNS Traffic - Out' -and $Direction -eq 'Outbound' -and $Protocol -eq 'UDP'
            }
        }

        It 'reports an error when a rule cannot be created' {
            Mock -ModuleName PDS New-NetFirewallRule { throw 'access denied' }

            Set-FirewallRule -Port 6040 -ErrorVariable err -ErrorAction SilentlyContinue

            "$err" | Should -BeLike '*Failed to create firewall rules:*access denied*'
        }
    }

    Context 'when not elevated' -Skip:$script:isAdmin {
        It 'refuses to run and creates no rule' {
            Set-FirewallRule -Port 6040 -ErrorVariable err -ErrorAction SilentlyContinue

            "$err" | Should -BeLike '*requires administrator privileges*'
            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 0
        }
    }
}
