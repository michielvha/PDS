BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Set-UserProfile' {
    BeforeEach {
        $script:profilePath = Join-Path $TestDrive 'profile.ps1'
        Remove-Item -Path $script:profilePath -Force -ErrorAction SilentlyContinue
    }

    It 'creates the profile and adds the default lines' {
        Set-UserProfile -ProfilePath $script:profilePath

        Get-Content -Path $script:profilePath | Should -Be @(
            'Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1',
            'Import-Module PDS'
        )
    }

    It 'adds only lines that are not already present' {
        Set-Content -Path $script:profilePath -Value 'Set-Alias ll Get-ChildItem'

        Set-UserProfile -ProfilePath $script:profilePath -Lines @('Set-Alias ll Get-ChildItem', 'Import-Module PDS')

        Get-Content -Path $script:profilePath | Should -Be @('Set-Alias ll Get-ChildItem', 'Import-Module PDS')
    }

    It 'is idempotent when run twice' {
        Set-UserProfile -ProfilePath $script:profilePath -Lines 'Import-Module PDS'
        Set-UserProfile -ProfilePath $script:profilePath -Lines 'Import-Module PDS'

        Get-Content -Path $script:profilePath | Should -HaveCount 1
    }

    It 'treats regex characters in a line literally' {
        Set-Content -Path $script:profilePath -Value 'Import-Module PDSX'

        Set-UserProfile -ProfilePath $script:profilePath -Lines 'Import-Module (PDS)'

        Get-Content -Path $script:profilePath | Should -Contain 'Import-Module (PDS)'
    }

    It 'changes nothing under -WhatIf' {
        Mock -ModuleName PDS New-Item { }
        Mock -ModuleName PDS Add-Content { }

        Set-UserProfile -ProfilePath $script:profilePath -WhatIf

        Should -Invoke -ModuleName PDS New-Item -Times 0 -Exactly
        Should -Invoke -ModuleName PDS Add-Content -Times 0 -Exactly
        $script:profilePath | Should -Not -Exist
    }
}
