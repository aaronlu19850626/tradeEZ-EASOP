# Gold_SOP_EA 开发笔记

> 本文件是给"下一个会话/下一个开发者"看的**权威事实来源**。
> 会话记忆会丢，代码会被误记，但这份文档跟着 EA 走。
> **改代码前先读它，做判断前先核对代码，不要凭印象。**

最后更新：2026-07-18

---

## 一、防幻觉工作约定（重要）

1. **改任何逻辑前，先用工具读对应函数的真实代码**，不要靠记忆或本文件的描述直接下结论。本文件描述的是"设计意图"，真实行为以 `Gold_SOP_EA.mq5` 为准。
2. **一次只改一个明确的点**，改完立即在 MetaEditor 里 F7 编译验证，再进行下一处。
3. **关键数字必须对账**：拿面板真实显示值和账户真实余额核对，而不是听描述判断对错。
4. 会话变长（接近上下文上限、出现 `429 prompt is too long`）就**重开新会话**，新会话第一步读本文件接上下文。

---

## 二、余额基准的核心设计（曾经的 bug 根源）

### 症状（已修复）
重启 / 跨会话重载后，面板出现矛盾：**今日盈亏 0、无浮动，但"今日初始金额" ≠ 当前余额**。
动态回撤基准/阈值都依赖 `g_InitBalance`，所以连带全错。

### 根因
`g_InitBalance` / `g_PeakBalance` 曾被持久化并在 `LoadState()` 里用旧存档值直接沿用，
而不是按当前状态重算 → 旧初始金额污染了显示和风控。

### 修复原则（当前实现）
`g_InitBalance` 与 `g_PeakBalance` 是**自愈的、不跨档持久化**的值：

- **不写入存档**：`SaveState()` / `LoadState()` 都**不**碰这两个变量（见 `Gold_SOP_EA.mq5:2520` 与 `:2538` 的注释）。
- **每次 `OnInit` 无条件重算**（`Gold_SOP_EA.mq5:2637-2638`）：
  ```
  g_InitBalance = 当前余额 - AllRealizedPL();          // 今日起点余额
  g_PeakBalance = max(g_InitBalance, 当前余额);
  ```
  含义：**今日起点余额 = 当前余额 − 今日已实现盈亏**。无论全新启动、切周期、还是过了重置点重载，算出来都对。

### 什么才跨档持久化
只有**纪律类状态**才存档恢复（`SaveState`/`LoadState`，`Gold_SOP_EA.mq5:2513-2544`）：
`StatDay`(统计日戳)、`ResetTime`、`Cooldown`(连亏冷却)、`ConsecLoss`(连亏计数)、`LastDeal`、以及各类高水位
(`TodayHi/ScalpHi/TrendHi/GlobalHi` 及其 `*Init` 标志)。
存档带 `StatDay` 校验：**存档不属于当前统计日就丢弃**（`Gold_SOP_EA.mq5:2532`，跨日不恢复）。

---

## 三、每日重置 / 跨日翻转

- 重置点由 `Inp_ResetHour` / `Inp_ResetMinute` 决定，默认 **北京时间 4:30**（`TodayStart()`，`Gold_SOP_EA.mq5:326`，北京基准换算回服务器 epoch）。
- `CheckDayRollover()`（`Gold_SOP_EA.mq5:1059`）每 tick 由 `OnTick` 调用（`:2684`），也在 `OnInit` 走到 `CheckAllRiskControl` 前对齐过。
- 跨过重置点（`g_DayStart != TodayStart()`）时自动触发一次归零：
  - 先 `ExportDailyReport()` 导出**即将结束**那天的日报（首次 `g_DayStart==0` 跳过）。
  - 清零当日封锁/高水位/连亏/冷却，`g_LastDealTime` 重置到当日起点。
  - **余额基准归位到当前余额**：`g_InitBalance = 当前余额`，`g_PeakBalance = g_InitBalance`（`:1086-1087`）。
    注意：这里跟 `OnInit` 的"当前余额−已实现"算法不同——因为跨日瞬间当日已实现盈亏应为 0，两者等价。

> "过了初始化时间要执行一次"指的就是这个：跨过 4:30 时 `CheckDayRollover()` 自动触发一次重置。
> 之前看起来"没执行"，其实是执行了但初始金额被旧存档污染，显示成了错的。修复后就正确刷新了。

---

## 四、手动重置（面板按钮）

