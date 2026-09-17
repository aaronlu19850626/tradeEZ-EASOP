# 数据同步增量模式设计文档

## 变更概述

**日期**：2026-01-18  
**版本**：v2.0（增量同步）  
**理由**：实现真正的增量同步，避免重复上传，减少服务器压力

---

## 核心设计

### 同步流程

```
┌─────────────────────────────────────────────────────────────┐
│                     OnTimer (每N分钟)                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
          ┌────────────────────────┐
          │   调用 SyncDeals()      │
          └────────┬───────────────┘
                   │
                   ▼
     ┌─────────────────────────────────┐
     │ 1. GetServerLastSyncTime()      │
     │    获取服务器最后同步时间        │
     └─────────┬───────────────────────┘
               │ 返回 lastTime (例如：1753082193)
               ▼
     ┌─────────────────────────────────┐
     │ 2. CollectDealsAfterTime()      │
     │    查询 HistorySelect(           │
     │        lastTime + 1,             │  ← 加1秒避免边界重复
     │        TimeCurrent()             │
     │    )                             │
     └─────────┬───────────────────────┘
               │ 返回 deals[] 数组
               ▼
     ┌─────────────────────────────────┐
     │ 3. GetLatestDealTime()          │
     │    提取最新成交时间               │
     └─────────┬───────────────────────┘
               │ 返回 latestTime
               ▼
     ┌─────────────────────────────────┐
     │ 4. POST /api/v1/ingest/deals    │
     │    {                             │
     │      "last_deal_time": latestTime│  ← 关键字段
     │      "deals": [...]              │
     │    }                             │
     └─────────┬───────────────────────┘
               │
               ▼
     ┌─────────────────────────────────┐
     │ 服务器端处理：                   │
     │ - 幂等插入成交                   │
     │ - 更新 last_sync_time=latestTime│
     └─────────────────────────────────┘
```

---

## 关键函数说明

### 1. GetServerLastSyncTime()

**作用**：从服务器获取该账户的最后同步时间

**请求**：
```json
POST /api/v1/sync/last_sync_time
{
  "mt5_login": 88973405
}
```

**响应**：
```json
{
  "last_sync_time": 1753082193
}
```

**返回值**：
- 成功：服务器最后同步时间（datetime）
- 失败/首次：0（表示从头开始）

**简化 JSON 解析**：
```mql5
int pos = StringFind(response, "\"last_sync_time\"");
int colonPos = StringFind(response, ":", pos);
string numStr = StringSubstr(response, colonPos + 1);
// 清理非数字字符
StringReplace(numStr, "}", "");
StringReplace(numStr, " ", "");
datetime lastTime = (datetime)StringToInteger(numStr);
```

---

### 2. CollectDealsAfterTime(afterTime, &dealsJson[])

**作用**：收集指定时间之后的所有成交

**核心逻辑**：
```mql5
datetime fromTime = afterTime + 1;  // 加1秒避免边界重复
datetime toTime = TimeCurrent();

if(!HistorySelect(fromTime, toTime))
    return 0;

int total = HistoryDealsTotal();
for(int i = 0; i < total; i++)
{
    ulong dealTicket = HistoryDealGetTicket(i);
    // 构造 JSON 并加入数组
}
```

**边界处理**：
- `afterTime + 1`：避免重复上传边界时间点的订单
- 例如：上次同步到 `2026-01-18 10:30:00`
  - 下次查询从 `2026-01-18 10:30:01` 开始
  - `10:30:00` 的订单不会被重复上传

**返回值**：收集到的成交数量

---

### 3. GetLatestDealTime(&dealsJson[])

**作用**：从成交数组中提取最新的成交时间

**核心逻辑**：
```mql5
datetime latestTime = 0;

for(int i = 0; i < ArraySize(dealsJson); i++)
{
    string json = dealsJson[i];
    int pos = StringFind(json, "\"deal_time\":");
    string timeStr = StringSubstr(json, pos + 12);
    StringReplace(timeStr, "}", "");
    datetime dealTime = (datetime)StringToInteger(timeStr);
    if(dealTime > latestTime)
        latestTime = dealTime;
}

return latestTime;
```

