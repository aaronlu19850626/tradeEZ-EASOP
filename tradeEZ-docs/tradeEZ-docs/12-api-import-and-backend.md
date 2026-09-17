# API、交易导入与后端架构

> 归档日期：2026-09-10。来源：原会话《黄金行情监控》。本文是会话资料整理，方案与参数仍属草案；所有案例数值均为教学或产品示例，非已验证业绩。

REST 路径、导入管道和后端技术均为原会话方案；前端框架、组件树与 UI 建议已剔除。

## API 设计原则

使用：

```text
/api/v1
```

REST 足够。

Phase 1 不需要 GraphQL。

## 核心 API

## Trades

```text
GET    /trades
GET    /trades/:id
POST   /trades
PATCH  /trades/:id
DELETE /trades/:id
```

---

## Imports

```text
POST /imports
GET  /imports/:id
```

---

## Playbooks

```text
GET    /playbooks
POST   /playbooks
GET    /playbooks/:id
PATCH  /playbooks/:id
DELETE /playbooks/:id
```

---

## Rules

```text
POST  /playbooks/:id/rules
PATCH /rules/:id
DELETE /rules/:id
```

---

## Trade Evaluation

```text
POST /trades/:id/evaluate
```

输出：

```text
rule_results
execution_score
grade
```

---

## AI Review

```text
POST /trades/:id/ai-review
GET  /trades/:id/ai-review
```

---

## Analytics

```text
GET /analytics/overview

GET /analytics/setups

GET /analytics/sessions

GET /analytics/mistakes

GET /analytics/execution
```

## Import Architecture

```text
MT5 CSV
    ↓
Upload
    ↓
File Parser
    ↓
Normalize
    ↓
Execution Records
    ↓
Trade Reconstruction
    ↓
Metrics Calculation
    ↓
Journal
```

Trade Reconstruction 是关键模块。

因为多个订单必须聚合成一笔 Trade。

## Import Normalized Schema

所有 Broker 先转换为统一结构：

```text
ExternalExecution

broker
account
symbol
side
action
quantity
price
timestamp
commission
swap
external_order_id
external_position_id
```

再统一生成 Trade。

以后扩展 Broker 不需要修改 Journal。

## Backend 建议

如果团队主要 TypeScript：

```text
NestJS
```

会比较顺。

模块：

```text
AuthModule

UsersModule

AccountsModule

ImportsModule

TradesModule

PlaybooksModule

AnalyticsModule

KnowledgeModule

CasesModule

AIReviewModule
```

架构：

# Modular Monolith

暂时不要微服务。

## Async Jobs

这些操作走异步：

```text
CSV Import

Trade Reconstruction

Metric Recalculation

AI Review

Screenshot Processing

Analytics Refresh
```

使用：

```text
Redis
+
BullMQ
```

第一阶段足够。

## 数据计算层

所有核心指标必须由代码计算：

```text
R

MAE

MFE

Win Rate

Profit Factor

Expectancy

Drawdown

Rule Score

Execution Score
```

不要交给LLM。

## 蓝图中的基础设施候选

PostgreSQL；对象存储 S3-compatible；Redis；Queue/Worker；AI 检索候选 pgvector。蓝图曾列 NestJS 或 FastAPI，后续 PRD 在 TypeScript 团队条件下倾向 NestJS，尚无最终技术决策。

## 归档整理补充：API 契约缺口

原文没有定义请求/响应 JSON Schema、鉴权、分页、排序、错误码、异步 Job 状态、幂等键、上传限制或删除语义。也没有 MT4/MT5 各导出格式样本和完整交易重建算法。开发前应通过脱敏样本明确这些边界。

接口清单未覆盖全部产品域，例如 Lesson/Case/Recommendation；不能将当前列表称为完整 API。

---

来源章节：MVP PRD 第 70–73、77–79 节；蓝图后端与基础设施候选。来源范围及待确认事项见 [归档说明](15-source-and-decisions.md)。

[返回总索引](README.md)
