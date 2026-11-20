BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Point $PROFILE at TestDrive for the module only, so the real profile is never read or written.
    $script:profilePath = Join-Path $TestDrive 'profile' 'Microsoft.PowerShell_profile.ps1'
    InModuleScope PDS -Parameters @{ ProfilePath = $script:profilePath } {
        param($ProfilePath)
        $script:PROFILE = $ProfilePath
    }

    # ncurl is defined by Invoke-Expression at run time; a stub lets the test mock it instead.
    InModuleScope PDS { function script:ncurl { } }
}

AfterAll {
    InModuleScope PDS { Remove-Variable -Name PROFILE -Scope Script -ErrorAction SilentlyContinue }
}

Describe 'Register-NativeCurl' {
    BeforeEach {
        Remove-Item -Path (Split-Path -Path $script:profilePath -Parent) -Recurse -Force -ErrorAction SilentlyContinue
        # Pester 6 has no fall-through to the real command, so other paths go to it explicitly.
        Mock -ModuleName PDS Test-Path { Microsoft.PowerShell.Management\Test-Path @PesterBoundParameters }
        Mock -ModuleName PDS Test-Path { $false } -ParameterFilter { $Path -eq 'C:\ProgramData\chocolatey\bin\curl.exe' }
        Mock -ModuleName PDS Test-Path { $true } -ParameterFilter { $Path -eq 'C:\Windows\System32\curl.exe' }
        Mock -ModuleName PDS Invoke-Expression { }
        Mock -ModuleName PDS ncurl { @('curl 8.9.1 (Windows) libcurl/8.9.1', 'Release-Date: 2024-07-31') }
    }

    It 'defines ncurl for the built-in curl and adds it to the profile' {
        $output = Register-NativeCurl

        Should -Invoke -ModuleName PDS Invoke-Expression -Times 1 -Exactly -ParameterFilter {
            $Command -like "*function global:ncurl*& 'C:\Windows\System32\curl.exe'*"
        }
        $output | Should -Contain "Created 'ncurl' function for: C:\Windows\System32\curl.exe"
        $output | Should -Contain 'curl 8.9.1 (Windows) libcurl/8.9.1'
        $output | Should -Contain "Added ncurl function to your PowerShell profile at: $script:profilePath"
        Get-Content -Path $script:profilePath -Raw | Should -BeLike '*function global:ncurl*'
    }

    It 'prefers the Chocolatey curl when it exists' {
        Mock -ModuleName PDS Test-Path { $true } -ParameterFilter { $Path -eq 'C:\ProgramData\chocolatey\bin\curl.exe' }

        Register-NativeCurl | Out-Null

        Should -Invoke -ModuleName PDS Invoke-Expression -Times 1 -Exactly -ParameterFilter {
            $Command -like "*& 'C:\ProgramData\chocolatey\bin\curl.exe'*"
        }
    }

    It 'does not add ncurl to the profile twice' {
        New-Item -Path $script:profilePath -ItemType File -Force | Out-Null
        Set-Content -Path $script:profilePath -Value 'function global:ncurl { }'

        $output = Register-NativeCurl

        $output | Should -Contain 'Your PowerShell profile already contains a ncurl function.'
        Get-Content -Path $script:profilePath | Should -Be 'function global:ncurl { }'
    }

    It 'reports an error when no curl.exe is found' {
        Mock -ModuleName PDS Test-Path { $false } -ParameterFilter { $Path -eq 'C:\Windows\System32\curl.exe' }

        Register-NativeCurl -ErrorAction SilentlyContinue -ErrorVariable errors

        ($errors | Select-Object -First 1).ToString() | Should -BeLike 'Could not find curl.exe*'
        Should -Invoke -ModuleName PDS Invoke-Expression -Times 0 -Exactly
        $script:profilePath | Should -Not -Exist
    }
}