**用途**：
- 上传到服务器后，服务器用这个时间更新 `last_sync_time`
- 本地也缓存到 `g_ServerLastSyncTime`

---

### 4. SyncDeals() - 主同步函数

**完整流程**：
```mql5
bool SyncDeals()
{
    // 1. 获取服务器最后同步时间
    datetime serverLastTime = GetServerLastSyncTime();
    if(serverLastTime == 0 && g_ServerLastSyncTime > 0)
        serverLastTime = g_ServerLastSyncTime; // 使用缓存
    if(serverLastTime == 0)
        serverLastTime = TimeCurrent() - 7 * 86400; // 首次：7天前

    // 2. 收集该时间之后的成交
    string deals[];
    int count = CollectDealsAfterTime(serverLastTime, deals);
    if(count == 0)
        return true; // 没有新成交

    // 3. 获取最新成交时间
    datetime latestDealTime = GetLatestDealTime(deals);

    // 4. 构造请求体（包含 last_deal_time）
    string body = StringFormat(
        "{\"mt5_login\":%I64d,\"server_gmt_off\":%d,\"last_deal_time\":%d,\"deals\":[%s]}",
        login, gmtOffset, latestDealTime, bodyDeals
    );

    // 5. 发送请求
    int res = WebRequest("POST", url, headers, timeout, post, result, headers);

    // 6. 成功后更新缓存
    if(res == 200)
    {
        g_ServerLastSyncTime = latestDealTime;
        return true;
    }

    return false;
}
```

---

## 服务器端要求

### 1. 新增接口：获取最后同步时间

```python
@router.post("/api/v1/sync/last_sync_time")
async def get_last_sync_time(request: LastSyncTimeRequest):
    # 从数据库查询
    account = db.query(Account).filter(
        Account.mt5_login == request.mt5_login
    ).first()
    
    if not account:
        return {"last_sync_time": 0}  # 首次同步
    
    return {"last_sync_time": account.last_sync_time or 0}
```

**数据库字段**：
```sql
ALTER TABLE accounts ADD COLUMN last_sync_time BIGINT DEFAULT 0;
```

---

### 2. 修改接口：上传成交

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
@router.post("/api/v1/ingest/deals")
async def ingest_deals(request: IngestDealsRequest):
    account = get_account_by_login(request.mt5_login)
    
    # 1. 幂等插入成交
    for deal in request.deals:
        db.execute(
            "INSERT INTO deals (...) VALUES (...) ON CONFLICT (account_id, ticket) DO NOTHING"
        )
    
    # 2. 更新最后同步时间
    if request.last_deal_time:
        db.execute(
            "UPDATE accounts SET last_sync_time = :time WHERE id = :id",
            {"time": request.last_deal_time, "id": account.id}
        )
    
    db.commit()
    return {"accepted": len(request.deals)}
```

---

## 边界情况处理

### 情况1：服务器接口失败

```mql5
datetime serverLastTime = GetServerLastSyncTime();
if(serverLastTime == 0 && g_ServerLastSyncTime > 0)
    serverLastTime = g_ServerLastSyncTime; // 使用缓存
```

**行为**：
- 使用本地缓存的最后同步时间
- 下次成功后会更新缓存

---

### 情况2：首次同步

```mql5
if(serverLastTime == 0)
    serverLastTime = TimeCurrent() - 7 * 86400;
