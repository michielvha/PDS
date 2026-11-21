BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The test machine has no RemoteDesktop module, so its command is stubbed in module scope
    # and mocked per test. The stub is created from a string so the analyzer does not report its
    # unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Set-RDSessionHost { [CmdletBinding()] param($SessionHost, $NewConnectionAllowed) }
'@))
    }
}

Describe 'Enable-RDSHost' {
    BeforeAll {
        Mock Import-Module -ModuleName PDS -ParameterFilter { $Name -contains 'RemoteDesktop' }
        Mock Get-Module -ModuleName PDS
        Mock Write-Host -ModuleName PDS
        Mock Set-RDSessionHost -ModuleName PDS
    }

    It 'allows new connections on each named host' {
        Enable-RDSHost -ServerNames 'rdsh01', 'rdsh02'

        Should -Invoke Import-Module -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Name -contains 'RemoteDesktop' }
        Should -Invoke Set-RDSessionHost -ModuleName PDS -Times 2 -Exactly
        Should -Invoke Set-RDSessionHost -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $SessionHost -eq 'rdsh02' -and $NewConnectionAllowed -eq 'Yes'
        }
    }

    It 'reads the hosts from -ConfigPath' {
        $config = Join-Path $TestDrive 'hosts.txt'
        Set-Content -Path $config -Value 'rdsh03', 'rdsh04', 'rdsh05'

        Enable-RDSHost -ConfigPath $config

        Should -Invoke Set-RDSessionHost -ModuleName PDS -Times 3 -Exactly
        Should -Invoke Set-RDSessionHost -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $SessionHost -eq 'rdsh05' }
    }

    It 'reports a failed host and carries on with the others' {
        Mock Set-RDSessionHost -ModuleName PDS -ParameterFilter { $SessionHost -eq 'rdsh01' } { throw 'host unreachable' }

        Enable-RDSHost -ServerNames 'rdsh01', 'rdsh02' -ErrorVariable errors -ErrorAction SilentlyContinue

        "$errors" | Should -Match 'Failed to enable connections on rdsh01'
        Should -Invoke Set-RDSessionHost -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $SessionHost -eq 'rdsh02' }
    }

    It 'errors when no host is given' {
        Enable-RDSHost -ErrorVariable errors -ErrorAction SilentlyContinue

        "$errors" | Should -Match 'No server names provided'
        Should -Invoke Set-RDSessionHost -ModuleName PDS -Times 0 -Exactly
    }

    It 'stops when the RemoteDesktop module cannot be loaded' {
        Mock Import-Module -ModuleName PDS -ParameterFilter { $Name -contains 'RemoteDesktop' } { throw 'module not found' }

        Enable-RDSHost -ServerNames 'rdsh01' -ErrorVariable errors -ErrorAction SilentlyContinue

        "$errors" | Should -Match 'Failed to import the RemoteDesktop module'
        Should -Invoke Set-RDSessionHost -ModuleName PDS -Times 0 -Exactly
    }

    It 'still runs under its old name' {
        $old = Get-Command 'Enable-RDSHosts' -Module PDS
        $old.CommandType | Should -Be 'Alias'
        $old.ResolvedCommand.Name | Should -Be 'Enable-RDSHost'

        & $old -ServerNames 'rdsh01'

        Should -Invoke Set-RDSessionHost -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $SessionHost -eq 'rdsh01' }
    }
}
