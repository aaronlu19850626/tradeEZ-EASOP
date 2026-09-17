# 领域模型与数据库字段草案

> 归档日期：2026-09-10。来源：原会话《黄金行情监控》。本文是会话资料整理，方案与参数仍属草案；所有案例数值均为教学或产品示例，非已验证业绩。

这是领域和字段清单，尚不是可执行数据库迁移；原会话没有给出完整类型、约束、索引或权限策略。

## Domain Model

核心领域拆成：

```text
Identity
Trading
Journal
Playbook
Analytics
Knowledge
AI
Market
```

## Trading Domain

```text
TradingAccount

Broker

ImportJob

Order

Execution

Trade

Position
```

## Playbook Domain

```text
Setup

Playbook

PlaybookRule

TradeRuleResult

TradeGrade
```

## Knowledge Domain

```text
Concept

Lesson

CaseStudy

Mistake

Tag
```

## AI Domain

```text
AIReview

AIInsight

Recommendation

Evidence
```

## Database Core Schema

建议 PostgreSQL。

核心表：

```text
users

workspaces

trading_accounts

brokers

import_jobs

orders

executions

trades

trade_metrics

trade_notes

trade_screenshots

setups

playbooks

playbook_rules

trade_rule_results

mistakes

trade_mistakes

tags

trade_tags

concepts

lessons

lesson_concepts

case_studies

case_concepts

ai_reviews

ai_review_evidence
```

## trades

建议：

```text
id

workspace_id

account_id

symbol

side

opened_at

closed_at

entry_price

exit_price

quantity

gross_pnl

net_pnl

commission

swap

initial_stop

planned_target

initial_risk_amount

initial_risk_price

realized_r

mae

mfe

status

setup_id

playbook_id

session

market_condition

execution_score

grade

created_at

updated_at
```

## executions

```text
id

trade_id

external_id

side

type

price

quantity

executed_at

commission
```

## playbooks

```text
id

workspace_id

name

slug

description

symbol_scope

direction

style

status

created_at

updated_at
```

## playbook_rules

```text
id

playbook_id

name

description

category

rule_type

operator

target_value

required

weight

evaluation_mode

sort_order
```

evaluation_mode：

```text
MANUAL
AUTOMATIC
AI_ASSISTED
```

## trade_rule_results

```text
id

trade_id

rule_id

status

actual_value

score

source

reason

evaluated_at
```

status：

```text
PASS
FAIL
UNKNOWN
NOT_APPLICABLE
```

## mistakes

```text
id

code

name

category

description

related_concept_id
```

## AI Review 数据

```text
ai_reviews

id
trade_id
model
prompt_version
verdict
summary
confidence
created_at
```

另：

```text
ai_review_evidence

review_id

evidence_type

source_id

content

weight
```

## 长期扩展对象

## 核心数据库

建议至少建立：

```text
users

trading_accounts

brokers

orders

executions

trades

trade_positions

trade_tags

setups

playbooks

playbook_rules

trade_rule_results

mistakes

trade_mistakes

concepts

lessons

lesson_concepts

case_studies

case_features

exercises

exercise_attempts

backtest_sessions

backtest_trades

market_contexts

macro_events

orderflow_contexts

skills

user_skills

skill_evidence

ai_reviews
```

## 核心关系

```text
User
 │
 ├── TradingAccount
 │      │
 │      └── Trade
 │             │
 │             ├── Setup
 │             │
 │             ├── Playbook
 │             │
 │             ├── RuleResult
 │             │
 │             ├── Mistake
 │             │
 │             ├── MarketContext
 │             │
 │             ├── MacroContext
 │             │
 │             └── AIReview
 │
 ├── Skill
 │
 ├── Exercise
 │
 └── Backtest
```

## 归档整理补充：建表前必须补齐

1. workspace/account 数据归属、跨用户隔离与关联约束。
2. 金额与数量精度、币种、合约乘数、服务器时间与 UTC 换算。
3. Order、Execution、Position、Trade 的净持仓/对冲模式聚合规则。
4. 导入去重键及 external_id 的账户/经纪商作用域。
5. 初始风险、加仓、部分平仓、佣金、Swap、退款与修正记录的计算口径。
6. MAE/MFE 的单位与价格路径要求；无数据时使用缺失状态。
7. Playbook/Rule 版本与评估证据快照。
8. Setup 与 Playbook 的关系、Lesson 和 Concept 的关联、Case 从用户 Trade 转为教学素材的流程。
9. 长期表只保留设计方向，不能将蓝图全部表视为首发建表要求。

---

来源章节：MVP PRD 第 57–69 节；蓝图第 26–27 节。来源范围及待确认事项见 [归档说明](15-source-and-decisions.md)。

[返回总索引](README.md)
