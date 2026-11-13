@echo off
setlocal EnableDelayedExpansion
title Cursor Trail Control
set "SCRIPT=%~dp0cursor-trail.ps1"
set "RUNKEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
set "OLDLNK=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\CursorTrail.lnk"

set "HEX_COLOR=00FFFF"
set "TRAIL_LEN=5"

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
echo  Current Color: #%HEX_COLOR%  ^|  Length: %TRAIL_LEN%
echo.
echo  [1] Start
echo  [2] Stop
echo  [3] Enable auto-start with Windows
echo  [4] Disable auto-start
echo  [5] Change Color (Hex)
echo  [6] Change Length (1-10)
echo  [7] Exit
echo.
choice /c 1234567 /n /m "Choose 1-7: "
if errorlevel 7 goto :eof
if errorlevel 6 goto setlength
if errorlevel 5 goto setcolor
if errorlevel 4 goto disable
if errorlevel 3 goto enable
if errorlevel 2 goto stop
if errorlevel 1 goto start

:start
call :killtrail
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT%" -Color "%HEX_COLOR%" -Length %TRAIL_LEN%
echo Cursor trail updated and running!
timeout /t 1 >nul
goto menu

:stop
call :killtrail
echo Cursor trail stopped.
timeout /t 1 >nul
goto menu

:enable
del "%OLDLNK%" >nul 2>&1
reg add "%RUNKEY%" /v CursorTrail /t REG_SZ /d "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%SCRIPT%\" -Color \"%HEX_COLOR%\" -Length %TRAIL_LEN%" /f >nul
echo Auto-start enabled with current settings.
timeout /t 2 >nul
goto menu

:disable
del "%OLDLNK%" >nul 2>&1
reg delete "%RUNKEY%" /v CursorTrail /f >nul 2>&1
echo Auto-start disabled.
timeout /t 2 >nul
goto menu

:setcolor
set /p "INPUT_COLOR=Enter Hex Color (e.g. FF0000 for Red): "
set "INPUT_COLOR=%INPUT_COLOR:#=%"
echo:%INPUT_COLOR%| findstr /r /i "^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$" >nul
if errorlevel 1 (
    echo.
    echo [ERROR] Invalid hex color! Please use 6 characters like FF0000 or 00FF00.
    timeout /t 3 >nul
    goto setcolor
)
set "HEX_COLOR=%INPUT_COLOR%"
goto start

:setlength
:: auto apply the last valid length if the user just presses Enter
set /p "INPUT_LEN=Enter Trail Length (1-10): "
set /a "TEST_LEN=INPUT_LEN" 2>nul
if %TEST_LEN% geq 1 if %TEST_LEN% leq 10 (
    set "TRAIL_LEN=%TEST_LEN%"
    goto start
)
echo.
echo [ERROR] Invalid length Please enter a number between 1 and 10
timeout /t 3 >nul
goto setlength

:killtrail
powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'powershell.exe' -and $_.CommandLine -like '*cursor-trail.ps1*' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
exit /b
