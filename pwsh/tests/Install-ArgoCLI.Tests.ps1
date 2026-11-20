BeforeDiscovery {
    # Install-ArgoCLI adds its bin directory to the persistent PATH through
    # [System.Environment]::SetEnvironmentVariable, which cannot be mocked. The tests that let
    # it reach that step run only where that PATH already holds the directory, so it writes
    # nothing.
    $binDir = "$env:USERPROFILE\AppData\Local\bin"
    $target = if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544') { 'Machine' } else { 'User' }
    $script:pathHasBinDir = $IsWindows -and ([System.Environment]::GetEnvironmentVariable('Path', $target) -like "*$binDir*")
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stub, so argocd can be mocked whether or not it is installed.
    InModuleScope PDS { function script:argocd { } }

    $script:binDir = "$env:USERPROFILE\AppData\Local\bin"
}

Describe 'Install-ArgoCLI' {
    BeforeEach {
        Mock -ModuleName PDS argocd { }
        Mock -ModuleName PDS Invoke-RestMethod { [pscustomobject]@{ tag_name = 'v2.13.1' } }
        Mock -ModuleName PDS Invoke-WebRequest { }
    }

    It 'checks the installed version and creates the bin directory when it is missing' {
        Mock -ModuleName PDS Test-Path { $false }
        # Stop the function here: the next step writes the persistent PATH.
        Mock -ModuleName PDS New-Item { throw 'stop before the PATH change' }

        { Install-ArgoCLI } | Should -Throw 'stop before the PATH change'

        Should -Invoke -ModuleName PDS argocd -Times 1 -Exactly -ParameterFilter { ($args -join ' ') -eq 'version --client' }
        Should -Invoke -ModuleName PDS New-Item -Times 1 -Exactly -ParameterFilter {
            $ItemType -eq 'Directory' -and $Path -eq $script:binDir
        }
        Should -Invoke -ModuleName PDS Invoke-WebRequest -Times 0
    }

    Context 'when the PATH already holds the bin directory' -Skip:(-not $script:pathHasBinDir) {
        BeforeEach {
            Mock -ModuleName PDS Test-Path { $true }
            Mock -ModuleName PDS New-Item { }
        }

        It 'downloads the latest release into the bin directory' {
            Install-ArgoCLI | Out-Null

            Should -Invoke -ModuleName PDS Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                "$Uri" -eq 'https://api.github.com/repos/argoproj/argo-cd/releases/latest'
            }
            Should -Invoke -ModuleName PDS Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                "$Uri" -eq 'https://github.com/argoproj/argo-cd/releases/download/v2.13.1/argocd-windows-amd64.exe' -and
                $OutFile -eq "$($script:binDir)\argocd.exe"
            }
            Should -Invoke -ModuleName PDS New-Item -Times 0
        }
    }
}
