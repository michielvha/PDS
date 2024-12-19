function Set-ShellHistory
{
    <#
.SYNOPSIS
    This function sets allows you to modify the shell history file

.DESCRIPTION
    The `Set-ShellHistory` function allows you to quickly modify the shell history file via notepad.exe
.EXAMPLE

.NOTES
    Author: michielvha
#>

    notepad.exe $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
}