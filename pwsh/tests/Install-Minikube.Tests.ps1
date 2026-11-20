BeforeDiscovery {
    # Install-Minikube adds C:\minikube to the machine PATH through
    # [Environment]::SetEnvironmentVariable, which cannot be mocked. The test that lets it reach
    # that step runs only where the machine PATH already holds C:\minikube, so it writes nothing.
    $script:pathHasMinikube = $IsWindows -and ([Environment]::GetEnvironmentVariable('Path', 'Machine').Split(';') -contains 'C:\minikube')
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Install-Minikube' {
    BeforeEach {
        Mock -ModuleName PDS New-Item { }
        Mock -ModuleName PDS Invoke-WebRequest { }
    }

    It 'creates C:\minikube and downloads the latest minikube.exe into it' {
        # Stop the function after the download: the next step writes the machine PATH.
        Mock -ModuleName PDS Invoke-WebRequest { throw 'stop before the PATH change' }

        { Install-Minikube } | Should -Throw 'stop before the PATH change'

        Should -Invoke -ModuleName PDS New-Item -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'c:\' -and $Name -eq 'minikube' -and $ItemType -eq 'Directory'
        }
        Should -Invoke -ModuleName PDS Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
            "$Uri" -eq 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -and
            $OutFile -eq 'c:\minikube\minikube.exe'
        }
    }

    Context 'when the machine PATH already holds C:\minikube' -Skip:(-not $script:pathHasMinikube) {
        It 'completes without an error' {
            { Install-Minikube | Out-Null } | Should -Not -Throw

            Should -Invoke -ModuleName PDS Invoke-WebRequest -Times 1 -Exactly
        }
    }
}
