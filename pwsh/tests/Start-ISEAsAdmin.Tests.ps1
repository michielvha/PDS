BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Start-ISEAsAdmin' {
    BeforeEach {
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'powershell_ise.exe' } {
            [pscustomobject]@{ Name = 'powershell_ise.exe' }
        }
        # Never start a process, elevated or not.
        Mock Start-Process -ModuleName PDS { [pscustomobject]@{ Id = 4242; ProcessName = 'powershell_ise' } }
    }

    It 'starts ISE elevated and returns the process' {
        $process = Start-ISEAsAdmin

        $process.Id | Should -Be 4242
        Should -Invoke Start-Process -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq 'powershell_ise.exe' -and $Verb -eq 'runas' -and -not $ArgumentList -and -not $Wait
        }
    }

    It 'opens an existing file and quotes its path' {
        $file = Join-Path $TestDrive 'my script.ps1'
        Set-Content -Path $file -Value '# test'

        Start-ISEAsAdmin -FilePath $file | Out-Null

        Should -Invoke Start-Process -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $ArgumentList -eq "`"$file`"" -and $Verb -eq 'runas'
        }
    }

    It 'waits for ISE and returns nothing with -Wait' {
        $result = Start-ISEAsAdmin -Wait

        $result | Should -BeNullOrEmpty
        Should -Invoke Start-Process -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Wait }
    }

    It 'writes an error and starts nothing when ISE is not installed' {
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'powershell_ise.exe' } { }

        Start-ISEAsAdmin -ErrorAction SilentlyContinue -ErrorVariable iseError

        $iseError[0].Exception.Message | Should -BeLike 'PowerShell ISE (powershell_ise.exe) not found*'
        Should -Invoke Start-Process -ModuleName PDS -Times 0 -Exactly
    }

    It 'writes an error when the elevated start fails' {
        Mock Start-Process -ModuleName PDS { throw 'The operation was canceled by the user.' }

        Start-ISEAsAdmin -ErrorAction SilentlyContinue -ErrorVariable iseError

        $iseError[-1].Exception.Message | Should -BeLike 'Failed to start PowerShell ISE: *canceled by the user*'
    }

    It 'changes nothing under -WhatIf' {
        $result = Start-ISEAsAdmin -WhatIf

        $result | Should -BeNullOrEmpty
        Should -Invoke Start-Process -ModuleName PDS -Times 0 -Exactly
    }
}
