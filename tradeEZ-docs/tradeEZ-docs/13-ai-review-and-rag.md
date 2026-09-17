# AI Review、Evidence 与 RAG 架构

> 归档日期：2026-09-10。来源：原会话《黄金行情监控》。本文是会话资料整理，方案与参数仍属草案；所有案例数值均为教学或产品示例，非已验证业绩。

AI 定位为基于证据的复盘教练。关键盈亏、风险、统计和规则评分由代码产生，AI 负责解释、归纳和知识关联。

## AI Review 页面模块

AI Review 不应仅返回一大段文字。

返回结构化结果：

```text
Trade Verdict

Rule Review

What You Did Well

What Needs Improvement

Primary Mistake

Evidence

Historical Comparison

Suggested Lesson

Suggested Exercise
```

## AI Review 示例

```text
TRADE REVIEW

Verdict
GOOD LOSS

Execution
91 / 100

Main Observation
Your entry followed the Liquidity Sweep playbook,
but the trade failed probabilistically.

What You Did Well
✓ PDH sweep
✓ CHOCH confirmation
✓ Valid retest
✓ Risk 0.9%

Improvement
Order flow confirmation was absent.

Historical Evidence
Similar trades with absorption:
Expectancy +1.18R

Without absorption:
Expectancy +0.41R

Recommended
Order Flow 06:
Understanding Absorption
```

这是最终希望达到的体验。

## AI Review 架构原则

绝不能：

```text
Trade JSON
 ↓
直接发给LLM
 ↓
让LLM自由分析
```

应该：

```text
Trade
 ↓
Data Normalizer
 ↓
Metrics Engine
 ↓
Rule Engine
 ↓
Historical Analytics
 ↓
Relevant Knowledge Retrieval
 ↓
AI Reasoning
 ↓
Structured Review
```

## AI Review Pipeline

```text
                     Trade ID
                        │
                        ↓
                 Trade Repository
                        │
          ┌─────────────┼─────────────┐
          ↓             ↓             ↓
      Trade Stats   Playbook Rules  Context
          │             │             │
          ↓             ↓             ↓
       Metrics       Rule Engine   Context Engine
          │             │             │
          └─────────────┼─────────────┘
                        ↓
                  Evidence Bundle
                        │
          ┌─────────────┴─────────────┐
          ↓                           ↓
  Similar Trade Search         Knowledge RAG
          │                           │
          └─────────────┬─────────────┘
                        ↓
                     LLM
                        ↓
               Structured Review
```

## Evidence Bundle

传入AI的对象建议类似：

```json
{
  "trade": {},
  "performance": {},
  "playbook": {},
  "rule_results": [],
  "market_context": {},
  "historical_stats": {},
  "similar_trades": [],
  "knowledge": []
}
```

AI不得自己计算关键统计指标。

统计必须由后端计算。

## AI Structured Output

AI必须返回 schema。

例如：

```json
{
  "verdict": "GOOD_LOSS",
  "summary": "...",
  "strengths": [],
  "issues": [],
  "primary_mistake_id": null,
  "evidence": [],
  "recommended_concept_ids": [],
  "recommended_case_ids": [],
  "confidence": 0.86
}
```

这样前端才能结构化展示。

## AI 允许做什么

AI负责：

```text
解释

总结

识别语言模式

关联知识

发现可能问题

基于Evidence提出建议
```

AI暂时不要负责：

```text
P&L计算

Expectancy计算

Trade Reconstruction

风险计算

核心统计
```

## AI Coach定位

AI不应该定位：

> 预测黄金下一步涨还是跌。

正确定位：

# Evidence-Based Trading Coach

AI输入：

```text
User
+
Trades
+
Playbook
+
Rules
+
Analytics
+
Market Context
+
Macro
+
Case Library
+
Lessons
```

输出：

- 交易复盘
- 重复错误
- Setup分析
- 规则执行
- 个性化训练
- Playbook建议
- 学习建议

## AI/RAG总体架构

```text
                   AI COACH
                      │
        ┌─────────────┼─────────────┐
        │             │             │
     SQL Tool      RAG Search    Rule Engine
        │             │             │
        │             │             │
   User Trades     Lessons       Playbook
   Analytics       Cases         Rules
   Statistics      Concepts      Compliance
        │             │             │
        └─────────────┼─────────────┘
                      ↓
                  Reasoning
                      ↓
               Evidence Layer
                      ↓
                 AI Review
```

## RAG知识来源

RAG不是把整个互联网塞进去。

第一阶段：

```text
Internal Academy

Playbooks

Concept Definitions

Case Library

Platform Documentation
```

第二阶段：

```text
Curated Books Notes

CME Materials

Trading Research

Macro Research
```

最重要：

AI回答时明确区分：

```text
Your Data

Your Playbook

Educational Knowledge

Market Data
```

避免混在一起。

## 归档整理补充：交付前待定

- Evidence 应能追溯到交易、规则、样本统计和知识版本；缺失证据时不能生成确定判断。
- 用户交易笔记与检索内容属于数据，不得作为修改权限或系统行为的指令。
- 同类比较必须显示样本数量、时间范围、筛选条件；相关性不能直接解释为因果改善。
- AI 的 confidence 示例没有校准定义，不应直接解释为策略成功概率。
- 原会话给出的是 JSON 形状示例，不是完整校验 Schema 或最终 Prompt。
- 自动读图、Setup 识别与错误识别不等于 Phase 1 已可用能力。
- 第 81 节 AI Coach 后续正文未取得；此文仅整合已读取的 PRD 与更早蓝图，不重建缺失章节。

---

来源章节：MVP PRD 第 32–37、80 节；产品蓝图第 23–25 节。来源范围及待确认事项见 [归档说明](15-source-and-decisions.md)。

[返回总索引](README.md)
