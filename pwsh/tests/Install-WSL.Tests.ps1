BeforeDiscovery {
    # The function checks elevation through .NET, which cannot be mocked, so each test runs only
    # under the elevation it needs.
    $script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # A module-scope stub shadows wsl.exe, so the real executable never runs even if a mock is missed.
    InModuleScope PDS { function script:wsl { } }
}

Describe 'Install-WSL' {
    BeforeEach {
        Mock Get-WindowsOptionalFeature -ModuleName PDS -MockWith { [pscustomobject]@{ State = 'Enabled' } }
        Mock Enable-WindowsOptionalFeature -ModuleName PDS
        Mock wsl -ModuleName PDS
        Mock Write-Warning -ModuleName PDS
        Mock Write-Error -ModuleName PDS
    }

    It 'lists the online distributions when no distro is given' -Skip:(-not $script:isAdmin) {
        $result = Install-WSL

        $result | Should -Be 'This function is a wrapper for installing WSL. Call it with any distro listed below.'
        Should -Invoke wsl -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq '--list --online'
        }
        Should -Invoke Enable-WindowsOptionalFeature -ModuleName PDS -Times 0 -Exactly
    }

    It 'installs each requested distro' -Skip:(-not $script:isAdmin) {
        $null = Install-WSL -distros 'Ubuntu', 'Debian'

        Should -Invoke wsl -ModuleName PDS -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq '--install -d Ubuntu' }
        Should -Invoke wsl -ModuleName PDS -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq '--install -d Debian' }
    }

    It 'enables Virtual Machine Platform and WSL when they are disabled' -Skip:(-not $script:isAdmin) {
        Mock Get-WindowsOptionalFeature -ModuleName PDS -MockWith { [pscustomobject]@{ State = 'Disabled' } }

        $null = Install-WSL

        Should -Invoke Enable-WindowsOptionalFeature -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Online -and $NoRestart -and $FeatureName -eq 'VirtualMachinePlatform'
        }
        Should -Invoke Enable-WindowsOptionalFeature -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Online -and $NoRestart -and $FeatureName -eq 'Microsoft-Windows-Subsystem-Linux'
        }
        Should -Invoke wsl -ModuleName PDS -Times 1 -Exactly
    }

    It 'stops when enabling Virtual Machine Platform fails' -Skip:(-not $script:isAdmin) {
        Mock Get-WindowsOptionalFeature -ModuleName PDS -MockWith { [pscustomobject]@{ State = 'Disabled' } }
        Mock Enable-WindowsOptionalFeature -ModuleName PDS -MockWith { throw 'dism failed' }

        $null = Install-WSL -distros 'Ubuntu'

        Should -Invoke Write-Error -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like 'Failed to enable Virtual Machine Platform: *dism failed*'
        }
        Should -Invoke wsl -ModuleName PDS -Times 0 -Exactly
    }

    It 'refuses to run without elevation' -Skip:$script:isAdmin {
        $null = Install-WSL -distros 'Ubuntu'

        Should -Invoke Write-Warning -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like '*requires administrative privileges*'
        }
        Should -Invoke wsl -ModuleName PDS -Times 0 -Exactly
    }
}
