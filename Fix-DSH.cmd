@echo off
setlocal
rem Use inbox Windows PowerShell: the pwsh alias and npm are not needed.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-DSH.ps1" %*
set "dsh_fix_exit=%errorlevel%"
if not "%dsh_fix_exit%"=="0" echo Repair did not complete. Read the error above; see docs\troubleshooting.md.
if "%~1"=="" pause
exit /b %dsh_fix_exit%
