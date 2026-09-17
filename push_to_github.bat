@echo off
chcp 65001 >nul
echo ================================
echo   tradeEZ EA - 推送到 GitHub
echo ================================
echo.

REM 设置 Git 路径
set GIT="C:\Program Files\Git\bin\git.exe"

echo 🚀 推送到 GitHub...
echo.
echo ⚠️  首次推送需要输入凭据：
echo    用户名: aaronlu19850626
echo    密码: 使用 GitHub Personal Access Token 不是密码
echo.
echo 💡 如何获取 Token:
echo    1. 访问: https://github.com/settings/tokens
echo    2. 点击 Generate new token - Generate new token classic
echo    3. 名称填: tradeEZ-EA-Token
echo    4. 勾选: repo 完整权限
echo    5. 点击 Generate token
echo    6. 复制生成的 token 格式: ghp_xxxxxxxxxxxx
echo.
echo ================================
echo.

%GIT% push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo ✅ 推送成功！
    echo.
    echo 🌐 查看仓库: https://github.com/aaronlu19850626/tradeEZ-EASOP
    echo.
) else (
    echo.
    echo ❌ 推送失败
    echo.
    echo 💡 可能的原因:
    echo    1. Token 权限不足 需要 repo 权限
    echo    2. Token 已过期
    echo    3. 用户名或 Token 输入错误
    echo.
)

pause
