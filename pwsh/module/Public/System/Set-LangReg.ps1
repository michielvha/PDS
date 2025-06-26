Function Set-LangReg {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .PARAMETER Username

    .PARAMETER Password

    .EXAMPLE

    .NOTES

    .LINK

    #>

        # Set the system display language to English (United States)
        Set-WinUILanguageOverride -Language "en-US"

        # Set the system locale to English (United States)
        Set-WinSystemLocale -SystemLocale "nl-BE"

        # Set the input method and language list to English (United States)
        $LanguageList = New-WinUserLanguageList -Language "nl-BE"
        Set-WinUserLanguageList $LanguageList -Force

        # Set the home location (locale) to the United States
        Set-WinHomeLocation -GeoId 244

        # Check the display language
        Get-WinUILanguageOverride

        # Check the system locale
        Get-WinSystemLocale

        # Check the user's language list
        Get-WinUserLanguageList

        # Check the home location (locale)
        Get-WinHomeLocation
}
