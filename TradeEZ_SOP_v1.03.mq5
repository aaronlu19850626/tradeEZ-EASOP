//+------------------------------------------------------------------+
//|                                           TradeEZ_SOP_EA.mq5      |
//|                    TradeEZ-SOP 分控 EA (高分辨率优化版)            |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "TradeEZ-SOP"
#property link      "https://www.mql5.com"
#property version   "1.03"
#property description "TradeEZ-SOP 分控 EA - 手数识别 / 分策略移动止损 / 分控熔断 / 利润护城河 / 彭博终端级面板"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//|                      彭博终端级暗黑配色规范                        |
//+------------------------------------------------------------------+
#define COLOR_APP_BG            C'13,16,21'       // 底层深钛灰
#define COLOR_CARD_BG           C'21,26,35'       // 卡片背景深海蓝灰
#define COLOR_CARD_BORDER       C'38,46,59'       // 卡片边框冷灰

#define COLOR_TEXT_HEADER       C'240,243,246'    // 核心标题：钛白
#define COLOR_TEXT_BODY         C'176,186,201'    // 数据数值：冰川灰
#define COLOR_TEXT_MUTED        C'112,125,142'    // 描述标签：深雾灰

#define COLOR_SIGNAL_PROFIT     C'41,121,255'     // 科技蓝（多头/盈利/安全）
#define COLOR_SIGNAL_LOSS       C'255,82,82'      // 珊瑚红（空头/亏损/关闭）
#define COLOR_SIGNAL_WARNING    C'255,160,0'      // 琥珀橙（倒计时/告警）

// 按钮配色
#define COLOR_BTN_BUY_BG        C'22,39,57'
#define COLOR_BTN_BUY_BORDER    C'41,121,255'
#define COLOR_BTN_SELL_BG       C'45,29,34'
#define COLOR_BTN_SELL_BORDER   C'255,82,82'
#define COLOR_BTN_SYS_BG        C'29,34,44'
#define COLOR_BTN_SYS_BORDER    C'58,68,85'
#define COLOR_BTN_DISABLED_BG   C'26,30,38'
#define COLOR_BTN_DISABLED_TXT  C'80,90,104'
#define COLOR_GOLD              C'212,175,55'     // 金色外边框

#define PANEL_FONT              "Segoe UI"

//+------------------------------------------------------------------+
//| 尺寸与对齐核心常量（高分辨率优化：增加尺寸和间距）                  |
//+------------------------------------------------------------------+
const string   Prefix = "GSOP_";
const int      StartX = 12;
const int      StartY = 12;
// 双列布局（增加卡片宽度和间距）
const int      CardW      = 380;                 // 单卡片宽度（原342 → 380）
const int      CardGap    = 16;                  // 卡片间距（原12 → 16）
const int      Col1X      = StartX + 14;         // 左列卡片X
const int      Col2X      = StartX + 14 + CardW + CardGap; // 右列卡片X
const int      PanelWidth  = 14 + CardW + CardGap + CardW + 14; // 两列+间距
const int      PanelHeight = 880;                // 增加面板高度（原800 → 880）
const int      LeftPad     = 20;                 // 卡片内左侧文字缩进（原18 → 20）
const int      RightPad    = 16;                 // 卡片内右侧数值缩进（原12 → 16）

//+------------------------------------------------------------------+
//| 输入参数                                                          |
//+------------------------------------------------------------------+
input group "===== 基础 ====="
input long     Inp_Magic             = 920716;   // EA 基础魔术号
input long     Inp_MagicScalp        = 920717;   // 剥头皮魔术号
input long     Inp_MagicTrend        = 920718;   // 趋势魔术号
input string   Inp_CommentScalp      = "TradeEZ-SC"; // 剥头皮订单备注
input string   Inp_CommentTrend      = "TradeEZ-TR"; // 趋势订单备注
input int      Inp_Slippage          = 30;       // 滑点(点)
input double   Inp_LotsTolerance     = 0.001;    // 手数匹配容差(备用)
input int      Inp_RefreshSeconds    = 1;        // 面板刷新间隔(秒)
input bool     Inp_DefaultChinese    = true;     // 默认中文

input group "===== 交易时段 ====="
input bool     Inp_UseSession        = true;     // 启用时段门控(仅显示则关闭)
input int      Inp_SessionStartHour  = 6;        // 时段开始(时)
input int      Inp_SessionEndHour    = 5;        // 时段结束(时)

input group "===== 每日初始化 ====="
input int      Inp_ResetHour         = 4;        // 每日重置-时(北京时间)
input int      Inp_ResetMinute       = 50;       // 每日重置-分
input bool     Inp_ExportOnReset     = true;     // 重置前导出当日统计到本地

