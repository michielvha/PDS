BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Test-Admin' {
    It 'returns whether the current token is in the Administrators role' -Skip:(-not $IsWindows) {
        $expected = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        $result = Test-Admin

        $result | Should -BeOfType [bool]
        $result | Should -Be $expected
    }
}