```

**行为**：
- 默认从7天前开始同步
- 可根据需要修改天数

---

### 情况3：边界时间重复

**问题**：
- 上次同步到 `10:30:00`
- 如果查询 `>= 10:30:00`，该时间点的订单会被重复上传

**解决**：
```mql5
datetime fromTime = afterTime + 1;  // 加1秒
```

**验证**：
- 订单A：`10:30:00` - 上次已同步
- 订单B：`10:30:01` - 本次会同步
- 订单A不会被重复上传 ✅

---

### 情况4：批量订单同时成交

**场景**：
- 同一秒内有多笔成交（例如 10 笔都是 `10:30:05`）

**处理**：
- `GetLatestDealTime()` 返回 `10:30:05`
- 下次查询从 `10:30:06` 开始
- 所有 `10:30:05` 的订单都会在本批次上传 ✅

---

## 性能对比

### 旧版（队列模式）

| 操作 | 性能 |
|-----|------|
| OnTradeTransaction | 文件写入（每笔） |
| OnTimer | 文件读取 + 网络上传 + 文件删除 |
| 磁盘IO | 高（每笔成交都写文件） |
| 重复上传风险 | 低（队列清空） |

---

### 新版（增量模式）

| 操作 | 性能 |
|-----|------|
| OnTradeTransaction | 无操作 |
| OnTimer | 网络请求（2次）+ HistorySelect |
| 磁盘IO | 无 |
| 重复上传风险 | 无（服务器幂等 + 边界处理） |

**优势**：
- ✅ 减少磁盘IO
- ✅ 无需管理队列文件
- ✅ 服务器端控制同步状态，更可靠
- ✅ 自动去重

---

## 调试日志示例

### 首次启动
```
[Sync] Module initialized. Server last sync time: 1970-01-01 00:00
[Sync] Found 156 deals after 2026-01-11 10:30
[Sync] Successfully synced 156 deals. Latest deal time: 2026-01-18 15:45
```

### 后续同步（有新成交）
```
[Sync] Server last sync time: 2026-01-18 15:45
[Sync] Found 3 deals after 2026-01-18 15:45
[Sync] Successfully synced 3 deals. Latest deal time: 2026-01-18 16:02
```

### 后续同步（无新成交）
```
[Sync] Server last sync time: 2026-01-18 16:02
[Sync] No new deals after 2026-01-18 16:02
```

---

## 验收测试

### 测试用例1：首次同步

**步骤**：
1. 清空服务器 `accounts.last_sync_time`
2. 启动 EA
3. 等待 N 分钟

**预期**：
- 上传最近7天的所有成交
- 服务器 `last_sync_time` 更新为最新成交时间

---

### 测试用例2：增量同步

**步骤**：
1. 已有同步记录（例如 `last_sync_time = 10:30:00`）
2. 下单 3 笔（时间分别为 `10:35:00`, `10:36:00`, `10:37:00`）
3. 等待 N 分钟

**预期**：
- 仅上传这 3 笔新成交
- 服务器 `last_sync_time` 更新为 `10:37:00`

---

### 测试用例3：边界不重复

**步骤**：
1. 已有同步记录（`last_sync_time = 10:30:00`）
2. 该时间点恰好有 1 笔成交
3. 再次同步

**预期**：
- 不会重复上传 `10:30:00` 的订单
- 日志显示 `No new deals after 10:30:00`

---

### 测试用例4：服务器接口失败

**步骤**：
1. 关闭服务器或填写错误 URL
2. 下单 5 笔
3. 恢复服务器
4. 等待 N 分钟

**预期**：
- 使用缓存的 `g_ServerLastSyncTime`
- 恢复后自动上传缺失的成交

---

## 迁移指南

### 从队列模式迁移

**无需用户操作**：
- 队列文件会自动废弃
- 首次同步会从服务器获取 `last_sync_time`
- 如果服务器为空，自动回补 7 天

**注意**：
- 旧版队列文件可手动删除：`MQL5/Files/GSOP_sync_queue_*.jsonl`

---

## 总结

### 核心改进
1. **无队列文件** - 减少磁盘IO
2. **服务器控制** - 同步状态由服务器管理
3. **增量查询** - 只传输新成交
4. **边界严格** - +1秒避免重复

### 服务器端需求
- ✅ 实现 `POST /api/v1/sync/last_sync_time`
- ✅ 修改 `POST /api/v1/ingest/deals` 处理 `last_deal_time`
- ✅ 数据库添加 `accounts.last_sync_time` 字段

### EA 侧完成度
- ✅ GetServerLastSyncTime() 实现
- ✅ CollectDealsAfterTime() 实现
- ✅ GetLatestDealTime() 实现
- ✅ SyncDeals() 重构完成
- ✅ 移除队列文件相关代码
- ✅ 边界处理 (+1秒)
- ✅ 缓存机制

---

**文档版本**：v2.0  
**最后更新**：2026-01-18  
**作者**：Claude Code (Opus 5)
