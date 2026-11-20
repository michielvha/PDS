BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    $script:systemKey = 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment'
    $script:userKey = 'HKCU:\Environment'
}

Describe 'Update-Env' {
    BeforeEach {
        # Update-Env only changes variables of the current process, which AfterEach restores.
        $script:sessionPath = $env:Path
        Mock Write-Host -ModuleName PDS
        Mock Get-ItemProperty -ModuleName PDS -ParameterFilter { $Path -eq $script:systemKey } -MockWith {
            [pscustomobject]@{
                PDS_T21_SYSTEM = 'system-value'
                PDS_T21_SHARED = 'from-system'
                Path           = 'C:\Sys1;;C:\Sys2'
            }
        }
        Mock Get-ItemProperty -ModuleName PDS -ParameterFilter { $Path -eq $script:userKey } -MockWith {
            [pscustomobject]@{
                PDS_T21_USER   = 'user-value'
                PDS_T21_SHARED = 'from-user'
                Path           = 'C:\User1;'
            }
        }
    }

    AfterEach {
        $env:Path = $script:sessionPath
        foreach ($name in 'PDS_T21_SYSTEM', 'PDS_T21_USER', 'PDS_T21_SHARED') {
            Remove-Item -Path "Env:\$name" -ErrorAction SilentlyContinue
        }
    }

    It 'loads system and user variables into the session' {
        Update-Env

        Should -Invoke Get-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Path -eq $script:systemKey }
        Should -Invoke Get-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Path -eq $script:userKey }
        $env:PDS_T21_SYSTEM | Should -Be 'system-value'
        $env:PDS_T21_USER | Should -Be 'user-value'
    }

    It 'lets a user variable override the system variable of the same name' {
        Update-Env

        $env:PDS_T21_SHARED | Should -Be 'from-user'
    }

    It 'merges the system and user PATH without empty entries' {
        Update-Env

        $env:Path | Should -Be 'C:\Sys1;C:\Sys2;C:\User1'
    }

    It 'reports progress' {
        Update-Env

        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Object -eq 'Environment variables refreshed successfully!'
        }
    }
}
