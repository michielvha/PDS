BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Set-DefaultProfile' {
    It 'appends the commands to the all-users profile' {
        Mock Out-File -ModuleName PDS
        $expected = $PROFILE.AllUsersAllHosts

        Set-DefaultProfile -Commands 'Set-Alias ll Get-ChildItem'

        Should -Invoke Out-File -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $expected -and
            $InputObject -eq 'Set-Alias ll Get-ChildItem' -and
            $Append -and
            "$Encoding" -match 'utf-?8'
        }
    }

    Context 'with the profile path redirected to TestDrive' {
        BeforeEach {
            # A module-scope $PROFILE shadows the global one for the function, so the real
            # all-users profile is never touched.
            $script:target = Join-Path $TestDrive 'profile.ps1'
            InModuleScope PDS -Parameters @{ Target = $script:target } {
                param ($Target)
                $script:PROFILE = [pscustomobject]@{ AllUsersAllHosts = $Target }
            }
        }

        AfterEach {
            InModuleScope PDS { Remove-Variable -Name PROFILE -Scope Script -ErrorAction SilentlyContinue }
        }

        It 'keeps existing profile content and adds each call at the end' {
            Set-Content -Path $script:target -Value '# existing'

            Set-DefaultProfile -Commands 'Import-Module PSReadLine'
            Set-DefaultProfile -Commands 'Set-PSReadLineOption -PredictionViewStyle ListView'

            Get-Content -Path $script:target | Should -Be @(
                '# existing'
                'Import-Module PSReadLine'
                'Set-PSReadLineOption -PredictionViewStyle ListView'
            )
        }
    }

    It 'changes nothing under -WhatIf' {
        Mock Out-File -ModuleName PDS

        Set-DefaultProfile -Commands 'Set-Alias ll Get-ChildItem' -WhatIf

        Should -Invoke Out-File -ModuleName PDS -Times 0 -Exactly
    }
}
