# TradeEZ 产品蓝图

> 归档日期：2026-09-10。来源：原会话《黄金行情监控》。本文是会话资料整理，方案与参数仍属草案；所有案例数值均为教学或产品示例，非已验证业绩。

定位为 AI 驱动的交易学习与绩效提升平台。原蓝图标题为 V1.0、正文版本为 0.1；此处统一视为产品草案，不据此判断已完成评审。

## 产品重新定位

TradeEZ 不应定义为：

> 一个交易日志工具。

也不应简单定义为：

> 一个 TradeZella 替代品。

建议正式定位为：

# AI-Powered Trading Learning & Performance Platform

中文：

# AI驱动的交易学习与绩效提升平台

核心价值主张：

> **Don’t just track your trades. Learn from every one.**  
> 不只是记录每笔交易，而是从每一笔交易中进化。

平台最终解决四个问题：

1. 我到底赚在哪里？
2. 我到底亏在哪里？
3. 我的交易是否符合自己的系统？
4. 下一步应该学习和训练什么？

## TradeEZ 核心产品理念

传统交易日志：

```text
交易
 ↓
记录
 ↓
统计
 ↓
结束
```

TradeEZ：

```text
学习
 ↓
建立 Playbook
 ↓
盘前准备
 ↓
执行交易
 ↓
自动记录
 ↓
规则检查
 ↓
AI复盘
 ↓
发现错误 / Edge
 ↓
关联课程
 ↓
Replay训练
 ↓
Backtest验证
 ↓
技能评分
 ↓
优化Playbook
 ↓
再次交易
```

形成：

# Learn → Plan → Trade → Review → Practice → Improve

这个闭环将成为整个产品的核心。

## 首阶段产品战略

不要一开始做：

- 股票
- 期权
- Crypto
- Forex
- Futures
- 黄金
- 原油
- 指数

全部市场。

第一阶段聚焦：

# Gold Trader OS

重点支持：

```text
XAUUSD
+
COMEX GC / MGC
```

围绕黄金把以下能力做到极深：

```text
Price Action
+
Market Structure
+
SMC
+
Liquidity
+
Order Flow
+
Macro
+
Risk
+
Journal
+
Playbook
+
AI
```

形成第一个清晰的垂直用户群：

> 高频使用 TradingView / MT4 / MT5，进行 XAUUSD 日内交易，希望改善执行和交易系统的个人交易者。

## 产品核心护城河

TradeEZ 的长期资产包括统一知识语义与结构化案例。

## 4.1 Trading Ontology

建立统一的交易知识语义。

例如：

```text
Market Structure
├─ HH
├─ HL
├─ LH
├─ LL
├─ BOS
└─ CHOCH

Liquidity
├─ PDH
├─ PDL
├─ Asia High
├─ Asia Low
├─ London High
├─ London Low
├─ Equal High
├─ Equal Low
└─ Sweep

Order Flow
├─ Delta
├─ CVD
├─ Absorption
├─ Imbalance
└─ Stacked Imbalance
```

Academy、Journal、Playbook、AI、Case Library、Backtest全部使用同一个语义体系。

---

## 4.2 Structured Trading Case Database

不是积累500篇文章。

而是积累5000个：

**结构化真实交易案例。**

例如：

```text
Case ID:
XAU-20260910-001

Symbol:
XAUUSD

Session:
New York

Setup:
Liquidity Sweep Short

Location:
PDH

Structure:
CHOCH

Order Flow:
Sell Absorption

Macro:
PPI

Entry:
4451.2

SL:
4459.1

MFE:
4.7R

MAE:
0.42R

Result:
+3.8R
```

以后AI和用户都可以检索：

> 找出所有“纽约盘 + PDH Sweep + CHOCH + Absorption”的黄金案例。

这才是真正的数据资产。

## Trade 是系统核心对象

一笔交易应该连接：

```text
                       LESSON
                          ↑
                          │
CASE ←──── SETUP ←──── TRADE ─────→ MISTAKE
                          │
                     PLAYBOOK
                          │
        ┌─────────────────┼────────────────┐
        ↓                 ↓                ↓
Market Context      Macro Context    Order Flow
        │
        ↓
    Analytics
        │
        ↓
     AI Coach
        │
        ↓
     Exercise
        │
        ↓
     Backtest
```

这样所有模块不再割裂。

## 核心模块一：Home / Trading Dashboard

## 页面目标

用户进入平台10秒内回答：

> 今天我应该关注什么？

Dashboard 不只是显示：

```text
P&L
Win Rate
Trade Count
```

