# 数据同步模块 v2.0 变更说明

**日期**：2026-01-18  
**版本**：v1.0 → v2.0  
**类型**：重大架构变更（队列模式 → 增量同步模式）

---

## 变更原因

用户要求实现**真正的增量同步**：
- 每次同步前，先获取服务器端最后同步时间
- 只上传该时间之后的新成交
- 避免重复上传，减少服务器压力
- 严格处理边界时间

---

## 核心变更对比

| 维度 | v1.0（队列模式） | v2.0（增量模式） |
|-----|----------------|----------------|
| **同步流程** | 成交入队 → 定时上传 → 清空队列 | 获取服务器时间 → 增量查询 → 批量上传 |
| **OnTradeTransaction** | 写入队列文件 | 无操作 |
| **OnTimer** | 读取队列 → 上传 → 删除文件 | 查询 HistorySelect → 上传 |
| **本地存储** | JSONL 队列文件 | 无（仅缓存服务器时间） |
| **边界处理** | 队列清空，依赖幂等 | `lastTime + 1` 秒，避免重复 |
| **断线恢复** | 保留队列文件 | 下次从服务器时间继续 |
| **服务器接口** | `/api/v1/ingest/deals` | 新增 `/api/v1/sync/last_sync_time` |

---

## 代码变更

### ❌ 移除的函数

```mql5
// 1. 队列文件管理
string SyncQueueFile()
void AppendDealToQueue(ulong dealTicket)
string ReadQueueDeals(int maxCount, string &deals[])
void ClearQueueFile()

// 2. 历史回补
void BackfillHistoryDeals(int daysBack)
```

**原因**：
- 队列文件机制被增量查询替代
- 历史回补由服务器端 `last_sync_time` 自动处理

---

### ✅ 新增的函数

```mql5
// 1. 获取服务器最后同步时间
datetime GetServerLastSyncTime()

// 2. 增量收集成交
int CollectDealsAfterTime(datetime afterTime, string &dealsJson[])

// 3. 提取最新成交时间
datetime GetLatestDealTime(const string &dealsJson[])
```

---

### 🔄 修改的函数

#### SyncDeals() - 核心同步函数

**v1.0**：
```mql5
bool SyncDeals()
{
    // 读取队列
    string deals[];
    ReadQueueDeals(Inp_MaxBatchSize, deals);
    if(ArraySize(deals) == 0) return true;
    
    // 上传
    WebRequest(...);
    
    // 清空队列
    if(res == 200)
        ClearQueueFile();
}
```

**v2.0**：
```mql5
bool SyncDeals()
{
    // 1. 获取服务器最后同步时间
    datetime serverLastTime = GetServerLastSyncTime();
    
    // 2. 增量收集成交
    string deals[];
    int count = CollectDealsAfterTime(serverLastTime, deals);
    if(count == 0) return true;
    
    // 3. 获取最新成交时间
    datetime latestDealTime = GetLatestDealTime(deals);
    
    // 4. 上传（包含 last_deal_time）
    string body = StringFormat(
        "{...,\"last_deal_time\":%d,\"deals\":[%s]}",
        latestDealTime, bodyDeals
    );
    WebRequest(...);
    
    // 5. 更新缓存
    if(res == 200)
        g_ServerLastSyncTime = latestDealTime;
}
```

---

#### OnInit() - 初始化

**v1.0**：
```mql5
if(Inp_EnableSync && Inp_SecretKey != "")
{
    SyncSymbols();
    BackfillHistoryDeals(7); // 回补7天
}
```

**v2.0**：
```mql5
if(Inp_EnableSync && Inp_SecretKey != "")
{
    SyncSymbols();
    g_ServerLastSyncTime = GetServerLastSyncTime(); // 获取服务器时间
}
```

---

#### OnTradeTransaction() - 成交事件

**v1.0**：
```mql5
if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
{
    if(Inp_EnableSync)
        AppendDealToQueue(trans.deal); // 入队
    
    CheckAllRiskControl();
    RenderPerfectUI();
}
```

