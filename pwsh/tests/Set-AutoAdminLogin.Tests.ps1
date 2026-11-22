BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    $script:winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $script:passwordLess = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'
}

Describe 'Set-AutoAdminLogin' {
    BeforeEach {
        Mock Set-ItemProperty -ModuleName PDS
        Mock Remove-ItemProperty -ModuleName PDS
        Mock Test-Path -ModuleName PDS -MockWith { $true }
        Mock Set-AutoLogonSecret -ModuleName PDS
        Mock Test-AutoLogonCredential -ModuleName PDS -MockWith { $true }
        Mock Write-Error -ModuleName PDS
        $script:password = [System.Net.NetworkCredential]::new('', 'test-only-password').SecurePassword
    }

    It 'checks the password, then sets the account, the LSA secret and AutoAdminLogon' {
        $result = Set-AutoAdminLogin -Username 'tester' -Password $script:password -Domain 'HOST'

        Should -Invoke Test-AutoLogonCredential -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Credential.UserName -eq 'tester' -and $Credential.GetNetworkCredential().Password -ceq 'test-only-password' -and $Domain -eq 'HOST'
        }
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq $script:winlogon -and $Name -eq 'DefaultUserName' -and $Value -eq 'tester'
        }
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq $script:winlogon -and $Name -eq 'DefaultDomainName' -and $Value -eq 'HOST'
        }
        Should -Invoke Set-AutoLogonSecret -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Value -ceq 'test-only-password' }
        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq $script:winlogon -and $Name -eq 'AutoAdminLogon' -and $Value -eq '1'
        }
        $result | Should -Be 'HOST\tester signs in automatically from the next startup.'
    }

    It 'never writes the password to the registry and removes a plain-text copy' {
        $null = Set-AutoAdminLogin -Username 'tester' -Password $script:password

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 0 -Exactly -ParameterFilter { $Name -eq 'DefaultPassword' }
        Should -Invoke Remove-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq $script:winlogon -and $Name -eq 'DefaultPassword'
        }
    }

    It 'allows password sign-in when only Windows Hello sign-in is allowed' {
        $null = Set-AutoAdminLogin -Username 'tester' -Password $script:password

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq $script:passwordLess -and $Name -eq 'DevicePasswordLessBuildVersion' -and $Value -eq 0
        }
    }

    It 'stores an empty secret for an account without a password' {
        $null = Set-AutoAdminLogin -Username 'tester'

        Should -Invoke Set-AutoLogonSecret -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Value -eq '' }
    }

    It 'changes nothing when the password is not accepted' {
        Mock Test-AutoLogonCredential -ModuleName PDS -MockWith { $false }

        $result = Set-AutoAdminLogin -Username 'tester' -Password $script:password -Domain 'HOST'

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Set-AutoLogonSecret -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Write-Error -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -eq 'The password for HOST\tester was not accepted, so automatic sign-in was not changed.'
        }
        $result | Should -BeNullOrEmpty
    }

    It 'turns automatic sign-in off and deletes the stored password with -Disable' {
        $result = Set-AutoAdminLogin -Disable

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Path -eq $script:winlogon -and $Name -eq 'AutoAdminLogon' -and $Value -eq '0'
        }
        Should -Invoke Set-AutoLogonSecret -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $null -eq $Value }
        Should -Invoke Remove-ItemProperty -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Name -eq 'DefaultPassword' }
        $result | Should -Be 'Automatic sign-in is off and no password is stored.'
    }

    It 'changes nothing under -WhatIf' {
        $null = Set-AutoAdminLogin -Username 'tester' -Password $script:password -WhatIf
        $null = Set-AutoAdminLogin -Disable -WhatIf

        Should -Invoke Set-ItemProperty -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Remove-ItemProperty -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Set-AutoLogonSecret -ModuleName PDS -Times 0 -Exactly
    }

    It 'requires a user name unless it is disabling' {
        (Get-Command Set-AutoAdminLogin).ParameterSets.Name | Should -Be @('Enable', 'Disable')
        { Set-AutoAdminLogin -Username '' } | Should -Throw
    }
}
