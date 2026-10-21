@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch-Kawai.ps1"
set "launchExit=%ERRORLEVEL%"
if not "%launchExit%"=="0" pause
exit /b %launchExit%
