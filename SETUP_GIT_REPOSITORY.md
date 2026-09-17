# 设置 Git 仓库 - 完整操作指南

**仓库地址**：https://github.com/aaronlu19850626/tradeEZ-EASOP

---

## 📋 前提条件

### 1. 安装 Git

**下载地址**：https://git-scm.com/download/win

**安装步骤**：
1. 下载 Git 安装程序
2. 运行安装程序，全部选择默认选项
3. 安装完成后，打开命令提示符或 PowerShell
4. 验证安装：
   ```bash
   git --version
   ```
   应显示类似：`git version 2.43.0`

---

## 🚀 初始化本地仓库

### 方式一：在现有文件夹初始化（推荐）

**步骤**：

1. **打开 PowerShell**（以管理员身份）

2. **进入项目目录**：
   ```powershell
   cd "C:\Users\lzq31\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\Gold SOP"
   ```

3. **配置 Git 用户信息**（首次使用）：
   ```bash
   git config --global user.name "Aaron Lu"
   git config --global user.email "aaronlu19850626@gmail.com"
   ```

4. **初始化 Git 仓库**：
   ```bash
   git init
   ```

5. **添加远程仓库**：
   ```bash
   git remote add origin https://github.com/aaronlu19850626/tradeEZ-EASOP.git
   ```

6. **创建 .gitignore 文件**：
   ```bash
   @"
# 编译产物
*.ex5

# 临时文件
*.tmp
*.bak
*.log

# 状态文件
GSOP_state_*.csv

# IDE 配置
.vscode/
.idea/

# 系统文件
Thumbs.db
.DS_Store
"@ | Out-File -FilePath .gitignore -Encoding utf8
   ```

7. **添加所有文件**：
   ```bash
   git add .
   ```

8. **首次提交**：
   ```bash
   git commit -m "feat: Initial commit - tradeEZ EA v2.0 with incremental sync"
   ```

9. **设置主分支名称**（如果需要）：
   ```bash
   git branch -M main
   ```

10. **推送到 GitHub**：
    ```bash
    git push -u origin main
    ```

---

### 方式二：克隆空仓库后复制文件

**步骤**：

1. **克隆空仓库**：
   ```bash
   cd C:\Users\lzq31\Desktop
   git clone https://github.com/aaronlu19850626/tradeEZ-EASOP.git
   ```

