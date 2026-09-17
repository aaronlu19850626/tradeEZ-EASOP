# Gold SOP 分控 EA — 精简需求文档 V1

> 基于《Gold SOP EA 开发需求文档 V2.1》与《交易回撤控制 SOP》精简而成。
> 精简原则:保留全部核心风控能力,收敛表达与档位口径,去掉次数熔断,触发时只禁开新仓。

## 版本信息


| 项目        | 内容                                                                  |
| ----------- | --------------------------------------------------------------------- |
| 文档版本    | 精简 V1                                                               |
| 日期        | 2026/07/17                                                            |
| EA 名称     | Gold_SOP_EA.mq5                                                       |
| 平台 / 品种 | MetaTrader 5 / 现货黄金 XAUUSD                                        |
| 定位        | **辅助型分控 EA**(手动/一键开仓 + 自动风控与移动止损),非全自动信号 EA |

---

## 一、设计原则(6 条)

1. **手数决定策略**:0.5 手 = 剥头皮,0.3 手 = 趋势单,其他手数完全忽略。
2. **策略隔离**:两类策略各自独立风控,互不影响。
3. **持仓限制**:每类策略同时最多 1 单。
4. **比例联动**:用户只设【日最大回撤】,系统按比例自动拆出各策略熔断线。
5. **触发只禁开**:熔断/护城河触发时,仅禁止开新仓 + 面板告警,**不强平已有持仓**(交给移动止损自然了结)。
6. **全量参数化**:所有关键档位均为 input 参数。

---

## 二、订单识别(纯手数)


| 手数   | 类型     | 处理           |
| ------ | -------- | -------------- |
| 0.5 手 | 剥头皮   | 应用剥头皮规则 |
| 0.3 手 | 趋势单   | 应用趋势规则   |
| 其他   | 非系统单 | **完全忽略**   |

- 用容差 `Inp_LotsTolerance` 做浮点匹配(如 0.4999→剥头皮)。
- 不使用 Magic Number。任何 0.5/0.3 手订单(含手动下单)都会被接管。

---

## 三、持仓限制


| 策略   | 最大持仓 | 超限处理            |
| ------ | -------- | ------------------- |
| 剥头皮 | 1 单     | 禁止开新仓,面板告警 |
| 趋势单 | 1 单     | 禁止开新仓,面板告警 |

---

## 四、移动止损

### 4.1 剥头皮(简单保本锁利)


| 触发         | 动作                   |
| ------------ | ---------------------- |
| 浮盈 ≥ $1.5 | 止损移至盈利 $0.5 位置 |

- 开仓即挂 TP = 2 点(`Inp_ScalpTP_Points`),到点自动止盈离场。

### 4.2 趋势单(SOP 追踪版)


| 浮盈       | 止损动作                            | 附加动作                   |
| ---------- | ----------------------------------- | -------------------------- |
| +3 点      | 移至成本价                          | —                         |
| +5 点      | 移至 +2 点                          | —                         |
| +8 点      | 移至 +5 点                          | **减仓 50%**(0.3→0.15 手) |
| +10 点以上 | **从最高点回撤 3 点出局**(追踪止损) | 持续跟踪最高价             |

- +10 点后进入追踪止损阶段:记录浮盈最高点,当回撤达 `Inp_TrendTrailStep`(默认 3 点)即平仓离场。
- 减仓在 +8 点档触发一次,后续不重复减仓。

---

## 五、分控熔断(核心)

### 5.1 额度计算

```
剥头皮熔断额度 = 日最大回撤 × 剥头皮比例%
趋势单熔断额度 = 日最大回撤 × 趋势比例%
全局熔断额度   = 日最大回撤 × 100%
```

默认比例:剥头皮 60% / 趋势 40%。

### 5.2 熔断分级(触发动作 = 仅禁开新仓)


| 级别       | 触发条件                      | 动作                | 恢复          |
| ---------- | ----------------------------- | ------------------- | ------------- |
| Warning    | 连续 N 笔止损                 | 面板告警 + 可选弹窗 | 手动          |
| Scalp 熔断 | 剥头皮当日亏损 ≥ 日回撤×60% | 禁开剥头皮          | 次日 0 点重置 |
| Trend 熔断 | 趋势当日亏损 ≥ 日回撤×40%   | 禁开趋势            | 次日 0 点重置 |
| Total 熔断 | 当日总亏损 ≥ 日回撤×100%    | 禁开所有            | 次日 0 点重置 |

### 5.3 额度示例


| 日回撤 | 剥头皮(60%) | 趋势(40%) | 全局(100%) |
| ------ | ----------- | --------- | ---------- |
| $500   | $300        | $200      | $500       |
| $300   | $180        | $120      | $300       |
| $200   | $120        | $80       | $200       |

> 已去掉「止损次数熔断」,仅按金额回撤判定。连续止损仅作提醒,不冻结。

---

## 六、利润护城河 + 周目标

### 6.1 日内利润保护(触发只禁开新仓)


| 累计盈利 | 动作                    |
| -------- | ----------------------- |
| +$300    | 最多回撤 50%(保底 $150) |
| +$500    | 最多回撤$200(保底 $300) |
| +$800    | 进入清盘:禁开新仓       |
| +$1000   | 强制停止:禁开新仓       |

