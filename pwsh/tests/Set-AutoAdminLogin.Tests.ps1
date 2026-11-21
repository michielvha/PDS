BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    $script:winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
}

Describe 'Set-AutoAdminLogin' {
    BeforeEach {
        Mock Set-ItemProperty -ModuleName PDS
        Mock Get-ItemProperty -ModuleName PDS -MockWith {
            [pscustomobject]@{
                DefaultUserName = 'devUser'
                DefaultPassword = 'stored'
                AutoAdminLogon  = '1'
            }
        }
    }

    It 'sets the user name, password and AutoAdminLogon' {
        $password = [System.Net.NetworkCredential]::new('', 'test-only-password').SecurePassword

        $result = Set-AutoAdminLogin -Username 'devUser' -Password $password

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq $script:winlogon -and $Name -eq 'DefaultUserName' -and $Value -eq 'devUser'
        }
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq $script:winlogon -and $Name -eq 'DefaultPassword' -and $Value -is [string] -and $Value -ceq 'test-only-password'
        }
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq $script:winlogon -and $Name -eq 'AutoAdminLogon' -and $Value -eq '1'
        }
        $result | Should -Contain 'setting devUser as DefaultUserName'
        $result | Should -Contain 'setting DefaultPassword'
    }

    It 'returns the resulting Winlogon settings' {
        $result = Set-AutoAdminLogin -Username 'devUser'

        Should -Invoke Get-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Path -eq $script:winlogon }
        $settings = $result | Where-Object { $_ -isnot [string] }
        $settings.DefaultUserName | Should -Be 'devUser'
        $settings.AutoAdminLogon | Should -Be '1'
    }

    It 'only enables AutoAdminLogon when no user or password is given' {
        $null = Set-AutoAdminLogin

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Name -eq 'AutoAdminLogon' }
    }

    It 'reports a failed user name write and still enables AutoAdminLogon' {
        Mock Set-ItemProperty -ModuleName PDS -ParameterFilter { $Name -eq 'DefaultUserName' } -MockWith { throw 'access denied' }

        $result = Set-AutoAdminLogin -Username 'devUser'

        $result | Should -Contain 'An error occurred while trying to set the `DefaultUserName`: access denied'
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Name -eq 'AutoAdminLogon' }
    }

    It 'reports a failed password write' {
        Mock Set-ItemProperty -ModuleName PDS -ParameterFilter { $Name -eq 'DefaultPassword' } -MockWith { throw 'access denied' }
        $password = [System.Net.NetworkCredential]::new('', 'test-only-password').SecurePassword

        $result = Set-AutoAdminLogin -Password $password

        $result | Should -Contain 'An error occurred while trying to set the `DefaultPassword`: access denied'
    }

    It 'changes nothing under -WhatIf' {
        $password = [System.Net.NetworkCredential]::new('', 'test-only-password').SecurePassword

        $null = Set-AutoAdminLogin -Username 'devUser' -Password $password -WhatIf

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 0 -Exactly
    }
}
