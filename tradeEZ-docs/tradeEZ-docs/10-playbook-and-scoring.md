# Playbook、规则引擎与执行评分

> 归档日期：2026-09-10。来源：原会话《黄金行情监控》。本文是会话资料整理，方案与参数仍属草案；所有案例数值均为教学或产品示例，非已验证业绩。

规则引擎优先确定性计算。下列分级和权重是 V1 草案，需要先处理 UNKNOWN、N/A、必选规则和版本变化。

## Playbook Rule Checklist

Trade Detail 最重要区域之一。

例如：

## Liquidity Sweep Short

```text
LOCATION

✓ At PDH
✓ External Liquidity

STRUCTURE

✓ Sweep occurred
✓ Price reclaimed below level
✓ CHOCH confirmed

ENTRY

✓ Retest
✗ Order flow confirmation

RISK

✓ Stop beyond sweep
✓ RR >= 2
```

最终：

```text
8 / 9 Rules Followed
```

## Rule 类型

playbook_rule 必须支持：

```text
BOOLEAN
NUMBER
ENUM
TEXT
AUTOMATIC
AI_ASSISTED
```

例如：

### BOOLEAN

```text
CHOCH confirmed?
```

### NUMBER

```text
Minimum RR >= 2
```

### ENUM

```text
Session:
London / NY
```

### AUTOMATIC

```text
Risk <= 1.5%
```

### AI_ASSISTED

```text
Was there a valid liquidity sweep?
```

## Execution Score V1

建议不要让AI自由打分。

先固定公式。

```text
Setup Context       20%
Location            20%
Entry Confirmation  20%
Risk                 20%
Management           20%
```

每个 Rule 属于一个 Category。

例如：

```text
CHOCH confirmed

Category:
ENTRY_CONFIRMATION

Weight:
6
```

则：

```text
Category Score =
Passed Rule Weight
/
Total Rule Weight
```

最终：

```text
Execution Score =
Σ CategoryScore × CategoryWeight
```

## Trade Grade

建议：

```text
A+   >= 95
A    85–94
B    70–84
C    50–69
D    < 50
```

但：

## Grade 与 Result 完全分离。

例如：

```text
A Trade
-1R
```

仍然应该被标记：

# Good Loss

## Process / Outcome Matrix

Trade Detail 加入：

| | 盈利 | 亏损 |
|---|---|---|
| High Execution | Good Win | Good Loss |
| Low Execution | Lucky Win | Bad Loss |

这一块非常值得成为 TradeEZ 的品牌语言。

## Playbook List PRD

路由：

```text
/playbooks
```

展示：

```text
Liquidity Sweep Short

Active

Trades
46

Win Rate
56%

Expectancy
+0.83R

Execution
82
```

## Playbook Detail

路由：

```text
/playbooks/:id
```

结构：

```text
Overview

Rules

Entry Model

Risk Model

Trade Management

Examples

Performance

Mistakes

Related Lessons
```

## Playbook Builder

Phase 1 做简单版本。

创建 Playbook：

### Basic

```text
Name

Market

Direction

Style

Description
```

### Rules

用户创建：

```text
Rule Name
Category
Type
Required?
Weight
```

例如：

```text
CHOCH confirmed

Entry Confirmation

Boolean

Required

Weight 5
```

## Playbook Stats

统计：

```text
Trades
Win Rate
Profit Factor
Expectancy
Average R
Max Drawdown
Execution Score
```

并支持：

```text
Rule Followed
vs
Rule Violated
```

例如：

```text
CHOCH CONFIRMED

YES
42 trades
Expectancy +1.12R

NO
19 trades
Expectancy -0.47R
```

这一能力非常关键。

## 归档整理补充：实现前待定

- BOOLEAN/NUMBER/ENUM/TEXT 是值类型；MANUAL/AUTOMATIC/AI_ASSISTED 是评估模式。原 PRD 第 24 节混合了两者，第 66 节已单列 evaluation_mode，应进一步统一。
- Category Score 原式是 0–1 比例，最终 0–100 分的量纲需明确。
- UNKNOWN 与 NOT_APPLICABLE 是否计入分母；某类别无规则时如何分配权重。
- Required 失败是否直接限制 Grade，不能默认为普通扣分。
- 分数小数、四舍五入与等级边界需明确。
- 原蓝图将 High-Quality Execution 定义为 ≥80，但 A 从 85 起，二者不是同一口径。
- Playbook 修改后，旧交易采用历史规则版本还是重算，尚未决定。
- Similar Case 权重为 Setup 40%、Direction/Session/Market Condition/Location 各15%；缺失特征与 Symbol 的硬过滤策略待定。

---

来源章节：MVP PRD 第 23–27、38–41 节；归档时交叉核对。来源范围及待确认事项见 [归档说明](15-source-and-decisions.md)。

[返回总索引](README.md)