- 「最多回撤」按当日最高盈利回落判定,回落超阈值 → 禁开新仓并告警。

### 6.2 周目标(面板提示,手动调参)


| 周累计盈利 | 建议                  |
| ---------- | --------------------- |
| +$1000     | 建议把日回撤调到 $300 |
| +$1500     | 建议把日回撤调到 $200 |
| +$2000+    | 建议降频/休息         |

> 周目标只在面板提示,由用户手动调整 `Inp_DailyMaxDrawdown`,系统按比例自动联动熔断线。

---

## 七、信息面板

分区显示:账户信息 / 今日目标(净盈亏、完成度)/ 三级熔断距离(带进度条+颜色)/ 持仓状态 / 移动止损进度 / 周目标提示。

进度条颜色:<30% 绿,30–60% 黄,>60% 红。

一键按钮:剥头皮 Buy/Sell/平剥头皮、趋势 Buy/Sell/平趋势、一键全平。熔断时对应按钮置灰。

---

## 八、参数汇总(全量参数化)

```mql5
input group "===== 基础 ====="
input int    Inp_Slippage           = 30;     // 滑点(点)
input double Inp_LotsTolerance      = 0.001;  // 手数容差

input group "===== 目标与回撤(核心)====="
input double Inp_DailyMaxDrawdown    = 500.0;  // 日最大回撤 ★核心
input double Inp_DailyProfitTarget   = 500.0;  // 日盈利目标
input double Inp_ScalpDrawdownRatio  = 60.0;   // 剥头皮占比%
input double Inp_TrendDrawdownRatio  = 40.0;   // 趋势占比%
input double Inp_WeeklyProfitTarget  = 2000.0; // 周盈利目标(面板用)

input group "===== 剥头皮 ====="
input double Inp_ScalpLots           = 0.5;
input int    Inp_ScalpMaxPositions   = 1;
input double Inp_ScalpSL_Points      = 2.0;    // 止损(点)
input double Inp_ScalpTP_Points      = 2.0;    // 止盈(点)
input double Inp_ScalpBETrigger      = 1.5;    // 保本触发($)
input double Inp_ScalpBELock         = 0.5;    // 保本锁定($)

input group "===== 趋势(SOP 追踪版)====="
input double Inp_TrendLots           = 0.3;
input int    Inp_TrendMaxPositions   = 1;
input double Inp_TrendSL_Points      = 5.0;    // 初始止损(点)
input double Inp_TrendBE1_Trigger    = 3.0;    // 移成本价
input double Inp_TrendBE2_Trigger    = 5.0;    // 移+2点
input double Inp_TrendBE2_Lock       = 2.0;
input double Inp_TrendBE3_Trigger    = 8.0;    // 移+5点 + 减仓
input double Inp_TrendBE3_Lock       = 5.0;
input double Inp_TrendReducePercent  = 50.0;   // 减仓比例%
input double Inp_TrendTrailTrigger   = 10.0;   // 进入追踪(点)
input double Inp_TrendTrailStep      = 3.0;    // 最高点回撤(点)出局

input group "===== 风控开关 ====="
input int    Inp_ConsecutiveSLWarning = 2;     // 连续止损提醒阈值
input bool   Inp_EnableCircuitBreaker = true;
input bool   Inp_AlertOnBreaker       = true;

input group "===== 利润护城河 ====="
input bool   Inp_EnableProfitProtect      = true;
input double Inp_ProfitProtect1_Trigger   = 300.0;
input double Inp_ProfitProtect1_Percent   = 50.0;
input double Inp_ProfitProtect2_Trigger   = 500.0;
input double Inp_ProfitProtect2_Amount    = 200.0; // 最多回撤$
input double Inp_ProfitLiquidation        = 800.0;
input double Inp_ProfitShutdown           = 1000.0;

input group "===== 面板 ====="
input bool   Inp_ShowPanel     = true;
input int    Inp_PanelX        = 20;
input int    Inp_PanelY        = 20;
input int    Inp_PanelWidth    = 380;
input color  Inp_PanelBgColor  = C'20,20,30';
input color  Inp_PanelTextColor= clrWhite;
```

---

## 九、开发优先级


| 优先级 | 模块                        |
| ------ | --------------------------- |
| P0     | 订单识别 + 持仓限制         |
| P0     | 移动止损(剥头皮 + 趋势追踪) |
| P0     | 分控熔断                    |
| P1     | 统计计算 + 信息面板         |
| P1     | 一键操作按钮                |
| P2     | 利润护城河 + 周目标提示     |

---

## 十、关键测试点

- 手数识别:0.5→剥头皮,0.3→趋势,0.1/1.0→忽略,0.4999→剥头皮(容差)。
- 剥头皮:浮盈 $1.5 → 止损移到锁 $0.5。
- 趋势:+3 移成本,+5 移+2,+8 移+5 且减半仓,+10 后从最高点回撤 3 点出局。
- 熔断:日回撤 $500 时剥头皮亏 $300 禁开剥头皮;总亏 $500 禁开所有;日回撤改 $300 后剥头皮线自动变 $180。
- 护城河:盈利 $500 后回落超 $200 禁开新仓;盈利达 $800/$1000 禁开新仓。
- 触发时:只禁开新仓,已有持仓不被强平。
