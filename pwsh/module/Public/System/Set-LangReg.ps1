function Set-LangReg {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .PARAMETER Username

    .PARAMETER Password

    .EXAMPLE

    .NOTES

    .LINK

    #>
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    # Set the system display language to English (United States)
    if ($PSCmdlet.ShouldProcess('Windows display language override', 'Set to en-US')) {
        Set-WinUILanguageOverride -Language "en-US"
    }

    # Set the system locale to English (United States)
    if ($PSCmdlet.ShouldProcess('Windows system locale', 'Set to nl-BE')) {
        Set-WinSystemLocale -SystemLocale "nl-BE"
    }

    # Set the input method and language list to English (United States)
    if ($PSCmdlet.ShouldProcess('Windows user language list', 'Set to nl-BE')) {
        $LanguageList = New-WinUserLanguageList -Language "nl-BE"
        Set-WinUserLanguageList $LanguageList -Force
    }

    # Set the home location (locale) to the United States
    if ($PSCmdlet.ShouldProcess('Windows home location', 'Set to GeoId 244')) {
        Set-WinHomeLocation -GeoId 244
    }

    # Check the display language
    Get-WinUILanguageOverride

    # Check the system locale
    Get-WinSystemLocale

    # Check the user's language list
    Get-WinUserLanguageList

    # Check the home location (locale)
    Get-WinHomeLocation
}
