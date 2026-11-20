@echo off
rem Build the web app for the Docker server (backend\compose.yaml serves build\web at http://localhost:8093).
rem  Mobile: http://localhost:8093/     PC: http://localhost:8093/pc     Doctor: http://localhost:8093/doctor
rem  Accounts and password: backend\.env (APP_ACCOUNTS, APP_TEST_PASSWORD). Setup guide: SETUP.md
rem  Uses D:\dev\flutter if it exists, otherwise "flutter" from PATH.
cd /d "%~dp0"
set FLUTTER=D:\dev\flutter\bin\flutter.bat
if not exist "%FLUTTER%" set FLUTTER=flutter
call %FLUTTER% pub get
call %FLUTTER% build web --release --dart-define=API_BASE_URL=/api/
if errorlevel 1 goto end
echo.
echo Done. Reload http://localhost:8093/ (mobile) or http://localhost:8093/pc (PC).
:end
pause
