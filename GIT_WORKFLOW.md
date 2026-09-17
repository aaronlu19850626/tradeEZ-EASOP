# Git 工作流程 - tradeEZ EA 项目

## 仓库信息
- **GitHub 仓库**：https://github.com/aaronlu19850626/tradeEZ-EASOP
- **主文件名**：`tradeEZ.mq5`
- **提交规则**：每次修改后必须提交

---

## 首次设置

### 1. 安装 Git

**下载地址**：https://git-scm.com/download/win

**安装后验证**：
```bash
git --version
```

### 2. 配置 Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 3. 克隆仓库（如果还未克隆）

```bash
cd "C:\Users\lzq31\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Gold SOP"
git init
git remote add origin https://github.com/aaronlu19850626/tradeEZ-EASOP.git
```

或直接克隆：
```bash
git clone https://github.com/aaronlu19850626/tradeEZ-EASOP.git
```

---

## 日常提交工作流

### 方式一：命令行（推荐）

```bash
# 1. 进入项目目录
cd "C:\Users\lzq31\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Gold SOP"

# 2. 查看状态
git status

# 3. 添加修改的文件
git add tradeEZ.mq5

# 或添加所有修改
git add .

# 4. 提交（填写有意义的提交信息）
git commit -m "描述本次修改的内容"

# 5. 推送到 GitHub
git push origin main
```

### 方式二：VS Code（可视化）

1. 打开 VS Code
2. 打开项目文件夹
3. 点击左侧「源代码管理」图标
4. 在「更改」列表中查看修改的文件
5. 点击「+」号暂存更改
6. 输入提交信息
7. 点击「✓ 提交」
8. 点击「...」→「推送」

---

## 提交信息规范

### 格式

```
类型(范围): 简短描述

详细说明（可选）
```

### 类型

- `feat`: 新功能
- `fix`: Bug 修复
- `refactor`: 重构（不改变功能）
- `docs`: 文档更新
- `style`: 代码格式调整
- `perf`: 性能优化
- `test`: 测试相关

### 示例

```bash
# 新功能
git commit -m "feat(sync): 实现增量同步机制"

# Bug 修复
git commit -m "fix(sync): 修复边界时间重复上传问题"

# 重构
git commit -m "refactor(sync): 移除队列文件机制，改为增量查询"

# 文档
git commit -m "docs: 更新 API 规范文档 v2.0"

# 性能优化
git commit -m "perf(sync): 减少磁盘 IO，提升同步性能"
```

---

## 快速提交脚本

创建 `quick_commit.bat`：

```batch
@echo off
cd /d "C:\Users\lzq31\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Gold SOP"

echo ========================================
echo   tradeEZ EA - Quick Commit
echo ========================================
echo.

REM 查看状态
git status

echo.
set /p commit_msg="输入提交信息: "

REM 添加所有修改
git add .

REM 提交
git commit -m "%commit_msg%"

REM 推送
git push origin main

echo.
echo ✅ 提交完成！
pause
```

**使用方法**：双击运行，输入提交信息即可。

---

## PowerShell 快速提交函数

添加到 PowerShell 配置文件（`$PROFILE`）：

```powershell
function Commit-TradeEZ {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $ProjectPath = "C:\Users\lzq31\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Gold SOP"
    
    Push-Location $ProjectPath
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  tradeEZ EA - Quick Commit" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # 状态
    git status
    
    # 添加
    git add .
    
    # 提交
    git commit -m $Message
    
    # 推送
    git push origin main
    
    Write-Host ""
    Write-Host "✅ 提交完成！" -ForegroundColor Green
    
    Pop-Location
}

# 别名
Set-Alias ctez Commit-TradeEZ
```

**使用方法**：
```powershell
ctez "feat(sync): 实现增量同步"
```

---

## 常见问题

### Q1: push 时要求输入用户名密码

**A:** GitHub 已不支持密码登录，需要使用 Personal Access Token (PAT)。

**步骤**：
1. 访问 https://github.com/settings/tokens
2. 点击「Generate new token」→「Generate new token (classic)」
3. 勾选 `repo` 权限
4. 复制生成的 token（类似 `ghp_xxxx...`）
5. 使用时：
   - 用户名：`aaronlu19850626`
   - 密码：粘贴 token

**保存凭据**（推荐）：
```bash
git config --global credential.helper wincred
```

---

### Q2: 提交冲突

**A:** 先拉取远程更改，再提交：
```bash
git pull origin main --rebase
git push origin main
```

---

### Q3: 撤销上次提交

**A:** 
```bash
# 撤销提交但保留修改
git reset --soft HEAD~1

# 撤销提交并丢弃修改（危险）
git reset --hard HEAD~1
```

---

### Q4: 查看提交历史

**A:**
```bash
# 简洁版
git log --oneline -10

# 图形化
git log --graph --oneline --all

# 详细版
git log -p -2
```

---

## 文件结构建议

```
tradeEZ-EASOP/
├── tradeEZ.mq5                      # 主 EA 源码
├── README.md                         # 项目说明
├── DEV_NOTES.md                      # 开发笔记
├── CHANGELOG.md                      # 变更日志
├── docs/
│   ├── API_SPECIFICATION_V2.md      # API 规范
│   ├── SYNC_INCREMENTAL_DESIGN.md   # 增量同步设计
│   ├── SYNC_SETUP_GUIDE.md          # 用户设置指南
│   └── ...
├── tests/
│   └── ...                          # 测试脚本
└── .gitignore                       # Git 忽略文件
```

---

## .gitignore 建议

创建 `.gitignore` 文件：

```gitignore
# 编译产物
*.ex5

# 临时文件
*.tmp
*.bak
*.log

# 队列文件（v1.0 遗留）
GSOP_sync_queue_*.jsonl

# 状态文件
GSOP_state_*.csv

# IDE 配置
.vscode/
.idea/

# 系统文件
Thumbs.db
.DS_Store
```

---

## 自动化提交（高级）

### Git Hooks - pre-commit

创建 `.git/hooks/pre-commit`：

```bash
#!/bin/sh

echo "运行 pre-commit 检查..."

# 检查是否有未添加的 .mq5 文件
if git diff --name-only | grep -q '\.mq5$'; then
    echo "警告：有 .mq5 文件未添加到暂存区"
    echo "运行: git add *.mq5"
    exit 1
fi

echo "✅ 检查通过"
exit 0
```

---

**最后更新**：2026-01-18  
**维护者**：Claude Code
