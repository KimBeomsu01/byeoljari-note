@echo off
rem Run Byeoljari Note in Chrome (double-click, or run_chrome.bat in a terminal).
rem Runs flutter through cmd because flutter run typed in PowerShell sometimes fails to compile.
cd /d "%~dp0"
call D:\dev\flutter\bin\flutter.bat run -d chrome
pause
