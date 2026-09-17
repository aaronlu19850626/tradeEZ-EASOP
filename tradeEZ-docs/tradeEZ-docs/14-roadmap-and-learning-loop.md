# 开发路线、学习闭环与产品指标

> 归档日期：2026-09-10。来源：原会话《黄金行情监控》。本文是会话资料整理，方案与参数仍属草案；所有案例数值均为教学或产品示例，非已验证业绩。

以较晚的 Phase 1 PRD 限定首发范围；蓝图中的长期用户故事不全部纳入 MVP。

## Phase 1 MVP

目标：

# Make Every Trade Explainable

第一阶段只做：

### A. Account

- Login
- Workspace
- Account

### B. Import

- CSV
- MT4
- MT5

### C. Journal

- Trade list
- Trade detail
- Screenshots
- Notes
- Tags

### D. Analytics

- P&L
- R
- Win Rate
- Expectancy
- Drawdown
- Setup
- Session
- Time
- Day

### E. Playbook

- Setup
- Rules
- Checklist

### F. Execution Score

- Rule compliance
- Trade grade

### G. Academy

- Concept
- Article
- Video
- Example

### H. Case Library

基础案例。

### I. AI Review

基于：

```text
Trade
+
Rules
+
History
+
Lessons
```

给出复盘。

## Phase 1 暂时不做

不要MVP阶段就做：

- 自动交易
- DOM
- Bookmap替代
- GC完整订单流
- 实时信号
- AI预测方向
- 高频实时行情
- 全市场
- 社交社区
- Copy Trading

这些会严重拖慢第一版。

## Phase 2

目标：

# Close the Learning Loop

增加：

```text
Replay
Manual Backtest
Skill Map
Exercise
Adaptive Learning
Similar Cases
MT5 Auto Sync
Economic Calendar
Gold Market Lab
```

形成：

```text
Trade
→
Review
→
Learn
→
Practice
```

## Phase 3

目标：

# Intelligent Trading OS

加入：

```text
Automated Backtest

Strategy DSL

Automatic Setup Detection

Automatic Mistake Detection

GC Order Flow

Delta / CVD

Volume Profile

Absorption

Macro Context Engine

Advanced Pattern Retrieval
```

这时平台真正形成壁垒。

## 核心产品指标

不要只看DAU。

## Activation

用户7天内是否：

```text
导入≥20笔Trade

建立≥1个Playbook

完成≥3次Review
```

---

## Engagement

每周：

```text
Reviewed Trades

Playbook Usage

Replay Sessions

Lessons Completed
```

---

## Trading Improvement Metrics

这是平台最独特的一类指标：

```text
Execution Score ↑

Mistake Cost ↓

Playbook Compliance ↑

Expectancy ↑

Overtrade ↓
```

平台最终要证明：

> 用户使用TradeEZ以后，交易过程是否变好了。

## North Star Metric

第一版本建议：

# Reviewed & Rule-Scored Trades per Active Trader

中文：

> 每个活跃用户每周完成规则评估的交易数量。

后期可以升级：

# High-Quality Execution Rate

定义：

```text
Execution Score >= 80
```

的交易比例。

## 第一阶段开发优先级

### P0

```text
Auth
Account
Trade Import
Trade Model
Journal
Trade Detail
Analytics Core
Playbook
Playbook Rules
```

### P1

```text
Execution Score
Screenshots
Mistakes
AI Review
Concept
Lesson
```

### P2

```text
Case Library
Similar Cases
Learning Recommendation
Gold Dashboard
```

暂时不要跳过P0直接做AI。

因为：

# AI质量取决于结构化交易数据质量。

数据层不稳，AI一定会沦为普通聊天机器人。

## 学习闭环与技能评分

Trade → Rule Review → Mistake → Concept/Lesson → Exercise → Replay/Backtest → Live Execution → Playbook 改进。

较早方案提出 Skill Score 权重：Knowledge 20%、Exercise 20%、Backtest 25%、Live Execution 35%。原例 100/85/78/54 标为 68，但按所列权重计算为 75.4；该示例存在算术不一致，不能照搬。技能评分应在 Phase 2 单独定义和验证。

## 范围冲突处理

- 蓝图的完整 Golden Path 包含 Replay 练习，但较晚 PRD 将 Replay/Backtest/Skill Map 排除在首发之外。
- Similar Cases 在蓝图中偏后期，PRD 则明确 V1 用结构化加权匹配、Phase 2 再加 Embedding。
- 导入在蓝图覆盖 CSV/MT4/MT5，PRD 的具体管道主要为 MT5 CSV；首发格式尚需确认。
- North Star 在蓝图是“每活跃交易者每周完成规则评估的交易数”，PRD 简写为完成复盘并评分的交易数量；用户、周与完成状态口径尚未统一。
- Activation 的 7 天内 20 笔导入、1 个 Playbook、3 次 Review 是草案目标。
- 自动行情、复杂宏观、完整 GC 订单流与自动策略 DSL 回测属于后续阶段。

---

来源章节：产品蓝图第 29–34、38 节；平台结合方案 Skill Score；较晚 PRD 范围。来源范围及待确认事项见 [归档说明](15-source-and-decisions.md)。

[返回总索引](README.md)