`ResetBtn` 处理逻辑（`Gold_SOP_EA.mq5:2830` 附近）：
用户当天中途手动重置时，`g_InitBalance = 当前余额`（把此刻当作新起点），随后 `SaveState()` 立即持久化纪律状态。
这与自动跨日重置行为一致，是"用户主动重设基线"的正确语义。

---

## 五、面板对账口径（验收用）

1. **今日初始金额** 应 = 当前余额 − 今日已实现盈亏（无盈亏时等于当前余额）。
2. **动态回撤基准**（`DrawdownBase()`，`Gold_SOP_EA.mq5:1372`）口径**必须与 `CheckProfitProtection` 真实触发一致**（2026-07-21 修）：
   - 未达档：初始金额 − 日最大回撤。
   - 第1档（高水位 ≥ Trigger1）：初始金额 + 高水位×(1−回撤%)。
   - 第2档（高水位 ≥ Trigger2）：初始金额 + (高水位 − 最多回撤额)。
   - **关键**：用**真实高水位 `g_TodayHighProfit`** 算，不是用档位触发额。旧版用触发额算 → 面板显示"还剩缓冲"但实际已熔断，口径矛盾（曾经的 bug）。
3. **动态回撤阈值** = 当前净值 − 基准。**阈值 ≤ 0 即已触及/跌破基准（红）**，> 0 有缓冲（蓝）。跌破 0 应正好对应护城河"利润护城河-回撤保护"触发。

若面板任一数字对不上账，把各字段真实数值发出来逐项核对，不要只凭描述改。

---

## 五点五、休市判定（`IsMarketClosed()`，曾经的 bug 根源）

- **休市 ≠ 休息**：休息(非时段)是本策略人为设的激活时段(`InSession`)；休市是券商侧根本不接单(周末/节假日/盘间)。
- **判定入口**：`IsMarketClosed()`（`InSession()` 之后）。休市时：① 标题栏北京时间右侧显示红色小字"休市"；② 策略状态显示"休市 (禁开)"(优先级：熔断 > 休市 > 满仓 > 休息)；③ `ValidateOpenConditions()` 最前面拦截，直接拒单，无法建仓。
- **踩过的坑**：最初用 `TimeCurrent()` 取当前时间判时段 → **完全无效**。因为 `TimeCurrent()` 是"最后一个 tick 的服务器时间"，休市时它冻结在收盘时刻(如周五 20:xx)，`day_of_week`/时刻被判成落在上一交易日的交易时段内 → 永远判不出休市。
- **正确做法**：用 `TimeTradeServer()`(持续前进的当前服务器时间)判时段；再加"报价静默 >300s"兜底(`TimeTradeServer()-TimeCurrent()`，同为服务器时基，差值即静默秒数)，对时段表异常的券商也稳。

---

## 五点六、剥头皮超时强平倒计时遮罩

- **后台逻辑**（一直都有，别误以为没实现）：剥头皮持仓超 `Inp_ScalpMaxHoldSecs`(默认120s) 未止盈/止损则强平（`Gold_SOP_EA.mq5:809` 附近）；用户可点"取消平仓"把该 ticket 加入取消名单不再强平。
- **遮罩显示**：`RenderScalpCountdown()`，由 `RenderPerfectUI()` 每次调用（`Inp_ScalpTimeLimitOn` 开关）。独立浮层，挂在主面板右侧（`cx = StartX + PanelWidth + 12`）。
- **触发口径（已改）**：遮罩**只在剩余 ≤ `SCALP_CD_POPUP_SECS`(30s) 时才弹出**，刚下单不打扰。收集阶段就过滤掉"已取消倒计时"和"还没进最后30秒"的单，都没有就整个不显示。之前是一有剥头皮持仓就弹，用户觉得"一下单就强制挡画面"。
- **注意**：函数注释写"主面板正下方"，实际放在右侧；改位置时以代码 `cx/cy` 为准。

---

## 五点七、成交的策略归属（手工平仓统计归类，曾经的 bug 根源）

