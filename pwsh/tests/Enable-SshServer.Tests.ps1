BeforeDiscovery {
    # The function checks the real token, which cannot be mocked, so each branch runs only
    # where it can.
    $script:isAdmin = $IsWindows -and ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stub, so the ACL call is never the real icacls.exe even if a mock does not match.
    InModuleScope PDS { function script:icacls.exe { } }

    $script:originalProgramData = $env:ProgramData
    $script:key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPdsTestKeyOne me@laptop'
    $script:otherKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPdsTestKeyTwo me@desktop'
    $script:defaultConfig = @(
        '#Port 22'
        '#PubkeyAuthentication yes'
        '#PasswordAuthentication yes'
        ''
        'Match Group administrators'
        '       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys'
    ) -join "`r`n"
    if ($IsWindows) {
        $script:userSid = ([System.Security.Principal.NTAccount]::new($env:USERNAME)).Translate([System.Security.Principal.SecurityIdentifier]).Value
    }
}

AfterAll {
    $env:ProgramData = $script:originalProgramData
}

Describe 'Set-SshdConfigOption' {
    It 'replaces a commented global entry and leaves Match blocks alone' {
        $config = "#Port 22`r`nMatch Group administrators`r`n    Port 2200`r`n"

        $result = InModuleScope PDS -Parameters @{ Config = $config } {
            param($Config)
            $option = @{ Config = $Config; Name = 'Port'; Value = 2222 }
            Set-SshdConfigOption @option
        }

        $result | Should -Be "Port 2222`r`nMatch Group administrators`r`n    Port 2200`r`n"
    }

    It 'prepends an option that is not present' {
        $result = InModuleScope PDS {
            $option = @{ Config = "Subsystem sftp sftp-server.exe`r`n"; Name = 'PasswordAuthentication'; Value = 'no' }
            Set-SshdConfigOption @option
        }

        $result | Should -Be "PasswordAuthentication no`r`nSubsystem sftp sftp-server.exe`r`n"
    }

    It 'changes nothing under -WhatIf' {
        # The helper only returns text, so there is no command to count: the text must come back as given.
        $config = "#Port 22`r`nSubsystem sftp sftp-server.exe`r`n"

        $result = InModuleScope PDS -Parameters @{ Config = $config } {
            param($Config)
            $option = @{ Config = $Config; Name = 'Port'; Value = 2222 }
            Set-SshdConfigOption @option -WhatIf
        }

        $result | Should -Be $config
    }
}

