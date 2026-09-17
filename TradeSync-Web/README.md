# TradeSync — MT5 交易数据同步与复盘 SaaS

把 MT5 的原始成交同步到云端，变成**不可篡改的交易档案 + 纪律考官 + 复盘教练**。

## 是什么

多用户 Web SaaS。用户在 Web 注册会员、绑定 MT5 账户、拿到同步 Key 填进 EA；
EA 把成交/快照准实时推到云端；Web 端提供每日盈亏、订单查询、订单统计（R 倍数口径）、
纪律合规、复盘、以及每日美盘前 AI 盘前简报。

## 三大目标

1. **严明记录**：以 MT5 原始成交为唯一真相源，只增不改，不可事后篡改。
2. **严格自律**：用户预设交易规则，系统每日自动判定违规，量化自律评分。
3. **复盘提升**：每笔交易可标注回看；每天美盘前 AI 生成基本面+技术面参考。

## 技术栈

- 后端：Python **FastAPI** + **PostgreSQL**（+ TimescaleDB 存净值时序）
- 前端：**Next.js** + TradingView Lightweight Charts / ECharts
- 任务：Celery/APScheduler（AI 简报、每日物化统计、爬虫）
- 数据源同步端：MT5 EA 内置 `SyncModule`（WebRequest）
- 部署：Docker Compose + Nginx + 自建海外服务器；代码托管 GitHub

## 文档索引

| 文档 | 内容 |
|---|---|
| [docs/PRD.md](docs/PRD.md) | 产品需求文档：用户/功能/验收标准/路线图 |
| [docs/DESIGN.md](docs/DESIGN.md) | 技术设计：架构/同步契约/统计口径/EA 模块 |
| [docs/DATABASE.md](docs/DATABASE.md) | 数据库 schema（PostgreSQL DDL） |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | GitHub 托管 + 服务器部署手册 |

## 快速上手（开发）

```bash
# 后端
cd backend && python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head        # 建表
uvicorn app.main:app --reload

# 前端
cd frontend && npm install && npm run dev
```

## 目标市场 / 关键决策

海外市场 · 盈亏比用 **R 倍数** · 成交**准实时**推送 · 财经日历**爬虫**抓取 · **全品种**支持。
详见 PRD 与 DESIGN。
