@echo off
rem Build the web app for the Docker server (backend\compose.yaml serves build\web at http://localhost:8093).
rem  Mobile: http://localhost:8093/     PC: http://localhost:8093/pc
rem  Accounts and password: backend\.env (APP_ACCOUNTS, APP_TEST_PASSWORD)
cd /d "%~dp0"
call D:\dev\flutter\bin\flutter.bat pub get
call D:\dev\flutter\bin\flutter.bat build web --release --dart-define=API_BASE_URL=/api/
if errorlevel 1 goto end
echo.
echo Done. Reload http://localhost:8093/ (mobile) or http://localhost:8093/pc (PC).
:end
pause
