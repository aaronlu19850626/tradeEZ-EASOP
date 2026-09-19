# TradeEZ-SOP 中枢与边缘剥头皮模型实现原理

> 范围：人工定义现货黄金价格区间，EA负责逐 Tick 信号、订单执行、退出保护和区间失效。本文是后续 MQL5 开发规格，不代表已经写入 `tradeEZ.mq5`。

## 1. 目标和边界

交易员只提供中心点、上下对称距离、点差、每笔手数和区间最大可承受总亏损。EA自动计算区间和全部策略参数，并在区间有效期间执行两类可选模型：

- 中枢动量：价格从中轴区域向一侧加速时顺势入场，在真正边界前完成止盈。
- 边缘回归：价格进入边缘候选带、形成明确反转后逆向入场。该模型频率较低，突破风险更高，默认低优先级。

两类模型共享同一个 `RangeID`。任一真正边界被可成交报价触发后，整个区间永久失效；价格返回区间不能自动恢复。

系统不实现以下行为：

- 不同时市价持有等量多空锁仓。
- 不使用马丁、倍增或亏损补仓。
- 不把每次穿越同一阈值都当成独立机会。
- 不以 K 线收盘代替强边界的 Tick 级判断。
- 不因本地逻辑止损存在而取消服务器灾难保护。

## 2. 基础定义

```text
M = 用户输入的中心点
D = 用户输入的上下距离
L = M - D
U = M + D
W = 2 × D
S = 用户输入的基准点差；实盘使用当前 Ask - Bid 再做门控
Lots = 用户输入的每笔手数
MaxRangeLoss = 用户输入的本区间最大可承受总亏损
```

方向化可平仓利润距离：

```text
多单 profit_distance = current_bid - open_ask
空单 profit_distance = open_bid - current_ask
```

金额近似：

```text
price_pnl_cash = price_distance × contract_size × lots
net_win  = TP_distance × contract_size × lots - commission - slippage_reserve
net_loss = SL_distance × contract_size × lots + commission + slippage_reserve
break_even_win_rate = net_loss / (net_win + net_loss)
```

正式实现应使用 `OrderCalcProfit()` 验证金额，不应假定所有黄金品种均为每手 100 盎司。

## 3. 用户输入与自动参数

HTML和EA界面只保留以下五项用户输入：

| 用户输入 | 示例 | 说明 |
|---|---:|---|
| 中心点 `M` | `4320.50` | 人工判断的区间中点 |
| 上下距离 `D` | `2.00` | 自动得到 `4318.50～4322.50` |
| 基准点差 `S` | `0.15` | 15点且标准点为0.01时填0.15 |
| 每笔手数 | `0.40` | 下单固定手数 |
| 区间总亏损上限 | `$100` | 达到后撤单、全平、锁死 |

其他参数全部自动推导，不暴露给普通用户：

| 参数 | 推荐值 | 含义 |
|---|---:|---|
| 中轴核心半宽 | `5% × W` | 4 美元区间为中轴上下各 0.20 |
| 中枢触发距离 | `max(12.5% × W, 1.5S)` | 避免触发带被点差覆盖 |
| 每侧边缘禁入 | `20% × W` | 进入外侧 0.80 后不再开中枢单 |
| 最大入场点差 | `max(1.35S, S+0.05)` | 自动门控；超过则只管理已有仓位 |
| 逻辑止盈 | `min(max(4S, 22.5%W), 可用边界空间)` | 按可平仓报价计算 |
| 逻辑止损 | `min(max(2S, 16.25%W), 20%W)` | 信号失败退出 |
| 服务器灾难止损 | `逻辑SL + max(S, 7.5%W)` | EA离线时的次级保护 |
| 保本启动 | `67% × TP` | 首次达到后保护阶段永久激活 |
| 保本锁定 | `min(0.10, max(0.05, 11%TP))` | 不保证覆盖全部费用 |
| 初始最长持仓 | `60 + 7.5W` 秒 | 4美元区间为90秒 |
| 同时持仓 | `1` | 两模型共享上限 |

参数必须按品种位数转换。项目约定策略标准点为 `0.01` 价格单位，服务商原生 `_Point` 只用于下单允许偏差、Stops Level 等平台参数。

## 4. 中枢动量模型

### 4.1 区域