input group "===== 目标与回撤(核心)====="
input double   Inp_DailyMaxDrawdown   = 500.0;   // 日最大回撤 ★核心
input double   Inp_DailyProfitTarget  = 1000.0;  // 日盈利目标
input double   Inp_ScalpDrawdownRatio = 70.0;    // 剥头皮占比%
input double   Inp_TrendDrawdownRatio = 30.0;    // 趋势占比%

input group "===== 周目标计划 ====="
input double   Inp_WeeklyProfitTarget = 4000.0;  // 周盈利目标(面板显示)
input double   Inp_WeeklyPlan1_Level  = 2000.0;  // 周盈档1触发($)
input double   Inp_WeeklyPlan1_DD     = 600.0;   // 周盈档1建议日回撤($)
input double   Inp_WeeklyPlan2_Level  = 3000.0;  // 周盈档2触发($)
input double   Inp_WeeklyPlan2_DD     = 800.0;   // 周盈档2建议日回撤($)
input double   Inp_WeeklyPlan3_Level  = 3500.0;  // 周盈档3触发($,建议降频/休息)

input group "===== 剥头皮 ====="
input double   Inp_ScalpLots          = 0.4;     // 剥头皮手数
input int      Inp_ScalpMaxPositions  = 1;       // 最大持仓
input int      Inp_ScalpSL_Points     = 350;     // 止损(标准点,1点=0.01)
input int      Inp_ScalpTP_Points     = 500;     // 止盈(标准点)
input int      Inp_ScalpBETrigger     = 300;     // 峰值追踪触发(标准点)
input int      Inp_ScalpTrailStep     = 150;     // 峰值回撤点数(标准点)
input bool     Inp_ScalpTimeLimitOn   = false;   // 启用剥头皮超时强平
input int      Inp_ScalpMaxHoldSecs   = 120;     // 超时强平秒数

input group "===== 趋势(SOP 追踪版)====="
input double   Inp_TrendLots          = 0.25;    // 趋势手数
input int      Inp_TrendMaxPositions  = 1;       // 最大持仓
input int      Inp_TrendSL_Points     = 500;     // 初始止损(标准点,1点=0.01)
input int      Inp_TrendBE1_Trigger   = 300;     // 移成本价(标准点)
input int      Inp_TrendBE2_Trigger   = 500;     // 移+2点触发(标准点)
input int      Inp_TrendBE2_Lock      = 200;     // 第2档锁定(标准点)
input int      Inp_TrendBE3_Trigger   = 800;     // 移+5点+减仓触发(标准点)
input int      Inp_TrendBE3_Lock      = 500;     // 第3档锁定(标准点)
input double   Inp_TrendReducePercent = 50.0;    // 减仓比例%
input int      Inp_TrendTrailTrigger  = 1000;    // 进入追踪(标准点)
input int      Inp_TrendTrailStep     = 350;     // 最高点回撤(标准点)出局

input group "===== 界面 ====="
input bool     Inp_ShowResetBtn         = false;  // 显示重置按钮

input group "===== 风控开关 ====="
input int      Inp_ConsecutiveSLWarning = 2;     // 连续止损提醒阈值
input int      Inp_ConsecLossLimit      = 3;     // 连续亏损熔断阈值(笔)
input int      Inp_CooldownMinutes      = 10;    // 连续亏损熔断冷却(分钟)
input bool     Inp_EnableCircuitBreaker = true;  // 启用熔断
input bool     Inp_AlertOnBreaker       = true;  // 熔断弹窗

input group "===== 利润护城河 ====="
input bool     Inp_EnableProfitProtect    = true;
input double   Inp_ProfitProtect1_Trigger = 500.0;  // 第1档触发($)
input double   Inp_ProfitProtect1_Percent = 300.0;  // 第1档最大回撤%
input double   Inp_ProfitProtect2_Trigger = 800.0;  // 第2档触发($)
input double   Inp_ProfitProtect2_Amount  = 500.0;  // 第2档最多回撤$
input double   Inp_ProfitLiquidation      = 1000.0; // 清盘触发($)
input double   Inp_ProfitShutdown         = 2000.0; // 强制停止($)

//+------------------------------------------------------------------+
//| 枚举                                                              |
//+------------------------------------------------------------------+
enum ENUM_SOP_ORDER
{
    SOP_IGNORE = 0,   // 忽略
    SOP_SCALP  = 1,   // 剥头皮
    SOP_TREND  = 2    // 趋势
};

