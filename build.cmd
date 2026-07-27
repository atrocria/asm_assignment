@echo off
setlocal

rem Run only this build process with script execution enabled.
rem This does not change the user's or computer's execution policy.
set "DOSBOX_FOLDER=C:\ProgramData\Microsoft\Windows\Start Menu\Programs\DOSBox-0.74-3"

if not exist "%DOSBOX_FOLDER%\" goto AUTO_DETECT_DOSBOX
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" -DosBox "%DOSBOX_FOLDER%" %*
goto BUILD_FINISHED

:AUTO_DETECT_DOSBOX
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*

:BUILD_FINISHED
set "BUILD_EXIT_CODE=%ERRORLEVEL%"
if not "%BUILD_EXIT_CODE%"=="0" pause
exit /b %BUILD_EXIT_CODE%