- **口径**：所有日内统计按**平仓成交**归日、按**策略**分类。分类只认 magic，不认注释（注释区分不了"用户手动开(magic=0)"和"EA开手工平"）。
- **踩过的坑**：分类曾用平仓成交自身的 `DEAL_MAGIC`(`DealType()`)。用户在 MT5 界面**手工平仓**时,平仓成交 `DEAL_MAGIC=0` → EA 开的趋势/剥头皮单被误判成手动单,脱离原策略统计(现象:0.3手趋势单没进趋势净额,只进了"规则外手动")。
- **真根因(第三次才找到)**:全局 `g_trade`(CTrade)的 magic **粘连**。开剥头皮单时 `SetExpertMagicNumber(剥头皮magic)`(`:1508`),此后该对象一直是剥头皮magic;之后 `PositionClose()` 平**任何**单(含趋势单)时,平仓成交都盖上剥头皮magic。故**平仓成交的 magic 完全不可信**——趋势单的 -4.80 被误算进剥头皮(现象:分策略拆解 剥头皮含了它、趋势仍 0)。
- **修复**：`DealStrategyType()`(`Gold_SOP_EA.mq5:298` 附近)改成**以「开仓成交」为准**:① 按 `DEAL_POSITION_ID` 回溯到开仓成交(`DEAL_ENTRY_IN`),用其 magic(开单那刻显式设置,永远正确),再退用其注释;② 仅当开仓成交不在选择区间(跨日单)时,才用平仓成交自身注释兜底。**绝不用平仓成交的 magic**。
- **手动单不会误算**:用户手动开的单开仓成交 magic=0 且注释空 → IGNORE,仍归"规则外手动"(如那笔 68.10)。前提:手动下单别在注释里手打 `GoldSOP-*`。
- **可选的更彻底修法(未做)**:在每个 `PositionClose()` 前按被平持仓重设 `g_trade` magic,消除粘连,让平仓成交 magic 也正确。当前分类已不依赖它,未改以降风险。
- **已替换的调用点**：`RealizedPL` / `ComputeDailyStats` / `ExportDailyReport` / 明细舱行(`HistorySelect` 区间内遍历,原 `DealType(dt)` → `DealStrategyType(dt)`)。`PosType()`(持仓,非成交)不受影响,持仓的 `POSITION_MAGIC` 一直正确。
- **已知边界**：回溯只在外层已选的 `HistorySelect` 区间内找开仓成交,不重新 select(避免破坏外层遍历)。**跨重置点(4:30)开、今日手工平的单**,开仓成交在区间外 → 回溯失败仍归 IGNORE。EA 自平的跨日单不受影响(magic 命中)。如需覆盖,放宽回溯取数区间。

---

## 五点八、明细舱（RenderHistoryCabin）

- **三个入口**（都在 `OnChartEvent` 里）：
  - 点账户核心"**今日实现盈亏 🔍**"(`C1_Real_Left/Right`) → `g_DetailAll=true`,显示今日**全部**平仓单(剥头皮+趋势+手动)。
  - 点剥头皮/趋势卡片"今日胜负平统计 🔍"(`Sc_Orders_*`/`Tr_Orders_*`) → `g_DetailAll=false`,只显示该策略。切策略时务必同时置 `g_DetailAll=false`。
- **列**(`ClosedRow` 结构 `:219`)：成交时间 | 策略(剥头皮/趋势/手动) | 方向 | 手数(`DEAL_VOLUME`) | 开仓价→平仓价 | 持时 | 盈亏。舱宽 `cabW=510`。
- **数据源**：`BuildClosedRows(kind)`,按 `StatStart()` 起、`DealStrategyType()` 分类(见五点七);全部模式 `g_DetailAll` 跳过 `dk!=kind` 过滤。策略标签也来自 `DealStrategyType`,所以手动单(magic0/注释空)会显示"手动"。

---

## 五点九、护城河回撤保护强平（2026-07-21 加）

- **需求**：动态回撤阈值还剩一点（哪怕不够一次止损）仍**允许开仓**；一旦**阈值触及 0 就强平**本品种全部持仓，并**当日锁定不再开**。
- **等价关系**：面板"动态回撤阈值 ≤ 0" ⟺ 护城河"回撤保护"触发条件 `drawFromHi >= 允许回撤`（已数学验证，见五点五之后的对账口径）。所以"阈值触及0强平"实现为"回撤保护触发时强平"。
- **开仓侧不变**：只在 `g_TotalBlocked`(阈值≤0) 时禁开；阈值 >0 一律允许，不做"够不够一次止损"的预判拦截。符合需求第一句。
- **强平实现**：
  - `CheckProfitProtection()` 触发回撤保护(两档任一)时置 `g_MoatDrawHit=true`(每tick先清零重算)。
  - `CheckAllRiskControl()` 两个调用点后都调 `EnforceMoatLiquidation()`(`Gold_SOP_EA.mq5` 搜该名)：首次 `g_MoatDrawHit` → `CloseAllOrders()`(本品种全部持仓+挂单,含手动单,与护城河全局口径一致) + 置 `g_MoatLiquidated=true` + 锁 `g_TotalBlocked`。已锁定则只保持禁开、**不重复平仓**(guard 防每tick反复平/防重载重平)。
  - `g_MoatLiquidated` **持久化**(`SaveState`/`LoadState`,带 StatDay 校验,跨日不恢复);**跨日重置**(`CheckDayRollover`)和**手动重置按钮**都清零 → 当日锁定、次日(北京4:30)自愈。
