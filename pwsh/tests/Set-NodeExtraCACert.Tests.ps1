BeforeDiscovery {
    $script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    $script:isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    # The function writes the machine variable with [Environment]::SetEnvironmentVariable, which
    # cannot be mocked. Every call therefore passes the value the machine already has: the current
    # value, or an empty string when the variable is unset (an empty value removes a variable, and
    # removing an absent one is a no-op). The machine is left exactly as it was.
    $script:harmlessValue = [System.Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS', 'Machine')
    if (-not $script:harmlessValue) {
        $script:harmlessValue = ''
    }
}

Describe 'Set-NodeExtraCACert' {
    BeforeEach {
        Mock Write-Host -ModuleName PDS
        Mock Write-Error -ModuleName PDS
    }

    AfterEach {
        $after = [System.Environment]::GetEnvironmentVariable('NODE_EXTRA_CA_CERTS', 'Machine')
        if (-not $after) {
            $after = ''
        }
        $after | Should -Be $script:harmlessValue -Because 'the tests must not change the machine'
    }

    It 'defaults to the certificate bundle shipped with Azure CLI' {
        $parameter = (Get-Command 'Set-NodeExtraCACert' -Module PDS).ScriptBlock.Ast.FindAll({
                param ($node)
                $node -is [System.Management.Automation.Language.ParameterAst]
            }, $true) | Where-Object { $_.Name.VariablePath.UserPath -eq 'CertPath' }

        $parameter.DefaultValue.Value | Should -Be 'C:\Program Files\Microsoft SDKs\Azure\CLI2\Lib\site-packages\certifi\cacert.pem'
    }

    It 'sets NODE_EXTRA_CA_CERTS for the machine and reports it' -Skip:(-not $script:isAdmin) {
        Set-NodeExtraCACert -CertPath $script:harmlessValue

        Should -Invoke Write-Host -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Object -eq "NODE_EXTRA_CA_CERTS set to: $script:harmlessValue" -and $ForegroundColor -eq 'Green'
        }
        Should -Invoke Write-Error -ModuleName PDS -Times 0 -Exactly
    }

    It 'writes an error when it may not change machine variables' -Skip:$script:isAdmin {
        Set-NodeExtraCACert -CertPath $script:harmlessValue

        Should -Invoke Write-Error -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $Message -like 'Failed to set NODE_EXTRA_CA_CERTS: *'
        }
        Should -Invoke Write-Host -ModuleName PDS -Times 0 -Exactly
    }

    It 'still runs under its old name' {
        $command = Get-Command 'Set-NodeExtraCACerts' -Module PDS
        $command.CommandType | Should -Be 'Alias'
        $command.ResolvedCommandName | Should -Be 'Set-NodeExtraCACert'

        Set-NodeExtraCACerts -CertPath $script:harmlessValue

        # Elevated, the variable is written and reported; otherwise the write fails with an error.
        Should -Invoke Write-Host -ModuleName PDS -Times ([int]$script:isElevated) -Exactly -ParameterFilter {
            $Object -eq "NODE_EXTRA_CA_CERTS set to: $script:harmlessValue"
        }
        Should -Invoke Write-Error -ModuleName PDS -Times ([int](-not $script:isElevated)) -Exactly
    }
}
