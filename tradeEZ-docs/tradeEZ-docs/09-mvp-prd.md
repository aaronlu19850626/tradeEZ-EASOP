# Phase 1 MVP PRD

> 归档日期：2026-09-10。来源：原会话《黄金行情监控》。本文是会话资料整理，方案与参数仍属草案；所有案例数值均为教学或产品示例，非已验证业绩。

本文件保留功能、字段、业务路由与用户流程。评分、数据模型和 AI 分别独立成文。PRD 可读取原文止于第 80 节，第 81 节仅有残缺标题。

## MVP 核心目标

Phase 1 不追求成为完整的 TradeZella 替代品。

第一阶段只验证一个核心产品假设：

> **相比单纯记录盈亏，用户是否愿意持续使用一个能够分析“交易执行质量”的平台。**

因此 MVP 的 North Star 不是 P&L。

而是：

## Reviewed & Rule-Scored Trades

即：

> 被用户完成复盘并经过 Playbook 规则评分的交易数量。

## MVP 核心用户

第一阶段只服务一种典型用户。

## Persona A｜黄金日内交易者

典型特征：

- 主要交易 XAUUSD；
- 使用 MT4 / MT5；
- 使用 TradingView 看盘；
- 一天交易 1～10 笔；
- 使用技术分析；
- 对 SMC / Price Action / Order Flow 感兴趣；
- 有一定交易经验；
- 但交易规则没有完全结构化；
- 经常存在过度交易、提前入场、追单、移动止损等问题；
- 有复盘意愿，但执行不稳定。

## MVP 的核心 Jobs To Be Done

用户不是来“记账”。

用户真正需要完成：

### JTBD 01

> 帮我把过去的交易导进来。

### JTBD 02

> 告诉我哪些交易实际上符合我的系统。

### JTBD 03

> 告诉我真正赚钱的 Setup 是什么。

### JTBD 04

> 告诉我反复犯什么错误。

### JTBD 05

> 告诉我下一步应该改善什么。

## Golden Path

整个 MVP 必须围绕下面这条路径优化。

```text
注册
 ↓
创建 Trading Account
 ↓
导入 MT5 / CSV
 ↓
系统生成 Trades
 ↓
进入 Journal
 ↓
打开一笔交易
 ↓
关联 Playbook
 ↓
完成规则 Checklist
 ↓
生成 Execution Score
 ↓
添加 Screenshot / Note / Emotion
 ↓
AI Review
 ↓
发现 Mistake
 ↓
Analytics 更新
 ↓
推荐 Lesson
```

这一条流程必须在第一版完全跑通。

## MVP Sitemap

```text
/
├── dashboard
│
├── journal
│   └── /trade/:tradeId
│
├── analytics
│
├── playbooks
│   ├── /
│   └── /:playbookId
│
├── academy
│   ├── /
│   ├── /concept/:slug
│   └── /lesson/:slug
│
├── cases
│   └── /:caseId
│
├── ai-coach
│
├── settings
│   ├── accounts
│   ├── imports
│   ├── tags
│   └── profile
│
└── onboarding
```

Phase 1 暂时不独立开放：

```text
Replay
Backtest Lab
Skill Map
Order Flow Lab
```

数据库预留，但前端暂不建设完整产品。

## Dashboard PRD

路由：

```text
/dashboard
```

## 8.1 页面目标

用户打开后在 10 秒内回答：

1. 最近表现怎么样？
2. 当前最大的执行问题是什么？
3. 哪个 Setup 最赚钱？
4. 下一步应该做什么？

## Journal List PRD

路由：

```text
/journal
```

这是高频页面。

## Journal 表格

默认字段：

| 字段 | 描述 |
|---|---|
| Date | 开仓时间 |
| Symbol | XAUUSD |
| Side | Long / Short |
| Setup | Liquidity Sweep |
| Session | NY |
| Entry | 均价 |
| Exit | 均价 |
| P&L | 金额 |
| R | R-Multiple |
| Grade | A/B/C |
| Score | Execution |
| Mistake | 核心错误 |

## Journal Filtering

必须支持：

```text
Date
Account
Symbol
Setup
Playbook
Side
Session
Result
Grade
Execution Score
Mistake
Tag
```

例如用户可以快速搜索：

```text
XAUUSD
+
New York
+
Liquidity Sweep
+
Short
+
Execution > 80
```

## Trade 数据粒度

不要直接把：

```text
Order = Trade
```

必须区分：

```text
Order
Execution
Position
Trade
```

例如：

用户：

```text
4430 Long 0.5
4435 Add 0.3
4440 Partial Close 0.4
4450 Close 0.4
```

这应该仍然是一笔：

# Trade

而底层包含多个 Executions。

## Trade Detail PRD

路由：

```text
/journal/trade/:tradeId
```

这是 MVP 中最重要的页面。

## Trade Chart

第一版需要支持：

```text
Candlestick
Entry
Exit
Stop
Target
Execution markers
```

以及：

```text
1m
5m
15m
1h
```

如果没有历史行情数据：

Phase 1 可先允许：

## Screenshot First

即用户上传 TradingView / MT5 图。

同时底层为 Phase 2 行情重建预留。

## Trade Summary

字段：

```text
Entry

Average Exit

Initial Stop

Planned Target

Position Size

Commission

Swap

Net P&L

Initial Risk

Realized R

MAE

MFE

Hold Time
```

## Trade Classification

## Setup

例如：

```text
Liquidity Sweep Short
```

## Session

```text
Asia
London
NY AM
NY PM
Other
```

## Market Condition

