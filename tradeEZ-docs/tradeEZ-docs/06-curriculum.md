# 课程体系：六阶段十八模块

> 归档日期：2026-09-10。来源：原会话《黄金行情监控》。本文是会话资料整理，方案与参数仍属草案；所有案例数值均为教学或产品示例，非已验证业绩。

课程主线：黄金市场 → 价格行为 → SMC/流动性 → 订单流 → 宏观 → 风险与交易系统。内容层级属于原会话课程规划。

# 一、整个课程的知识架构

建议分成 **6大阶段、18个模块**。

| 阶段 | 核心问题 |
|---|---|
| Phase 1 市场基础 | 黄金到底是怎么交易的？ |
| Phase 2 Price Action | 价格现在在做什么？ |
| Phase 3 SMC / Liquidity | 价格为什么经常扫高低点？ |
| Phase 4 Order Flow | 谁在真正买、谁在真正卖？ |
| Phase 5 Macro + Risk | 为什么黄金突然大涨大跌？ |
| Phase 6 Trading System | 如何形成自己的可重复交易系统？ |

这个顺序非常重要。

不要从：

> FVG → OB → ICT → Footprint

直接开始。

否则很容易知道很多名词，却不知道市场为什么运行。

---

# Phase 1：黄金交易基础

## Module 01｜黄金市场到底是什么

这是整个课程第一章。

### 学习内容

理解：

```text
黄金市场

      ┌─ 现货黄金 XAUUSD
      │
Gold ├─ COMEX Futures GC
      │
      ├─ Micro Gold MGC
      │
      ├─ Gold ETF
      │
      └─ Physical Gold
```

重点学习：

- XAUUSD是什么；
- OTC是什么意思；
- COMEX是什么；
- GC、MGC是什么；
- Spot与Futures区别；
- Broker；
- Liquidity Provider；
- Bid / Ask；
- Spread；
- Slippage；
- Margin；
- Leverage；
- Contract Size；
- Tick / Point。

这一章非常重要，因为以后你讲Order Flow时必须解释：

> 为什么XAUUSD没有统一中央订单簿，而GC期货更适合读取集中交易市场的订单流。

CME官方资料也把GC黄金期货作为其核心黄金产品，并明确强调黄金受到美国货币政策、CPI、PPI、非农以及全球政治经济因素影响。

### 图文教程

可以制作：

**《01：一张图看懂全球黄金交易市场》**

配图：

```text
全球黄金市场
       ↓
OTC XAUUSD ←→ COMEX GC
       ↓
经纪商
       ↓
交易者
```

### 视频

8～12分钟：

**“你每天交易的XAUUSD到底是什么？”**

---

# Module 02｜K线真正表达了什么

不要一开始教几十个蜡烛图形态。

主要讲：

```text
Open
High
Low
Close
```

然后理解：

- 实体；
- 上影线；
- 下影线；
- Range；
- Body；
- Momentum Candle；
- Rejection Candle；
- Inside Bar；
- Outside Bar。

核心思想：

> 一根K线本身意义有限，位置 + 上下文才有意义。

例如：

```text
普通长上影
≠
一定做空
```

但：

```text
PDH
+
Sweep
+
长上影
+
CHOCH
```

意义完全不同。

Steve Nison 的《Japanese Candlestick Charting Techniques》仍然是学习K线体系非常经典的参考书，第二版包含大量图例，并扩展到了日内交易。

---

# Phase 2：Price Action与市场结构

这是你未来整个课程最重要的一部分。

# Module 03｜Market Structure 市场结构

完整学习：

```text
HH = Higher High
HL = Higher Low

LH = Lower High
LL = Lower Low
```

然后：

```text
上涨：

HH
 ↓
HL
 ↓
HH
 ↓
HL
```

和：

```text
下跌：

LL
 ↓
LH
 ↓
LL
 ↓
LH
```

进一步：

- Trend；
- Range；
- Expansion；
- Consolidation；
- Pullback；
- Correction；
- Reversal。

### 视频标题

**《不用MACD，如何只看价格判断黄金趋势？》**

---

# Module 04｜BOS与CHOCH

系统学习：

### BOS

Break of Structure

结构突破。

代表：

