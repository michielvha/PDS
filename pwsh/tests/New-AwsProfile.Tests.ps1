BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'New-AwsProfile' {
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

    It 'creates the .aws folder and writes the SSO profile' {
        $null = New-AwsProfile -sso_profile 'dev' -sso_session 'corp' -sso_account_id '123456789012' -sso_role_name 'Admin' 6>$null

        $content = Get-Content -Raw -Path $script:configPath
        $content | Should -Match '\[profile dev\]\r?\nsso_session = corp\r?\nsso_account_id = 123456789012\r?\nsso_role_name = Admin'
    }

    It 'appends to an existing config without changing it' {
        $null = New-Item -ItemType Directory -Path (Join-Path $script:testHome '.aws')
        [System.IO.File]::WriteAllText($script:configPath, "[default]`nregion = eu-west-1`n")

        $null = New-AwsProfile -sso_profile 'dev' -sso_session 'corp' -sso_account_id '111111111111' -sso_role_name 'Admin' 6>$null
        $null = New-AwsProfile -sso_profile 'prod' -sso_session 'corp' -sso_account_id '222222222222' -sso_role_name 'ReadOnly' 6>$null

        $content = Get-Content -Raw -Path $script:configPath
        $content | Should -BeLike "[[]default]`nregion = eu-west-1`n*"
        $content | Should -Match '\[profile dev\]\r?\nsso_session = corp\r?\nsso_account_id = 111111111111'
        $content | Should -Match '\[profile prod\]\r?\nsso_session = corp\r?\nsso_account_id = 222222222222\r?\nsso_role_name = ReadOnly'
    }
}
