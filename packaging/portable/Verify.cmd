@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Verify-Package.ps1"
set "verifyExit=%ERRORLEVEL%"
pause
exit /b %verifyExit%