> 原趋势可能延续。

### CHOCH

Change of Character

结构行为变化。

代表：

> 原来的市场结构可能发生转变。

关键是教会：

```text
BOS ≠ 所有突破

CHOCH ≠ 所有小高低点突破
```

必须定义：

- Significant Swing；
- Internal Structure；
- External Structure。

这会避免SMC最严重的问题：

> 图画完以后到处都是BOS和CHOCH。

---

# Module 05｜关键价格位置

这是以后真正交易的地图。

每天标记：

| 位置 | 英文 |
|---|---|
| 昨日高点 | PDH |
| 昨日低点 | PDL |
| 亚洲高点 | Asia High |
| 亚洲低点 | Asia Low |
| 伦敦高点 | London High |
| 伦敦低点 | London Low |
| 当日开盘 | Daily Open |
| 周高/周低 | Weekly High/Low |
| 整数位 | Psychological Level |
| VWAP | VWAP |

核心认知：

> **Location > Pattern**

一个好形态出现在错误位置，价值很低。

---

# Module 06｜传统指标到底有没有用

这一章非常值得放到网站，因为很多用户都是从：

```text
MACD
RSI
KDJ
均线
布林带
```

开始学交易。

讲清：

### MACD

趋势/动量工具。

### RSI

动量工具。

### KDJ

震荡指标。

### EMA

趋势平滑工具。

然后解释：

> 为什么指标不是敌人，但不应该成为我们交易系统的核心。

推荐做一个经典对比：

```text
价格
↓
指标计算
↓
MACD / RSI / KDJ
```

vs

```text
价格
↓
市场结构
↓
Liquidity
↓
订单流
```

John Murphy 的《Technical Analysis of the Financial Markets》很适合这一阶段作为传统技术分析的基础参考，它系统覆盖图表、指标、K线和跨市场关系。

---

# Phase 3：SMC与Liquidity

然后才正式进入SMC。

# Module 07｜Liquidity

这是SMC最值得学习的概念之一。

讲：

### Buy-side Liquidity

通常位于：

```text
High
↑
Stop Loss
↑
Breakout Buy
```

### Sell-side Liquidity

通常位于：

```text
Low
↓
Stop Loss
↓
Breakout Sell
```

然后介绍：

- Equal High；
- Equal Low；
- Previous High；
- Previous Low；
- Session High；
- Session Low。

---

# Module 08｜Liquidity Sweep

这是你自己的黄金系统核心章节。

完整模型：

```text
PDH

────────────── 4450
                 ↑
                 │
                4458
                 │
               Sweep
                 ↓
                4448
                 ↓
              CHOCH
                 ↓
              Short
```

重点区分：

### Breakout

```text
突破
+
站稳
+
回踩
+
延续
```

vs

### Sweep

```text
突破
+
无法站稳
+
重新进入区间
+
结构反转
```

这可以直接形成你的第一套主交易模型。

---

# Module 09｜FVG、OB与Displacement

这章要“去神秘化”。

### FVG

Fair Value Gap。

讲成：

> 快速价格位移留下的交易失衡区域。

### OB

Order Block。

不要讲成：

> “机构在这里偷偷下了订单。”

而应该讲：

> 强烈价格位移产生之前的关键价格区域。

### Displacement

强位移：

```text
小K线
小K线
小K线
↓
大实体
大实体
大实体
```

讲：

> 真正重要的不是OB/FVG本身，而是它们出现在什么结构和位置。

---

# Module 10｜SMC两个核心Setup

到这里开始真正形成交易系统。

## Setup A

### Trend Pullback

```text
趋势
↓
BOS
↓
Displacement
↓
Retest
↓
1M BOS
↓
Entry
```

---

## Setup B

### Liquidity Sweep

```text
关键Liquidity
↓
Sweep
↓
回到区间
↓
CHOCH
↓
Retest
↓
Entry
```

这两个Setup建议以后成为你网站中的：

# Playbook

而不是不停增加交易形态。

---

# Phase 4：Order Flow

这一部分会成为你网站区别于大量普通“技术分析教程”的地方。

# Module 11｜订单流基础

从市场微观结构讲起。

学习：

```text
Market Order

vs

Limit Order
```

