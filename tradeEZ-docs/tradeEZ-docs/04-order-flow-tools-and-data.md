# 订单流工具与数据接入

> 归档日期：2026-09-10。来源：原会话《黄金行情监控》。本文是会话资料整理，方案与参数仍属草案；所有案例数值均为教学或产品示例，非已验证业绩。

仅归档原会话的工具分工与数据需求，不保留时效性价格、采购结论或前端模板内容。

| 工具/数据 | 原讨论用途 |
|---|---|
| TradingView | XAUUSD 价格结构、关键位、截图 |
| Quantower | GC Footprint、Delta/CVD、Volume Profile、Time & Sales |
| Bookmap | 后续学习流动性热图、吸收与深度变化 |
| Sierra Chart | 后续专业足迹图和历史市场深度研究 |
| CME/COMEX GC 数据 | 黄金期货集中市场成交和深度参考 |

原会话曾提出 TradingView + Quantower + GC 数据的学习组合；这是历史建议，未确认采购。软件费与交易所数据费是不同项目，功能权限、历史逐笔数据、深度数据、专业/非专业资格需另行核实。

## 学习顺序

Volume Profile（POC/VAH/VAL）→ Footprint（Bid×Ask、Delta）→ Imbalance / Absorption → CVD 综合确认 → DOM / Heatmap。原回答在 CVD 的先后顺序上略有差别，核心一致：先理解成交和位置，再研究快速变化的挂单。

## 接入边界

- XAUUSD 为 OTC 市场，经纪商提供的量和深度不能代表全球市场。
- GC 与 XAUUSD 不是同一价格序列；期货价格不能直接复制到现货执行。
- 区分成交数据、报价数据和挂单深度；Tick Volume 不等同集中市场实际成交量。
- Phase 1 先保留截图与人工标签；完整 GC 订单流属于 Phase 3。
- 待定义：合约与换月、现货/期货时间对齐、来源与延迟、数据许可、留存和历史重放覆盖。

---

来源章节：订单流工具回答；软件费用回答（剔除报价）；产品蓝图分期。来源范围及待确认事项见 [归档说明](15-source-and-decisions.md)。

[返回总索引](README.md)
