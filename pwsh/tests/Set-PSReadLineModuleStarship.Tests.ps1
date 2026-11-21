BeforeDiscovery {
    # Without administrator rights the function calls exit, which would end the test host, so
    # its tests run only when elevated.
    $script:isAdmin = $IsWindows -and ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    $script:allUsersProfile = Join-Path $TestDrive 'profile.ps1'
    $fakeProfile = Add-Member -InputObject (Join-Path $TestDrive 'user-profile.ps1') -NotePropertyName AllUsersAllHosts -NotePropertyValue $script:allUsersProfile -PassThru
    InModuleScope PDS -Parameters @{ FakeProfile = $fakeProfile } {
        param($FakeProfile)
        $script:PROFILE = $FakeProfile
    }
}

AfterAll {
    InModuleScope PDS { Remove-Variable -Name PROFILE -Scope Script -ErrorAction SilentlyContinue }
}

Describe 'Set-PSReadLineModuleStarship' -Skip:(-not $script:isAdmin) {
    BeforeEach {
        Remove-Item -Path $script:allUsersProfile -Force -ErrorAction SilentlyContinue
        Mock -ModuleName PDS Install-Module { }
        Mock -ModuleName PDS Start-Sleep { }
    }

    It 'installs PSReadLine and appends the Starship profile block' {
        $output = Set-PSReadLineModuleStarship

        $output | Should -Be 'PSReadLine Module will be installed'
        Should -Invoke -ModuleName PDS Install-Module -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'PSReadLine' -and $Force -and $SkipPublisherCheck
        }
        $content = Get-Content -Path $script:allUsersProfile -Raw
        $content | Should -BeLike '*Invoke-Expression (&starship init powershell)*'
        $content | Should -BeLike '*Import-Module -Name PDS*'
    }

    It 'appends again on a second run' {
        Set-PSReadLineModuleStarship | Out-Null
        Set-PSReadLineModuleStarship | Out-Null

        $hits = Select-String -Path $script:allUsersProfile -Pattern 'starship init powershell' -SimpleMatch
        $hits | Should -HaveCount 2
    }

    It 'changes nothing under -WhatIf' {
        Mock -ModuleName PDS Out-File { }

        Set-PSReadLineModuleStarship -WhatIf | Out-Null

        Should -Invoke -ModuleName PDS Install-Module -Times 0 -Exactly
        Should -Invoke -ModuleName PDS Out-File -Times 0 -Exactly
        $script:allUsersProfile | Should -Not -Exist
    }
}
