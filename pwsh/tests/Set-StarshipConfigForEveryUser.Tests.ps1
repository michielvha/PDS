BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Get-WmiObject is missing or a compatibility shim depending on the PowerShell version, so
    # a stub with a known signature makes the mock behave the same everywhere.
    InModuleScope PDS {
        function script:Get-WmiObject {
            param([string]$Class)
            $null = $Class
        }
    }

    $script:usersDir = Join-Path $TestDrive 'Users'
    $script:config = "[character]`nsuccess_symbol = '>'"
}

Describe 'Set-StarshipConfigForEveryUser' {
    BeforeEach {
        Remove-Item -Path $script:usersDir -Recurse -Force -ErrorAction SilentlyContinue
        $script:alice = Join-Path $script:usersDir 'alice'
        $script:bob = Join-Path $script:usersDir 'bob'
        $script:system = Join-Path $script:usersDir 'systemprofile'
        New-Item -Path $script:alice, $script:system -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:bob '.config') -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $script:bob '.config' 'starship.toml') -Value 'existing'

        $profiles = @(
            [pscustomobject]@{ LocalPath = $script:alice; Special = $false }
            [pscustomobject]@{ LocalPath = $script:bob; Special = $false }
            [pscustomobject]@{ LocalPath = $script:system; Special = $true }
        )
        Mock -ModuleName PDS Get-WmiObject { $profiles }
        Mock -ModuleName PDS Write-Host { }
    }

    It 'writes starship.toml for each normal user that has none' {
        Set-StarshipConfigForEveryUser -configContent $script:config | Out-Null

        Get-Content -Path (Join-Path $script:alice '.config' 'starship.toml') -Raw | Should -Be ($script:config + [Environment]::NewLine)
        Should -Invoke -ModuleName PDS Get-WmiObject -Times 1 -Exactly -ParameterFilter { $Class -eq 'Win32_UserProfile' }
    }

    It 'keeps an existing starship.toml' {
        Set-StarshipConfigForEveryUser -configContent $script:config | Out-Null

        Get-Content -Path (Join-Path $script:bob '.config' 'starship.toml') | Should -Be 'existing'
    }

    It 'skips special profiles' {
        Set-StarshipConfigForEveryUser -configContent $script:config | Out-Null

        Join-Path $script:system '.config' | Should -Not -Exist
    }

    It 'still runs under its old name' {
        $old = Get-Command 'Set-StarshipConfigForAllUsers' -Module PDS
        $old.CommandType | Should -Be 'Alias'
        $old.ResolvedCommand.Name | Should -Be 'Set-StarshipConfigForEveryUser'

        Set-StarshipConfigForAllUsers -configContent $script:config | Out-Null

        Join-Path $script:alice '.config' 'starship.toml' | Should -Exist
    }
}
