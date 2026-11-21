@echo off
rem Builds botcams.dll with Visual Studio 2022 and the BakkesMod SDK, then installs it.
setlocal
set SDK=%APPDATA%\bakkesmod\bakkesmod\bakkesmodsdk
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
cd /d "%~dp0"
cl /nologo /LD /std:c++20 /EHsc /MD /O2 /I "%SDK%\include" botcams.cpp /link "%SDK%\lib\pluginsdk.lib" /OUT:botcams.dll || exit /b 1
copy /y botcams.dll "%APPDATA%\bakkesmod\bakkesmod\plugins\botcams.dll" || exit /b 1
findstr /i /c:"plugin load botcams" "%APPDATA%\bakkesmod\bakkesmod\cfg\plugins.cfg" >nul || echo plugin load botcams>>"%APPDATA%\bakkesmod\bakkesmod\cfg\plugins.cfg"
echo botcams installed
