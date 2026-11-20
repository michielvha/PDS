BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    if (-not (Get-Command -Name New-LocalUser -ErrorAction SilentlyContinue)) {
        InModuleScope PDS {
            function script:Get-LocalUser {
                [CmdletBinding()]
                param ([string]$Name)
                $null = $Name
            }
            function script:New-LocalUser {
                [CmdletBinding()]
                param ([string]$Name, [securestring]$Password, [string]$FullName, [string]$Description, [switch]$AccountNeverExpires)
                $null = $Name, $Password, $FullName, $Description, $AccountNeverExpires
            }
            function script:Add-LocalGroupMember {
                [CmdletBinding()]
                param ([object]$Group, [object[]]$Member)
                $null = $Group, $Member
            }
        }
    }

    $secure = [System.Net.NetworkCredential]::new('', 'test-only-password').SecurePassword
    $script:credential = [pscredential]::new('pds-test-user', $secure)
}

Describe 'New-AdminLegacy' {
    BeforeEach {
        Mock Get-LocalUser -ModuleName PDS
        Mock New-LocalUser -ModuleName PDS
        Mock Add-LocalGroupMember -ModuleName PDS
        Mock Write-Host -ModuleName PDS
        Mock Write-Error -ModuleName PDS
    }

    It 'creates the user with default details and adds it to Administrators' {
        New-AdminLegacy -Credential $script:credential

        Should -Invoke New-LocalUser -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'pds-test-user' -and
            $FullName -eq 'pds-test-user' -and
            $Description -eq 'Local user account for pds-test-user' -and
            $AccountNeverExpires
        }
        Should -Invoke Add-LocalGroupMember -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Group.Name -eq 'Administrators' -and $Member.Name -contains 'pds-test-user'
        }
        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Object -like 'User pds-test-user created*'
        }
    }

    It 'uses the given full name and description' {
        New-AdminLegacy -Credential $script:credential -FullName 'Test User' -Description 'Test admin account'

        Should -Invoke New-LocalUser -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $FullName -eq 'Test User' -and $Description -eq 'Test admin account'
        }
    }

    It 'does nothing when the user already exists' {
        Mock Get-LocalUser -ModuleName PDS -MockWith { [pscustomobject]@{ Name = 'pds-test-user' } }

        New-AdminLegacy -Credential $script:credential

        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Object -eq 'User pds-test-user already exists.'
        }
        Should -Invoke New-LocalUser -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Add-LocalGroupMember -ModuleName PDS -Times 0 -Exactly
    }

    It 'writes an error when the user cannot be created' {
        Mock New-LocalUser -ModuleName PDS -MockWith { throw 'password does not meet policy' }

        New-AdminLegacy -Credential $script:credential

        Should -Invoke Write-Error -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like 'Failed to create user pds-test-user : *password does not meet policy*'
        }
        Should -Invoke Add-LocalGroupMember -ModuleName PDS -Times 0 -Exactly
    }

    It 'changes nothing under -WhatIf' {
        New-AdminLegacy -Credential $script:credential -WhatIf

        Should -Invoke New-LocalUser -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Add-LocalGroupMember -ModuleName PDS -Times 0 -Exactly
    }
}
