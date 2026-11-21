BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The function walks every $env:Path entry, so give it a known PATH with no empty entry.
    $script:originalPath = $env:Path
    $env:Path = (Join-Path $TestDrive 'bin1') + ';' + (Join-Path $TestDrive 'bin2')
}

AfterAll {
    $env:Path = $script:originalPath
}

Describe 'Get-CurlStatus' {
    BeforeEach {
        Mock -ModuleName PDS Write-Host { }
        # No curl.exe anywhere, so the function never runs a real binary.
        Mock -ModuleName PDS Test-Path { $false } -ParameterFilter { $Path -like '*curl.exe' }
    }

    It 'reports a curl alias that points to Invoke-WebRequest' {
        Mock -ModuleName PDS Get-Alias {
            [pscustomobject]@{ Name = 'curl'; Definition = 'Invoke-WebRequest' }
        }
        Mock -ModuleName PDS Get-Command {
            [pscustomobject]@{ Source = 'Invoke-WebRequest'; CommandType = 'Alias' }
        } -ParameterFilter { $Name -eq 'curl' }

        Get-CurlStatus

        Should -Invoke -ModuleName PDS Write-Host -ParameterFilter { $Object -eq 'curl alias exists:' }
        Should -Invoke -ModuleName PDS Write-Host -ParameterFilter { $Object -eq '  Points to: Invoke-WebRequest' }
        Should -Invoke -ModuleName PDS Write-Host -ParameterFilter { $Object -like '*Found Invoke-WebRequest alias for curl:' }
        Should -Invoke -ModuleName PDS Write-Host -ParameterFilter { $Object -eq '  curl resolves to: Invoke-WebRequest' }
    }

    It 'reports that no alias and no curl binary were found' {
        Mock -ModuleName PDS Get-Alias { }
        Mock -ModuleName PDS Get-Command { } -ParameterFilter { $Name -eq 'curl' }

        Get-CurlStatus

        Should -Invoke -ModuleName PDS Write-Host -ParameterFilter { $Object -eq 'No curl alias found in current session.' }
        Should -Invoke -ModuleName PDS Write-Host -ParameterFilter { $Object -eq '  No curl binary found in common locations' }
        Should -Invoke -ModuleName PDS Write-Host -ParameterFilter { $Object -eq '  No directories with curl.exe found in PATH' }
        Should -Invoke -ModuleName PDS Write-Host -ParameterFilter { $Object -eq '  curl command not found in current session' }
    }

    It 'returns nothing on the output stream' {
        Mock -ModuleName PDS Get-Alias { }
        Mock -ModuleName PDS Get-Command { } -ParameterFilter { $Name -eq 'curl' }

        Get-CurlStatus | Should -BeNullOrEmpty
    }
}
