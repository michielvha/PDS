BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force

    # The test machine has no RSAT and no ImportExcel, and may lack PowerShellGet, so their
    # commands are stubbed in module scope and mocked per test. The stubs are created from a
    # string so the analyzer does not report their unused parameters.
    InModuleScope PDS {
        . ([scriptblock]::Create(@'
function script:Get-ADComputer { [CmdletBinding()] param($Filter, $Properties, $SearchBase) }
function script:Export-Excel { [CmdletBinding()] param([Parameter(ValueFromPipeline)]$InputObject, $Path, [switch]$AutoSize) }
function script:Install-Module { [CmdletBinding()] param($Name, $Scope, [switch]$Force) }
'@))
    }
}

Describe 'Export-ComputerInfo' {
    BeforeAll {
        Mock Import-Module -ModuleName PDS -ParameterFilter { $Name -contains 'ActiveDirectory' -or $Name -contains 'ImportExcel' }
        Mock Install-Module -ModuleName PDS
        # Pester 6 does not fall through to the real command when no filter matches, so a
        # default Get-Module mock reports that no module is loaded or installed.
        Mock Get-Module -ModuleName PDS
        Mock Write-Host -ModuleName PDS
        Mock Export-Excel -ModuleName PDS
        Mock Get-ADComputer -ModuleName PDS {
            [pscustomobject]@{ Name = 'PC-OLD'; DistinguishedName = 'CN=PC-OLD,OU=Workstations,DC=contoso,DC=com'; LastLogonDate = [datetime]'2024-01-01' }
            [pscustomobject]@{ Name = 'PC-NEW'; DistinguishedName = 'CN=PC-NEW,OU=Workstations,DC=contoso,DC=com'; LastLogonDate = [datetime]'2026-11-01' }
        }
    }

    It 'exports every computer to CSV, most recently seen first' {
        $path = Join-Path $TestDrive 'computers.csv'

        Export-ComputerInfo -Path $path

        $rows = @(Import-Csv -Path $path)
        $rows.Count | Should -Be 2
        $rows[0].'Computer Name' | Should -Be 'PC-NEW'
        $rows[1].'Computer Name' | Should -Be 'PC-OLD'
        $rows[1].Location | Should -Be 'CN=PC-OLD,OU=Workstations,DC=contoso,DC=com'
    }

    It 'returns the sorted rows with -PassThru and passes SearchBase and Filter to Get-ADComputer' {
        $path = Join-Path $TestDrive 'passthru.csv'

        $result = Export-ComputerInfo -Path $path -SearchBase 'OU=Workstations,DC=contoso,DC=com' -Filter "Name -like 'PC*'" -PassThru

        $result.'Computer Name' | Should -Be @('PC-NEW', 'PC-OLD')
        Should -Invoke Get-ADComputer -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $SearchBase -eq 'OU=Workstations,DC=contoso,DC=com' -and
            $Filter -eq "Name -like 'PC*'" -and
            $Properties -contains 'LastLogonDate'
        }
    }

    It 'creates the output directory when it does not exist' {
        $path = Join-Path $TestDrive 'new' 'nested' 'computers.csv'

        Export-ComputerInfo -Path $path

        Test-Path -Path $path | Should -BeTrue
    }

    It 'exports to Excel for an .xlsx path without installing ImportExcel when it is available' {
        Mock Get-Module -ModuleName PDS -ParameterFilter { $Name -contains 'ImportExcel' } { [pscustomobject]@{ Name = 'ImportExcel' } }
        Export-ComputerInfo -Path (Join-Path $TestDrive 'computers.xlsx')

        Should -Invoke Export-Excel -ModuleName PDS -ParameterFilter { $Path -like '*computers.xlsx' -and $AutoSize }
        Should -Invoke Install-Module -ModuleName PDS -Times 0 -Exactly
    }

    It 'installs and imports ImportExcel when it is missing' {
        Mock Get-Module -ModuleName PDS -ParameterFilter { $Name -contains 'ImportExcel' }

        Export-ComputerInfo -Path (Join-Path $TestDrive 'install.xlsx')

        Should -Invoke Install-Module -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Name -contains 'ImportExcel' -and $Scope -eq 'CurrentUser' }
        Should -Invoke Import-Module -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Name -contains 'ImportExcel' }
    }

    It 'throws for an unknown extension when -Format is not given' {
        { Export-ComputerInfo -Path (Join-Path $TestDrive 'computers.txt') } | Should -Throw '*Unable to determine format*'
    }

    It 'warns and writes no file when no computer matches' {
        Mock Get-ADComputer -ModuleName PDS { }
        $path = Join-Path $TestDrive 'empty.csv'

        Export-ComputerInfo -Path $path -WarningVariable warnings -WarningAction SilentlyContinue

        $warnings | Should -Match 'No computers found'
        Test-Path -Path $path | Should -BeFalse
    }
}
