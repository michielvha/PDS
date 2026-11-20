BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Set-AwsCli' {
    BeforeEach {
        # Shadow $PROFILE in the module scope with an empty TestDrive file, so the real profile
        # is never read or written. The file must exist: Select-String -Quiet throws on a
        # missing path despite -ErrorAction SilentlyContinue.
        $script:profilePath = Join-Path $TestDrive "$([guid]::NewGuid())-profile.ps1"
        $null = New-Item -ItemType File -Path $script:profilePath
        InModuleScope PDS -Parameters @{ Path = $script:profilePath } {
            param($Path)
            Set-Variable -Name PROFILE -Value $Path -Scope Script
        }
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'aws' } { [pscustomobject]@{ Name = 'aws' } }
        $script:expectedLine = '$env:AWS_CA_BUNDLE="' + $env:USERPROFILE + '\.aws\cacert.pem"'
    }

    AfterEach {
        InModuleScope PDS { Remove-Variable -Name PROFILE -Scope Script -ErrorAction SilentlyContinue }
    }

    It 'adds AWS_CA_BUNDLE to the profile' {
        Set-AwsCli 6>$null

        Get-Content -Path $script:profilePath | Should -BeExactly $script:expectedLine
    }

    It 'keeps existing profile content' {
        Set-Content -Path $script:profilePath -Value 'Set-Alias -Name ll -Value Get-ChildItem'

        Set-AwsCli 6>$null

        $content = Get-Content -Path $script:profilePath
        $content[0] | Should -Be 'Set-Alias -Name ll -Value Get-ChildItem'
        $content[1] | Should -BeExactly $script:expectedLine
    }

    It 'does not add the line twice' {
        Set-AwsCli 6>$null

        $messages = Set-AwsCli 6>&1 | ForEach-Object { "$_" }

        $messages | Should -Contain 'AWS_CA_BUNDLE already set in profile'
        @(Get-Content -Path $script:profilePath).Count | Should -Be 1
    }

    It 'writes an error and leaves the profile alone when the AWS CLI is missing' {
        Mock Get-Command -ModuleName PDS -ParameterFilter { $Name -eq 'aws' } { }

        $result = Set-AwsCli 2>&1

        $errorRecord = $result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        $errorRecord.Exception.Message | Should -Be 'AWS CLI is not installed. Please install it first.'
        Get-Content -Raw -Path $script:profilePath | Should -BeNullOrEmpty
    }

    It 'changes nothing under -WhatIf' {
        Mock Add-Content -ModuleName PDS { }

        Set-AwsCli -WhatIf 6>$null

        Should -Invoke Add-Content -ModuleName PDS -Times 0 -Exactly
        Get-Content -Raw -Path $script:profilePath | Should -BeNullOrEmpty
    }
}
