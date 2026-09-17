@echo off
REM Simple push script for tradeEZ EA

"C:\Program Files\Git\bin\git.exe" push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo Success! View your repo at:
    echo https://github.com/aaronlu19850626/tradeEZ-EASOP
    echo.
) else (
    echo.
    echo Push failed. Please check:
    echo - GitHub token is valid
    echo - Token has repo permissions
    echo - Network connection is working
    echo.
)

pause
