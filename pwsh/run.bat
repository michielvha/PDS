@echo off
PowerShell -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File "".\main.ps1""' -Verb RunAs}"
pause
