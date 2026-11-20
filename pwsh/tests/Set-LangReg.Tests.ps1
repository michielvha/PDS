BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'module' 'PDS.psm1') -Force
}

Describe 'Set-LangReg' {
    BeforeEach {
        Mock Set-WinUILanguageOverride -ModuleName PDS
        Mock Set-WinSystemLocale -ModuleName PDS
        Mock Set-WinUserLanguageList -ModuleName PDS
        Mock Set-WinHomeLocation -ModuleName PDS
        Mock Get-WinUILanguageOverride -ModuleName PDS -MockWith { 'ui-language' }
        Mock Get-WinSystemLocale -ModuleName PDS -MockWith { 'system-locale' }
        Mock Get-WinUserLanguageList -ModuleName PDS -MockWith { 'user-language-list' }
        Mock Get-WinHomeLocation -ModuleName PDS -MockWith { 'home-location' }
    }

    It 'sets the display language, locale, language list and home location' {
        $null = Set-LangReg

        Should -Invoke Set-WinUILanguageOverride -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $Language.Name -eq 'en-US' }
        Should -Invoke Set-WinSystemLocale -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $SystemLocale.Name -eq 'nl-BE' }
        Should -Invoke Set-WinUserLanguageList -ModuleName PDS -Times 1 -Exactly -ParameterFilter {
            $LanguageList[0].LanguageTag -eq 'nl-BE' -and $Force
        }
        Should -Invoke Set-WinHomeLocation -ModuleName PDS -Times 1 -Exactly -ParameterFilter { $GeoId -eq 244 }
    }

    It 'returns the resulting language settings' {
        $result = Set-LangReg

        $result | Should -Be @('ui-language', 'system-locale', 'user-language-list', 'home-location')
    }

    It 'changes nothing under -WhatIf' {
        $null = Set-LangReg -WhatIf

        Should -Invoke Set-WinUILanguageOverride -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Set-WinSystemLocale -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Set-WinUserLanguageList -ModuleName PDS -Times 0 -Exactly
        Should -Invoke Set-WinHomeLocation -ModuleName PDS -Times 0 -Exactly
    }
}
