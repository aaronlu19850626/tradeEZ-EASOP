# SMC、订单流与统一概念

> 归档日期：2026-09-10。来源：原会话《黄金行情监控》。本文是会话资料整理，方案与参数仍属草案；所有案例数值均为教学或产品示例，非已验证业绩。

SMC 用于描述结构与位置；订单流提供特定数据源的成交证据。它们都不构成已验证优势，也不能从形态直接断言机构意图。

SMC 是 **Smart Money Concepts**，中文一般叫“聪明钱概念”或“机构资金交易逻辑”。

它不是一个单独指标，而是一套试图从 **市场结构、流动性、关键价格区域和价格失衡** 来理解行情的方法。你前面看到我讲的很多词，其实都属于 SMC 体系，例如：

- **BOS**：Break of Structure，结构突破
- **CHOCH**：Change of Character，结构转变
- **Liquidity**：流动性
- **Liquidity Sweep**：扫流动性/扫止损
- **Order Block，OB**：订单块
- **FVG**：Fair Value Gap，公允价值缺口
- **Displacement**：强位移
- **Premium / Discount**：溢价区 / 折价区

SMC 的核心思路可以压缩成一句话：

> 不只看“价格涨跌”，而是看价格在什么结构里、哪里聚集了大量订单、这些订单是否被清扫，以及清扫后市场结构有没有改变。

比如黄金昨日高点是 4450：

```text
4450  ← 昨日高点，大量止损/突破单可能集中在这里
  ↑
4458  ← 向上扫流动性
  ↓
4448  ← 又跌回4450下方
  ↓
4442  ← 跌破短周期低点，出现CHOCH
  ↑
4449  ← 回抽失败
  ↓
Short
```

传统技术分析可能看到的是“RSI超买、MACD准备死叉”，而 SMC 会把这段行情理解为：

> **PDH 流动性 → Sweep → CHOCH → 回抽 → 做空。**

### SMC 和 ICT 是什么关系

你以后很容易同时看到这两个词。

**ICT = Inner Circle Trader**，是 Michael Huddleston 推广的一整套交易方法；现代网络上很多所谓 SMC 内容实际上大量借用了 ICT 的概念。

可以粗略理解为：

```text
传统 Price Action
        +
市场结构
        +
Liquidity
        +
OB / FVG
        +
ICT相关概念
        ↓
现代网络上的 SMC
```

但不需要纠结谁先谁后。对你做黄金来说，重点是哪些东西真的能形成可测试的交易规则。

### SMC 最大的优势

对于你这种 XAUUSD 日内交易者，它有三个明显优势。

第一，**止损逻辑清楚**。例如 Sweep 高点在 4458，做空以后如果价格重新有效突破 4458，这个交易逻辑基本失效，因此止损位置天然明确。

第二，**容易构建高盈亏比**。不是在区间中间随机买卖，而是在关键流动性位置等待确认，因此经常可以形成小止损、较大目标。

第三，**非常适合黄金这种喜欢扫高低点的市场**。昨日高低、亚洲盘高低、伦敦盘高低都是常见观察区域。

### 但 SMC 也有一个很大的问题

SMC 特别容易被“事后解释”。

行情走完以后，你几乎总能画出：

```text
这里是OB
这里有FVG
这里是Liquidity
这里是CHOCH
```

于是图表看起来每一笔都非常完美，但实盘时未必知道该交易哪一个。

所以我不建议你把 SMC 学成几十个术语，而是只保留最有用的主干：

```text
1. Market Structure
   HH / HL / LH / LL

2. Key Liquidity
   PDH / PDL
   Asia High / Low
   London High / Low

3. 两种行为
   Breakout
   Sweep

4. 两种确认
   BOS
   CHOCH

5. 一个执行原则
   Retest后入场

6. 一个风险原则
   Structure Invalidation作为止损
```

这已经足够形成一套完整系统。

而且结合我们前面讨论的订单流，我认为更成熟的版本应该是：

> **SMC负责告诉你“在哪里交易”，订单流负责告诉你“这里到底有没有真实买卖力量确认”。**

