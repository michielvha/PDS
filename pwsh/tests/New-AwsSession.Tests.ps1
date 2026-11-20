BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'New-AwsSession' {
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

    It 'creates the .aws folder and writes the SSO session' {
        $null = New-AwsSession -sso_session 'corp' -sso_start_url 'https://corp.awsapps.com/start' -sso_region 'eu-west-1' 6>$null

        $content = Get-Content -Raw -Path $script:configPath
        $content | Should -Match (
            '\[sso-session corp\]\r?\nsso_start_url = https://corp\.awsapps\.com/start\r?\n' +
            'sso_region = eu-west-1\r?\nsso_registration_scopes=sso:account:access')
    }

    It 'appends to an existing config without changing it' {
        $null = New-Item -ItemType Directory -Path (Join-Path $script:testHome '.aws')
        [System.IO.File]::WriteAllText($script:configPath, "[profile dev]`nsso_session = corp`n")

        $null = New-AwsSession -sso_session 'corp' -sso_start_url 'https://corp.awsapps.com/start' -sso_region 'eu-west-1' 6>$null

        $content = Get-Content -Raw -Path $script:configPath
        $content | Should -BeLike "[[]profile dev]`nsso_session = corp`n*"
        $content | Should -Match '\[sso-session corp\]'
    }
}
