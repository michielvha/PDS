@echo off

SET SCRIPTDRIVE=%~d0
SET SCRIPTPATH=%~p0

powershell.exe -ExecutionPolicy Bypass -File "%SCRIPTDRIVE%%SCRIPTPATH%main.ps1"