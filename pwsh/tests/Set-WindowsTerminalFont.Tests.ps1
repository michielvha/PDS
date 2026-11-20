BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    InModuleScope PDS {
        ${function:script:oh-my-posh} = { }
        function script:winget { }
    }

    # The function reads settings.json under $env:LOCALAPPDATA and may rebuild $env:Path, so
    # both are pointed at or restored from test values.
    $script:originalLocalAppData = $env:LOCALAPPDATA
    $script:originalPath = $env:Path
    $env:LOCALAPPDATA = $TestDrive
    $script:settingsDir = Join-Path $TestDrive 'Packages' 'Microsoft.WindowsTerminal_8wekyb3d8bbwe' 'LocalState'
    $script:settingsFile = Join-Path $script:settingsDir 'settings.json'
}

AfterAll {
    $env:LOCALAPPDATA = $script:originalLocalAppData
    $env:Path = $script:originalPath
}

Describe 'Set-WindowsTerminalFont' {
    BeforeEach {
        Remove-Item -Path $script:settingsDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $script:settingsDir -ItemType Directory -Force | Out-Null
        Set-Content -Path $script:settingsFile -Value '{"theme":"dark","profiles":{"list":[{"name":"PowerShell"}]}}'
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS winget { }
        Mock -ModuleName PDS oh-my-posh { }
        Mock -ModuleName PDS Get-Command { [pscustomobject]@{ Name = 'oh-my-posh' } } -ParameterFilter { $Name -eq 'oh-my-posh' }
    }

    AfterEach {
        $env:Path = $script:originalPath
    }

    It 'sets the default font face and keeps the other settings' {
        Set-WindowsTerminalFont -FontName 'JetBrainsMono Nerd Font Mono'

        $settings = Get-Content -Path $script:settingsFile -Raw | ConvertFrom-Json
        $settings.profiles.defaults.font.face | Should -Be 'JetBrainsMono Nerd Font Mono'
        $settings.theme | Should -Be 'dark'
        $settings.profiles.list[0].name | Should -Be 'PowerShell'
    }

    It 'uses MesloLGM Nerd Font by default and keeps existing font settings' {
        Set-Content -Path $script:settingsFile -Value '{"profiles":{"defaults":{"font":{"size":11,"face":"Consolas"}}}}'

        Set-WindowsTerminalFont

        $settings = Get-Content -Path $script:settingsFile -Raw | ConvertFrom-Json
        $settings.profiles.defaults.font.face | Should -Be 'MesloLGM Nerd Font'
        $settings.profiles.defaults.font.size | Should -Be 11
    }

    It 'installs the Meslo and JetBrainsMono Nerd Fonts through oh-my-posh' {
        Set-WindowsTerminalFont

        Should -Invoke -ModuleName PDS oh-my-posh -Times 1 -Exactly -ParameterFilter { "$args" -eq 'font install meslo' }
        Should -Invoke -ModuleName PDS oh-my-posh -Times 1 -Exactly -ParameterFilter { "$args" -eq 'font install JetBrainsMono' }
        Should -Invoke -ModuleName PDS winget -Times 0 -Exactly
    }

    It 'installs Oh My Posh with winget when it is missing' {
        Mock -ModuleName PDS Get-Command { } -ParameterFilter { $Name -eq 'oh-my-posh' }

        Set-WindowsTerminalFont 3>$null

        Should -Invoke -ModuleName PDS winget -Times 1 -Exactly -ParameterFilter {
            "$args" -eq 'install JanDeDobbeleer.OhMyPosh -s winget'
        }
        Should -Invoke -ModuleName PDS oh-my-posh -Times 0 -Exactly
    }

    It 'reports an error when settings.json does not exist' {
        Remove-Item -Path $script:settingsFile -Force

        # Set-WindowsTerminalFont is not an advanced function, so it takes no -ErrorVariable.
        $errors = Set-WindowsTerminalFont 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }

        $errors[0].ToString() | Should -BeLike 'Windows Terminal settings.json not found at:*'
        $script:settingsFile | Should -Not -Exist
    }
}
