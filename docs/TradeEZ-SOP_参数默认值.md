# TradeEZ-SOP 参数默认值

基于 `tradeEZ.mq5` v1.03，源码最后修改时间 2026-09-18 15:25（北京时间）。以下为源码声明值，并非当前图表实际输入值；已有模板、预设文件及手动修改均可能覆盖默认值。

策略标准点固定按 0.01 价格单位换算；滑点例外使用品种原生报价点。金额通常是账户货币，界面美元符号不执行汇率转换。注释只用于识别参数，真实行为以操作手册和功能分析为准。

## 基础

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_Magic` | `920716` | EA 基础魔术号 | 基础编号；两套策略实际归属使用各自魔术号。 |
| `Inp_MagicScalp` | `920717` | 剥头皮魔术号 | — |
| `Inp_MagicTrend` | `920718` | 趋势魔术号 | — |
| `Inp_CommentScalp` | `"TradeEZ-SC"` | 剥头皮订单备注 | — |
| `Inp_CommentTrend` | `"TradeEZ-TR"` | 趋势订单备注 | — |
| `Inp_Slippage` | `30` | 滑点(点) | 原生报价点（_Point），不同于策略的标准点。 |
| `Inp_LotsTolerance` | `0.001` | 手数匹配容差(备用) | 备用参数，不应视作有效的风控开关。 |
| `Inp_RefreshSeconds` | `1` | 面板刷新间隔(秒) | 也是定时器步长；同步周期用累计步长计数，不是严格墙钟时间。 |
| `Inp_DefaultChinese` | `true` | 默认中文 | — |

## 界面适配(高DPI屏幕)

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_UIScale` | `1.00` | 全局UI缩放系数(高DPI填Windows缩放:150%=1.5) | — |

## 交易时段

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_UseSession` | `true` | 启用时段门控(仅显示则关闭) | — |
| `Inp_SessionStartHour` | `6` | 时段开始(时) | — |
| `Inp_SessionEndHour` | `5` | 时段结束(时) | — |

## 每日初始化

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_ResetHour` | `4` | 每日重置-时(北京时间) | — |
| `Inp_ResetMinute` | `50` | 每日重置-分 | — |
| `Inp_ExportOnReset` | `true` | 重置前导出当日统计到本地 | — |

## 目标与回撤(核心)

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_DailyMaxDrawdown` | `500.0` | 日最大回撤 ★核心 | 实际按当日净亏损阈值判断，不是峰值回撤。 |
| `Inp_DailyProfitTarget` | `1000.0` | 日盈利目标 | — |
| `Inp_ScalpDrawdownRatio` | `70.0` | 剥头皮占比% | — |
| `Inp_TrendDrawdownRatio` | `30.0` | 趋势占比% | — |

## 周目标计划

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_WeeklyProfitTarget` | `4000.0` | 周盈利目标(面板显示) | — |
| `Inp_WeeklyPlan1_Level` | `2000.0` | 周盈档1触发($) | 相关提示函数未接入当前主要流程；不会自动调整日回撤。 |
| `Inp_WeeklyPlan1_DD` | `600.0` | 周盈档1建议日回撤($) | 相关提示函数未接入当前主要流程；不会自动调整日回撤。 |
| `Inp_WeeklyPlan2_Level` | `3000.0` | 周盈档2触发($) | 相关提示函数未接入当前主要流程；不会自动调整日回撤。 |
| `Inp_WeeklyPlan2_DD` | `800.0` | 周盈档2建议日回撤($) | 相关提示函数未接入当前主要流程；不会自动调整日回撤。 |
| `Inp_WeeklyPlan3_Level` | `3500.0` | 周盈档3触发($,建议降频/休息) | 相关提示函数未接入当前主要流程；不会自动调整日回撤。 |

