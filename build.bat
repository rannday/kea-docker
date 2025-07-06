@echo off
setlocal

echo Building Docker image: kea-custom

REM Build Docker image and save output to log file
docker build -t kea-custom . > build.log 2>&1

REM Check for errors
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build failed. Check build.log for details.
    exit /b %ERRORLEVEL%
)

echo.
echo Build completed successfully.
echo Log saved to build.log

endlocal
