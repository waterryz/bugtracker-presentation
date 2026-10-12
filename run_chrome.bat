@echo off
setlocal
cd /d "%~dp0"
set "BUGTRACKER_FLUTTER=C:\flutter\bin\flutter.bat"
if not exist "%BUGTRACKER_FLUTTER%" set "BUGTRACKER_FLUTTER=flutter"
call "%BUGTRACKER_FLUTTER%" --no-version-check run -d chrome --web-hostname=127.0.0.1 --web-port=8766 --no-web-resources-cdn "--web-browser-flag=--user-data-dir=%~dp0.chrome-profile"
endlocal