而应该分成：

### Today

- 今日P&L
- 今日R
- 当前Drawdown
- 今日最大风险
- 连续亏损次数
- 是否触发Daily Stop

### Market Context

针对黄金：

- XAUUSD
- DXY
- US10Y
- VIX
- Oil
- Economic Calendar
- Upcoming CPI / PPI / NFP / FOMC

### Playbook Status

例如：

```text
Today:

Trend Pullback
Available

Liquidity Sweep
Available

News Trade
Disabled
```

### AI Insight

例如：

> 最近15笔纽约盘交易中，你在22:30以后胜率只有31%，Expectancy -0.38R。

### Learning Recommendation

> 建议训练：Liquidity Sweep → CHOCH Confirmation

## 核心模块二：Journal

Journal 是最基础的数据入口。

支持：

### 导入

Phase 1：

- CSV
- MT4 statement
- MT5 statement
- Manual entry

Phase 2：

- MT4自动同步
- MT5自动同步
- cTrader
- Tradovate

竞品目前已经广泛支持 MT4/MT5、Tradovate、cTrader 等同步，因此 MT5 对我们的黄金用户最终属于必备能力，而不是附加功能。

---

## Journal列表字段

```text
Date
Symbol
Direction
Session
Setup
Entry
Exit
Size
P&L
R
MAE
MFE
Grade
Execution Score
Mistake
Emotion
```

关键区别：

不要只显示：

> +$532

应该同时显示：

```text
+$532
+2.6R
Execution 91
A Setup
```

## 核心模块四：Analytics

基础指标：

- Net P&L
- Gross P&L
- Win Rate
- Profit Factor
- Avg Winner
- Avg Loser
- Expectancy
- Avg R
- Max Drawdown
- Sharpe
- Consecutive Wins
- Consecutive Losses

但真正重要的是：

# Conditional Analytics

例如：

```text
Setup
×
Session
×
Day
×
Direction
×
Macro
×
Execution
```

用户可以发现：

```text
Liquidity Sweep
+
New York
+
SHORT
+
Execution > 80

Win Rate: 64%
Expectancy: +1.46R
```

而：

```text
Liquidity Sweep
+
Before CHOCH

Win Rate: 27%
Expectancy: -0.61R
```

这就是：

# Edge Discovery

## Mistake Analytics

建立错误分类体系：

```text
Entry Mistakes
├─ Chase
├─ Early Entry
├─ Late Entry
├─ No Confirmation
└─ Counter Trend

Risk Mistakes
├─ Oversized
├─ Moved Stop
├─ No Stop
└─ Averaging Loss

Management
├─ Early Exit
├─ Overholding
├─ Revenge Trade
└─ Overtrade

Context
├─ Range Middle
├─ Major News
├─ Wrong Session
└─ Wrong HTF Bias
```

然后产生：

# Mistake Cost

例如：

```text
Early Entry

Trades:
38

Total Cost:
-14.7R
```

这会成为非常强的用户价值。

## 核心模块五：Academy

课程不是一个孤立视频网站。

每个知识点都是Concept。

例如：

## Liquidity Sweep

包含：

```text
Definition
Diagram
Article
Video
Correct Example
Wrong Example
Playbook
Case Studies
Exercise
User Performance
```

课程目录沿用：

```text
01 Foundation

02 Price Action

03 Market Structure

04 SMC & Liquidity

05 Order Flow

06 Gold Macro

07 Risk

08 Psychology

09 Trading System

10 Case Studies
```

## Academy和Journal联动

例如用户最近：

```text
12个Sweep交易
```

其中：

```text
8个没有等待CHOCH
```

AI生成：

> 你近期67%的Liquidity Sweep交易在CHOCH确认之前入场。

数据显示：

```text
Before CHOCH

Win Rate
27%

Expectancy
-0.58R
```

而：

```text
After CHOCH

Win Rate
58%

Expectancy
+1.12R
```

系统推荐：

# Liquidity Sweep → CHOCH Confirmation

关联操作：

```text
Learn
Practice
View Examples
```

真正实现：

# Just-in-Time Learning

## 核心模块六：Case Library

Case Library以后可能成为平台最重要的知识资产。

过滤器：

```text
Instrument
Session
Direction
Setup
Location
Structure
Macro
Order Flow
Result
R
Grade
```

例如：

> XAUUSD  
> New York  
> PDH  
> Sweep  
> CHOCH  
> Sell Absorption

返回对应案例。

## Similar Trade Engine

进入一笔Trade后：

系统查找：

