BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    $script:originalUserProfile = $env:USERPROFILE
}

AfterAll {
    $env:USERPROFILE = $script:originalUserProfile
}

Describe 'Remove-ArgoCLI' {
    BeforeEach {
        # The function works under $env:USERPROFILE, so point it at TestDrive.
        $env:USERPROFILE = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:binDir = Join-Path $env:USERPROFILE 'AppData' 'Local' 'bin'
        $script:argo = Join-Path $script:binDir 'argocd.exe'
        New-Item -Path $script:binDir -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        $env:USERPROFILE = $script:originalUserProfile
    }

    It 'removes argocd.exe from the local bin directory' {
        Set-Content -LiteralPath $script:argo -Value 'binary'
        Set-Content -LiteralPath (Join-Path $script:binDir 'other.exe') -Value 'binary'

        $output = Remove-ArgoCLI

        $script:argo | Should -Not -Exist
        Join-Path $script:binDir 'other.exe' | Should -Exist
        $output | Should -BeNullOrEmpty
    }

    It 'reports that argocd was not installed by PDS when the file is missing' {
        $output = Remove-ArgoCLI

        $output | Should -BeLike '*argocd.exe directory doesn''t exist. ArgoCD CLI was not installed via PDS Module.'
    }

    It 'changes nothing under -WhatIf' {
        Set-Content -LiteralPath $script:argo -Value 'binary'
        Mock -ModuleName PDS Remove-Item { }

        Remove-ArgoCLI -WhatIf

        Should -Invoke -ModuleName PDS Remove-Item -Times 0 -Exactly
        $script:argo | Should -Exist
    }
}
