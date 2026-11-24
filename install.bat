@echo off
rem botcams installer: double-click it after extracting the zip.
rem Copies cameras.py and botcams.dll where they belong, enables the plugin in BakkesMod
rem and downloads the camera list once, checking each step.
setlocal
title botcams installer
set "SRC=%~dp0"
set "BOTSWAP=%APPDATA%\rl-career-hub\botswap"
set "BAKKES=%APPDATA%\bakkesmod\bakkesmod"

echo.
echo  botcams installer
echo  -----------------
echo.

if not exist "%SRC%botcams.dll" goto :notextracted
if not exist "%SRC%cameras.py" goto :notextracted

rem RL Career Hub: where Windows' "Installed apps" list says it is, else the usual folders,
rem else ask. Its Python fetches the camera list.
set "HUB="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "$a = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA 0 | Where-Object { $_.DisplayName -like 'RL Career Hub*' -and $_.DisplayIcon } | Select-Object -First 1; if ($a) { Split-Path (($a.DisplayIcon -replace ',\d+$', '').Trim([char]34)) }" 2^>nul`) do set "HUB=%%i"
if not exist "%HUB%\resources\python\python.exe" set "HUB=%LOCALAPPDATA%\Programs\RL Career Hub"
if not exist "%HUB%\resources\python\python.exe" set "HUB=%ProgramFiles%\RL Career Hub"
if exist "%HUB%\resources\python\python.exe" goto :hubfound
echo  RL Career Hub was not found automatically.
echo  Paste the folder that contains "RL Career Hub.exe", then press Enter:
set /p "HUB=  > "
set "HUB=%HUB:"=%"
rem "Copy as path" on the exe gives the file, not the folder.
if /i "%HUB:~-4%"==".exe" for %%f in ("%HUB%") do set "HUB=%%~dpf"
if "%HUB:~-1%"=="\" set "HUB=%HUB:~0,-1%"
if exist "%HUB%\resources\python\python.exe" goto :hubfound
echo.
echo  [ERROR] RL Career Hub not found in that folder.
echo          Install RL Career Hub first, or check the folder and run this again.
goto :fail
:hubfound
set "PYTHON=%HUB%\resources\python\python.exe"
echo  [OK] RL Career Hub found: %HUB%
if not exist "%BAKKES%\plugins" (
    echo  [ERROR] BakkesMod not found ^(%BAKKES%^).
    echo          Install BakkesMod and start Rocket League once with it, then run this again.
    goto :fail
)
rem The game keeps the plugin open: the copy would fail while it runs.
tasklist /fi "imagename eq RocketLeague.exe" 2>nul | find /i "RocketLeague.exe" >nul && (
    echo  [ERROR] Rocket League is running. Close it and run this again.
    goto :fail
)

if not exist "%BOTSWAP%" mkdir "%BOTSWAP%" || goto :fail
copy /y "%SRC%cameras.py" "%BOTSWAP%\" >nul || (
    echo  [ERROR] Could not copy cameras.py to %BOTSWAP%
    goto :fail
)
echo  [OK] cameras.py copied to %BOTSWAP%
rem The plugin reads this to find the hub's Python for the weekly refresh.
>"%BOTSWAP%\python.txt" echo(%PYTHON%

copy /y "%SRC%botcams.dll" "%BAKKES%\plugins\" >nul || (
    echo  [ERROR] Could not copy botcams.dll to %BAKKES%\plugins
    goto :fail
)
echo  [OK] botcams.dll copied to %BAKKES%\plugins

set "CFG=%BAKKES%\cfg\plugins.cfg"
if not exist "%BAKKES%\cfg" mkdir "%BAKKES%\cfg"
findstr /i /x /c:"plugin load botcams" "%CFG%" >nul 2>nul && (
    echo  [OK] botcams already enabled in plugins.cfg
) || (
    rem New line first: the file may not end with one.
    (echo.& echo plugin load botcams)>>"%CFG%" || (
        echo  [ERROR] Could not write to %CFG%
        goto :fail
    )
    echo  [OK] botcams enabled in plugins.cfg
)

echo.
echo  Downloading the pro camera list...
"%PYTHON%" "%BOTSWAP%\cameras.py" --refresh >nul 2>nul
if not exist "%BOTSWAP%\cameras.txt" (
    echo  [WARNING] The camera list could not be downloaded now ^(no internet?^).
    echo            The plugin will try again by itself when Rocket League starts.
) else (
    echo  [OK] Camera list ready
)

echo.
echo  Done. Start Rocket League, play a career match and spectate a bot.
echo.
pause
exit /b 0

:notextracted
echo  [ERROR] botcams.dll or cameras.py is missing next to this file.
echo          Right-click the zip, choose "Extract All", then run install.bat from the extracted folder.
:fail
echo.
echo  Installation not finished. If you are stuck, open an issue on the GitHub page
echo  with a screenshot of this window.
echo.
pause
exit /b 1