> 历史上最相似的交易。

返回：

```text
34 Similar Trades

Win Rate
61.8%

Average R
+1.42R
```

并显示：

### Case #38

92% Similar

### Case #71

89% Similar

### Case #112

86% Similar

实现方式可使用：

```text
Structured Filter
+
Feature Similarity
+
Vector Embedding
```

不是只靠Embedding。

## Replay

Replay有两种。

## Trade Replay

复盘自己的交易。

看到：

```text
Entry之前
Entry
Position
Exit
```

然后判断：

> 当时究竟为什么进入？

---

## Training Replay

隐藏未来K线。

系统问：

```text
Is this a valid Liquidity Sweep?

YES
NO
```

下一步：

```text
Do we have CHOCH?

YES
NO
```

再下一步：

```text
Entry?

LONG
SHORT
WAIT
```

这就变成真正训练工具。

## Backtest Lab

Phase 2：

手动Backtest。

Phase 3：

规则自动回测。

输入：

```text
15M bullish structure

PDH breakout

5M pullback

1M BOS

SL below structure

TP = 3R
```

AI首先转成：

```text
Structured Strategy DSL
```

然后由Backtest Engine执行。

不要让LLM直接“模拟结果”。

架构应该是：

```text
Natural Language
       ↓
LLM Parser
       ↓
Strategy DSL
       ↓
Validation
       ↓
Backtest Engine
       ↓
Trade Results
       ↓
Analytics
```

这比直接让AI回答：

> “你的策略胜率大约60%”

可靠得多。

## Skill Map

每项能力形成技能分。

例如：

# Liquidity Sweep

```text
Knowledge        92
Exercise         78
Backtest         71
Live Execution   53
──────────────────
Skill Score      68
```

最终形成：

```text
MARKET READING

Structure
████████░░

Liquidity
███████░░░

ORDER FLOW

Footprint
████░░░░░░

Delta
███░░░░░░░

RISK

Position Size
█████████░

Execution
██████░░░░
```

## Market Lab

第一阶段只做Gold。

页面包含：

## Gold Dashboard

```text
XAUUSD
DXY
US10Y
Real Yield
Oil
VIX
```

## Economic Events

```text
CPI
PPI
NFP
PCE
FOMC
Powell
```

## Session Levels

```text
PDH
PDL
Asia H/L
London H/L
Daily Open
VWAP
```

Phase 3加入：

## GC Order Flow

```text
Volume Profile
Delta
CVD
Absorption
Imbalance
```

## 产品护栏

必须非常明确：

TradeEZ应该定位为：

```text
Education
+
Analytics
+
Performance Improvement
```

而不要直接定位：

```text
Guaranteed Signals

AI Buy/Sell Prediction

Guaranteed Returns
```

AI可以解释：

> 当前结构是什么。

可以指出：

> 这笔交易是否符合你的Playbook。

但不能把整个品牌建立在：

> AI告诉你下一单做多还是做空。

长期产品价值、合规风险以及用户行为质量都会更好。

## TradeEZ最核心的五个产品能力

最终对外可以只讲这五个：

## 01 Journal

Capture Every Trade

## 02 Understand

Find Your Real Edge

## 03 Playbook

Trade Your Rules

## 04 Learn

Learn From Every Mistake

## 05 Improve

Build a Better Trader

## 最终产品愿景

TradeEZ最终不是记录：

> 你过去做过什么。

而是逐渐回答：

> 你是什么类型的交易者？

> 你的真实Edge在哪里？

> 什么情况下你最容易犯错？

> 哪些Setup真正赚钱？

> 你的实际执行和Playbook差距有多大？

> 下一项应该训练什么？

最终形成：

# Trader Digital Twin

一个基于用户真实历史交易建立起来的：

> **交易者数字画像。**

包含：

```text
Risk Profile
Execution Profile
Setup Profile
Session Profile
Psychology Profile
Market Profile
Skill Profile
```

AI Coach最终服务的不是“一笔黄金交易”。

而是这个交易者长期的：

# Trading Development Model

这才是TradeEZ真正可能形成长期竞争力的方向。

---

# 一句话战略总结

TradeEZ 不做：

> 更好的交易日志。

TradeEZ 要做：

> **连接“交易数据、交易知识、交易训练和AI”的交易者成长操作系统。**

---

来源章节：产品总蓝图第 1–40 节中相关业务内容（排除视觉布局、首页展示及前端建议）。来源范围及待确认事项见 [归档说明](15-source-and-decisions.md)。

[返回总索引](README.md)
