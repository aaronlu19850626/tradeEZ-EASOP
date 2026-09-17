# tradeEZ EA - 黄金交易专家顾问

[![Version](https://img.shields.io/badge/version-v1.03-blue.svg)](https://github.com/aaronlu19850626/tradeEZ-EASOP)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-MetaTrader%205-orange.svg)](https://www.metatrader5.com)

一款专业的黄金交易 EA，集成分策略管理、动态风控、彭博终端级 UI，并支持数据同步到云端 Web 平台。

---

## ✨ 核心特性

### 交易管理
- 🎯 **分策略控制** - 剥头皮 + 趋势双策略，独立手数、独立风控
- 📊 **智能移损** - 多阶段动态止损，保护利润
- ⏱️ **超时强平** - 剥头皮持仓超时自动平仓（可取消）
- 🎨 **彭博终端级 UI** - 暗黑配色，数据可视化，实时更新

### 风险控制
- 🛡️ **日最大回撤** - 分策略额度分配（剥头皮 70% / 趋势 30%）
- 🚨 **连亏冷却** - N 连亏后强制休息 M 分钟
- 💰 **利润护城河** - 动态回撤保护，两档触发
- 🔒 **满仓禁开** - 防止过度持仓

### 数据同步（v2.0 增量同步）
- ☁️ **云端同步** - 实时上传成交到 TradeSync-Web 平台
- 📈 **增量机制** - 基于服务器最后同步时间，只传输新成交
- 🔐 **安全鉴权** - Bearer Token + HMAC 签名
- 🚀 **高性能** - 无本地队列文件，减少磁盘 IO

---

## 📦 安装

### 1. 下载

```bash
git clone https://github.com/aaronlu19850626/tradeEZ-EASOP.git
```

或直接下载 `tradeEZ.mq5`

### 2. 复制到 MT5

将 `tradeEZ.mq5` 复制到：
```
C:\Users\{你的用户名}\AppData\Roaming\MetaQuotes\Terminal\{经纪商ID}\MQL5\Experts\
```

### 3. 编译

1. 打开 MetaEditor
2. 打开 `tradeEZ.mq5`
3. 按 `F7` 编译
4. 确认无错误

### 4. 使用

1. 在 MT5 中打开黄金图表（XAUUSD / GOLD#）
2. 将 `tradeEZ` EA 拖到图表上
3. 配置参数（见下方）
4. 点击「确定」启动

---

## ⚙️ 核心参数配置

### 基础设置

| 参数 | 说明 | 默认值 | 建议 |
|-----|------|--------|------|
| `Inp_Magic` | EA 基础魔术号 | 920716 | 不冲突即可 |
| `Inp_MagicScalp` | 剥头皮魔术号 | 920717 | 不冲突即可 |
| `Inp_MagicTrend` | 趋势魔术号 | 920718 | 不冲突即可 |

### 手数设置

| 参数 | 说明 | 默认值 | 建议 |
|-----|------|--------|------|
| `Inp_ScalpLots` | 剥头皮手数 | 0.30 | 根据资金调整 |
| `Inp_TrendLots` | 趋势手数 | 0.30 | 根据资金调整 |

### 风控参数（重要）

| 参数 | 说明 | 默认值 | 建议 |
|-----|------|--------|------|
| `Inp_DailyMaxDrawdown` | 日最大回撤（$） | 500 | 账户的 2-5% |
| `Inp_ScalpDrawdownRatio` | 剥头皮占比（%） | 70 | 70-80 |
| `Inp_TrendDrawdownRatio` | 趋势占比（%） | 30 | 20-30 |
| `Inp_ConsecLossLimit` | 连亏触发次数 | 5 | 3-5 |
| `Inp_CooldownMinutes` | 冷却时间（分钟） | 30 | 30-60 |

### 数据同步（可选）

| 参数 | 说明 | 默认值 |
|-----|------|--------|
| `Inp_EnableSync` | 启用订单同步 | false |
| `Inp_ApiBaseURL` | API 基础地址 | https://api.yourdomain.com |
| `Inp_SecretKey` | 账户密钥 | （从 Web 平台获取） |
| `Inp_SyncIntervalMin` | 同步频率（分钟） | 5 |

---

## 📊 数据同步 Web 平台

### TradeSync-Web 功能

- 📈 **每日盈亏查询** - 净值曲线、余额统计
- 📋 **订单查询** - 按日期/策略/品种/盈亏筛选
- 📊 **订单统计** - R 倍数、胜率、盈利因子、期望值
- 🎯 **纪律合规引擎** - 自动检测违规交易（P1）
- 📝 **复盘工具** - K 线标注、复盘笔记（P1）
- 🤖 **AI 盘前简报** - 每日美盘前技术面+基本面分析（P2）

### 设置指南

详见：[SYNC_SETUP_GUIDE.md](SYNC_SETUP_GUIDE.md)

---

## 📚 文档

- [GIT_WORKFLOW.md](GIT_WORKFLOW.md) - Git 工作流程
- [DEV_NOTES.md](DEV_NOTES.md) - 开发笔记（重要！）
- [API_SPECIFICATION_V2.md](API_SPECIFICATION_V2.md) - 服务器端 API 规范
- [SYNC_INCREMENTAL_DESIGN.md](SYNC_INCREMENTAL_DESIGN.md) - 增量同步技术设计
- [SYNC_SETUP_GUIDE.md](SYNC_SETUP_GUIDE.md) - 用户设置指南
- [SYNC_V2_CHANGES.md](SYNC_V2_CHANGES.md) - v2.0 变更说明
- [IMPLEMENTATION_COMPLETE_V2.md](IMPLEMENTATION_COMPLETE_V2.md) - 实现报告

---

## 🔧 开发

### 环境要求

- MetaTrader 5 Build 3650+
- MetaEditor 5

### 代码结构

```
tradeEZ.mq5 (3852 行)
├── 输入参数定义 (L72-L160)
├── 全局变量 (L174-L272)
├── 工具函数 (L276-L686)
│   ├── 价格/点数换算
│   ├── 策略识别
│   ├── 时间处理
│   └── 持仓统计
├── 风控逻辑 (L1059-L1488)
│   ├── 跨日重置
│   ├── 分策略熔断
│   ├── 利润护城河
│   └── 连亏冷却
├── 交易逻辑 (L1490-L2437)
│   ├── 开仓验证
│   ├── 移动止损
│   ├── 超时强平
│   └── 一键改单
├── UI 渲染 (L2439-L2987)
│   ├── 面板布局
│   ├── 数据展示
│   ├── 明细舱
│   └── 按钮处理
├── 状态持久化 (L2989-L3121)
│   ├── SaveState / LoadState
│   └── SaveArrays / LoadArrays
├── 数据同步模块 (L3123-L3534)
│   ├── GetServerLastSyncTime
│   ├── CollectDealsAfterTime
│   ├── SyncDeals
│   └── 其他同步函数
└── 事件处理 (L3536-L3855)
    ├── OnInit / OnDeinit
    ├── OnTick / OnTimer
    ├── OnTradeTransaction
    └── OnChartEvent
```

### 编译

```bash
# MetaEditor 中按 F7
# 或命令行编译（如果配置了 metaeditor64.exe）
metaeditor64.exe /compile:"path\to\tradeEZ.mq5"
```

### 提交规则

**每次修改后必须提交到 GitHub！**

```bash
# 快速提交（使用 quick_commit.bat）
quick_commit.bat

# 或手动提交
git add .
git commit -m "feat(sync): 实现增量同步"
git push origin main
```

详见：[GIT_WORKFLOW.md](GIT_WORKFLOW.md)

---

## 📝 变更日志

### v2.0 (2026-01-18) - 增量同步

**新增**：
- ✅ 增量同步机制（基于服务器最后同步时间）
- ✅ GetServerLastSyncTime() 函数
- ✅ CollectDealsAfterTime() 函数
- ✅ 严格边界处理（+1 秒避免重复）

**移除**：
- ❌ 队列文件机制（JSONL）
- ❌ AppendDealToQueue() 函数
- ❌ BackfillHistoryDeals() 函数

**优化**：
- ⚡ 减少磁盘 IO
- ⚡ OnTradeTransaction 零延迟
- ⚡ 服务器端控制同步状态

详见：[SYNC_V2_CHANGES.md](SYNC_V2_CHANGES.md)

### v1.03 (2026-01-17) - 数据同步

**新增**：
- ✅ 队列模式数据同步
- ✅ 品种规格上传
- ✅ 账户快照上传
- ✅ 心跳机制

详见：[CHANGELOG_SYNC.md](CHANGELOG_SYNC.md)

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发流程

1. Fork 仓库
2. 创建分支 (`git checkout -b feature/AmazingFeature`)
3. 提交修改 (`git commit -m 'feat: Add AmazingFeature'`)
4. 推送分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

---

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

## 👤 作者

**Aaron Lu**
- GitHub: [@aaronlu19850626](https://github.com/aaronlu19850626)
- Email: aaronlu19850626@gmail.com（示例）

---

## 🙏 致谢

- MetaQuotes Software Corp. - MetaTrader 5 平台
- Claude Code (Opus 5) - 开发与文档编写

---

## ⚠️ 免责声明

本 EA 仅供学习和研究使用。

外汇和差价合约交易具有高风险，可能导致您损失全部投资。请确保您完全理解相关风险，并在必要时寻求独立建议。过往表现不代表未来结果。

使用本 EA 进行实盘交易的风险由您自行承担。

---

**最后更新**：2026-01-18  
**版本**：v2.0（增量同步）
