@echo off

SET SCRIPTDRIVE=%~d0
SET SCRIPTPATH=%~p0
@REM or just use %~dp0 => refers to currently running script fully qualified path

powershell.exe -ExecutionPolicy Bypass -File "%SCRIPTDRIVE%%SCRIPTPATH%main.ps1"