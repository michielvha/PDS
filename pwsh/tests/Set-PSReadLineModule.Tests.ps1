BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Point $PROFILE and $PROFILE.AllUsersAllHosts at TestDrive for the module only.
    $script:allUsersProfile = Join-Path $TestDrive 'AllUsers' 'profile.ps1'
    $fakeProfile = Add-Member -InputObject (Join-Path $TestDrive 'profile.ps1') -NotePropertyName AllUsersAllHosts -NotePropertyValue $script:allUsersProfile -PassThru
    InModuleScope PDS -Parameters @{ FakeProfile = $fakeProfile } {
        param($FakeProfile)
        $script:PROFILE = $FakeProfile
    }
}

AfterAll {
    InModuleScope PDS { Remove-Variable -Name PROFILE -Scope Script -ErrorAction SilentlyContinue }
}

Describe 'Set-PSReadLineModule' {
    BeforeEach {
        Remove-Item -Path (Split-Path -Path $script:allUsersProfile -Parent) -Recurse -Force -ErrorAction SilentlyContinue
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS Install-Module { }
        Mock -ModuleName PDS Get-Module { [pscustomobject]@{ Name = 'PSReadLine' } } -ParameterFilter { $ListAvailable -and $Name -eq 'PSReadLine' }
    }

    It 'appends the PSReadLine configuration to the all-users profile' {
        Set-PSReadLineModule

        $content = Get-Content -Path $script:allUsersProfile -Raw
        $content | Should -BeLike '*# PSreadLine configuration*'
        $content | Should -BeLike '*Set-PSReadLineOption -PredictionViewStyle ListView*'
        Should -Invoke -ModuleName PDS Install-Module -Times 0 -Exactly
    }

    It 'installs PSReadLine when it is not available' {
        Mock -ModuleName PDS Get-Module { } -ParameterFilter { $ListAvailable -and $Name -eq 'PSReadLine' }

        Set-PSReadLineModule

        Should -Invoke -ModuleName PDS Install-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'PSReadLine' -and $Force }
        $script:allUsersProfile | Should -Exist
    }

    It 'stops without touching the profile when the install fails' {
        Mock -ModuleName PDS Get-Module { } -ParameterFilter { $ListAvailable -and $Name -eq 'PSReadLine' }
        Mock -ModuleName PDS Install-Module { throw 'module in use' }

        $warnings = Set-PSReadLineModule 3>&1

        $warnings | Should -BeLike '*Failed to install PSReadLine module*'
        $script:allUsersProfile | Should -Not -Exist
    }

    It 'changes nothing under -WhatIf' {
        Mock -ModuleName PDS Get-Module { } -ParameterFilter { $ListAvailable -and $Name -eq 'PSReadLine' }
        Mock -ModuleName PDS New-Item { }
        Mock -ModuleName PDS Out-File { }

        Set-PSReadLineModule -WhatIf

        Should -Invoke -ModuleName PDS Install-Module -Times 0 -Exactly
        Should -Invoke -ModuleName PDS New-Item -Times 0 -Exactly
        Should -Invoke -ModuleName PDS Out-File -Times 0 -Exactly
        $script:allUsersProfile | Should -Not -Exist
    }
}
