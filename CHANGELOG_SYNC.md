# Gold_SOP_EA 数据同步模块更新日志

## [2026-01-18] TradeSync-Web 数据同步模块

### ✨ 新增功能
- 集成 TradeSync-Web 数据同步模块
- 支持将 MT5 交易数据准实时同步到云端 Web 平台

### 📦 新增输入参数
```mql5
input group "===== 数据同步 Data Sync ====="
input bool   Inp_EnableSync        = false;                        // 启用订单同步
input string Inp_ApiBaseURL        = "https://api.yourdomain.com"; // API基础地址
input string Inp_SecretKey         = "";                           // 账户密钥(从服务器获取)
input int    Inp_SyncIntervalMin   = 5;                            // 常规同步频率(分钟)
input int    Inp_AlignIntervalHours= 6;                            // 哈希校准频率(小时)
input int    Inp_RequestTimeoutMS  = 10000;                        // HTTP请求超时(毫秒)
input int    Inp_MaxBatchSize      = 100;                          // 单批次最大订单数
input bool   Inp_DebugSync         = false;                        // 调试模式(详细日志)
```

### 🔧 新增函数

#### 核心同步函数
- `AppendDealToQueue(ulong dealTicket)` - 将成交记录追加到队列文件
- `ReadQueueDeals(int maxCount, string &deals[])` - 读取队列中的待上传成交
- `ClearQueueFile()` - 清空队列文件
- `SyncDeals()` - 批量上传成交记录到服务器
- `SyncSymbols()` - 上传品种规格信息
- `SyncSnapshot()` - 上传账户快照（余额、净值、保证金）
- `SyncHeartbeat()` - 发送心跳保持在线状态
- `BackfillHistoryDeals(int daysBack)` - 首次启动时回补历史成交

#### 辅助函数
- `ComputeHMAC(string secret, string body)` - 计算请求签名（简化版 HMAC-SHA256）
- `SyncQueueFile()` - 返回队列文件路径

### 🔄 修改的函数

#### OnInit()
```mql5
// 新增：数据同步初始化
if(Inp_EnableSync && Inp_SecretKey != "")
{
    SyncSymbols();                  // 上传品种规格
    BackfillHistoryDeals(7);        // 回补最近7天历史成交
}
```

#### OnTimer()
```mql5
// 新增：定时同步任务
if(Inp_EnableSync)
{
    // 每 N 分钟同步成交
    if(g_SyncTimerCounter >= Inp_SyncIntervalMin * 60)
        SyncDeals();
    
    // 每 30 秒上传快照
    if(snapshotCounter >= 30)
        SyncSnapshot();
    
    // 每 5 分钟发送心跳
    if(heartbeatCounter >= 300)
        SyncHeartbeat();
}
```

#### OnTradeTransaction()
```mql5
// 新增：成交入队（关键：只入队，不发网络）
if(Inp_EnableSync)
    AppendDealToQueue(trans.deal);
```

### 📁 新增文件
- 队列文件：`MQL5/Files/GSOP_sync_queue_{LOGIN}.jsonl`
- 文档：`SYNC_SETUP_GUIDE.md` - 用户设置指南
- 文档：`DEV_NOTES.md` - 新增"七、数据同步模块"章节

### 🛡️ 安全特性
- 使用 HMAC-SHA256 签名防重放攻击
- 时间戳验证（±5 分钟窗口）
- 密钥格式：`prefix.secret`（只在生成时显示一次）
- 服务端按 `DEAL_TICKET` 幂等去重

### ⚡ 性能保证
- **OnTradeTransaction 不阻塞**：只写本地文件，不发网络请求
- **OnTimer 批量上传**：避免频繁网络请求
- **队列持久化**：断网期间数据不丢失，恢复后自动补发

### 📊 同步内容

#### 1. 成交记录（每笔交易）
```json
{
  "ticket": 1234567890,
  "position_id": 1234567890,
  "order_id": 0,
  "symbol": "GOLD#",
  "entry": 0,           // 0=IN 1=OUT 2=INOUT
  "type": 0,            // 0=BUY 1=SELL
  "volume": 0.30,
  "price": 4061.81,
  "sl_price": 4056.81,
  "tp_price": 0,
  "profit": 0,
  "swap": 0,
  "commission": 0,
  "magic": 920718,
  "comment": "GoldSOP-TR",
  "deal_time": 1753082193
}
```

#### 2. 品种规格（首次启动）
```json
{
  "name": "GOLD#",
  "digits": 2,
  "point": 0.01,
  "tick_value": 1.0,
  "contract_size": 100
}
```

#### 3. 账户快照（每 30 秒）
```json
{
  "balance": 10000.00,
  "equity": 10150.50,
  "margin": 500.00,
  "free_margin": 9650.50,
  "snapshot_time": 1753082193
}
```

#### 4. 心跳（每 5 分钟）
```json
{
  "mt5_login": 88973405
}
```

### 🔗 API 端点

| 端点 | 方法 | 用途 |
|------|------|------|
| `/api/v1/ingest/deals` | POST | 批量上传成交 |
| `/api/v1/ingest/symbols` | POST | 上传品种规格 |
| `/api/v1/ingest/snapshots` | POST | 上传账户快照 |
| `/api/v1/ingest/heartbeat` | POST | 发送心跳 |

所有请求需携带请求头：
- `Authorization: Bearer {prefix.secret}`
- `X-Timestamp: {unix秒}`
- `X-Signature: {HMAC-SHA256签名}`

### ⚠️ 已知限制
1. **HMAC 签名为简化版**：使用 `SHA256(secret + body)`，生产环境建议标准 HMAC-SHA256
2. **JSON 构造未严格转义**：`comment` 中包含双引号可能导致格式错误
3. **队列文件无大小限制**：长期断网可能积压过多（未来版本会优化）
4. **无自动重连逻辑**：依赖定时器周期性重试

### 📝 使用前提
1. 在 TradeSync-Web 平台注册账户并生成同步密钥
2. 在 MT5「工具→选项→EA 交易→允许的 WebRequest URL」中添加 API 域名
3. 配置 EA 参数：`Inp_EnableSync=true`、`Inp_ApiBaseURL`、`Inp_SecretKey`

### 🧪 测试建议
1. 首次启用时设置 `Inp_DebugSync=true`
2. 下单后检查日志：`[Sync] Deal xxx queued`
3. 等待 N 分钟后检查日志：`[Sync] Successfully synced x deals`
4. 在 Web 平台查看数据是否同步

### 📚 相关文档
- 产品需求：`TradeSync-Web/docs/PRD.md`
- 技术设计：`TradeSync-Web/docs/DESIGN.md`
- 数据库设计：`TradeSync-Web/docs/DATABASE.md`
- 部署手册：`TradeSync-Web/docs/DEPLOYMENT.md`

### 🔮 后续计划
- P1: 标准 HMAC-SHA256 签名
- P1: JSON 严格转义
- P1: 队列文件大小限制与自动清理
- P2: 断线重连逻辑与指数退避
- P2: 增量同步优化（服务端返回 `server_max_ticket`，EA 只推送更新的成交）

---

**代码行数**：+392 行
**修改文件**：Gold_SOP_EA.mq5
**新增文件**：SYNC_SETUP_GUIDE.md, CHANGELOG_SYNC.md
**更新文件**：DEV_NOTES.md
