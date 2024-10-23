Function Enable-BGInfoAtStartup {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .PARAMETER Username

    .PARAMETER Password

    .EXAMPLE

    .NOTES

    .LINK

    #>
    # Path to the .bgi file inside the assets folder of the module
    $bgiFilePath = Join-Path $PSScriptRoot "assets\default.bgi"
    $bginfoPath = "C:\ProgramData\chocolatey\lib\bginfo\tools\Bginfo64.exe"
    $arguments = "`"$bgiFilePath`" /timer:0"

    # Create a shortcut in the startup folder
    $shortcutPath = Join-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" "BGInfo.lnk"
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $bginfoPath
    $shortcut.Arguments = $arguments
    $shortcut.Save()
}


# Optional: You can also add a scheduled task to run BGInfo if preferred (not tested - I've done this before somewhere, go look if needed.)
#$action = New-ScheduledTaskAction -Execute "C:\ProgramData\chocolatey\lib\bginfo\tools\Bginfo64.exe" -Argument '"C:\path\to\bginfo.bgi" /silent /timer:0'
#$trigger = New-ScheduledTaskTrigger -AtLogon
#$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
#Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "BGInfo" -Description "Run BGInfo silently at startup"
