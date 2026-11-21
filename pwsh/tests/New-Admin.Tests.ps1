BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # New-Admin works through System.DirectoryServices.AccountManagement, whose static lookups
    # cannot be mocked. The lookup is read-only; creating the UserPrincipal goes through New-Object,
    # which these tests replace with a mock that throws, so no account is ever created.
    function Get-TestCredential {
        param ([string]$UserName)
        $secure = [System.Net.NetworkCredential]::new('', 'test-only-password').SecurePassword
        [pscredential]::new($UserName, $secure)
    }
}

Describe 'New-Admin' {
    BeforeEach {
        # Every other New-Object call, such as the PrincipalContext, goes to the real cmdlet.
        Mock New-Object -ModuleName PDS -MockWith { Microsoft.PowerShell.Utility\New-Object @PesterBoundParameters }
        Mock New-Object -ModuleName PDS -ParameterFilter {
            $TypeName -eq 'System.DirectoryServices.AccountManagement.UserPrincipal'
        } -MockWith { throw 'account creation blocked by test' }
        Mock Write-Host -ModuleName PDS
        Mock Write-Error -ModuleName PDS
    }

    It 'does nothing when the user already exists' {
        New-Admin -Credential (Get-TestCredential -UserName $env:USERNAME)

        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Object -eq "User $env:USERNAME already exists."
        }
        Should -Invoke New-Object -ModuleName PDS -Times 0 -Exactly -ParameterFilter {
            $TypeName -eq 'System.DirectoryServices.AccountManagement.UserPrincipal'
        }
        Should -Invoke Write-Error -ModuleName PDS -Times 0 -Exactly
    }

    It 'goes on to create a user that does not exist' {
        $userName = 'pdst21x{0}' -f (Get-Random -Minimum 10000 -Maximum 99999)

        New-Admin -Credential (Get-TestCredential -UserName $userName)

        Should -Invoke New-Object -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $TypeName -eq 'System.DirectoryServices.AccountManagement.UserPrincipal'
        }
        Should -Invoke Write-Error -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like "Failed to create user $userName : *account creation blocked by test*"
        }
        Get-LocalUser $userName -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'changes nothing under -WhatIf' {
        $userName = 'pdst23x{0}' -f (Get-Random -Minimum 10000 -Maximum 99999)

        New-Admin -Credential (Get-TestCredential -UserName $userName) -WhatIf

        Should -Invoke New-Object -ModuleName PDS -Times 0 -Exactly -ParameterFilter {
            $TypeName -eq 'System.DirectoryServices.AccountManagement.UserPrincipal'
        }
        Should -Invoke Write-Error -ModuleName PDS -Times 0 -Exactly
        Get-LocalUser $userName -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}
