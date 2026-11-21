BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stub, so the real robocopy never runs even if a mock does not match.
    InModuleScope PDS { function script:robocopy { } }
}

Describe 'Clear-DirectoryContent' {
    BeforeEach {
        $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:target = Join-Path $script:root 'target'
        $script:tempPath = Join-Path $script:root 'empty'
        New-Item -Path $script:target -ItemType Directory -Force | Out-Null
        $script:tempExistedDuringCopy = $false
        $script:robocopyExitCode = 1

        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS Write-Warning { }
        Mock -ModuleName PDS robocopy {
            $script:tempExistedDuringCopy = Test-Path -LiteralPath $args[0]
            Set-Variable -Name LASTEXITCODE -Value $script:robocopyExitCode -Scope Global
        }
    }

    It 'mirrors an empty temporary directory onto the target and removes it afterwards' {
        Clear-DirectoryContent -Path $script:target -TempPath $script:tempPath

        Should -Invoke -ModuleName PDS robocopy -Times 1 -Exactly -ParameterFilter {
            $args[0] -eq $script:tempPath -and $args[1] -eq $script:target -and $args[2] -eq '/MIR'
        }
        $script:tempExistedDuringCopy | Should -BeTrue
        $script:tempPath | Should -Not -Exist
        Should -Invoke -ModuleName PDS Write-Warning -Times 0
    }

    It 'warns when robocopy reports a failure exit code' {
        $script:robocopyExitCode = 8

        Clear-DirectoryContent -Path $script:target -TempPath $script:tempPath

        Should -Invoke -ModuleName PDS Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like 'Robocopy returned exit code 8*' }
        $script:tempPath | Should -Not -Exist
    }

    It 'removes the temporary directory and rethrows when robocopy fails' {
        Mock -ModuleName PDS robocopy { throw 'robocopy crashed' }

        { Clear-DirectoryContent -Path $script:target -TempPath $script:tempPath } | Should -Throw '*robocopy crashed*'

        $script:tempPath | Should -Not -Exist
        $script:target | Should -Exist
    }
}