2. **复制文件到克隆的文件夹**：
   将以下文件从原目录复制到 `C:\Users\lzq31\Desktop\tradeEZ-EASOP\`：
   - `tradeEZ.mq5`
   - 所有 `*.md` 文档
   - `quick_commit.bat`

3. **进入仓库目录**：
   ```bash
   cd tradeEZ-EASOP
   ```

4. **创建 .gitignore**（同上）

5. **提交并推送**：
   ```bash
   git add .
   git commit -m "feat: Initial commit - tradeEZ EA v2.0"
   git push origin main
   ```

---

## 🔑 配置 GitHub 鉴权

### 使用 Personal Access Token (PAT)

GitHub 已不支持密码登录，需要使用 PAT。

**步骤**：

1. **生成 Token**：
   - 访问：https://github.com/settings/tokens
   - 点击「Generate new token」→「Generate new token (classic)」
   - 设置名称：`tradeEZ-EA-Token`
   - 勾选权限：
     - ✅ `repo`（完整仓库权限）
   - 点击「Generate token」
   - **复制生成的 token**（类似 `ghp_xxxxxxxxxxxx`）
   - ⚠️ 立即保存！此 token 只显示一次

2. **首次推送时**：
   ```bash
   git push origin main
   ```
   会提示输入用户名和密码：
   - **用户名**：`aaronlu19850626`
   - **密码**：粘贴刚才的 token（`ghp_xxxxxxxxxxxx`）

3. **保存凭据**（避免每次输入）：
   ```bash
   git config --global credential.helper wincred
   ```
   Windows 会将凭据保存到「凭据管理器」。

---

## 📂 文件结构检查

确认以下文件已添加到仓库：

```
tradeEZ-EASOP/
├── tradeEZ.mq5                         ✅ 主 EA 源码
├── README.md                            ✅ 项目说明
├── DEV_NOTES.md                         ✅ 开发笔记
├── GIT_WORKFLOW.md                      ✅ Git 工作流程
├── SETUP_GIT_REPOSITORY.md              ✅ 本文档
├── API_SPECIFICATION_V2.md              ✅ API 规范
├── SYNC_INCREMENTAL_DESIGN.md           ✅ 增量同步设计
├── SYNC_SETUP_GUIDE.md                  ✅ 用户指南
├── SYNC_V2_CHANGES.md                   ✅ 变更说明
├── IMPLEMENTATION_COMPLETE_V2.md        ✅ 实现报告
├── quick_commit.bat                     ✅ 快速提交脚本
├── .gitignore                           ✅ Git 忽略规则
└── Gold_SOP_EA.mq5                      ⚠️ 旧文件（可选保留）
```

**验证文件已添加**：
```bash
git status
```

应显示：`nothing to commit, working tree clean`

---

## 🧪 测试提交流程

1. **修改一个文件**（例如 README.md）：
   ```bash
   echo "" >> README.md
   ```

2. **查看状态**：
   ```bash
   git status
   ```
   应显示：`modified: README.md`

3. **添加修改**：
   ```bash
   git add README.md
   ```

4. **提交**：
   ```bash
   git commit -m "test: Test commit workflow"
   ```

5. **推送**：
   ```bash
   git push origin main
   ```

6. **验证**：
   访问 https://github.com/aaronlu19850626/tradeEZ-EASOP
   确认文件已更新

---

## 🛠️ 常见问题

### Q1: `fatal: not a git repository`

**A:** 未初始化 Git 仓库，运行：
```bash
git init
```

---

### Q2: `error: remote origin already exists`

**A:** 远程仓库已存在，查看：
```bash
git remote -v
```

如果地址错误，删除后重新添加：
```bash
git remote remove origin
git remote add origin https://github.com/aaronlu19850626/tradeEZ-EASOP.git
```

---

### Q3: `error: src refspec main does not exist`

**A:** 当前分支不是 `main`，重命名分支：
```bash
git branch -M main
```

---

### Q4: 推送时提示 `rejected`（拒绝）

**A:** 远程仓库有本地没有的提交，先拉取：
```bash
git pull origin main --allow-unrelated-histories
git push origin main
```

---

### Q5: 推送时提示 403 Forbidden

**A:** Token 无效或权限不足：
1. 检查 token 是否勾选 `repo` 权限
2. 重新生成 token
3. 清除旧凭据：
   ```bash
   git credential-manager delete https://github.com
   ```
4. 重新推送（会要求输入新 token）

---

### Q6: 如何查看提交历史？

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

### Q7: 如何撤销上次提交？

**A:**
```bash
# 撤销提交但保留修改
git reset --soft HEAD~1

# 撤销提交并丢弃修改（危险）
git reset --hard HEAD~1
```

---

### Q8: 如何忽略某些文件？

**A:** 编辑 `.gitignore` 文件，添加文件名或模式：
```
# 忽略所有 .ex5 文件
*.ex5

# 忽略特定文件
Gold_SOP_EA.mq5

# 忽略目录
.vscode/
```

---

## ✅ 验收检查清单

完成以下检查后，Git 仓库设置成功：

- [ ] Git 已安装并验证（`git --version`）
- [ ] 用户名和邮箱已配置（`git config --list`）
- [ ] 本地仓库已初始化（`.git` 文件夹存在）
- [ ] 远程仓库已添加（`git remote -v` 显示正确地址）
- [ ] `.gitignore` 文件已创建
- [ ] 所有文件已提交（`git status` 显示 clean）
- [ ] 已成功推送到 GitHub（访问网页确认）
- [ ] PAT 已保存到凭据管理器（`git config credential.helper`）
- [ ] 测试提交流程通过

---

## 📝 下一步

仓库设置完成后：

1. **日常提交**：使用 `quick_commit.bat`
2. **查看文档**：[GIT_WORKFLOW.md](GIT_WORKFLOW.md)
3. **开始开发**：每次修改后记得提交！

---

**最后更新**：2026-01-18  
**维护者**：Claude Code
