BeforeDiscovery {
    # The function checks the real token, which cannot be mocked, so each branch runs only
    # where it can.
    $script:isAdmin = $IsWindows -and ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stub so the validation call can be mocked whether or not sudo.exe exists.
    InModuleScope PDS { function script:sudo { } }
}

Describe 'Enable-Sudo' {
    BeforeEach {
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS Start-Sleep { }
        Mock -ModuleName PDS Get-CimInstance { [pscustomobject]@{ BuildNumber = '26100'; ProductType = 1 } }
        Mock -ModuleName PDS Test-Path { $false } -ParameterFilter { $Path -like 'HKLM:*' }
        Mock -ModuleName PDS New-Item { }
        Mock -ModuleName PDS Set-ItemProperty { }
        Mock -ModuleName PDS Get-Command { } -ParameterFilter { $Name -eq 'sudo' }
        Mock -ModuleName PDS sudo { 'Sudo test successful' }
    }

    Context 'as administrator' -Skip:(-not $script:isAdmin) {
        It 'creates the registry key and enables inline mode by default' {
            Enable-Sudo

            Should -Invoke -ModuleName PDS New-Item -Times 1 -Exactly -ParameterFilter {
                $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo'
            }
            Should -Invoke -ModuleName PDS Set-ItemProperty -Times 1 -Exactly -ParameterFilter {
                $Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo' -and $Name -eq 'Enabled' -and $Value -eq 3 -and $Type -eq 'DWord'
            }
        }

        It 'writes <Expected> for mode <Mode>' -ForEach @(
            @{ Mode = 'NewWindow'; Expected = 1 }
            @{ Mode = 'DisableInput'; Expected = 2 }
            @{ Mode = 'Normal'; Expected = 3 }
        ) {
            Enable-Sudo -Mode $Mode

            Should -Invoke -ModuleName PDS Set-ItemProperty -Times 1 -Exactly -ParameterFilter { $Value -eq $Expected }
        }

        It 'refuses a workstation build older than 26100' {
            Mock -ModuleName PDS Get-CimInstance { [pscustomobject]@{ BuildNumber = '22631'; ProductType = 1 } }

            # Enable-Sudo is not an advanced function, so it takes no -ErrorVariable.
            $errors = Enable-Sudo 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }

            ($errors | Select-Object -First 1).ToString() | Should -BeLike '*Build 26100*Current build: 22631'
            Should -Invoke -ModuleName PDS Set-ItemProperty -Times 0 -Exactly
        }

        It 'validates sudo when the command is available' {
            Mock -ModuleName PDS Get-Command { [pscustomobject]@{ Source = 'C:\Windows\System32\sudo.exe' } } -ParameterFilter { $Name -eq 'sudo' }

            Enable-Sudo

            Should -Invoke -ModuleName PDS sudo -Times 1 -Exactly
        }

        It 'skips validation with -NoValidation' {
            Mock -ModuleName PDS Get-Command { [pscustomobject]@{ Source = 'C:\Windows\System32\sudo.exe' } } -ParameterFilter { $Name -eq 'sudo' }

            Enable-Sudo -NoValidation

            Should -Invoke -ModuleName PDS sudo -Times 0 -Exactly
            Should -Invoke -ModuleName PDS Set-ItemProperty -Times 1 -Exactly
        }
    }

    Context 'without administrator rights' -Skip:$script:isAdmin {
        It 'reports an error and changes nothing' {
            # Enable-Sudo is not an advanced function, so it takes no -ErrorVariable.
            $errors = Enable-Sudo 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }

            ($errors | Select-Object -First 1).ToString() | Should -BeLike '*requires administrator privileges*'
            Should -Invoke -ModuleName PDS Set-ItemProperty -Times 0 -Exactly
        }
    }
}
