BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    # Connect-AzAccount comes from Az.Accounts, which the test machine need not have; Pester
    # can only mock a command that exists, so give the module a stub to mock.
    InModuleScope PDS { function script:Connect-AzAccount { } }
}

Describe 'New-AzSession' {
    BeforeEach {
        Mock Set-ExecutionPolicy -ModuleName PDS { }
        Mock Install-Module -ModuleName PDS { }
        Mock Connect-AzAccount -ModuleName PDS { }
    }

    It 'installs Az for the current user from PSGallery and signs in' {
        New-AzSession 6>$null

        Should -Invoke Set-ExecutionPolicy -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $ExecutionPolicy -eq 'RemoteSigned' -and $Scope -eq 'CurrentUser'
        }
        Should -Invoke Install-Module -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'Az' -and $Scope -eq 'CurrentUser' -and $Repository -eq 'PSGallery' -and $Force
        }
        Should -Invoke Connect-AzAccount -ModuleName PDS -Times 1 -Exactly
    }

    It 'does not sign in when installing Az fails' {
        Mock Install-Module -ModuleName PDS { throw 'No match was found for the specified search criteria.' }

        { New-AzSession 6>$null } | Should -Throw '*No match was found*'
        Should -Invoke Connect-AzAccount -ModuleName PDS -Times 0 -Exactly
    }

    It 'changes nothing under -WhatIf' {
        New-AzSession -WhatIf 6>$null

        Should -Invoke Set-ExecutionPolicy -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Install-Module -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Connect-AzAccount -ModuleName PDS -Times 0 -Exactly
    }
}
