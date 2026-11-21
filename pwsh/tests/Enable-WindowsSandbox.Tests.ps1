BeforeDiscovery {
    # The function checks elevation through .NET, which cannot be mocked, so each test runs only
    # under the elevation it needs.
    $script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Enable-WindowsSandbox' {
    BeforeEach {
        Mock Get-WindowsOptionalFeature -ModuleName PDS -MockWith { [pscustomobject]@{ State = 'Disabled' } }
        Mock Enable-WindowsOptionalFeature -ModuleName PDS -MockWith { [pscustomobject]@{ RestartNeeded = $false } }
        Mock Write-Warning -ModuleName PDS
        Mock Write-Error -ModuleName PDS
    }

    It 'does nothing when Windows Sandbox is already enabled' -Skip:(-not $script:isAdmin) {
        Mock Get-WindowsOptionalFeature -ModuleName PDS -MockWith { [pscustomobject]@{ State = 'Enabled' } }

        $result = Enable-WindowsSandbox

        $result | Should -Be 'Windows Sandbox is already enabled.'
        Should -Invoke Get-WindowsOptionalFeature -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Online -and $FeatureName -eq 'Containers-DisposableClientVM'
        }
        Should -Invoke Enable-WindowsOptionalFeature -ModuleName PDS -Times 0 -Exactly
    }

    It 'enables the feature without restarting when it is disabled' -Skip:(-not $script:isAdmin) {
        $result = Enable-WindowsSandbox

        Should -Invoke Enable-WindowsOptionalFeature -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Online -and $NoRestart -and $FeatureName -eq 'Containers-DisposableClientVM'
        }
        $result | Should -Be @(
            'Enabling Windows Sandbox feature...'
            'Windows Sandbox has been successfully enabled.'
        )
        Should -Invoke Write-Warning -ModuleName PDS -Times 0 -Exactly
    }

    It 'warns when a restart is needed' -Skip:(-not $script:isAdmin) {
        Mock Enable-WindowsOptionalFeature -ModuleName PDS -MockWith { [pscustomobject]@{ RestartNeeded = $true } }

        $result = Enable-WindowsSandbox

        $result | Should -Contain 'Windows Sandbox has been enabled.'
        Should -Invoke Write-Warning -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like 'A system restart is required*'
        }
    }

    It 'writes an error and rethrows when the feature query fails' -Skip:(-not $script:isAdmin) {
        Mock Get-WindowsOptionalFeature -ModuleName PDS -MockWith { throw 'feature query failed' }

        { Enable-WindowsSandbox } | Should -Throw '*feature query failed*'
        Should -Invoke Write-Error -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like 'Failed to enable Windows Sandbox: *'
        }
        Should -Invoke Enable-WindowsOptionalFeature -ModuleName PDS -Times 0 -Exactly
    }

    It 'refuses to run without elevation' -Skip:$script:isAdmin {
        Enable-WindowsSandbox

        Should -Invoke Write-Error -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like '*requires administrative privileges*'
        }
        Should -Invoke Get-WindowsOptionalFeature -ModuleName PDS -Times 0 -Exactly
    }
}
