BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stubs so the external executables can be mocked whether or not they are installed.
    InModuleScope PDS {
        ${function:script:oh-my-posh} = { }
        function script:winget { }
    }

    # Point $PROFILE and $PROFILE.AllUsersAllHosts at TestDrive for the module only.
    $script:allUsersProfile = Join-Path $TestDrive 'AllUsers' 'profile.ps1'
    $fakeProfile = Add-Member -InputObject (Join-Path $TestDrive 'user-profile.ps1') -NotePropertyName AllUsersAllHosts -NotePropertyValue $script:allUsersProfile -PassThru
    InModuleScope PDS -Parameters @{ FakeProfile = $fakeProfile } {
        param($FakeProfile)
        $script:PROFILE = $FakeProfile
    }

    $script:originalThemesPath = $env:POSH_THEMES_PATH
    $script:themesDir = Join-Path $TestDrive 'themes'
    $env:POSH_THEMES_PATH = $script:themesDir
    $script:themeFile = Join-Path $script:themesDir 'powerlevel10k_rainbow.omp.json'
}

AfterAll {
    $env:POSH_THEMES_PATH = $script:originalThemesPath
    InModuleScope PDS { Remove-Variable -Name PROFILE -Scope Script -ErrorAction SilentlyContinue }
}

Describe 'Install-OhMyPosh' {
    BeforeEach {
        Remove-Item -Path (Split-Path -Path $script:allUsersProfile -Parent) -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $script:themesDir -Recurse -Force -ErrorAction SilentlyContinue
        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS winget { }
        Mock -ModuleName PDS Install-Module { }
        Mock -ModuleName PDS Get-Module { [pscustomobject]@{ Name = $Name } } -ParameterFilter { $ListAvailable }
        Mock -ModuleName PDS Get-Command { [pscustomobject]@{ Name = 'oh-my-posh' } } -ParameterFilter { $Name -eq 'oh-my-posh' }
    }

    It 'installs Oh My Posh with winget when it is missing' {
        Mock -ModuleName PDS Get-Command { } -ParameterFilter { $Name -eq 'oh-my-posh' }

        Install-OhMyPosh

        Should -Invoke -ModuleName PDS winget -Times 1 -Exactly -ParameterFilter {
            "$args" -eq 'install JanDeDobbeleer.OhMyPosh -s winget'
        }
    }

    It 'does not reinstall Oh My Posh or modules that are present' {
        Install-OhMyPosh

        Should -Invoke -ModuleName PDS winget -Times 0 -Exactly
        Should -Invoke -ModuleName PDS Install-Module -Times 0 -Exactly
    }

    It 'installs Terminal-Icons and posh-git when they are missing' {
        Mock -ModuleName PDS Get-Module { } -ParameterFilter { $ListAvailable }

        Install-OhMyPosh

        Should -Invoke -ModuleName PDS Install-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'Terminal-Icons' }
        Should -Invoke -ModuleName PDS Install-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'posh-git' }
    }

    It 'appends the Oh My Posh initialisation to the all-users profile' {
        Install-OhMyPosh

        $content = Get-Content -Path $script:allUsersProfile -Raw
        $content | Should -BeLike '*oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\powerlevel10k_rainbow.omp.json"*'
        $content | Should -BeLike '*Import-Module Terminal-Icons*'
        $content | Should -BeLike '*Import-Module posh-git*'
    }

    It 'removes the console title template and adds Azure and Kubernetes segments to the theme' {
        New-Item -Path $script:themesDir -ItemType Directory -Force | Out-Null
        $theme = @'
{
  "console_title_template": "{{ .Shell }} in {{ .Folder }}",
  "blocks": [
    {
      "type": "prompt",
      "segments": [
        { "type": "path" }
      ]
    }
  ],
  "version": 2
}
'@
        Set-Content -Path $script:themeFile -Value $theme

        Install-OhMyPosh

        $result = Get-Content -Path $script:themeFile -Raw | ConvertFrom-Json
        $result.PSObject.Properties.Name | Should -Not -Contain 'console_title_template'
        $result.blocks[0].segments.type | Should -Be @('path', 'az', 'kubectl')
    }

    It 'leaves a theme that already has both segments unchanged' {
        New-Item -Path $script:themesDir -ItemType Directory -Force | Out-Null
        $theme = '{"blocks":[{"segments":[{"type":"az"},{"type":"kubectl"}]}]}'
        Set-Content -Path $script:themeFile -Value $theme -NoNewline

        Install-OhMyPosh

        Get-Content -Path $script:themeFile -Raw | Should -Be $theme
        Should -Invoke -ModuleName PDS Write-Host -ParameterFilter { $Object -eq 'No theme modifications needed' }
    }
}