Describe 'Enable-SshServer' {
    BeforeEach {
        # Point the sshd data directory at TestDrive so sshd_config and the key files are
        # written there and never to the real C:\ProgramData\ssh.
        $env:ProgramData = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:sshDir = Join-Path $env:ProgramData 'ssh'
        $script:sshdConfig = Join-Path $script:sshDir 'sshd_config'
        New-Item -Path $script:sshDir -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath $script:sshdConfig -Value $script:defaultConfig -NoNewline

        $script:capabilityState = 'NotPresent'
        $script:existingRule = $null
        $script:adminMembers = @([pscustomobject]@{ SID = [pscustomobject]@{ Value = $script:userSid } })
        $script:profilePath = Join-Path $TestDrive ([guid]::NewGuid().ToString())

        # Every system call is mocked: the function installs a Windows capability and changes
        # services, the firewall, the registry and file ACLs.
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS Get-WindowsCapability {
            [pscustomobject]@{ Name = 'OpenSSH.Server~~~~0.0.1.0'; State = $script:capabilityState }
        }
        Mock -ModuleName PDS Add-WindowsCapability { }
        Mock -ModuleName PDS Set-Service { }
        Mock -ModuleName PDS Start-Service { }
        Mock -ModuleName PDS Restart-Service { }
        Mock -ModuleName PDS New-Item { }
        Mock -ModuleName PDS New-ItemProperty { }
        Mock -ModuleName PDS Get-NetFirewallRule { $script:existingRule }
        Mock -ModuleName PDS Set-NetFirewallRule { }
        Mock -ModuleName PDS New-NetFirewallRule { }
        Mock -ModuleName PDS Get-LocalGroupMember { $script:adminMembers }
        Mock -ModuleName PDS Get-CimInstance { [pscustomobject]@{ LocalPath = $script:profilePath } }
        Mock -ModuleName PDS icacls.exe { Set-Variable -Name LASTEXITCODE -Value 0 -Scope Global }
        Mock -ModuleName PDS Get-NetIPAddress {
            [pscustomobject]@{ IPAddress = '127.0.0.1' }
            [pscustomobject]@{ IPAddress = '192.168.10.20' }
        }
    }

    AfterEach {
        $env:ProgramData = $script:originalProgramData
    }

    Context 'when elevated' -Skip:(-not $script:isAdmin) {
        It 'installs the capability, starts sshd and opens the firewall when no key is given' {
            Enable-SshServer

            Should -Invoke -ModuleName PDS Add-WindowsCapability -Times 1 -Exactly -ParameterFilter { $Name -eq 'OpenSSH.Server~~~~0.0.1.0' }
            Should -Invoke -ModuleName PDS Set-Service -Times 1 -Exactly -ParameterFilter { $Name -eq 'sshd' -and $StartupType -eq 'Automatic' }
            Should -Invoke -ModuleName PDS Start-Service -Times 1 -Exactly -ParameterFilter { $Name -eq 'sshd' }
            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'PDS-OpenSSH-Server-In-TCP-22' -and $LocalPort -eq 22 -and $Profile -eq 'Any' -and $Direction -eq 'Inbound'
            }
            Should -Invoke -ModuleName PDS Restart-Service -Times 1 -Exactly -ParameterFilter { $Name -eq 'sshd' }
            Should -Invoke -ModuleName PDS icacls.exe -Times 0
        }

        It 'enables the port and public key options in sshd_config and keeps a backup' {
            Enable-SshServer

            $config = Get-Content -LiteralPath $script:sshdConfig
            $config | Should -Contain 'Port 22'
            $config | Should -Contain 'PubkeyAuthentication yes'
            $config | Should -Contain '#PasswordAuthentication yes'
            Get-Content -LiteralPath "$($script:sshdConfig).bak" -Raw | Should -Be $script:defaultConfig
        }

        It 'leaves sshd_config untouched when it already has the settings' {
            Set-Content -LiteralPath $script:sshdConfig -Value "Port 22`r`nPubkeyAuthentication yes`r`n" -NoNewline

            Enable-SshServer

            "$($script:sshdConfig).bak" | Should -Not -Exist
        }

        It 'does not reinstall an installed capability and updates its existing firewall rule' {
            $script:capabilityState = 'Installed'
            $script:existingRule = [pscustomobject]@{ Name = 'PDS-OpenSSH-Server-In-TCP-2222' }

            Enable-SshServer -Port 2222

            Should -Invoke -ModuleName PDS Add-WindowsCapability -Times 0
            Should -Invoke -ModuleName PDS New-NetFirewallRule -Times 0
            Should -Invoke -ModuleName PDS Set-NetFirewallRule -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'PDS-OpenSSH-Server-In-TCP-2222' -and $Profile -eq 'Any' -and $Enabled -eq 'True'
            }
            Get-Content -LiteralPath $script:sshdConfig | Should -Contain 'Port 2222'
        }

        It 'authorizes a key for an administrator in administrators_authorized_keys' {
            Enable-SshServer -PublicKey $script:key

            $keysFile = Join-Path $script:sshDir 'administrators_authorized_keys'
            Get-Content -LiteralPath $keysFile | Should -Be $script:key
            Should -Invoke -ModuleName PDS icacls.exe -Times 1 -Exactly -ParameterFilter {
                $args[0] -eq $keysFile -and $args -contains '/inheritance:r' -and $args -contains '*S-1-5-18:F' -and
                $args -contains '*S-1-5-32-544:F' -and $args -notcontains "*$($script:userSid):F"
            }
        }

        It 'does not add a key that is already authorized' {
            $keysFile = Join-Path $script:sshDir 'administrators_authorized_keys'
            Set-Content -LiteralPath $keysFile -Value $script:key

            Enable-SshServer -PublicKey $script:key, $script:otherKey, $script:otherKey

            Get-Content -LiteralPath $keysFile | Should -Be @($script:key, $script:otherKey)
        }

        It 'authorizes a key for another user in the authorized_keys file of that profile' {
            $script:adminMembers = @()
            New-Item -Path (Join-Path $script:profilePath '.ssh') -ItemType Directory -Force | Out-Null

            Enable-SshServer -PublicKey $script:key

            $keysFile = Join-Path $script:profilePath '.ssh' 'authorized_keys'
            Get-Content -LiteralPath $keysFile | Should -Be $script:key
            Join-Path $script:sshDir 'administrators_authorized_keys' | Should -Not -Exist
            Should -Invoke -ModuleName PDS icacls.exe -Times 1 -Exactly -ParameterFilter {
                $args[0] -eq $keysFile -and $args -contains "*$($script:userSid):F"
            }
        }

        It 'reads every key from -PublicKeyPath and disables password authentication' {
            $keyPath = Join-Path $TestDrive 'id_ed25519.pub'
            Set-Content -LiteralPath $keyPath -Value @('# my keys', $script:key, '', $script:otherKey)

            Enable-SshServer -PublicKeyPath $keyPath -DisablePasswordAuthentication

            Get-Content -LiteralPath (Join-Path $script:sshDir 'administrators_authorized_keys') | Should -Be @($script:key, $script:otherKey)
            Get-Content -LiteralPath $script:sshdConfig | Should -Contain 'PasswordAuthentication no'
        }

        It 'sets the default shell in the registry' {
            $shell = Join-Path $TestDrive 'pwsh.exe'
            Set-Content -LiteralPath $shell -Value ''

            Enable-SshServer -DefaultShell $shell

            Should -Invoke -ModuleName PDS New-ItemProperty -Times 1 -Exactly -ParameterFilter {
                $Path -eq 'HKLM:\SOFTWARE\OpenSSH' -and $Name -eq 'DefaultShell' -and $Value -eq $shell
            }
        }

        It 'rejects an invalid key before changing anything' {
            Enable-SshServer -PublicKey 'not-a-key' -ErrorVariable err -ErrorAction SilentlyContinue

            "$err" | Should -BeLike '*No valid OpenSSH public key provided*not-a-key*'
            Should -Invoke -ModuleName PDS Get-WindowsCapability -Times 0
        }

        It 'refuses -DisablePasswordAuthentication without a key' {
            Enable-SshServer -DisablePasswordAuthentication -ErrorVariable err -ErrorAction SilentlyContinue

            "$err" | Should -BeLike '*-DisablePasswordAuthentication requires -PublicKey or -PublicKeyPath*'
            Should -Invoke -ModuleName PDS Get-WindowsCapability -Times 0
        }

        It 'reports an error when the capability is not available' {
            Mock -ModuleName PDS Get-WindowsCapability { }

            Enable-SshServer -ErrorVariable err -ErrorAction SilentlyContinue

            "$err" | Should -BeLike '*Failed to configure OpenSSH server:*not available*'
            Should -Invoke -ModuleName PDS Set-Service -Times 0
        }
    }

    Context 'when not elevated' -Skip:$script:isAdmin {
        It 'refuses to run and changes nothing' {
            Enable-SshServer -ErrorVariable err -ErrorAction SilentlyContinue

            "$err" | Should -BeLike '*requires administrator privileges*'
            Should -Invoke -ModuleName PDS Get-WindowsCapability -Times 0
            Should -Invoke -ModuleName PDS Set-Service -Times 0
        }
    }
}