- **口径**：护城河用 `GlobalNetPL`(已实现+浮动+手动单)。强平是**净值口径硬止损**,在老仓扛到各自止损跌破保底线前先平掉。
- **边界**：强平后用户手动再开的单,EA 不会自动平(guard 已锁,不重复动作)——锁的是"再开",手动覆盖是用户责任。

---

## 六、关键符号速查（行号随改动会漂，用作起点，读前先 Grep 确认）

| 符号 / 函数 | 作用 | 大致位置 |
|---|---|---|
| `g_InitBalance` / `g_PeakBalance` | 今日初始金额 / 期间峰值（自愈，不持久化） | 定义 `:179-180` |
| `OnInit()` | 重算余额基准 + 恢复纪律状态 | `:2616` |
| `SaveState()` / `LoadState()` | 纪律状态持久化（不含余额基准） | `:2513` / `:2528` |
| `CheckDayRollover()` | 跨 4:30 自动归零 + 导出日报 | `:1059` |
| `TodayStart()` | 当日统计起点（北京 4:30 → 服务器 epoch） | `:326` |
| `AllRealizedPL()` | 今日已实现盈亏合计 | `:464` |
| `ResetBtn` 手动重置 | 用户中途重设基线 | `:2830` 附近 |

---

## 七、数据同步模块 (TradeSync-Web，2026-01-18 新增)

### 功能概述
EA 现已集成 TradeSync-Web 同步模块，可将 MT5 原始成交数据、账户快照、品种规格准实时推送到云端 Web SaaS 平台。

### 核心设计原则（严格遵守 DESIGN.md 要求）
1. **OnTradeTransaction 只入队，不发网络**：避免 WebRequest 阻塞交易线程
2. **OnTimer 批量 flush**：每 N 分钟批量上传队列中的成交
3. **队列文件**：使用 JSONL 格式持久化未确认成交
4. **幂等上传**：服务端按 DEAL_TICKET 去重，支持断线补发
5. **HMAC 签名**：防重放攻击（简化版，生产环境需标准 HMAC）

### 输入参数
- `Inp_EnableSync`：启用/禁用同步（默认 false）
- `Inp_ApiBaseURL`：API 基础地址
- `Inp_SecretKey`：账户密钥（格式：prefix.secret，从 Web 平台获取）
- `Inp_SyncIntervalMin`：常规同步频率（分钟，默认 5）
- `Inp_RequestTimeoutMS`：HTTP 请求超时（毫秒）
- `Inp_MaxBatchSize`：单批次最大订单数（默认 100）
- `Inp_DebugSync`：调试模式（详细日志）

### 同步内容
1. **成交记录** (POST /api/v1/ingest/deals)：
   - 每次成交自动入队（OnTradeTransaction）
   - 每 N 分钟批量上传（OnTimer）
   - 包含：ticket, position_id, symbol, entry, type, volume, price, sl, tp, profit, swap, commission, magic, comment, deal_time

2. **品种规格** (POST /api/v1/ingest/symbols)：
   - OnInit 时自动上传一次
   - 包含：name, digits, point, tick_value, contract_size

3. **账户快照** (POST /api/v1/ingest/snapshots)：
   - 每 30 秒上传一次（净值曲线）
   - 包含：balance, equity, margin, free_margin, snapshot_time

4. **心跳** (POST /api/v1/ingest/heartbeat)：
   - 每 5 分钟发送一次（更新在线状态）

### 首次启动
- OnInit 会自动回补最近 7 天的历史成交（可调整）
- 确保 MT5「工具→选项→EA交易→允许的 WebRequest URL」已添加 API 域名

### 队列文件
- 路径：`MQL5/Files/GSOP_sync_queue_{LOGIN}.jsonl`
- 格式：每行一个 JSON 对象
- 上传成功后自动清空

### 错误处理
- 网络失败：保留队列，下次 Timer 重试
- 401 无效密钥：日志提示，停止上传
- 429 限速：按服务端指示退避

### 已知边界
- HMAC 签名为简化版（SHA256(secret+body)），生产环境建议标准 HMAC-SHA256
- JSON 构造未做严格转义，comment 中包含引号可能导致格式错误
- 队列文件无大小限制，长期断网可能积压过多
- 无自动重连逻辑，依赖定时器周期性重试