以及：

```text
Bid
Ask
```

核心：

### Aggressive Buyer

主动买方：

> Market Buy 打 Ask。

### Aggressive Seller

主动卖方：

> Market Sell 打 Bid。

Larry Harris 的《Trading and Exchanges》是这一领域很重要的基础著作，它系统讨论订单、交易者、交易场所、限价单、市价单以及市场结构，非常适合作为订单流课程的底层理论。

---

# Module 12｜Volume Profile

先学Volume Profile，再学Footprint。

学习：

### POC

Point of Control

### VAH

Value Area High

### VAL

Value Area Low

### HVN

High Volume Node

### LVN

Low Volume Node

核心理念：

> 市场不是简单上涨下降，而是在不断寻找被接受的价格。

这就开始进入：

# Auction Market Theory

---

# Module 13｜Footprint

这是订单流第一核心工具。

讲：

```text
Bid × Ask

4425  120 × 550
4424  260 × 680
4423  700 × 210
```

学习：

- Bid Volume；
- Ask Volume；
- Delta；
- Imbalance；
- Stacked Imbalance。

视频可以直接录Quantower/ATAS。

---

# Module 14｜Delta与CVD

学习：

### Delta

```text
Aggressive Buy
-
Aggressive Sell
```

### CVD

Cumulative Volume Delta。

然后重点讲：

# Divergence

例如：

```text
Price

HH
  ↑
新HH

CVD

LH
```

不要教：

```text
Delta > 0
=
Buy
```

而是教：

> Delta只有结合位置和市场结构才有意义。

---

# Module 15｜Absorption、Exhaustion、DOM

这是订单流高级部分。

### Absorption

例如：

```text
大量Market Buy
↓↓↓

巨大Sell Limit

↓↓↓

价格却无法上涨
```

说明：

> 买盘被吸收。

然后讲：

- Exhaustion；
- Iceberg；
- DOM；
- Time & Sales；
- Liquidity Heatmap；
- Bookmap。

这一章可以作为高级会员内容。

---

# Phase 5：黄金宏观交易

这一阶段不要省略。

很多纯SMC交易者最大的知识缺口就在这里。

# Module 16｜黄金为什么涨跌

建立黄金驱动框架：

```text
                  Gold
                   │
        ┌──────────┼───────────┐
        │          │           │
       USD       Yield      Risk
        │          │           │
       DXY     US10Y       Geopolitics
                   │
               Real Yield
```

学习：

- DXY；
- US10Y；
- Real Yield；
- Fed；
- CPI；
- PPI；
- NFP；
- GDP；
- PCE；
- FOMC；
- Oil；
- Geopolitical Risk。

CME的黄金教育材料也明确把美国货币政策、CPI/PPI、非农及国际政治经济稳定性列为黄金交易者必须关注的重要变量。

---

# Phase 6：真正形成交易系统

这是整个课程最有价值的一部分。

# Module 17｜Risk Management

这一章必须非常重。

学习：

```text
R
Risk Reward
Expectancy
Win Rate
Average Win
Average Loss
Max Drawdown
Risk of Ruin
```

核心公式：

### Expectancy

```text
E =
WinRate × AvgWin
-
LossRate × AvgLoss
```

例如：

```text
胜率 40%

平均盈利 3R

平均亏损 1R
```

那么：

```text
0.4 × 3
-
0.6 × 1

= +0.6R
```

这就是为什么：

> **40%胜率也完全可以是一套优秀系统。**

---

# Module 18｜建立自己的Trading Playbook

最终把所有知识收敛。

形成：

# XAUUSD Intraday System V1.0

只交易：

```text
Setup A
Trend Pullback

Setup B
Liquidity Sweep
```

每笔记录：

```text
Context
Location
Setup
Trigger
Entry
SL
TP
R
MAE
MFE
Screenshot
Mistake
Result
```

最终形成：

```text
交易
↓
记录
↓
统计
↓
复盘
↓
优化
↓
再交易
```

这才是真正意义上的系统交易。

---

---

来源章节：系统学习与教程大纲回答。来源范围及待确认事项见 [归档说明](15-source-and-decisions.md)。

[返回总索引](README.md)
