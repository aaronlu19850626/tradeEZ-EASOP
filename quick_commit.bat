@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ========================================
echo   tradeEZ EA - Quick Commit
echo ========================================
echo.

REM 检查 Git 是否安装
where git >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Git 未安装！
    echo.
    echo 请访问 https://git-scm.com/download/win 下载安装
    pause
    exit /b 1
)

REM 查看状态
echo 📋 当前状态：
git status -s
echo.

REM 输入提交信息
set /p commit_msg="💬 输入提交信息: "

if "%commit_msg%"=="" (
    echo ❌ 提交信息不能为空！
    pause
    exit /b 1
)

echo.
echo 📦 添加修改...
git add .

echo.
echo 💾 提交中...
git commit -m "%commit_msg%"

if %ERRORLEVEL% NEQ 0 (
    echo ❌ 提交失败！
    pause
    exit /b 1
)

echo.
echo 🚀 推送到 GitHub...
git push origin main

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ 提交完成！
) else (
    echo.
    echo ⚠️ 推送失败，可能需要先拉取远程更改：
    echo    git pull origin main --rebase
    echo    git push origin main
)

echo.
pause