### 验证方法
1. 启用 `Inp_DebugSync = true`
2. 下单后查看 Experts 日志：`[Sync] Deal xxx queued`
3. 等待 N 分钟后查看：`[Sync] Successfully synced x deals`
4. 检查队列文件是否已清空

### 关键函数
| 函数 | 作用 | 位置 |
|---|---|---|
| `AppendDealToQueue()` | 成交入队（OnTradeTransaction 调用） | ~3146 |
| `SyncDeals()` | 批量上传成交（OnTimer 调用） | ~3224 |
| `SyncSymbols()` | 上传品种规格（OnInit 调用） | ~3294 |
| `SyncSnapshot()` | 上传账户快照（OnTimer 调用） | ~3330 |
| `SyncHeartbeat()` | 发送心跳（OnTimer 调用） | ~3362 |
| `BackfillHistoryDeals()` | 回补历史成交（OnInit 调用） | ~3433 |


---

## 七点一、数据同步模块更新 (2026-01-18 增量同步版本)

### 重要变更：从队列模式改为增量同步模式

**原因**：用户要求实现真正的增量同步，避免重复上传已同步的成交。

### 新增 API 端点
- POST /api/v1/sync/last_sync_time - 获取服务器端该账户的最后同步时间

### 核心逻辑变更

#### 1. 同步流程（SyncDeals）
`
旧版：读取队列文件 → 批量上传 → 清空队列
新版：获取服务器最后同步时间 → 查询该时间之后的成交 → 上传并告知最新成交时间
`

#### 2. 关键函数
- **GetServerLastSyncTime()** - 调用服务器接口获取最后同步时间
- **CollectDealsAfterTime(afterTime)** - 收集指定时间之后的所有成交（加1秒避免边界重复）
- **GetLatestDealTime(dealsJson[])** - 从成交数组中提取最新的成交时间

#### 3. 边界处理
- 查询时使用 fterTime + 1 秒，避免重复上传边界时间点的订单
- 上传时在请求体中添加 last_deal_time 字段，服务器用它更新最后同步时间
- 首次同步（服务器返回0）时，默认从7天前开始

#### 4. 缓存机制
- g_ServerLastSyncTime 全局变量缓存服务器最后同步时间
- 避免每次同步都调用服务器接口（仅在网络失败时使用缓存）

### 移除的内容
- ❌ 队列文件 GSOP_sync_queue_{LOGIN}.jsonl
- ❌ AppendDealToQueue() 函数
- ❌ ReadQueueDeals() 函数
- ❌ ClearQueueFile() 函数
- ❌ BackfillHistoryDeals() 函数
- ❌ OnTradeTransaction 中的入队逻辑

### 新增内容
- ✅ GetServerLastSyncTime() - 获取服务器最后同步时间
- ✅ CollectDealsAfterTime() - 增量收集成交
- ✅ GetLatestDealTime() - 提取最新成交时间
- ✅ g_ServerLastSyncTime - 服务器时间缓存

### 请求/响应格式

#### 获取最后同步时间
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

#### 上传成交（新增 last_deal_time 字段）
**请求**：
```json
POST /api/v1/ingest/deals
{
  "mt5_login": 88973405,
  "server_gmt_off": 10800,
  "last_deal_time": 1753082193,
  "deals": [...]
}
```

**服务器行为**：
1. 按 DEAL_TICKET 幂等插入成交（ON CONFLICT DO NOTHING）
2. 更新账户的 last_sync_time = last_deal_time

### 验证方法
1. 启用 Inp_DebugSync = true
2. 首次启动查看：[Sync] Server last sync time: ...
3. 下单后等待 N 分钟查看：[Sync] Found X deals after ...
4. 上传成功后查看：[Sync] Successfully synced X deals. Latest deal time: ...
5. 再次同步应该看到：[Sync] No new deals after ...

### 优势
- ✅ 无需本地队列文件，减少文件操作
- ✅ 服务器端控制同步状态，更可靠
- ✅ 自动去重，不会重复上传
- ✅ 边界处理严格（+1秒），避免遗漏或重复

### 注意事项
- 服务器端必须实现 /api/v1/sync/last_sync_time 接口
- 服务器端 /api/v1/ingest/deals 必须处理 last_deal_time 字段并更新同步时间
- 如果服务器接口失败，会使用缓存的 g_ServerLastSyncTime
- 首次同步（服务器返回0）默认从7天前开始，可根据需要调整