//+------------------------------------------------------------------+
//| 全局状态                                                          |
//+------------------------------------------------------------------+
CTrade         g_trade;
bool           g_Language_ZH  = true;   // 语言
bool           g_ShowDetails  = false;  // 明细舱开关
bool           g_ShowStats    = false;  // 日统计舱开关
bool           g_ShowChangelog = false; // 更新日志舱开关
string         g_ChangelogVer  = "v1.03"; // 当前选中的版本号
bool           g_Collapsed    = false;  // 面板折叠
ENUM_SOP_ORDER g_DetailSide   = SOP_SCALP; // 明细舱当前展示策略
bool           g_DetailAll    = false;  // 明细舱"全部"模式:显示今日所有平仓单(含手动),忽略 g_DetailSide
datetime       g_ResetTime    = 0;      // 统计基线时间
datetime       g_DayStart     = 0;      // 当日0点

// 风控封锁标志(仅禁开)
bool           g_ScalpBlocked = false;
bool           g_TrendBlocked = false;
bool           g_TotalBlocked = false;

// 熔断原因(面板显示用)
string         g_ScalpReason  = "";
string         g_TrendReason  = "";
string         g_TotalReason  = "";

// 连续止损时间熔断
int            g_ConsecLoss     = 0;      // 当前连续亏损笔数
datetime       g_LastDealTime   = 0;      // 已统计到的最后一笔平仓成交时间
datetime       g_CooldownUntil  = 0;      // 冷却结束时刻(服务器时间);0=未冷却

double         g_TodayHighProfit = 0.0;   // 今日最高净盈利(护城河高水位)
bool           g_HighInit        = false;  // 高水位是否已初始化(允许为负)
double         g_EffectiveLimit  = 0.0;    // 护城河生效后的有效回撤限额(显示用)
bool           g_MoatDrawHit     = false;  // 本次风控:回撤保护条件是否触发(每tick重算,不持久化)
bool           g_MoatLiquidated  = false;  // 当日是否已因回撤保护强平并锁定(持久化,跨日自愈)

// 余额峰值统计(从初始化/重置时刻起)
double         g_InitBalance     = 0.0;    // 初始化时账户余额基准
double         g_PeakBalance     = 0.0;    // 期间账户余额最高值

// 各分项今日最高盈利(已平仓口径高水位,允许为负)
double         g_ScalpHighProfit = 0.0;
double         g_TrendHighProfit = 0.0;
bool           g_ScalpHiInit    = false;
bool           g_TrendHiInit    = false;
// 全局今日最高盈利(全部已平仓累计盈亏高水位,允许为负)
double         g_GlobalRealHigh = 0.0;
bool           g_GlobalHiInit   = false;

// 买卖价 tick 方向(用于涨跌变色)
double         g_PrevBid = 0.0;
int            g_BidDir  = 0;   // +1 涨 / -1 跌 / 0 平
double         g_PrevAsk = 0.0;
int            g_AskDir  = 0;

// 限价输入框已提交内容(ENDEDIT 时保存,重建时填回)
string         g_ScPriceTxt = "";
string         g_TrPriceTxt = "";

// 下单去抖(防止一次点击触发重复下单)
ulong          g_LastOrderMs = 0;

// 剥头皮超时强平:已被用户取消倒计时的 ticket(不再强平)
ulong          g_TimeoutCancelled[];

// 趋势 per-ticket 追踪状态
ulong          g_TrTicket[];            // ticket
bool           g_TrReduced[];           // 是否已减仓
double         g_TrPeakPoints[];        // 追踪阶段浮盈峰值(点)

// 剥头皮"追踪模式"后转为按峰值回撤管理的持仓 ticket
ulong          g_PromotedTickets[];

// 剥头皮追踪状态(类似趋势追踪,但保留止盈)
ulong          g_ScalpTrackTicket[];      // ticket
double         g_ScalpTrackPeak[];        // 峰值浮盈点数

// 数组状态变化标记(脏则下次落盘,避免每 tick 写文件)
bool           g_ArraysDirty = false;

// 明细舱历史缓存
struct ClosedRow
{
    string time;
    string type;
    double lots;         // 下单手数(平仓成交量)
    string strat;        // 策略标签(剥头皮/趋势/手动),供"全部"明细舱区分
    double open_price;
    double close_price;
    string duration;
    double pnl;
};
ClosedRow      g_Rows[];

//+------------------------------------------------------------------+
//| 双语切换器                                                        |
//+------------------------------------------------------------------+
string Lang(string zh, string en) { return g_Language_ZH ? zh : en; }

//+-----------------------------------------------------------------+
