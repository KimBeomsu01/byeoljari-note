@echo off
rem Build the Android install file (APK). Needs Android Studio (Android SDK) on this PC.
rem   build_android.bat http://<server PC IP>:8093
rem Find the server PC IP with ipconfig on the server PC (phone and server PC on the same Wi-Fi).
rem Output: build\app\outputs\flutter-apk\app-release.apk (copy to the phone and install)
cd /d "%~dp0"
set SERVER=%1
if "%SERVER%"=="" (
  echo Add the server address. Example: build_android.bat http://^<server PC IP^>:8093
  goto end
)
echo Server: %SERVER%
call flutter pub get
call flutter build apk --release --dart-define=API_BASE_URL=%SERVER%/api/
if errorlevel 1 goto end
echo.
echo Done: build\app\outputs\flutter-apk\app-release.apk
:end
pause
