@echo off
setlocal
title Cursor Trail Control
set "SCRIPT=%~dp0cursor-trail.ps1"
set "RUNKEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "OLDLNK=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\CursorTrail.lnk"

if not exist "%SCRIPT%" (
    echo Could not find cursor-trail.ps1 next to this file:
    echo %SCRIPT%
    echo Put both files in the same folder and try again.
    pause
    exit /b 1
)

:menu
cls
echo. 
echo           Cursor Trail
echo           Made By BONA
echo.
echo  [1] Start
echo  [2] Stop
echo  [3] Enable auto-start with Windows
echo  [4] Disable auto-start
echo  [5] Exit
echo.
choice /c 12345 /n /m "Choose 1-5: "
if errorlevel 5 goto :eof
if errorlevel 4 goto disable
if errorlevel 3 goto enable
if errorlevel 2 goto stop
if errorlevel 1 goto start

:start
call :killtrail
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT%"
echo Cursor trail started.
timeout /t 2 >nul
goto menu

:stop
call :killtrail
echo Cursor trail stopped.
timeout /t 2 >nul
goto menu

:enable
del "%OLDLNK%" >nul 2>&1
reg add "%RUNKEY%" /v CursorTrail /t REG_SZ /d "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%SCRIPT%\"" /f >nul
echo Auto-start enabled. It will run every time you sign in.
timeout /t 3 >nul
goto menu

:disable
del "%OLDLNK%" >nul 2>&1
reg delete "%RUNKEY%" /v CursorTrail /f >nul 2>&1
echo Auto-start disabled.
timeout /t 2 >nul
goto menu

:killtrail
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'powershell.exe' -and $_.CommandLine -like '*cursor-trail.ps1*' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
exit /b
