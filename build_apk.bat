@echo off
echo ========================================================
echo   Manjaly Multi Speciality Dental Care - APK Builder
echo ========================================================
echo.

cd dental_care_app

echo [1/3] Fetching Flutter dependencies...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo Error: flutter pub get failed. Please ensure Flutter is in your PATH.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Building Release APK...
call flutter build apk --release --android-skip-build-dependency-validation
if %ERRORLEVEL% neq 0 (
    echo Error: flutter build apk failed.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Success! Release APK built at:
echo build\app\outputs\flutter-apk\app-release.apk
echo.
pause