```text
core_low  = M - W × core_half_ratio
core_high = M + W × core_half_ratio
sell_trigger = M - W × trigger_ratio
buy_trigger  = M + W × trigger_ratio
lower_no_entry = L + W × edge_no_entry_ratio
upper_no_entry = U - W × edge_no_entry_ratio
```

对于用户输入 `M=4320.50, D=2.00, S=0.15`：

```text
L = 4318.50
U = 4322.50
W = 4.00
核心区 = 4320.30～4320.70
空头触发 = Bid ≤ 4320.00
多头触发 = Ask ≥ 4321.00
中枢单禁入区 = 4318.50～4319.30、4321.70～4322.50
```

### 4.2 重新武装

状态必须记录一次有效的中轴访问。平仓后只有再次访问核心区，才允许下一笔交易。不能因价格在触发线附近反复跳动而重复开仓。

建议使用：

```text
core_visited = true
core_visit_msc = tick.time_msc
```

不建议强制价格连续停留在 0.40 美元宽核心区 1 秒。示例 Tick 数据显示黄金可能在一个报价跳跃中穿过核心区，连续停留条件会把交易数压到零。可以把“到访后等待时间”作为可选防抖参数，而不是固定硬条件。

### 4.3 动量确认

维护最近 500 毫秒或最近 20 个有效报价变化：

```text
net_move = current_mid - oldest_mid_in_window
direction_score = (up_ticks - down_ticks) / changed_ticks
```

推荐条件：

```text
做多：net_move >= +0.15 且 direction_score >= +0.30
做空：net_move <= -0.15 且 direction_score <= -0.30
```

如果报价出现跨阈值跳跃，市价成交必须使用实际 Bid/Ask，不能用理论触发线回填成交价。

### 4.4 入场

```text
BUY  = core_visited && Ask >= buy_trigger  && momentum_up && spread_ok
SELL = core_visited && Bid <= sell_trigger && momentum_down && spread_ok
```

两侧是软件 OCO。一个方向进入 `ENTRY_PENDING` 后，另一方向立即失效，直到请求被核销并重新武装。

## 5. 边缘回归模型

边缘缓冲和候选带：

```text
edge_buffer = max(2 × median_spread, 0.10 × W)
edge_max = min(0.20 × W, 0.75 × TP_distance)
```

只有 `edge_buffer < edge_max` 时才存在有效候选带：

```text
下边缘多单候选带 = [L + edge_buffer, L + edge_max]
上边缘空单候选带 = [U - edge_max, U - edge_buffer]
```

入场不是触价即成交：

```text
下边缘：记录局部最低 Bid，反弹 confirm_distance 后才允许买入
上边缘：记录局部最高 Ask，回落 confirm_distance 后才允许卖出
```

同一次贴边只允许一次候选。价格必须先离开候选带、返回内部重置区，再次进入候选带才是新机会。

边缘模型使用真正边界作为结构失效线，因此必须以较小仓位或更严格的单区间风险预算运行。触碰边界时不再等待反转确认。

## 6. 三层退出体系

### 6.1 逻辑止损

由 EA 每 Tick 判断：

```text
多单：Bid <= actual_open_ask - logic_sl_distance
空单：Ask >= actual_open_bid + logic_sl_distance
```

触发后进入 `EXIT_PENDING(LOGIC_SL)`。

### 6.2 服务器灾难止损

下单后尽快提交服务器 SL：

```text
多单：open_price - emergency_sl_distance
空单：open_price + emergency_sl_distance
```

必须校验 `SYMBOL_TRADE_STOPS_LEVEL` 和 `SYMBOL_TRADE_FREEZE_LEVEL`。若暂时不能设置，保留本地保护并限频重试；界面必须显示“服务器保护未建立”。服务器止损不得比本地逻辑止损更近，否则两层职责倒置。

### 6.3 区间全局熔断

```text
lower_break = Bid <= L
upper_break = Ask >= U
```

执行顺序：

1. 原子地把 Range 状态改为 `RANGE_EXITING`，先阻止新仓。
2. 删除本 RangeID 的全部挂单。
3. 关闭本 RangeID 的全部持仓。
4. 通过 `OnTradeTransaction` 核对撤单、成交和残仓。
5. 全部归零后写入 `RANGE_LOCKED`。

### 6.4 用户总亏损熔断

总亏损是独立于价格边界的第二个区间退出条件：

```text
range_net_pnl = 本 RangeID 已实现净盈亏
              + 本 RangeID 当前未实现浮盈亏
              + 本 RangeID 手续费及交易费用

loss_break = range_net_pnl <= -MaxRangeLoss
```

