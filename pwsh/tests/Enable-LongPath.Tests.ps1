BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Enable-LongPath' {
    BeforeEach {
        Mock Test-Path -ModuleName PDS -MockWith { $true }
        Mock New-Item -ModuleName PDS
        Mock Set-ItemProperty -ModuleName PDS
        Mock Write-Error -ModuleName PDS
    }

    It 'sets LongPathsEnabled to 1 when the FileSystem key exists' {
        $result = Enable-LongPath

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -and
            $Name -eq 'LongPathsEnabled' -and
            $Value -eq 1
        }
        Should -Invoke New-Item -ModuleName PDS -Times 0 -Exactly
        $result | Should -Be 'Long paths enabled successfully.'
    }

    It 'creates the FileSystem key first when it is missing' {
        Mock Test-Path -ModuleName PDS -MockWith { $false }

        $result = Enable-LongPath

        Should -Invoke New-Item -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -and $Force
        }
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly
        $result | Should -Be @(
            'Registry path created: HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
            'Long paths enabled successfully.'
        )
    }

    It 'writes an error when the registry write fails' {
        Mock Set-ItemProperty -ModuleName PDS -MockWith { throw 'access denied' }

        $result = Enable-LongPath

        Should -Invoke Write-Error -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like 'Failed to set LongPathsEnabled: *access denied*'
        }
        $result | Should -BeNullOrEmpty
    }

    It 'still runs under its old name' {
        $command = Get-Command 'Enable-LongPaths' -Module PDS
        $command.CommandType | Should -Be 'Alias'
        $command.ResolvedCommandName | Should -Be 'Enable-LongPath'

        $result = Enable-LongPaths

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'LongPathsEnabled' -and $Value -eq 1
        }
        $result | Should -Be 'Long paths enabled successfully.'
    }
}
