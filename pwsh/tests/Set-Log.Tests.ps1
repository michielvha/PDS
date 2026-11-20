BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    $script:originalUserProfile = $env:USERPROFILE
    $script:entryPattern = '^\d{4}-\d{2}-\d{2} \| \d{2}:\d{2}:\d{2} : '
}

AfterAll {
    $env:USERPROFILE = $script:originalUserProfile
}

Describe 'Set-Log' {
    BeforeEach {
        # The log is written under $env:USERPROFILE, so point it at TestDrive.
        $env:USERPROFILE = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -Path $env:USERPROFILE -ItemType Directory | Out-Null
        Mock -ModuleName PDS Write-Host { }
    }

    AfterEach {
        $env:USERPROFILE = $script:originalUserProfile
        InModuleScope PDS { $script:LogProjectName = $env:COMPUTERNAME }
    }

    It 'appends a timestamped entry to the project log and echoes it' {
        Set-Log -Message 'first' -ProjectName 'Proj'
        Set-Log -Message 'second' -ProjectName 'Proj'

        $log = Get-Content -LiteralPath (Join-Path $env:USERPROFILE 'Proj-log.txt')
        $log | Should -HaveCount 2
        $log[0] | Should -Match ($script:entryPattern + 'first$')
        $log[1] | Should -Match ($script:entryPattern + 'second$')
        Should -Invoke -ModuleName PDS Write-Host -Times 1 -Exactly -ParameterFilter { $Object -match ($script:entryPattern + 'first$') }
    }

    It 'uses the computer name as the default project' {
        Set-Log 'default project'

        Get-Content -LiteralPath (Join-Path $env:USERPROFILE "$env:COMPUTERNAME-log.txt") | Should -Match ($script:entryPattern + 'default project$')
    }

    It 'uses the project set by Set-LogProject' {
        # Set-LogProject lives in Set-Log.ps1 but is not exported, so it is called in module scope.
        InModuleScope PDS { Set-LogProject -ProjectName 'WebApp' }

        Set-Log 'after switching'

        Get-Content -LiteralPath (Join-Path $env:USERPROFILE 'WebApp-log.txt') | Should -Match ($script:entryPattern + 'after switching$')
        Join-Path $env:USERPROFILE "$env:COMPUTERNAME-log.txt" | Should -Not -Exist
    }
}