**v2.0**：
```mql5
if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
{
    // 无操作，由 OnTimer 统一同步
    CheckAllRiskControl();
    RenderPerfectUI();
}
```

---

### 🆕 新增全局变量

```mql5
datetime g_ServerLastSyncTime = 0; // 服务器最后同步时间缓存
```

---

## 服务器端变更要求

### 1. 新增数据库字段

```sql
ALTER TABLE accounts 
ADD COLUMN last_sync_time BIGINT DEFAULT 0;
```

---

### 2. 新增接口

```python
@router.post("/api/v1/sync/last_sync_time")
async def get_last_sync_time(request: LastSyncTimeRequest):
    account = db.query(Account).filter(
        Account.mt5_login == request.mt5_login
    ).first()
    
    if not account:
        return {"last_sync_time": 0}
    
    return {"last_sync_time": account.last_sync_time or 0}
```

**请求体**：
```json
{
  "mt5_login": 88973405
}
```

**响应体**：
```json
{
  "last_sync_time": 1753082193
}
```

---

### 3. 修改现有接口

**接口**：`POST /api/v1/ingest/deals`

**请求体新增字段**：
```json
{
  "mt5_login": 88973405,
  "server_gmt_off": 10800,
  "last_deal_time": 1753082193,  // ← 新增
  "deals": [...]
}
```

**处理逻辑**：
```python
# 1. 幂等插入成交
for deal in request.deals:
    db.execute(
        "INSERT INTO deals (...) VALUES (...) "
        "ON CONFLICT (account_id, ticket) DO NOTHING"
    )

# 2. 更新最后同步时间
if request.last_deal_time:
    db.execute(
        "UPDATE accounts SET last_sync_time = :time WHERE id = :id",
        {"time": request.last_deal_time, "id": account.id}
    )

db.commit()
```

---

## 边界处理

### 关键设计：lastTime + 1 秒

**场景**：
- 服务器 `last_sync_time = 1753082193`（2026-01-18 10:30:00）
- 该时间点有 1 笔成交

**v1.0 风险**：
- 队列清空后，如果重复调用可能重新入队
- 依赖服务器端幂等（`ON CONFLICT DO NOTHING`）

**v2.0 保证**：
```mql5
datetime fromTime = afterTime + 1; // 1753082194 (10:30:01)
HistorySelect(fromTime, toTime);
```
- 查询从 `10:30:01` 开始
- `10:30:00` 的订单不会被重复上传 ✅

**验证**：
| 订单 | 成交时间 | 上次同步 | 本次查询 | 结果 |
|-----|---------|---------|---------|------|
| A | 10:30:00 | ✅ 已同步 | ❌ 不包含 | 不重复 ✅ |
| B | 10:30:01 | ❌ 未同步 | ✅ 包含 | 新上传 ✅ |

---

## 性能对比

### v1.0（队列模式）

| 操作 | 频率 | 性能开销 |
|-----|------|---------|
| 成交入队 | 每笔成交 | 文件写入（磁盘IO） |
| 读取队列 | 每 N 分钟 | 文件读取 |
| 上传成交 | 每 N 分钟 | 网络请求 1 次 |
| 清空队列 | 每 N 分钟 | 文件删除 |

**总计**：
- 磁盘IO：**高**（每笔成交都写文件）
- 网络请求：1 次/N 分钟

---

### v2.0（增量模式）

| 操作 | 频率 | 性能开销 |
|-----|------|---------|
| 获取服务器时间 | 每 N 分钟 | 网络请求 1 次 |
| 查询历史成交 | 每 N 分钟 | HistorySelect（内存） |
| 上传成交 | 每 N 分钟 | 网络请求 1 次 |

**总计**：
- 磁盘IO：**无**
- 网络请求：2 次/N 分钟

**结论**：
- ✅ 减少磁盘IO
- ⚠️ 网络请求增加 1 次（但可接受）

---

## 测试验证

### 测试用例1：首次同步

**前提**：
- 服务器端 `accounts.last_sync_time = 0`

**步骤**：
1. 启动 EA（`Inp_DebugSync = true`）
2. 等待 N 分钟

