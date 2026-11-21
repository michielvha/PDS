BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # Stub, so git can be mocked whether or not it is installed.
    InModuleScope PDS { function script:git { } }

    $script:apiUri = 'https://dev.azure.com/contoso/MyProject/_apis/git/repositories?api-version=7.0'
    $script:repos = @(
        [pscustomobject]@{ name = 'repo1'; remoteUrl = 'https://contoso@dev.azure.com/contoso/MyProject/_git/repo1' }
        [pscustomobject]@{ name = 'repo2'; remoteUrl = 'https://dev.azure.com/contoso/MyProject/_git/repo2' }
    )
}

Describe 'Get-AzureDevOpsLibrary' {
    BeforeEach {
        $script:destination = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:gitExitCode = 0
        $script:pullLocations = @()
        $script:gitCalls = @()
        $script:params = @{
            Organization        = 'contoso'
            Project             = 'MyProject'
            Username            = 'john@contoso.com'
            PersonalAccessToken = 'pat123'
            DestinationPath     = $script:destination
        }

        Mock -ModuleName PDS Write-Host { }
        Mock -ModuleName PDS Write-Warning { }
        Mock -ModuleName PDS Invoke-RestMethod { [pscustomobject]@{ value = $script:repos } }
        Mock -ModuleName PDS git {
            $script:gitCalls += [pscustomobject]@{ Arguments = "$args"; Header = $env:GIT_CONFIG_VALUE_0; Key = $env:GIT_CONFIG_KEY_0 }
            if ($args[0] -eq 'pull') {
                $script:pullLocations += (Get-Location).Path
            }
            Set-Variable -Name LASTEXITCODE -Value $script:gitExitCode -Scope Global
        }
    }

    It 'lists the repositories with the token as Basic authentication' {
        Get-AzureDevOpsLibrary @script:params

        $expectedAuth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(':pat123'))
        Should -Invoke -ModuleName PDS Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            "$Uri" -eq $script:apiUri -and $Method -eq 'Get' -and $Headers.Authorization -eq $expectedAuth
        }
    }

    It 'creates the destination and clones every repository from its URL without a user name' {
        Get-AzureDevOpsLibrary @script:params

        $script:destination | Should -Exist
        Should -Invoke -ModuleName PDS git -Times 1 -Exactly -ParameterFilter {
            $args[0] -eq 'clone' -and
            $args[1] -eq 'https://dev.azure.com/contoso/MyProject/_git/repo1' -and
            $args[2] -eq (Join-Path $script:destination 'repo1')
        }
        Should -Invoke -ModuleName PDS git -Times 1 -Exactly -ParameterFilter {
            $args[0] -eq 'clone' -and
            $args[1] -eq 'https://dev.azure.com/contoso/MyProject/_git/repo2' -and
            $args[2] -eq (Join-Path $script:destination 'repo2')
        }
        Should -Invoke -ModuleName PDS Write-Host -Times 1 -Exactly -ParameterFilter { $Object -eq '  Successful: 2' }
    }

    It 'gives git the token only as a header for the duration of each call' {
        Get-AzureDevOpsLibrary @script:params

        $expectedHeader = 'Authorization: Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('john@contoso.com:pat123'))
        $clones = @($script:gitCalls | Where-Object Arguments -Like 'clone *')
        $clones.Count | Should -Be 2
        $clones.Key | Should -Be @('http.extraHeader', 'http.extraHeader')
        $clones.Header | Should -Be @($expectedHeader, $expectedHeader)
        $script:gitCalls.Arguments | Should -Not -Match 'pat123'
        $env:GIT_CONFIG_COUNT | Should -BeNullOrEmpty
        $env:GIT_CONFIG_VALUE_0 | Should -BeNullOrEmpty
    }

    It 'pulls a repository that already exists inside its directory' {
        $repo1 = Join-Path $script:destination 'repo1'
        New-Item -Path $repo1 -ItemType Directory -Force | Out-Null

        Get-AzureDevOpsLibrary @script:params

        $script:pullLocations | Should -Be $repo1
        # A clone made by an earlier version kept the token in its remote URL; it is replaced.
        Should -Invoke -ModuleName PDS git -Times 1 -Exactly -ParameterFilter {
            "$args" -eq 'remote set-url origin https://dev.azure.com/contoso/MyProject/_git/repo1'
        }
        ($script:gitCalls | Where-Object Arguments -EQ 'pull').Header | Should -Match '^Authorization: Basic '
        Should -Invoke -ModuleName PDS git -Times 0 -ParameterFilter { $args[0] -eq 'clone' -and $args[2] -eq $repo1 }
        Should -Invoke -ModuleName PDS git -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'clone' -and $args[2] -like '*repo2' }
    }

    It 'removes and clones an existing repository again with -Force' {
        $repo1 = Join-Path $script:destination 'repo1'
        New-Item -Path $repo1 -ItemType Directory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $repo1 'marker.txt') -Value 'old'

        Get-AzureDevOpsLibrary @script:params -Force

        Join-Path $repo1 'marker.txt' | Should -Not -Exist
        Should -Invoke -ModuleName PDS git -Times 0 -ParameterFilter { $args[0] -eq 'pull' }
        Should -Invoke -ModuleName PDS git -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'clone' -and $args[2] -eq $repo1 }
    }

    It 'counts a failed clone' {
        $script:gitExitCode = 128

        Get-AzureDevOpsLibrary @script:params

        Should -Invoke -ModuleName PDS Write-Host -Times 1 -Exactly -ParameterFilter { $Object -eq '  Failed: 2' }
    }

    It 'warns and clones nothing when the project has no repositories' {
        Mock -ModuleName PDS Invoke-RestMethod { [pscustomobject]@{ value = @() } }

        Get-AzureDevOpsLibrary @script:params

        Should -Invoke -ModuleName PDS Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq "No repositories found in project 'MyProject'" }
        Should -Invoke -ModuleName PDS git -Times 0 -ParameterFilter { $args[0] -eq 'clone' }
    }

    It 'reports an error when the repository list cannot be retrieved' {
        Mock -ModuleName PDS Invoke-RestMethod { throw '401 Unauthorized' }

        Get-AzureDevOpsLibrary @script:params -ErrorVariable err -ErrorAction SilentlyContinue

        "$err" | Should -BeLike '*Failed to retrieve repositories:*401 Unauthorized*'
        Should -Invoke -ModuleName PDS git -Times 0 -ParameterFilter { $args[0] -eq 'clone' }
    }
}
