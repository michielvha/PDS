BeforeDiscovery {
    # The function checks the real token, which cannot be mocked, so each branch runs only
    # where it can.
    $script:isAdmin = $IsWindows -and ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    $script:rmAce = '(A;;GXGR;;;S-1-5-32-580)'
    $script:baseSddl = 'O:NSG:BAD:P(A;;GA;;;BA)(A;;GR;;;IU)S:P(AU;FA;GA;;;WD)(AU;SA;GXGW;;;WD)'
}

Describe 'Disable-WinRmServer' {
    BeforeEach {
        $script:serviceStatus = 'Running'
        $script:rootSddl = $script:baseSddl
        $script:existingUser = $null

        # Every system call is mocked: the function changes WinRM, the firewall and the registry.
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS Get-Service { [pscustomobject]@{ Name = 'WinRM'; Status = $script:serviceStatus } }
        Mock -ModuleName PDS Start-Service { }
        Mock -ModuleName PDS Stop-Service { }
        Mock -ModuleName PDS Set-Service { }
        Mock -ModuleName PDS Get-Item { [pscustomobject]@{ Value = $script:rootSddl } }
        Mock -ModuleName PDS Set-Item { }
        Mock -ModuleName PDS Get-ChildItem { 'Listener_1084132640' }
        Mock -ModuleName PDS Remove-Item { }
        Mock -ModuleName PDS Remove-NetFirewallRule { }
        Mock -ModuleName PDS Set-ItemProperty { }
        Mock -ModuleName PDS Get-LocalUser { $script:existingUser }
        Mock -ModuleName PDS Remove-LocalUser { }
    }

    Context 'when elevated' -Skip:(-not $script:isAdmin) {
        It 'removes the listener, stops WinRM and removes the firewall rule' {
            Disable-WinRmServer

            Should -Invoke -ModuleName PDS Remove-Item -Times 1 -Exactly
            Should -Invoke -ModuleName PDS Stop-Service -Times 1 -Exactly -ParameterFilter { $Name -eq 'WinRM' -and $Force }
            Should -Invoke -ModuleName PDS Set-Service -Times 1 -Exactly -ParameterFilter { $Name -eq 'WinRM' -and $StartupType -eq 'Manual' }
            Should -Invoke -ModuleName PDS Remove-NetFirewallRule -Times 1 -Exactly -ParameterFilter { $Name -eq 'PDS-WinRM-HTTP-In-TCP-5985' }
            Should -Invoke -ModuleName PDS Set-ItemProperty -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'LocalAccountTokenFilterPolicy' -and $Value -eq 0
            }
            Should -Invoke -ModuleName PDS Start-Service -Times 0
            Should -Invoke -ModuleName PDS Set-Item -Times 0
            Should -Invoke -ModuleName PDS Get-LocalUser -Times 0
        }

        It 'starts WinRM first when it is stopped, so the listeners can be read' {
            $script:serviceStatus = 'Stopped'

            Disable-WinRmServer

            Should -Invoke -ModuleName PDS Start-Service -Times 1 -Exactly -ParameterFilter { $Name -eq 'WinRM' }
        }

        It 'removes the Remote Management Users shell access from RootSDDL' {
            $script:rootSddl = $script:baseSddl.Replace('S:', "$($script:rmAce)S:")

            Disable-WinRmServer

            Should -Invoke -ModuleName PDS Set-Item -Times 1 -Exactly -ParameterFilter {
                $Path -eq 'WSMan:\localhost\Service\RootSDDL' -and $Value -eq $script:baseSddl
            }
        }

        It 'removes the named local user when it exists' {
            $script:existingUser = [pscustomobject]@{ Name = 'winrmtest' }

            Disable-WinRmServer -UserName winrmtest

            Should -Invoke -ModuleName PDS Remove-LocalUser -Times 1 -Exactly -ParameterFilter { $Name -eq 'winrmtest' }
        }

        It 'removes no user when the named user does not exist' {
            Disable-WinRmServer -UserName winrmtest

            Should -Invoke -ModuleName PDS Get-LocalUser -Times 1 -Exactly
            Should -Invoke -ModuleName PDS Remove-LocalUser -Times 0
        }

        It 'reports an error when a step fails' {
            Mock -ModuleName PDS Stop-Service { throw 'access denied' }

            Disable-WinRmServer -ErrorVariable err -ErrorAction SilentlyContinue

            $err | Should -Not -BeNullOrEmpty
            "$err" | Should -BeLike '*Failed to disable WinRM:*access denied*'
            Should -Invoke -ModuleName PDS Remove-NetFirewallRule -Times 0
        }
    }

    Context 'when not elevated' -Skip:$script:isAdmin {
        It 'refuses to run and changes nothing' {
            Disable-WinRmServer -ErrorVariable err -ErrorAction SilentlyContinue

            "$err" | Should -BeLike '*requires administrator privileges*'
            Should -Invoke -ModuleName PDS Stop-Service -Times 0
            Should -Invoke -ModuleName PDS Remove-NetFirewallRule -Times 0
        }
    }
}