触发后的处理与价格边界完全相同：先阻止新仓，再撤挂单、平全部持仓，最终进入 `RANGE_LOCKED`。总亏损判断必须优先于新入场；不能等到当前订单自己的 SL 或价格边界才退出。

HTML金额示例可按每手100盎司显示。EA不能写死该值，必须读取品种合约规格，并用 `OrderCalcProfit()` 或账户实际持仓利润计算。手续费以成交历史为准。

## 7. 单票状态机

```text
IDLE
  → ARMED
  → ENTRY_PENDING
  → POSITION_INITIAL
  → POSITION_PROTECTED
  → EXIT_PENDING
  → CLOSED
```

允许转换：

| 当前状态 | 条件 | 下一状态 |
|---|---|---|
| `IDLE` | 有效访问中轴或边缘重置区 | `ARMED` |
| `ARMED` | 信号和全部门控通过 | `ENTRY_PENDING` |
| `ENTRY_PENDING` | 成交核销 | `POSITION_INITIAL` |
| `ENTRY_PENDING` | 拒单或超时 | `IDLE` 或冷却状态 |
| `POSITION_INITIAL` | 浮盈达到保本启动 | `POSITION_PROTECTED` |
| `POSITION_INITIAL` | 逻辑止损或时间止损 | `EXIT_PENDING` |
| `POSITION_PROTECTED` | 保护线、TP或区间熔断 | `EXIT_PENDING` |
| `EXIT_PENDING` | 持仓最终归零 | `CLOSED` |
| `CLOSED` | 再次访问重置区 | `ARMED` |

`POSITION_PROTECTED` 不得退回 `POSITION_INITIAL`。峰值只增不减，保护线只向降低风险方向移动。

## 8. 区间状态机

```text
RANGE_DRAFT
  → RANGE_ACTIVE
  → RANGE_PAUSED
  → RANGE_ACTIVE
  → RANGE_EXITING
  → RANGE_LOCKED
```

含义：

- `DRAFT`：人工参数尚未确认。
- `ACTIVE`：允许产生信号。
- `PAUSED`：点差、权限或行情质量暂时不合格；只管理已有持仓。
- `EXITING`：已触发边界，正在撤单和平仓。
- `LOCKED`：区间永久失效，只能由新的 RangeID 重新开始。

点差恢复可以从 `PAUSED` 返回 `ACTIVE`；真正边界触发不能返回。

## 9. MQL5 数据结构建议

```cpp
enum ENUM_RANGE_PHASE
  {
   RANGE_DRAFT,
   RANGE_ACTIVE,
   RANGE_PAUSED,
   RANGE_EXITING,
   RANGE_LOCKED
  };

enum ENUM_ENTRY_MODEL
  {
   MODEL_CENTER_MOMENTUM,
   MODEL_EDGE_REVERSION
  };

struct RangeContext
  {
   long              range_id;
   double            lower;
   double            upper;
   double            middle;
   ENUM_RANGE_PHASE  phase;
   bool              core_visited;
   long              core_visit_msc;
   long              next_entry_allowed_msc;
   double            max_range_loss;
   double            realized_net_pnl;
   string            lock_reason;
  };

struct SignalSnapshot
  {
   long    time_msc;
   double  bid;
   double  ask;
   double  spread;
   double  net_move_500ms;
   double  direction_score;
   ENUM_ENTRY_MODEL model;
   ENUM_ORDER_TYPE  direction;
  };
```

逐票状态复用现有剥头皮状态机，不应再建立一套互相冲突的峰值和退出账本。

## 10. 事件分工

### `OnTick()`

按固定优先级执行：

1. `SymbolInfoTick()` 获取最新 Bid/Ask 和 `time_msc`。
2. 计算 RangeID 的已实现加未实现净盈亏，判断用户总亏损熔断。
3. 判断价格边界全局熔断。
4. 管理已有持仓的逻辑止损、TP、保本和超时。
5. 更新待处理请求的本地超时，但不在每 Tick 重发。
6. 检查点差、权限、持仓上限和冷却。
7. 更新中轴访问、边缘极值和 Tick 动量窗口。
8. 在 `ARMED` 状态产生至多一个入场请求。

### `OnTradeTransaction()`

- 核销下单、撤单和平仓请求。
- 保存实际成交价和成交量。
- 处理部分成交和残仓。
- 请求失败时保存 retcode，并按节流规则决定是否重试。
- 最后一笔成交完成后推进单票和区间状态。

