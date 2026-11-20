BeforeDiscovery {
    # The function checks the real token, which cannot be mocked, so each branch runs only
    # where it can.
    $script:isAdmin = $IsWindows -and ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    $script:rmAce = '(A;;GXGR;;;S-1-5-32-580)'
    $script:baseSddl = 'O:NSG:BAD:P(A;;GA;;;BA)(A;;GR;;;IU)S:P(AU;FA;GA;;;WD)(AU;SA;GXGW;;;WD)'
    $script:ruleName = 'PDS-WinRM-HTTP-In-TCP-5985'
}

Describe 'Enable-WinRmServer' {
    BeforeEach {
        $script:listeners = @()
        $script:allowUnencrypted = 'false'
        $script:rootSddl = $script:baseSddl
        $script:existingRule = $null
        $script:existingUser = $null
        $script:groupMembers = @()
        $script:password = [securestring]::new()

        # Every system call is mocked: the function changes WinRM, the firewall, local users
        # and the registry.
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS Set-Service { }
        Mock -ModuleName PDS Start-Service { }
        Mock -ModuleName PDS Get-ChildItem { $script:listeners }
        Mock -ModuleName PDS New-Item { }
        Mock -ModuleName PDS Get-Item {
            if ($Path -like '*AllowUnencrypted') {
                [pscustomobject]@{ Value = $script:allowUnencrypted }
            }
            else {
                [pscustomobject]@{ Value = $script:rootSddl }
            }
        }
        Mock -ModuleName PDS Set-Item { }
        Mock -ModuleName PDS Get-NetFirewallRule { $script:existingRule }
        Mock -ModuleName PDS Set-NetFirewallRule { }
        Mock -ModuleName PDS New-NetFirewallRule { }
        Mock -ModuleName PDS Get-LocalUser { $script:existingUser }
        Mock -ModuleName PDS Set-LocalUser { }
        Mock -ModuleName PDS Enable-LocalUser { }
        Mock -ModuleName PDS New-LocalUser { }
        Mock -ModuleName PDS Get-LocalGroupMember { $script:groupMembers }
        Mock -ModuleName PDS Add-LocalGroupMember { }
        Mock -ModuleName PDS Get-LocalGroup { [pscustomobject]@{ Name = 'Remote Management Users' } }
        Mock -ModuleName PDS Set-ItemProperty { }
        Mock -ModuleName PDS Get-NetIPAddress {
            [pscustomobject]@{ IPAddress = '127.0.0.1' }
            [pscustomobject]@{ IPAddress = '192.168.10.20' }
        }
    }

    Context 'when elevated' -Skip:(-not $script:isAdmin) {
        It 'creates the HTTP listener and its firewall rule when they are missing' {
            Enable-WinRmServer

            Should -Invoke -ModuleName PDS Set-Service -Times 1 -Exactly -ParameterFilter { $Name -eq 'WinRM' -and $StartupType -eq 'Automatic' }
            Should -Invoke -ModuleName PDS Start-Service -Times 1 -Exactly -ParameterFilter { $Name -eq 'WinRM' }
            Should -Invoke -ModuleName PDS New-Item -Times 1 -Exactly -ParameterFilter { $Path -eq 'WSMan:\localhost\Listener' }
            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 1 -Exactly -ParameterFilter {
                $Name -eq $script:ruleName -and $LocalPort -eq 5985 -and $Profile -eq 'Any' -and $RemoteAddress -eq 'LocalSubnet'
            }
            Should -Invoke -ModuleName PDS Set-NetFirewallRule -Times 0
        }

        It 'keeps Negotiate on and Basic off without touching AllowUnencrypted when it is already off' {
            Enable-WinRmServer

            Should -Invoke -ModuleName PDS Set-Item -Times 1 -Exactly -ParameterFilter { $Path -eq 'WSMan:\localhost\Service\Auth\Negotiate' -and $Value -eq $true }
            Should -Invoke -ModuleName PDS Set-Item -Times 1 -Exactly -ParameterFilter { $Path -eq 'WSMan:\localhost\Service\Auth\Basic' -and $Value -eq $false }
            Should -Invoke -ModuleName PDS Set-Item -Times 0 -ParameterFilter { $Path -eq 'WSMan:\localhost\Service\AllowUnencrypted' }
        }

        It 'turns AllowUnencrypted off when it is on' {
            $script:allowUnencrypted = 'true'

            Enable-WinRmServer

            Should -Invoke -ModuleName PDS Set-Item -Times 1 -Exactly -ParameterFilter {
                $Path -eq 'WSMan:\localhost\Service\AllowUnencrypted' -and $Value -eq $false
            }
        }

        It 'reuses an existing listener and updates an existing firewall rule' {
            $script:listeners = @([pscustomobject]@{ Keys = @('Transport=HTTP', 'Address=*') })
            $script:existingRule = [pscustomobject]@{ Name = $script:ruleName }

            Enable-WinRmServer -RemoteAddress '192.168.10.0/24'

            Should -Invoke -ModuleName PDS New-Item -Times 0
            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 0
            Should -Invoke -ModuleName PDS Set-NetFirewallRule -Times 1 -Exactly -ParameterFilter {
                $Name -eq $script:ruleName -and $Profile -eq 'Any' -and $RemoteAddress -eq '192.168.10.0/24'
            }
        }

        It 'creates a new user in Remote Management Users and grants it WinRS shell access' {
            Enable-WinRmServer -UserName winrmtest -Password $script:password

            Should -Invoke -ModuleName PDS New-LocalUser -Times 1 -Exactly -ParameterFilter { $Name -eq 'winrmtest' }
            Should -Invoke -ModuleName PDS Set-LocalUser -Times 0
            Should -Invoke -ModuleName PDS Add-LocalGroupMember -Times 1 -Exactly -ParameterFilter {
                "$SID" -eq 'S-1-5-32-580' -and $Member.Name -contains 'winrmtest'
            }
            Should -Invoke -ModuleName PDS Set-Item -Times 1 -Exactly -ParameterFilter {
                $Path -eq 'WSMan:\localhost\Service\RootSDDL' -and $Value -eq $script:baseSddl.Replace('S:', "$($script:rmAce)S:")
            }
            Should -Invoke -ModuleName PDS Set-ItemProperty -Times 0
        }

        It 'updates an existing user and makes it an administrator with -Administrator' {
            $script:existingUser = [pscustomobject]@{ Name = 'winrmtest' }
            $script:groupMembers = @([pscustomobject]@{ Name = 'W11\winrmtest' })

            Enable-WinRmServer -UserName winrmtest -Password $script:password -Administrator

            Should -Invoke -ModuleName PDS Set-LocalUser -Times 1 -Exactly -ParameterFilter { $Name -eq 'winrmtest' }
            Should -Invoke -ModuleName PDS Enable-LocalUser -Times 1 -Exactly -ParameterFilter { $Name -eq 'winrmtest' }
            Should -Invoke -ModuleName PDS New-LocalUser -Times 0
            Should -Invoke -ModuleName PDS Get-LocalGroupMember -Times 1 -Exactly -ParameterFilter { "$SID" -eq 'S-1-5-32-544' }
            Should -Invoke -ModuleName PDS Add-LocalGroupMember -Times 0
            Should -Invoke -ModuleName PDS Set-ItemProperty -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'LocalAccountTokenFilterPolicy' -and $Value -eq 1
            }
            Should -Invoke -ModuleName PDS Set-Item -Times 0 -ParameterFilter { $Path -eq 'WSMan:\localhost\Service\RootSDDL' }
        }

        It 'warns when WinRM refuses the RootSDDL change' {
            Mock -ModuleName PDS Set-Item { throw 'refused on a Public network' } -ParameterFilter { $Path -eq 'WSMan:\localhost\Service\RootSDDL' }

            Enable-WinRmServer -UserName winrmtest -Password $script:password -WarningVariable warnings -WarningAction SilentlyContinue

            "$warnings" | Should -BeLike '*refused to grant Remote Management Users shell access*'
        }

        It 'reports an error when a step fails' {
            Mock -ModuleName PDS Start-Service { throw 'service is disabled' }

            Enable-WinRmServer -ErrorVariable err -ErrorAction SilentlyContinue

            "$err" | Should -BeLike '*Failed to configure WinRM:*service is disabled*'
            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 0
        }
    }

    Context 'when not elevated' -Skip:$script:isAdmin {
        It 'refuses to run and changes nothing' {
            Enable-WinRmServer -ErrorVariable err -ErrorAction SilentlyContinue

            "$err" | Should -BeLike '*requires administrator privileges*'
            Should -Invoke -ModuleName PDS Set-Service -Times 0
            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 0
        }
    }
}