**预期日志**：
```
[Sync] Module initialized. Server last sync time: 1970-01-01 00:00
[Sync] Found 156 deals after 2026-01-11 10:30
[Sync] Successfully synced 156 deals. Latest deal time: 2026-01-18 15:45
```

**验证**：
- 服务器 `accounts.last_sync_time = 1753082193`（最新成交时间）
- 数据库包含所有成交

---

### 测试用例2：增量同步

**前提**：
- 服务器端 `accounts.last_sync_time = 1753082193`（10:30:00）

**步骤**：
1. 下单 3 笔（时间：10:35:00, 10:36:00, 10:37:00）
2. 等待 N 分钟

**预期日志**：
```
[Sync] Server last sync time: 2026-01-18 10:30
[Sync] Found 3 deals after 2026-01-18 10:30
[Sync] Successfully synced 3 deals. Latest deal time: 2026-01-18 10:37
```

**验证**：
- 服务器 `accounts.last_sync_time = 1753082400`（10:37:00）
- 数据库只新增 3 笔成交

---

### 测试用例3：边界不重复

**前提**：
- 服务器端 `last_sync_time = 1753082193`（10:30:00）
- 该时间点有 1 笔成交（ticket=123456）

**步骤**：
1. 再次同步（无新成交）
2. 查看日志

**预期日志**：
```
[Sync] Server last sync time: 2026-01-18 10:30
[Sync] No new deals after 2026-01-18 10:30
```

**验证**：
- 不会重复上传 ticket=123456
- 数据库成交数量不变

---

### 测试用例4：断线恢复

**前提**：
- 服务器端 `last_sync_time = 1753082193`（10:30:00）

**步骤**：
1. 断开网络
2. 下单 5 笔（10:35:00 ~ 10:39:00）
3. 等待 N 分钟（网络仍断开）
4. 恢复网络
5. 等待 N 分钟

**预期日志**：
```
// 断网期间
[Sync] Failed to get last sync time: ...
[Sync] Found 5 deals after 2026-01-18 10:30
[Sync] Failed: ...

// 恢复后
[Sync] Server last sync time: 2026-01-18 10:30
[Sync] Found 5 deals after 2026-01-18 10:30
[Sync] Successfully synced 5 deals. Latest deal time: 2026-01-18 10:39
```

**验证**：
- 断网期间使用缓存 `g_ServerLastSyncTime`
- 恢复后自动补发缺失成交

---

## 迁移指南

### 用户无需操作

- v2.0 自动处理历史数据
- 首次同步会从服务器获取 `last_sync_time`
- 如果服务器为空（首次使用），自动回补 7 天

### 可选：清理旧队列文件

```
路径：MQL5/Files/GSOP_sync_queue_*.jsonl
操作：可手动删除（不影响功能）
```

---

## 后续优化建议

### EA 侧

- [ ] 缓存优化：本地持久化 `g_ServerLastSyncTime`，减少网络请求
- [ ] 批次限制：单次上传成交数量限制（防止超大批次）
- [ ] 指数退避：网络失败时增加重试间隔

### 服务器侧

- [ ] 索引优化：`accounts.last_sync_time` 添加索引
- [ ] 批量插入：使用 `COPY` 或批量 INSERT 提升性能
- [ ] 监控告警：同步延迟超过阈值时告警

---

## 总结

### 核心改进
1. ✅ **无队列文件** - 减少磁盘IO
2. ✅ **服务器控制** - 同步状态可靠
3. ✅ **增量查询** - 只传输新成交
4. ✅ **边界严格** - 不会重复上传

### 代码统计
- **移除代码**：~120 行（队列管理）
- **新增代码**：~180 行（增量同步）
- **净增代码**：+60 行

### 服务器端需求
- ✅ 新增接口：`POST /api/v1/sync/last_sync_time`
- ✅ 修改接口：`POST /api/v1/ingest/deals` 处理 `last_deal_time`
- ✅ 数据库字段：`accounts.last_sync_time`

---

**变更完成日期**：2026-01-18  
**文档版本**：v2.0  
**审核状态**：已完成代码实现，待服务器端配套
