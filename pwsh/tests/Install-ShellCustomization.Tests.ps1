BeforeDiscovery {
    # Without administrator rights the function calls exit, which would end the test host, so
    # its tests run only when elevated.
    $script:isAdmin = $IsWindows -and ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    InModuleScope PDS { function script:winget { } }

    # The fallback path rebuilds $env:Path from the machine and user values.
    $script:originalPath = $env:Path
}

AfterAll {
    $env:Path = $script:originalPath
}

Describe 'Install-ShellCustomization' -Skip:(-not $script:isAdmin) {
    BeforeEach {
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS Start-Sleep { }
        Mock -ModuleName PDS winget { }
        Mock -ModuleName PDS Install-OhMyPosh { }
        Mock -ModuleName PDS Set-WindowsTerminalFont { }
        Mock -ModuleName PDS Set-PSReadLineModule { }
        Mock -ModuleName PDS Get-Command { } -ParameterFilter { $Name -eq 'oh-my-posh' }
    }

    AfterEach {
        $env:Path = $script:originalPath
    }

    It 'runs Install-OhMyPosh, Set-WindowsTerminalFont and Set-PSReadLineModule' {
        Install-ShellCustomization

        Should -Invoke -ModuleName PDS Install-OhMyPosh -Times 1 -Exactly
        Should -Invoke -ModuleName PDS Set-WindowsTerminalFont -Times 1 -Exactly -ParameterFilter {
            $FontName -eq 'JetBrainsMono Nerd Font Mono'
        }
        Should -Invoke -ModuleName PDS Set-PSReadLineModule -Times 1 -Exactly
        Should -Invoke -ModuleName PDS winget -Times 0 -Exactly
    }

    It 'falls back to winget when Install-OhMyPosh fails' {
        Mock -ModuleName PDS Install-OhMyPosh { throw 'install failed' }

        # Install-ShellCustomization is not an advanced function, so it takes no -ErrorVariable.
        $errors = Install-ShellCustomization 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }

        $errors[0].ToString() | Should -BeLike 'Failed to run Install-OhMyPosh:*install failed*'
        Should -Invoke -ModuleName PDS winget -Times 1 -Exactly -ParameterFilter {
            "$args" -eq 'install JanDeDobbeleer.OhMyPosh -s winget'
        }
        Should -Invoke -ModuleName PDS Set-PSReadLineModule -Times 1 -Exactly
    }

    It 'continues with the remaining steps when one of them fails' {
        Mock -ModuleName PDS Set-WindowsTerminalFont { throw 'no terminal' }

        $errors = Install-ShellCustomization 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }

        $errors[0].ToString() | Should -BeLike 'Failed to run Set-WindowsTerminalFont:*'
        Should -Invoke -ModuleName PDS Set-PSReadLineModule -Times 1 -Exactly
    }

    It 'still runs under its old name' {
        $old = Get-Command 'Install-ShellCustomizations' -Module PDS
        $old.CommandType | Should -Be 'Alias'
        $old.ResolvedCommand.Name | Should -Be 'Install-ShellCustomization'

        Install-ShellCustomizations

        Should -Invoke -ModuleName PDS Install-OhMyPosh -Times 1 -Exactly
        Should -Invoke -ModuleName PDS Set-PSReadLineModule -Times 1 -Exactly
    }
}