```text
Trending
Ranging
High Volatility
Low Volatility
News Driven
```

## Screenshot & Annotation

每笔交易支持：

```text
Before
Entry
Exit
Review
```

四类截图。

Phase 1：

上传图片 + Caption。

Phase 2：

内置标注：

```text
Arrow
Rectangle
Horizontal Line
Text
Entry
SL
TP
```

## Trade Notes

不要只有一个 Notes textarea。

应该结构化：

## Before

```text
Why did I enter?
```

## During

```text
What happened?
```

## After

```text
What did I learn?
```

## Psychology

第一版简单实现。

### Emotion Before

```text
Calm
Confident
Fearful
FOMO
Angry
Tired
```

### Emotion After

同样。

### Confidence

```text
1–5
```

不要一开始做复杂心理测试。

## Mistake System

用户可选择：

```text
Early Entry
Late Entry
Chasing
No Confirmation
Counter Trend
Oversized
Moved Stop
No Stop
Averaging Loss
Early Exit
Overholding
Revenge Trade
Overtrade
News Trade
Wrong Session
Range Middle
```

同时支持：

```text
Custom Mistake
```

## Analytics PRD

路由：

```text
/analytics
```

核心不是“更多图表”。

而是：

> 找出对交易结果真正有解释力的因素。

## Analytics Tab

建议：

```text
Overview

Setups

Sessions

Timing

Risk

Mistakes

Execution
```

## Analytics Overview

指标：

```text
Net P&L
Net R
Win Rate
Profit Factor
Expectancy
Avg Win
Avg Loss
Max Drawdown
```

图表：

```text
Equity Curve

Daily P&L

R Distribution

Win/Loss Distribution
```

## Setup Analytics

表格：

| Setup | Trades | WR | Avg R | Expectancy | Score |
|---|---:|---:|---:|---:|---:|
| Sweep Short | 42 | 59% | 1.12 | +0.82R | 84 |
| Pullback Long | 31 | 45% | 1.46 | +0.51R | 79 |

## Session Analytics

例如：

```text
Asia

London

NY AM

NY PM
```

展示：

```text
Trades
Win Rate
Expectancy
Net R
```

这对黄金尤其重要。

## Mistake Analytics

最重要：

```text
Mistake Cost
```

例如：

```text
Early Entry

17 occurrences

-11.4R

Average Cost
-0.67R
```

并关联：

```text
View Trades
Learn
```

## Execution Analytics

核心图：

```text
Execution Score
vs
Trading Result
```

例如：

```text
Score 90–100
Expectancy +1.2R

80–89
+0.54R

70–79
+0.08R

<70
-0.72R
```

如果能够建立这种关系，会非常有教育意义。

## Academy PRD

路由：

```text
/academy
```

Phase 1 课程：

```text
Foundation
Price Action
Market Structure
SMC & Liquidity
Risk Management
```

Order Flow 可先制作内容，但不必首发全部。

## Concept Object

Concept 不等于 Lesson。

例如：

```text
Concept:
CHOCH
```

可以关联：

```text
Definition

Diagrams

Lessons

Playbooks

Cases

Mistakes

Exercises
```

## Lesson 数据结构

```text
title

slug

description

level

duration

content_md

video_url

thumbnail

status

module

order
```

并关联：

```text
concept_ids
```

## Lesson Detail

固定结构：

```text
Learning Objective

Definition

Why It Matters

Diagram

Rules

Correct Example

Wrong Example

Real Gold Case

Common Mistakes

Checklist

Summary
```

这也是你以后图文教程的标准模板。

## Case Library PRD

路由：

```text
/cases
```

Phase 1 可以先使用人工整理案例。

筛选：

```text
Symbol
Setup
Direction
Session
Location
Structure
Result
Grade
```

## Case Detail

与 Trade Detail 非常相似。

但 Case 是：

> 教学标准案例。

字段：

```text
Context

Setup

Chart

Entry

SL

TP

Reasoning

Mistakes to Avoid

Related Concepts

Related Lesson
```

## Similar Case Engine V1

第一阶段先不用复杂AI。

使用：

```text
Symbol
Setup
Direction
Session
Market Condition
```

做权重匹配。

例如：

```text
Setup             40%
Direction         15%
Session           15%
Market Condition  15%
Location          15%
```

Phase 2 再加 Embedding。

## Onboarding

第一版 Onboarding 非常重要。

步骤：

## Step 1

```text
What do you trade?
```

默认：

```text
Gold / XAUUSD
```

---

## Step 2

```text
Trading Style
```

```text
Scalping
Intraday
Swing
```

---

## Step 3

```text
Platform
```

```text
MT4
MT5
Other
```

---

## Step 4

导入交易。

---

## Step 5

创建第一个 Playbook。

提供模板：

```text
Liquidity Sweep

Trend Pullback
```

用户可直接使用。

## 归档整理补充：建议验收场景（非原文已定验收标准）

1. 同一交易含开仓、加仓、部分平仓和最终平仓时，能聚合为一笔 Trade 并保留 Executions。
2. 用户可关联 Playbook、填写规则结果并得到可复算的分数；盈利不影响规则分。
3. 复盘能引用真实规则与统计证据，并关联已存在的 Concept/Lesson/Case。
4. Analytics 的筛选、样本与 Journal 可互相核对。
5. 缺少历史路径时允许截图复盘，不伪造 MAE/MFE 或自动结构识别。

---

来源章节：MVP PRD 第 1–56 节相关业务章节。来源范围及待确认事项见 [归档说明](15-source-and-decisions.md)。

[返回总索引](README.md)