## 剥头皮

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_ScalpLots` | `0.4` | 剥头皮手数 | — |
| `Inp_ScalpMaxPositions` | `1` | 最大持仓 | 只统计当前持仓，不预留挂单名额。 |
| `Inp_ScalpSL_Points` | `350` | 止损(标准点,1点=0.01) | — |
| `Inp_ScalpTP_Points` | `500` | 止盈(标准点) | — |
| `Inp_ScalpBETrigger` | `300` | 峰值追踪触发(标准点) | — |
| `Inp_ScalpTrailStep` | `150` | 峰值回撤点数(标准点) | — |
| `Inp_ScalpTimeLimitOn` | `false` | 启用剥头皮超时强平 | — |
| `Inp_ScalpMaxHoldSecs` | `120` | 超时强平秒数 | — |

## 趋势(SOP 追踪版)

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_TrendLots` | `0.25` | 趋势手数 | — |
| `Inp_TrendMaxPositions` | `1` | 最大持仓 | 只统计当前持仓，不预留挂单名额。 |
| `Inp_TrendSL_Points` | `500` | 初始止损(标准点,1点=0.01) | — |
| `Inp_TrendBE1_Trigger` | `300` | 移成本价(标准点) | — |
| `Inp_TrendBE2_Trigger` | `500` | 移+2点触发(标准点) | — |
| `Inp_TrendBE2_Lock` | `200` | 第2档锁定(标准点) | — |
| `Inp_TrendBE3_Trigger` | `800` | 移+5点+减仓触发(标准点) | — |
| `Inp_TrendBE3_Lock` | `500` | 第3档锁定(标准点) | — |
| `Inp_TrendReducePercent` | `50.0` | 减仓比例% | — |
| `Inp_TrendTrailTrigger` | `1000` | 进入追踪(标准点) | — |
| `Inp_TrendTrailStep` | `350` | 最高点回撤(标准点)出局 | — |

## 界面

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_ShowResetBtn` | `false` | 显示重置按钮 | 默认 false，截图中显示按钮不代表默认值。 |

## 风控开关

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_ConsecutiveSLWarning` | `2` | 连续止损提醒阈值 | 当前未发现实际调用。 |
| `Inp_ConsecLossLimit` | `3` | 连续亏损熔断阈值(笔) | — |
| `Inp_CooldownMinutes` | `10` | 连续亏损熔断冷却(分钟) | — |
| `Inp_EnableCircuitBreaker` | `true` | 启用熔断 | — |
| `Inp_AlertOnBreaker` | `true` | 熔断弹窗 | — |

## 利润护城河

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_EnableProfitProtect` | `true` | — | — |
| `Inp_ProfitProtect1_Trigger` | `500.0` | 第1档触发($) | — |
| `Inp_ProfitProtect1_Percent` | `300.0` | 第1档最大回撤% | 源码按百分比计算：300 表示 300%，不是 30% 或 300 美元。 |
| `Inp_ProfitProtect2_Trigger` | `800.0` | 第2档触发($) | — |
| `Inp_ProfitProtect2_Amount` | `500.0` | 第2档最多回撤$ | — |
| `Inp_ProfitLiquidation` | `1000.0` | 清盘触发($) | 达到该盈利值本身只锁定开仓；护城河回撤条件满足才发起全平。 |
| `Inp_ProfitShutdown` | `2000.0` | 强制停止($) | — |

## 数据同步 Data Sync

| 参数 | 默认值 | 源码说明 | 使用注意 |
|---|---|---|---|
| `Inp_EnableSync` | `false` | 启用订单同步 | — |
| `Inp_ApiBaseURL` | `"https://api.tradeez.cn"` | API基础地址 | — |
| `Inp_SecretKey` | `""` | 账户密钥(从服务器获取) | 敏感凭据，不要公开。 |
| `Inp_SyncIntervalMin` | `5` | 常规同步频率(分钟) | — |
| `Inp_AlignIntervalHours` | `6` | 哈希校准频率(小时) | 当前未发现实际哈希校准任务。 |
| `Inp_RequestTimeoutMS` | `800` | HTTP请求超时(毫秒,界面防卡上限800ms) | 请求实际限制见源码；单轮含多次同步请求，不能把此值视为整轮耗时上限。 |
| `Inp_MaxBatchSize` | `100` | 单批次最大订单数 | — |
| `Inp_DebugSync` | `true` | 调试模式(逐步输出专家日志) | — |

共 66 项输入参数。返回[操作手册](TradeEZ-SOP_操作手册.md)。

