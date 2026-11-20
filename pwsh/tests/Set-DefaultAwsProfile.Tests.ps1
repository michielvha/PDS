BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Set-DefaultAwsProfile' {
    BeforeEach {
        # Point $HOME at a fresh TestDrive folder so the real ~/.aws/config is never touched,
        # and refuse to run if the module does not see the redirect.
        $script:originalHome = $HOME
        $script:testHome = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $script:testHome
        Set-Variable -Name HOME -Value $script:testHome -Scope Global -Force
        if ((InModuleScope PDS { $HOME }) -ne $script:testHome) {
            throw 'The module does not see the redirected HOME; refusing to write an AWS config.'
        }
        $script:configPath = Join-Path $script:testHome '.aws' 'config'
    }

    AfterEach {
        Set-Variable -Name HOME -Value $script:originalHome -Scope Global -Force
    }

    It 'creates a config with a default section when none exists' {
        $output = Set-DefaultAwsProfile -region 'eu-west-1' -profile 'dev' 6>$null

        $output | Should -Be 'No existing default profile found, creating new profile...'
        $content = Get-Content -Raw -Path $script:configPath
        $content | Should -Match (
            '\[default\]\r?\nregion = eu-west-1\r?\nprofile = dev\r?\nsso_region = eu-west-1\r?\n' +
            'sso_start_url= https://d-93672f1b5f\.awsapps\.com/start\r?\noutput = json')
        [System.IO.File]::ReadAllBytes($script:configPath)[0] | Should -Not -Be 0xEF
    }

    It 'replaces an existing default section and keeps the other sections' {
        $null = New-Item -ItemType Directory -Path (Join-Path $script:testHome '.aws')
        [System.IO.File]::WriteAllText(
            $script:configPath,
            "[default]`nregion = us-east-1`noutput = text`n`n[profile other]`nsso_session = corp`n")

        $output = Set-DefaultAwsProfile -region 'eu-west-1' -profile 'dev' 6>$null

        $output | Should -Be 'Existing default profile found, replacing with new profile...'
        $content = Get-Content -Raw -Path $script:configPath
        ([regex]::Matches($content, '\[default\]')).Count | Should -Be 1
        $content | Should -Match '\[default\]\r?\nregion = eu-west-1\r?\nprofile = dev'
        $content | Should -Not -Match 'us-east-1'
        $content | Should -Not -Match 'output = text'
        $content | Should -Match '\[profile other\]\nsso_session = corp'
    }

    It 'uses the given SSO region and start URL' {
        $null = Set-DefaultAwsProfile -region 'eu-west-1' -profile 'dev' -sso_region 'us-east-1' -sso_start_url 'https://corp.awsapps.com/start' 6>$null

        $content = Get-Content -Raw -Path $script:configPath
        $content | Should -Match 'sso_region = us-east-1'
        $content | Should -Match 'sso_start_url= https://corp\.awsapps\.com/start'
    }
}
