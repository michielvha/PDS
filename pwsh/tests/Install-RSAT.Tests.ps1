BeforeDiscovery {
    # Install-RSAT checks elevation through .NET, which cannot be mocked, so the tests for each
    # path run only where the session matches it.
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $script:isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The capability commands are stubbed in module scope, where they shadow the real DISM
    # cmdlets, so no test can install anything. The stubs are created from a string so the
    # analyzer does not report their unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Get-WindowsCapability { [CmdletBinding()] param([switch]$Online, $Name) }
function script:Add-WindowsCapability { [CmdletBinding()] param([switch]$Online, $Name) }
'@))
    }
}

Describe 'Install-RSAT' {
    BeforeAll {
        Mock Write-Host -ModuleName PDS
        Mock Get-CimInstance -ModuleName PDS -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } {
            [pscustomobject]@{ Caption = 'Microsoft Windows 11 Pro'; Version = '10.0.26100' }
        }
        Mock Get-WindowsCapability -ModuleName PDS {
            [pscustomobject]@{ Name = 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'; State = 'NotPresent' }
            [pscustomobject]@{ Name = 'Rsat.Dns.Tools~~~~0.0.1.0'; State = 'Installed' }
            [pscustomobject]@{ Name = 'Rsat.DHCP.Tools~~~~0.0.1.0'; State = 'NotPresent' }
        }
        Mock Add-WindowsCapability -ModuleName PDS { [pscustomobject]@{ RestartNeeded = $false } }
    }

    Context 'as an administrator' -Skip:(-not $script:isAdmin) {
        It 'installs only the requested feature' {
            Install-RSAT -Feature AD

            Should -Invoke Add-WindowsCapability -ModuleName PDS -Times 1 -Exactly
            Should -Invoke Add-WindowsCapability -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
                $Online -and $Name -eq 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'
            }
        }

        It 'installs every missing feature and skips installed ones for All' {
            Install-RSAT

            Should -Invoke Add-WindowsCapability -ModuleName PDS -Times 2 -Exactly
            Should -Invoke Add-WindowsCapability -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Name -like 'Rsat.Dns.Tools*' }
        }

        It 'reinstalls an installed feature with -Force' {
            Install-RSAT -Feature DNS -Force

            Should -Invoke Add-WindowsCapability -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Name -like 'Rsat.Dns.Tools*' }
        }

        It 'refuses a Windows Home edition' {
            Mock Get-CimInstance -ModuleName PDS -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } {
                [pscustomobject]@{ Caption = 'Microsoft Windows 11 Home'; Version = '10.0.26100' }
            }

            Install-RSAT -ErrorVariable errors -ErrorAction SilentlyContinue

            "$errors" | Should -Match 'not available for Windows Home'
            Should -Invoke Get-WindowsCapability -ModuleName PDS -Times 0 -Exactly
        }

        It 'refuses an operating system other than Windows 10 or 11' {
            Mock Get-CimInstance -ModuleName PDS -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } {
                [pscustomobject]@{ Caption = 'Microsoft Windows Server 2022 Standard'; Version = '10.0.20348' }
            }

            Install-RSAT -ErrorVariable errors -ErrorAction SilentlyContinue

            "$errors" | Should -Match 'requires Windows 10 version 1809 or later'
            Should -Invoke Add-WindowsCapability -ModuleName PDS -Times 0 -Exactly
        }

        It 'warns when no RSAT feature is available' {
            Mock Get-WindowsCapability -ModuleName PDS { }

            Install-RSAT -WarningVariable warnings -WarningAction SilentlyContinue

            "$warnings" | Should -Match 'No RSAT features found'
            Should -Invoke Add-WindowsCapability -ModuleName PDS -Times 0 -Exactly
        }
    }

    Context 'without elevation' -Skip:$script:isAdmin {
        It 'stops before touching the system' {
            Install-RSAT -ErrorVariable errors -ErrorAction SilentlyContinue

            "$errors" | Should -Match 'requires administrative privileges'
            Should -Invoke Get-CimInstance -ModuleName PDS -Times 0 -Exactly
            Should -Invoke Add-WindowsCapability -ModuleName PDS -Times 0 -Exactly
        }
    }
}
