# Gold_SOP_EA 数据同步设置指南 v2.0

## 概述
Gold_SOP_EA 现已集成 **TradeSync-Web 增量数据同步模块**（v2.0），采用服务器端控制的增量同步机制，可将您的 MT5 交易数据准实时同步到云端 Web 平台，实现：
- 📊 每日盈亏查询与净值曲线
- 📈 订单查询与统计（R 倍数口径）
- 🎯 纪律合规引擎（后续版本）
- 📝 复盘与 AI 盘前简报（后续版本）

## ✨ v2.0 新特性（增量同步）

### 什么是增量同步？
- **旧版**：所有成交先写入本地队列文件，定时批量上传，上传后清空队列
- **新版**：每次同步前，EA 先向服务器询问"最后同步到哪笔订单"，然后只上传该时间点之后的新成交

### 优势
- ✅ **无队列文件** - 减少磁盘IO，提升性能
- ✅ **服务器控制** - 同步状态由服务器管理，更可靠
- ✅ **自动去重** - 严格的边界处理，不会重复上传
- ✅ **断线恢复** - 恢复后自动补发缺失成交

## 前置条件

### 1. 在 TradeSync-Web 平台注册账户
1. 访问 TradeSync-Web 平台（部署后的域名）
2. 注册并登录
3. 进入「账户管理」→「绑定 MT5 账户」
4. 系统会生成一个同步密钥（格式：`prefix.secret`）
5. **重要**：密钥只显示一次，请妥善保存

### 2. 配置 MT5 允许网络请求
1. 打开 MT5 客户端
2. 点击「工具」→「选项」→「EA 交易」
3. 找到「允许的 WebRequest URL 列表」
4. 添加您的 API 域名，例如：
   ```
   https://api.yourdomain.com
   ```
5. 点击「确定」保存

## EA 参数配置

### 必填参数
在 EA 的输入参数中，找到「数据同步 Data Sync」部分：

| 参数 | 说明 | 示例值 |
|-----|------|--------|
| `Inp_EnableSync` | **启用同步** | `true` |
| `Inp_ApiBaseURL` | **API 基础地址** | `https://api.yourdomain.com` |
| `Inp_SecretKey` | **账户密钥** | `abc123.xyz789secret` |

### 可选参数

| 参数 | 说明 | 默认值 | 建议 |
|-----|------|--------|------|
| `Inp_SyncIntervalMin` | 常规同步频率（分钟） | 5 | 1-10 分钟 |
| `Inp_AlignIntervalHours` | 哈希校准频率（小时） | 6 | 保持默认 |
| `Inp_RequestTimeoutMS` | HTTP 请求超时（毫秒） | 10000 | 5000-30000 |
| `Inp_MaxBatchSize` | 单批次最大订单数 | 100 | 50-200 |
| `Inp_DebugSync` | 调试模式（详细日志） | false | 首次启用建议 true |

## 验证同步是否正常

### 1. 查看 MT5 日志
启用 `Inp_DebugSync = true` 后，打开「工具箱」→「专家」标签，查看日志：

**首次启动时应看到：**
```
[Sync] Module initialized. Server last sync time: 1970-01-01 00:00
[Sync] Symbol specs synced
[Sync] Server last sync time: ...
[Sync] Found 156 deals after 2026-01-11 10:30
[Sync] Successfully synced 156 deals. Latest deal time: 2026-01-18 15:45
```

**下单后（N 分钟）应看到：**
```
[Sync] Server last sync time: 2026-01-18 15:45
[Sync] Found 3 deals after 2026-01-18 15:45
[Sync] Successfully synced 3 deals. Latest deal time: 2026-01-18 16:02
```

**如果没有新成交：**
```
[Sync] Server last sync time: 2026-01-18 16:02
[Sync] No new deals after 2026-01-18 16:02
```

