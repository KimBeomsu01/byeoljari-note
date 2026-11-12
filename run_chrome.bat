@echo off
rem Developer run in Chrome with hot reload (r). Uses a fresh Chrome profile, so saved records reset each run.
cd /d "%~dp0"
call D:\dev\flutter\bin\flutter.bat pub get
call D:\dev\flutter\bin\flutter.bat run -d chrome
pause
