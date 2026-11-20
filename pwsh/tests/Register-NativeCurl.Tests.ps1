BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Point $PROFILE at TestDrive for the module only, so the real profile is never read or written.
    $script:profilePath = Join-Path $TestDrive 'profile' 'Microsoft.PowerShell_profile.ps1'
    InModuleScope PDS -Parameters @{ ProfilePath = $script:profilePath } {
        param($ProfilePath)
        $script:PROFILE = $ProfilePath
    }

    # The function smoke-tests ncurl after defining it; a module-scope stub, found before the
    # global function, lets the test mock that call instead of running a real curl.exe.
    InModuleScope PDS { function script:ncurl { } }

    # Returns the curl path the global ncurl closure calls. Get-Item and Remove-Item do not resolve a
    # global: qualifier in a function: path, so the tests use the unqualified path, which finds the
    # global function from the test scope.
    function Get-NcurlTarget {
        (Get-Item -Path function:ncurl).ScriptBlock.Module.SessionState.PSVariable.GetValue('nativeCurl')
    }
}

AfterAll {
    InModuleScope PDS { Remove-Variable -Name PROFILE -Scope Script -ErrorAction SilentlyContinue }
    Remove-Item -Path function:ncurl -ErrorAction SilentlyContinue
}

Describe 'Register-NativeCurl' {
    BeforeEach {
        Remove-Item -Path (Split-Path -Path $script:profilePath -Parent) -Recurse -Force -ErrorAction SilentlyContinue
        # Pester 6 has no fall-through to the real command, so other paths go to it explicitly.
        Mock -ModuleName PDS Test-Path { Microsoft.PowerShell.Management\Test-Path @PesterBoundParameters }
        Mock -ModuleName PDS Test-Path { $false } -ParameterFilter { $Path -eq 'C:\ProgramData\chocolatey\bin\curl.exe' }
        Mock -ModuleName PDS Test-Path { $true } -ParameterFilter { $Path -eq 'C:\Windows\System32\curl.exe' }
        Mock -ModuleName PDS Invoke-Expression { }
        Remove-Item -Path function:ncurl -ErrorAction SilentlyContinue
        Mock -ModuleName PDS ncurl { @('curl 8.9.1 (Windows) libcurl/8.9.1', 'Release-Date: 2024-07-31') }
    }

    AfterEach {
        Remove-Item -Path function:ncurl -ErrorAction SilentlyContinue
    }

    It 'defines a global ncurl for the built-in curl and adds it to the profile' {
        $output = Register-NativeCurl

        Test-Path -Path function:global:ncurl | Should -BeTrue
        Get-NcurlTarget | Should -Be 'C:\Windows\System32\curl.exe'
        Should -Invoke -ModuleName PDS Invoke-Expression -Times 0 -Exactly
        $output | Should -Contain "Created 'ncurl' function for: C:\Windows\System32\curl.exe"
        $output | Should -Contain 'curl 8.9.1 (Windows) libcurl/8.9.1'
        $output | Should -Contain "Added ncurl function to your PowerShell profile at: $script:profilePath"
        Get-Content -Path $script:profilePath -Raw | Should -BeLike "*function global:ncurl*& 'C:\Windows\System32\curl.exe'*"
    }

    It 'makes the global ncurl pass every argument to the chosen curl' {
        Register-NativeCurl | Out-Null
        # Point the closure at a stand-in for curl.exe that echoes its arguments.
        $fakeCurl = Join-Path $TestDrive 'fake-curl.ps1'
        Set-Content -Path $fakeCurl -Value 'foreach ($argument in $args) { $argument }'
        (Get-Item -Path function:ncurl).ScriptBlock.Module.SessionState.PSVariable.Set('nativeCurl', $fakeCurl)

        $result = ncurl --head https://example.test

        $result | Should -Be @('--head', 'https://example.test')
    }

    It 'prefers the Chocolatey curl when it exists' {
        Mock -ModuleName PDS Test-Path { $true } -ParameterFilter { $Path -eq 'C:\ProgramData\chocolatey\bin\curl.exe' }

        Register-NativeCurl | Out-Null

        Get-NcurlTarget | Should -Be 'C:\ProgramData\chocolatey\bin\curl.exe'
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
        Test-Path -Path function:global:ncurl | Should -BeFalse
        $script:profilePath | Should -Not -Exist
    }
}
