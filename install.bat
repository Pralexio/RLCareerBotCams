@echo off
rem botcams installer: double-click it after extracting the zip.
rem Copies cameras.py and botcams.dll where they belong, enables the plugin in BakkesMod
rem and downloads the camera list once, checking each step.
setlocal
title botcams installer
set "SRC=%~dp0"
set "BOTSWAP=%APPDATA%\rl-career-hub\botswap"
set "BAKKES=%APPDATA%\bakkesmod\bakkesmod"
set "PYTHON=%LOCALAPPDATA%\Programs\RL Career Hub\resources\python\python.exe"

echo.
echo  botcams installer
echo  -----------------
echo.

if not exist "%SRC%botcams.dll" goto :notextracted
if not exist "%SRC%cameras.py" goto :notextracted

if not exist "%PYTHON%" (
    echo  [ERROR] RL Career Hub not found ^(%PYTHON%^).
    echo          Install RL Career Hub first.
    goto :fail
)
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
