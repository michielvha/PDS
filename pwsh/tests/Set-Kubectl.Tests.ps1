BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stubs, so the CLIs can be mocked whether or not they are installed; no cluster is needed.
    InModuleScope PDS {
        function script:kubectl { }
        function script:choco { }
    }
}

AfterAll {
    InModuleScope PDS { Remove-Variable -Name PROFILE -Scope Script -ErrorAction SilentlyContinue }
}

Describe 'Set-Kubectl' {
    BeforeEach {
        # The function appends to $PROFILE. A module-scope variable shadows the global one, so
        # the writes land in TestDrive.
        $script:profilePath = Join-Path $TestDrive "$([guid]::NewGuid())_profile.ps1"
        InModuleScope PDS -Parameters @{ Path = $script:profilePath } {
            param($Path)
            $script:PROFILE = $Path
        }

        $script:krewVersion = $null
        $script:sternVersion = $null
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS choco { }
        Mock -ModuleName PDS kubectl {
            switch ($args -join ' ') {
                'krew version' { $script:krewVersion }
                'stern -v' { $script:sternVersion }
                'completion powershell' { '# kubectl completion script' }
            }
        }
    }

    It 'installs krew and stern when they are missing and configures the profile' {
        Set-Kubectl

        Should -Invoke -ModuleName PDS choco -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'install krew -y' }
        Should -Invoke -ModuleName PDS kubectl -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'krew install stern' }
        $profileContent = Get-Content -LiteralPath $script:profilePath
        $profileContent | Should -Contain '# kubectl completion script'
        $profileContent | Should -Contain 'Set-Alias -Name k -Value kubectl'
        $profileContent | Should -Contain 'Register-ArgumentCompleter -CommandName k -ScriptBlock $__kubectlCompleterBlock'
    }

    It 'installs nothing and does not add the alias twice when everything is set up' {
        $script:krewVersion = 'v0.4.4'
        $script:sternVersion = 'version: 1.30.0'
        Set-Content -LiteralPath $script:profilePath -Value 'Set-Alias -Name k -Value kubectl'

        Set-Kubectl

        Should -Invoke -ModuleName PDS choco -Times 0
        Should -Invoke -ModuleName PDS kubectl -Times 0 -ParameterFilter { $args -contains 'install' }
        Should -Invoke -ModuleName PDS Write-Host -Times 1 -Exactly -ParameterFilter { $Object -eq 'Alias already set in profile' }
        Get-Content -LiteralPath $script:profilePath | Where-Object { $_ -eq 'Set-Alias -Name k -Value kubectl' } | Should -HaveCount 1
    }
}