例如：

```text
PDH
+
Liquidity Sweep
+
CHOCH
+
Footprint出现Absorption
+
Delta/CVD背离
```

这种信号的质量，通常明显高于单独看到一个 FVG 或 OB 就进场。

所以对你来说，SMC可以作为**主框架**，订单流作为**确认层**，而 MACD/RSI/KDJ最多作为辅助层。这套组合比单纯堆指标更适合你当前的黄金日内交易方向。

# 六、那么订单流到底是什么

这里开始进入真正更专业的一层。

**Order Flow = 订单流。**

价格K线告诉你的主要是：

> **最后价格去了哪里。**

订单流试图告诉你的则是：

> **这个价格为什么走到这里？买卖双方究竟在哪里发生了激烈交易？**

例如一根5分钟K线：

```text
Open  4430
High  4440
Low   4428
Close 4438
```

普通K线只能看到：

> 涨了。

订单流可能进一步告诉你：

```text
4430    买方一般
4432    买方增强
4434    主动买单大量增加
4436    +1800 Delta
4438    +2600 Delta
4440    买盘突然无法推进
```

这是完全不同的信息维度。

---

# 七、订单流里面你主要会遇到几个概念

### 1. Bid / Ask

Bid：

> 买方报价。

Ask：

> 卖方报价。

而在订单流语境里，经常观察的是：

> 主动买单打Ask，还是主动卖单砸Bid。

---

### 2. Market Order

市价单。

例如有人急着买黄金：

> 不等挂单成交，直接吃掉卖盘。

叫：

**Aggressive Buyer**

主动买方。

---

### 3. Limit Order

限价挂单。

例如4440挂着大量卖单：

```text
4440
SELL LIMIT
```

不断吸收市场买单。

这是所谓：

# Absorption

吸收。

---

# 八、Absorption非常适合黄金

假设黄金冲：

```text
PDH = 4450
```

然后：

```text
4450
4452
4454
4456
```

表面看很强。

但是订单流显示：

```text
大量Market Buy
```

不断打进去。

但奇怪的是：

```text
成交非常大
价格却涨不上去
```

这可能说明：

> 上面存在大型被动卖单不断吸收主动买盘。

这就是：

# Sell-side Absorption

随后价格：

```text
4456
↓
4448
```

这种Sweep做空机会质量会明显提高。

---

# 九、Delta是什么

非常重要。

### Delta

通常简单理解：

```text
Delta =
主动买入成交量
-
主动卖出成交量
```

例如：

```text
Ask成交：8000
Bid成交：5000

Delta = +3000
```

说明：

> 主动买方更强。

如果：

```text
Delta = -4000
```

说明：

> 主动卖方更强。

---

# 十、但Delta不能简单这样交易

不能变成：

```text
Delta正
→ 买

Delta负
→ 卖
```

那又重新变成“指标交易”。

真正有意义的是：

# Divergence

背离。

例如黄金：

```text
价格：
4450
→
4458 创新高
```

可是：

```text
Delta：
+5000
→
+1200
```

甚至出现负Delta。

意味着：

> 价格创新高，但主动买盘没有同步增强。

如果刚好这里还是：

```text
昨日高点
+
Liquidity Sweep
```

这个信息就很有价值。

---

# 十一、CVD是什么

# CVD = Cumulative Volume Delta

累计成交量Delta。

简单理解：

```text
CVD
=
不断累计Delta
```

用来观察：

> 主动买卖力量整体是在增强还是减弱。

比如：

黄金价格：

```text
4430
4440
4450
4460
```

持续创新高。

但是：

```text
CVD
↓
```

这就是比较值得警惕的：

**Price / CVD Divergence。**

---

# 十二、Footprint是什么

这个工具非常重要。

# Footprint Chart

中文通常叫：

**足迹图。**

普通K线：

```text
│
█
█
│
```

只告诉你OHLC。

Footprint可能显示：

```text
        Bid × Ask

4440    320 × 950
4439    410 × 1200
4438    780 × 1600
4437    1100 × 900
4436    1500 × 600
```