### `OnTimer()`

- 面板刷新。
- 低频持久化。
- 检查报价是否过期、交易权限和服务器保护缺失。
- 不代替 Tick 级边界判断。

## 11. Tick 数据和性能

`OnTick()` 只是行情变化通知，处理期间到达的新 Tick 可能不会逐个排队。交易路径使用最新 `SymbolInfoTick()`；研究、统计和动量窗口需要用 `CopyTicks()` 从最后游标补取。

热路径禁止：

- 每 Tick 写 CSV。
- 无边界扫描全部历史。
- `Sleep()`。
- 在未核销前重复提交相同请求。

使用固定容量环形缓冲保存最近 1～2 秒 Tick，字段只保留 `time_msc/bid/ask/mid/flags`。

## 12. 参数校验

初始化或启用新区间前必须满足：

```text
D > 0
S > 0
MaxRangeLoss > 0
Lots 符合 SYMBOL_VOLUME_MIN/MAX/STEP
自动计算后 W > 0
自动计算后 TP > 0
自动计算后 logic_SL > 0
自动计算后 emergency_SL >= logic_SL
自动计算后 0 <= BE_lock < BE_trigger < TP
自动计算后 max_hold_seconds > 0
```

若估算的单笔逻辑止损金额已经大于 `MaxRangeLoss`，必须禁止启用该区间并提示用户降低手数或提高可承受总亏损；系统不得擅自修改用户手数。

还应检查中枢目标没有越过边界：

```text
buy_trigger + TP < U
sell_trigger - TP > L
```

若不满足，阻止启用而不是自动篡改人工区间。

## 13. 验收场景

| 编号 | 场景 | 通过标准 |
|---:|---|---|
| CE-01 | 访问核心区后向上加速 | 只产生一笔 BUY 请求，SELL 候选取消 |
| CE-02 | 访问核心区后向下加速 | 只产生一笔 SELL 请求 |
| CE-03 | 触发线附近连续抖动 | 未重新访问核心区前不重复开仓 |
| CE-04 | 入场后立即反向 | 逻辑止损按可平仓报价触发 |
| CE-05 | 达到保本启动后回落 | 阶段不回退，按锁定线退出 |
| CE-06 | 初始阶段超过时间限制 | 进入 `EXIT_PENDING(TIMEOUT)` |
| CE-07 | 点差超限 | 不开新仓，已有仓位继续管理 |
| ED-01 | 下边缘触价但未反弹 | 不买入 |
| ED-02 | 下边缘确认反弹 | 只开一笔多单 |
| ED-03 | 同一次贴边反复抖动 | 不重复入场 |
| ED-04 | 边缘加速突破 | 不反向开仓，立即区间熔断 |
| RG-01 | Bid 触及下沿 | 撤单、全平、最终锁死 |
| RG-02 | Ask 触及上沿 | 撤单、全平、最终锁死 |
| RG-03 | 锁死后价格返回 | 不恢复、不新开仓 |
| RG-04 | 区间累计净亏损达到用户上限 | 撤单、全平、锁死，不等待边界 |
| RG-05 | 单笔估算风险大于总亏损上限 | 禁止启用并明确提示 |
| EX-01 | 平仓请求被拒 | 记录 retcode，节流重试，无请求风暴 |
| EX-02 | 部分成交 | 只管理剩余真实仓位，不重复计算原始手数 |
| RS-01 | EA重启且区间活跃 | 恢复 RangeID、阶段、持仓和保护状态 |
| RS-02 | EA重启且区间锁死 | 保持锁死，不因当前价格在区间内而恢复 |

## 14. 开发顺序

1. 先实现 `RangeContext`、参数校验、区间状态机和持久化。
2. 接入 Tick 环形缓冲与方向化 Bid/Ask 计算。
3. 实现中枢访问、重新武装和单方向软件 OCO。
4. 复用现有逐票剥头皮状态机实现三层退出。
5. 接入统一交易请求账本和 `OnTradeTransaction()` 核销。
6. 最后增加边缘回归模型，并默认关闭。
7. 使用服务商真实 Tick、真实浮动点差和随机执行延迟做专项回测。

中枢模型应先独立通过验收，再允许中枢与边缘模型在同一 RangeID 下共存。两模型不得同时争抢持仓名额；信号仲裁优先级默认为中枢模型高于边缘模型。
