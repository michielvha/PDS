BeforeDiscovery {
    # Without elevation the function calls exit, which would end the whole test run, so only the
    # elevated path is tested.
    $script:isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
    if (-not (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue)) {
        InModuleScope PDS { function script:Get-MpPreference { } }
    }
}

Describe 'Get-WinDefExcludedPath' {
    BeforeEach {
        Mock Start-Sleep -ModuleName PDS
    }

    It 'lists the paths excluded from Defender scanning' -Skip:(-not $script:isAdmin) {
        Mock Get-MpPreference -ModuleName PDS -MockWith {
            [pscustomobject]@{ ExclusionPath = @('C:\Temp', 'D:\Build') }
        }

        $result = Get-WinDefExcludedPath

        Should -Invoke Get-MpPreference -ModuleName PDS -Times 1 -Exactly
        $result[0] | Should -Match 'Listing all Windows Defender excluded paths'
        $result | Select-Object -Skip 1 | Should -Be @('C:\Temp', 'D:\Build')
    }

    It 'returns only the heading when there are no exclusions' -Skip:(-not $script:isAdmin) {
        Mock Get-MpPreference -ModuleName PDS -MockWith { [pscustomobject]@{ ExclusionPath = $null } }

        $result = @(Get-WinDefExcludedPath)

        $result.Count | Should -Be 1
        $result[0] | Should -Match 'Listing all Windows Defender excluded paths'
    }
}
