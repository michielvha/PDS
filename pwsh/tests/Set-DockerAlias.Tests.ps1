BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Set-DockerAlias' {
    BeforeEach {
        # Shadow $PROFILE in the module scope with a TestDrive file, so the real profile is
        # never read or written.
        $script:profilePath = Join-Path $TestDrive "$([guid]::NewGuid())-profile.ps1"
        InModuleScope PDS -Parameters @{ Path = $script:profilePath } {
            param($Path)
            Set-Variable -Name PROFILE -Value $Path -Scope Script
        }
    }

    AfterEach {
        InModuleScope PDS { Remove-Variable -Name PROFILE -Scope Script -ErrorAction SilentlyContinue }
    }

    It 'adds the d, dcu and dcd functions to an empty profile' {
        $output = Set-DockerAlias

        (Get-Content -Path $script:profilePath) -join "`n" | Should -BeExactly (
            'function d { docker }',
            'function dcu { docker compose up -d }',
            'function dcd { docker compose down }' -join "`n")
        $output | Should -Contain 'Function d added to profile successfully.'
        $output | Should -Contain 'Function dcu added to profile successfully.'
        $output | Should -Contain 'Function dcd added to profile successfully.'
        $output[-1] | Should -Be 'Reload your profile or restart PowerShell for changes to take effect.'
    }

    It 'keeps existing profile content and skips functions that are already defined' {
        Set-Content -Path $script:profilePath -Value 'Set-Alias -Name ll -Value Get-ChildItem', 'function d { docker }'

        $output = Set-DockerAlias

        $output | Should -Contain 'Function d is already defined in the profile.'
        $output | Should -Contain 'Function dcu added to profile successfully.'
        $content = Get-Content -Path $script:profilePath
        $content[0] | Should -Be 'Set-Alias -Name ll -Value Get-ChildItem'
        @($content | Where-Object { $_ -eq 'function d { docker }' }).Count | Should -Be 1
        $content | Should -Contain 'function dcd { docker compose down }'
    }

    It 'adds nothing when run a second time' {
        Set-DockerAlias | Out-Null

        $output = Set-DockerAlias

        @(Get-Content -Path $script:profilePath).Count | Should -Be 3
        @($output | Where-Object { $_ -like '*is already defined in the profile.' }).Count | Should -Be 3
    }

    It 'changes nothing under -WhatIf' {
        Mock Add-Content -ModuleName PDS

        $output = Set-DockerAlias -WhatIf

        Should -Invoke Add-Content -ModuleName PDS -Times 0 -Exactly
        Test-Path -Path $script:profilePath | Should -BeFalse
        $output | Should -Not -Contain 'Function d added to profile successfully.'
    }
}