这样你可以看到每一个价格：

> Bid成交多少；
> Ask成交多少。

对于精确入场非常有价值。

---

# 十三、还有一个非常重要的东西：DOM

# DOM = Depth of Market

市场深度。

或者：

**Order Book / 订单簿。**

例如：

```text
SELL

4442   850
4441   620
4440  2500   ← 大挂单

----------------

4439   市场价格

4438  1100
4437   700
4436  1800

BUY
```

你能看到：

> 哪些价位存在等待成交的挂单。

但是DOM的难点是：

**挂单可以撤掉。**

所以不能看到大单就认为：

> 一定是支撑/阻力。

还涉及：

- spoofing；
- iceberg orders；
- pull/stack；
- absorption。

这是更高级的一层。

---

# 十四、你的系统需不需要订单流？

我的答案是：

# 需要，但不是一开始就必须。

更准确地说：

> **订单流应该是第三层确认，不应该成为第一层决策。**

我建议你的系统按四层设计。

---

## Layer 1：Context

先判断环境：

```text
1H / 15M
```

回答：

> 趋势还是震荡？

---

## Layer 2：Location

然后找到：

```text
PDH
PDL
Asia High
Asia Low
London High
London Low
VWAP
重要结构位
```

回答：

> 现在是不是一个值得交易的位置？

---

## Layer 3：Price Action

出现：

```text
Breakout
Retest
Sweep
CHOCH
BOS
```

回答：

> 市场是不是开始按照我的假设行动？

---

## Layer 4：Order Flow

最后观察：

```text
Delta
CVD
Footprint
Absorption
Imbalance
```

回答：

> 买卖双方的真实成交行为是否支持我的交易？

于是：

```text
Context
   ↓
Location
   ↓
Price Action
   ↓
Order Flow
   ↓
Entry
```

我认为这是非常合理的黄金日内体系。

---

# 十六、但黄金订单流有一个非常重要的问题

你交易的：

# XAUUSD现货黄金

本质上属于全球OTC市场。

它不像股票或者CME期货一样存在一个：

> 完全集中的交易所订单簿。

所以你在某一个MT5经纪商看到的成交量、DOM：

**并不能代表全球黄金市场全部订单。**

这是非常关键的。

---

# 十七、所以我反而建议用黄金期货做订单流参考

如果你真的准备把这套系统专业化，我更建议：

交易：

> **XAUUSD**

但观察订单流时参考：

> **COMEX Gold Futures**

主要是：

```text
GC
```

或者微型：

```text
MGC
```

因为CME黄金期货有更标准化的：

- 成交量；
- Bid/Ask；
- Delta；
- Footprint；
- DOM；
- Volume Profile。

于是你的工作台可以变成：

```text
        决策

XAUUSD TradingView
15M / 5M
价格结构
      │
      │
      ▼
GC Futures
Footprint
Delta
CVD
Volume Profile
      │
      ▼
      Entry
      │
      ▼
XAUUSD执行
```

这是我认为明显比：

```text
MACD + RSI + KDJ
```

更适合专业黄金日内交易的方向。

不过GC期货与XAUUSD并不是逐tick完全相同，因此**订单流用于确认，不要直接机械复制期货价格点位到现货执行**。

---

## 与传统指标的关系

原会话将 MACD/RSI/KDJ 定位为历史价格的趋势或动量辅助，把 Context → Location → Price Action → Order Flow 作为主分析链。这里保留方法分工，不把“结构天然更快、更赚钱”当作结论。

## 产品映射

Concept 统一描述 HH/HL/LH/LL、BOS、CHOCH、Sweep、FVG、OB、Delta、CVD、Absorption 等术语；Rule 引用 Concept；Trade、Case、Lesson 和 Mistake 复用同一标识。定义版本和数据来源需后续补齐。

---

来源章节：SMC 解释；技术体系与订单流回答第六至十四、十六至十七节。来源范围及待确认事项见 [归档说明](15-source-and-decisions.md)。

[返回总索引](README.md)