### 2. ~~检查队列文件~~ (v2.0 已移除)
v2.0 不再使用队列文件，无需检查。

### 3. 检查 Web 平台
登录 TradeSync-Web 平台，查看：
- 「每日盈亏」页面是否有数据
- 「订单查询」页面是否显示最新成交

## 常见问题

### Q1: 日志显示 "WebRequest not allowed"
**A:** 您需要在 MT5「工具→选项→EA 交易→允许的 WebRequest URL」中添加 API 域名。

### Q2: 日志显示 "[Sync] Invalid key format"
**A:** 密钥格式应为 `prefix.secret`（两部分用点分隔），请检查是否完整复制。

### Q3: 日志显示 "[Sync] Failed: 401"
**A:** 密钥无效或已被吊销，请在 Web 平台重新生成密钥。

### Q4: 日志显示 "[Sync] Failed: 429"
**A:** 请求频率过高（超过服务端限速），稍后会自动重试。

### Q5: ~~队列文件一直增大，未被清空~~ (v2.0 已移除)
**A:** v2.0 不再使用队列文件，该问题已不存在。

### Q6: 首次启动后没有历史数据
**A:** 
- EA 会自动从服务器获取最后同步时间
- 如果是全新账户（服务器无记录），会自动回补最近 7 天的成交
- 如需更长时间，请在服务器端手动设置 `accounts.last_sync_time = 0`

### Q7: 担心重复上传同一笔订单
**A:** 
- v2.0 采用严格的边界处理：查询时使用 `last_sync_time + 1 秒`
- 服务器端采用幂等插入：`ON CONFLICT (account_id, ticket) DO NOTHING`
- 不会重复上传 ✅

## 安全提示

1. **密钥安全**：
   - 不要在公共场合泄露密钥
   - 如果怀疑密钥泄露，请在 Web 平台立即吊销并重新生成

2. **数据隐私**：
   - 同步的数据包含您的交易记录、账户余额等敏感信息
   - 确保 Web 平台使用 HTTPS 加密传输
   - 定期检查账户绑定列表，解绑不需要的账户

3. **性能影响**：
   - 同步模块在 OnTimer 中执行，不会阻塞交易线程
   - OnTradeTransaction 只入队，不发网络请求
   - 正常情况下对交易性能无影响

## 技术细节

### 数据同步机制（v2.0 增量模式）
1. **获取同步点**：OnTimer 调用服务器接口 `/api/v1/sync/last_sync_time` 获取最后同步时间
2. **增量查询**：使用 `HistorySelect(lastTime + 1, now)` 查询该时间之后的成交
3. **批量上传**：将成交数组和最新成交时间一起上传到服务器
4. **服务器更新**：服务器幂等插入成交，并更新 `last_sync_time`

### 边界处理
- 查询时加 1 秒：避免重复上传边界时间点的订单
- 例如：上次同步到 `10:30:00`，下次查询从 `10:30:01` 开始
- 服务器端幂等：即使重复上传也不会产生重复记录

### 上传内容
- **成交记录**：ticket, position_id, order_id, symbol, entry, type, volume, price, sl, tp, profit, swap, commission, magic, comment, deal_time
- **品种规格**：name, digits, point, tick_value, contract_size
- **账户快照**（每 30 秒）：balance, equity, margin, free_margin, snapshot_time
- **心跳**（每 5 分钟）：在线状态更新

### 鉴权机制
- 使用 Bearer Token（同步密钥）
- 请求签名：HMAC-SHA256（简化版）
- 时间戳防重放（±5 分钟窗口）

### 服务器端新增接口（v2.0）
- `POST /api/v1/sync/last_sync_time` - 获取最后同步时间
  - 请求：`{"mt5_login": 88973405}`
  - 响应：`{"last_sync_time": 1753082193}`

---

**最后更新**：2026-01-18 (v2.0 增量同步)  
**EA 版本**：v1.03+  
**文档版本**：v2.0
