@echo off
rem Build the web app and open it in your normal Chrome. Records stay in this browser after closing.
cd /d "%~dp0"
call D:\dev\flutter\bin\flutter.bat pub get
call D:\dev\flutter\bin\flutter.bat build web
if errorlevel 1 goto end
start "" http://localhost:8080
python -m http.server 8080 --bind 127.0.0.1 --directory build\web
:end
pause
