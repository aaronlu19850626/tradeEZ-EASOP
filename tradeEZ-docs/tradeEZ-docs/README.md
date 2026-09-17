# TradeEZ 项目文档归档

归档日期：2026-09-10  
来源会话：黄金行情监控  
内容状态：交易方法、课程、产品与技术方案草案。

## 当前阶段需求

[第一阶段详细功能需求文档（V1.0）](16-phase1-functional-requirements.md) 根据 2026-09-17 的新需求讨论补充，覆盖账号同步基础、标签、交易复盘、规则评价、整体分析、盘前计划、盘后总结和习惯闭环。包含业务流程、异常处理与验收用例，不包含接口或数据库设计。该文档是本次产品评审基线，以下 01–15 文件仍保留历史归档性质。

## 使用方式

将本目录中的 Markdown 文件复制到 `tradeEZ/docs/`。文件使用相对链接，复制后仍可浏览。先读产品蓝图与 MVP PRD，再按模块读取规则、数据、API 和 AI 文档。

本包已排除全部前端 UI 模板、模板选择及 UI 推荐内容。保留的页面名称、业务路由和字段仅表达功能需求。

## 总索引

| 文件 | 内容 |
|---|---|
| [01-trading-system.md](01-trading-system.md) | 黄金日内交易系统与风险管理 |
| [02-entry-setups-and-glossary.md](02-entry-setups-and-glossary.md) | 入场模型、确认规则与交易术语 |
| [03-smc-and-order-flow.md](03-smc-and-order-flow.md) | SMC、订单流与统一概念 |
| [04-order-flow-tools-and-data.md](04-order-flow-tools-and-data.md) | 订单流工具与数据接入 |
| [05-gold-macro-and-context.md](05-gold-macro-and-context.md) | 黄金宏观、事件与交易上下文 |
| [06-curriculum.md](06-curriculum.md) | 课程体系：六阶段十八模块 |
| [07-content-production-and-reading.md](07-content-production-and-reading.md) | 图文视频制作、阅读书单与内容分层 |
| [08-product-blueprint.md](08-product-blueprint.md) | TradeEZ 产品蓝图 |
| [09-mvp-prd.md](09-mvp-prd.md) | Phase 1 MVP PRD |
| [10-playbook-and-scoring.md](10-playbook-and-scoring.md) | Playbook、规则引擎与执行评分 |
| [11-data-model.md](11-data-model.md) | 领域模型与数据库字段草案 |
| [12-api-import-and-backend.md](12-api-import-and-backend.md) | API、交易导入与后端架构 |
| [13-ai-review-and-rag.md](13-ai-review-and-rag.md) | AI Review、Evidence 与 RAG 架构 |
| [14-roadmap-and-learning-loop.md](14-roadmap-and-learning-loop.md) | 开发路线、学习闭环与产品指标 |
| [15-source-and-decisions.md](15-source-and-decisions.md) | 来源、归档边界与待确认事项 |

## 开发阅读顺序

1. [产品蓝图](08-product-blueprint.md) → [MVP PRD](09-mvp-prd.md) → [开发路线](14-roadmap-and-learning-loop.md)。
2. [规则评分](10-playbook-and-scoring.md) → [数据模型](11-data-model.md) → [API 与导入](12-api-import-and-backend.md) → [AI 架构](13-ai-review-and-rag.md)。
3. 结合 [交易系统](01-trading-system.md)、[入场模型](02-entry-setups-and-glossary.md)、[SMC/订单流](03-smc-and-order-flow.md) 和 [宏观上下文](05-gold-macro-and-context.md) 建立统一概念。
4. 用 [课程体系](06-curriculum.md) 与 [内容生产规范](07-content-production-and-reading.md) 建设 Academy。

## 必须保留的来源限制

MVP PRD 在读取接口的 20,000 字符限制处截断，第 81 节之后未取得。所有已取得的相关模块已整理；未声称恢复缺失正文。原会话图像未返回。详情及发现的参数冲突、算术问题见 [来源与待确认事项](15-source-and-decisions.md)。

案例价格、收益率、胜率、评分与统计均为原会话示例，不能作为已验证业务数据。新增验收建议与开发缺口均单独标为“归档整理补充”。
