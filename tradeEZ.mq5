//+------------------------------------------------------------------+
//|                                           TradeEZ_SOP_EA.mq5      |
//|                    TradeEZ-SOP 分控 EA (UI 1:1 复刻 UI-TEST)      |
//|                  最后修改时间：2026-09-19 05:48（北京时间）       |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "TradeEZ-SOP"
#property link      "https://www.mql5.com"
#property version   "1.03"
#property description "TradeEZ-SOP 分控 EA - 手数识别 / 分策略移动止损 / 分控熔断 / 利润护城河 / 彭博终端级面板"

#include <Trade/Trade.mqh>
#resource "website-design\\logo\\ea-logo.bmp"

// Windows x64：使用系统默认浏览器打开固定官网地址。
#import "shell32.dll"
long ShellExecuteW(long hwnd, string operation, string file, string parameters, string directory, int showCmd);
#import
#import "user32.dll"
long LoadCursorW(long instance, long cursorId);
long SetCursor(long cursor);
uint GetWindowThreadProcessId(long hwnd, uint &processId);
int AttachThreadInput(uint fromThread, uint toThread, int attach);
#import
#import "kernel32.dll"
uint GetCurrentThreadId();
#import

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
#define COLOR_INPUT_BG          COLOR_BTN_SYS_BG       // 与 LANG 按钮共用底色
#define COLOR_INPUT_BORDER      COLOR_BTN_SYS_BORDER   // 与 LANG 按钮共用边框
#define COLOR_GOLD              C'212,175,55'     // 金色外边框

#define PANEL_FONT              "Segoe UI"

//+------------------------------------------------------------------+
//| 尺寸与对齐核心常量（支持全局缩放，适配任意DPI）                    |
//+------------------------------------------------------------------+
const string   Prefix = "GSOP_";

// 基准尺寸（缩放系数1.0时的标准尺寸）
const int      BASE_StartX    = 12;
const int      BASE_StartY    = 12;
const int      BASE_CardW     = 380;      // 单卡片宽度
const int      BASE_CardGap   = 16;       // 卡片间距
const int      BASE_PanelH    = 880;      // 面板高度
const int      BASE_LeftPad   = 20;       // 卡片内左侧文字缩进
const int      BASE_RightPad  = 16;       // 卡片内右侧数值缩进

// 动态计算的实际尺寸（根据 Inp_UIScale 缩放）
int Scale(int baseValue) { return (int)MathRound(baseValue * MathMax(0.7, MathMin(1.5, Inp_UIScale))); }

// MetaTrader is DPI-aware: object coordinates are physical pixels, while font
// point size is already enlarged by Windows. Divide UI scale by system DPI scale.
double SystemDpiScale()
{
    long dpi = TerminalInfoInteger(TERMINAL_SCREEN_DPI);
    if(dpi <= 0)
        return 1.0;
    return (double)dpi / 96.0;
}

int ScaledFont(double baseValue)
{
    double pointScale = MathMax(0.7, MathMin(1.5, Inp_UIScale)) / SystemDpiScale();
    return (int)MathRound(MathMax(6.0, baseValue * pointScale));
}

#define StartX      Scale(BASE_StartX)
#define StartY      Scale(BASE_StartY)
#define CardW       Scale(BASE_CardW)
#define CardGap     Scale(BASE_CardGap)
#define Col1X       (StartX + 14)
#define Col2X       (StartX + 14 + CardW + CardGap)
#define PanelWidth  (14 + CardW + CardGap + CardW + 14)
#define PanelHeight Scale(BASE_PanelH)
#define LeftPad     Scale(BASE_LeftPad)
#define RightPad    Scale(BASE_RightPad)

//+------------------------------------------------------------------+
//| 输入参数                                                          |
//+------------------------------------------------------------------+
input group "===== 基础 ====="
input long     Inp_Magic             = 920716;   // EA 基础魔术号
input long     Inp_MagicScalp        = 920717;   // 剥头皮魔术号
input long     Inp_MagicTrend        = 920718;   // 趋势魔术号
input string   Inp_InstanceId         = "primary"; // 稳定实例ID(同账户同品种多实例必须唯一)
input string   Inp_CommentScalp      = "TradeEZ-SC"; // 剥头皮订单备注
input string   Inp_CommentTrend      = "TradeEZ-TR"; // 趋势订单备注
input int      Inp_Slippage          = 30;       // 滑点(点)
input double   Inp_LotsTolerance     = 0.001;    // 手数匹配容差(备用)
input int      Inp_RefreshSeconds    = 1;        // 面板刷新间隔(秒)
input bool     Inp_DefaultChinese    = true;     // 默认中文

input group "===== 界面适配(高DPI屏幕) ====="
input double   Inp_UIScale           = 1.00;     // 全局UI缩放系数(高DPI填Windows缩放:150%=1.5)

input group "===== 交易时段 ====="
input bool     Inp_UseSession        = true;     // 启用时段门控(仅显示则关闭)
input int      Inp_SessionStartHour  = 6;        // 时段开始(时)
input int      Inp_SessionEndHour    = 5;        // 时段结束(时)

input group "===== 每日初始化 ====="
input int      Inp_ResetHour         = 4;        // 每日重置-时(北京时间)
input int      Inp_ResetMinute       = 50;       // 每日重置-分
input bool     Inp_ExportOnReset     = true;     // 重置前导出当日统计到本地
input int      Inp_RecoveryLookbackDays = 31;    // 启动时最多自动补做的统计周期数
input int      Inp_RecoveryRetrySeconds = 30;    // 历史恢复失败后的重试间隔(秒)
input int      Inp_TesterServerUtcOffsetHours = 0; // 回测服务器UTC偏移(小时,测试器必须显式设置)

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
input bool     Inp_CloseOnDailyDrawdown = false; // 日回撤熔断时强平本品种全部仓位/挂单

input group "===== 新增风险门禁 ====="
input double   Inp_RiskBufferPercent       = 10.0;  // 预计止损风险附加缓冲%
input int      Inp_MaxEntrySpreadPoints    = 80;    // 最大允许点差(MT5平台点)
input int      Inp_MaxQuoteAgeSeconds      = 5;     // 报价最大允许延迟(秒)
input double   Inp_MinProjectedMarginLevel = 200.0; // 开仓后最低预计保证金水平%

input group "===== 利润护城河 ====="
input bool     Inp_EnableProfitProtect    = true;
input double   Inp_ProfitProtect1_Trigger = 500.0;  // 第1档触发($)
input double   Inp_ProfitProtect1_Percent = 30.0;   // 第1档最大回撤%
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

enum ENUM_RECOVERY_STATUS
{
    RECOVERY_CHECKING     = 0,
    RECOVERY_EXACT        = 1,
    RECOVERY_CONSERVATIVE = 2,
    RECOVERY_FAILED       = 3
};

enum ENUM_PROTECTION_STATUS
{
    PROTECTION_CHECKING       = 0,
    PROTECTION_CONFIRMED      = 1,
    PROTECTION_REPAIR_PENDING = 2,
    PROTECTION_CLOSE_PENDING  = 3,
    PROTECTION_FAILED         = 4
};

enum ENUM_SCALP_PHASE
{
    SCALP_INITIAL       = 0,
    SCALP_TRAIL_ACTIVE  = 1,
    SCALP_EXIT_PENDING  = 2,
    SCALP_CLOSED        = 3
};

enum ENUM_SCALP_EXIT_REASON
{
    SCALP_EXIT_NONE     = 0,
    SCALP_EXIT_TIMEOUT  = 1,
    SCALP_EXIT_PULLBACK = 2
};

enum ENUM_SCALP_TP_POLICY
{
    SCALP_TP_REQUIRED       = 0,
    SCALP_TP_REMOVE_PENDING = 1,
    SCALP_TP_REMOVED        = 2
};

// 交易请求闭环：函数返回 true 只表示请求已提交，最终结果必须由服务器事实核销。
enum ENUM_TRADE_OP_ACTION
{
    TRADE_OP_OPEN_MARKET   = 1,
    TRADE_OP_OPEN_LIMIT    = 2,
    TRADE_OP_CLOSE         = 3,
    TRADE_OP_PARTIAL_CLOSE = 4,
    TRADE_OP_DELETE_ORDER  = 5,
    TRADE_OP_MODIFY        = 6,
    TRADE_OP_MODIFY_ORDER  = 7
};

enum ENUM_TRADE_OP_STATE
{
    TRADE_OP_CREATED   = 0,
    TRADE_OP_SUBMITTED = 1,
    TRADE_OP_ACCEPTED  = 2,
    TRADE_OP_PARTIAL   = 3,
    TRADE_OP_CONFIRMED = 4,
    TRADE_OP_FAILED    = 5,
    TRADE_OP_AMBIGUOUS = 6,
    TRADE_OP_CANCELLED = 7
};

//+------------------------------------------------------------------+
//| 全局状态                                                          |
//+------------------------------------------------------------------+
CTrade         g_trade;

bool           g_Language_ZH  = true;   // 语言
bool           g_ShowDetails  = false;  // 明细舱开关
bool           g_ShowStats    = false;  // 日统计舱开关
bool           g_ShowChangelog = false; // 更新日志舱开关
bool           g_Collapsed    = false;  // 面板折叠
ENUM_SOP_ORDER g_DetailSide   = SOP_SCALP; // 明细舱当前展示策略
bool           g_DetailAll    = false;  // 明细舱"全部"模式:显示今日所有平仓单(含手动),忽略 g_DetailSide
datetime       g_ResetTime    = 0;      // 统计基线时间
datetime       g_DayStart     = 0;      // 当日0点
ENUM_RECOVERY_STATUS g_RecoveryStatus = RECOVERY_CHECKING;
string         g_RecoveryReason = "";
bool           g_RecoveryAcknowledged = false;
datetime       g_LastRecoveryAttempt = 0;
datetime       g_RecoveryStartedUtc = 0;
datetime       g_RecoveryCompletedUtc = 0;
datetime       g_LastStateCheckpointUtc = 0;
datetime       g_LastCompletedPeriod = 0;
datetime       g_LastReportedPeriod = 0;
datetime       g_PendingReportPeriod = 0;
datetime       g_LastReportRetryUtc = 0;
double         g_WeeklyCachedPL = 0.0;
datetime       g_WeeklyCacheSecond = 0;
bool           g_TimeBoundaryUncertain = false;

// 服务器保护闭环。任何受管仓位/挂单未确认最低保护时，全局禁止新增风险。
bool           g_ProtectionBlocksNewRisk = true;
string         g_ProtectionReason = "";
int            g_ProtectionIssueCount = 0;
bool           g_AccountModeSupported = true;

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
long           g_LastDealTimeMsc = 0;     // 连亏重放游标：成交毫秒时间
ulong          g_LastDealTicket  = 0;     // 连亏重放游标：同毫秒成交票号
datetime       g_CooldownUntil  = 0;      // 冷却结束时刻(服务器时间);0=未冷却

double         g_TodayHighProfit = 0.0;   // 今日最高净盈利(护城河高水位)
bool           g_HighInit        = false;  // 高水位是否已初始化(允许为负)
double         g_EffectiveLimit  = 0.0;    // 护城河生效后的有效回撤限额(显示用)
bool           g_MoatDrawHit     = false;  // 本次风控:回撤保护条件是否触发(每tick重算,不持久化)
bool           g_MoatLiquidated  = false;  // 当日是否已因回撤保护强平并锁定(持久化,跨日自愈)
bool           g_DailyLiquidationActive = false; // 日回撤强平锁：持续执行至服务器确认空仓

// 当前品种统一风险快照。风险无从可靠计算时 fail-closed，禁止新增风险。
bool           g_RiskSnapshotValid = false;
string         g_RiskSnapshotReason = "尚未计算";
double         g_ScalpProjectedPL = 0.0;
double         g_TrendProjectedPL = 0.0;
double         g_SymbolProjectedPL = 0.0;
double         g_ScalpProjectedRisk = 0.0;
double         g_TrendProjectedRisk = 0.0;
double         g_SymbolProjectedRisk = 0.0;
int            g_ScalpRiskSlots = 0;
int            g_TrendRiskSlots = 0;
datetime       g_LastRiskSnapshotAt = 0;

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
bool           g_PriceEditActive = false; // 输入期间暂停整面板重建,避免编辑控件层级被新卡片覆盖

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
double         g_ScalpTrackLoggedPeak[];  // 仅用于日志限频，不参与交易判断

// 数组状态变化标记(脏则下次落盘,避免每 tick 写文件)
bool           g_ArraysDirty = false;

struct TradeOperation
{
    string   operation_id;
    string   batch_id;
    string   source;
    int      action;
    int      state;
    ulong    target_ticket;
    ulong    target_position_id;
    long     magic;
    int      requested_order_type;
    double   requested_entry_price;
    double   requested_volume;
    double   target_remaining_volume;
    double   target_sl;
    double   target_tp;
    ulong    request_id;
    ulong    order_ticket;
    ulong    deal_ticket;
    uint     last_retcode;
    int      retry_count;
    long     created_utc_msc;
    long     last_submit_utc_msc;
    long     next_retry_utc_msc;
    long     updated_utc_msc;
    bool     critical_exit;
    bool     continuous_batch;
};
TradeOperation g_TradeOps[];
long           g_TradeOpSequence = 0;
bool           g_TradeLedgerDirty = false;
bool           g_TradeLedgerDeferSave = false;
string         g_MoatBatchId = "";
const int      TRADE_LEDGER_SCHEMA = 2;

// 版本化逐票持久化记录。运行期仍沿用原数组，降低交易管理逻辑改动风险。
struct TicketStateRecord
{
    ulong    ticket;
    ulong    position_id;
    string   symbol;
    long     magic;
    long     open_time_msc;
    int      management_mode;       // 1=SCALP, 2=TREND；旧版3在迁移时归并为SCALP
    bool     timeout_cancelled;
    bool     scalp_track_active;
    double   scalp_peak_points;
    bool     trend_reduced;
    double   trend_peak_points;
    double   last_volume;
    int      scalp_phase;
    int      scalp_exit_reason;
    long     scalp_exit_requested_utc_msc;
    long     scalp_exit_next_retry_utc_msc;
    int      scalp_exit_retry_count;
    uint     scalp_exit_last_retcode;
    int      scalp_tp_policy;
    long     scalp_tp_requested_utc_msc;
    uint     scalp_tp_last_retcode;
    int      protection_status;
    double   minimum_required_sl;
    double   last_confirmed_sl;
    double   last_confirmed_tp;
    long     protection_first_failed_utc_msc;
    long     protection_next_retry_utc_msc;
    int      protection_retry_count;
    uint     protection_last_retcode;
    datetime updated_utc;
    datetime closed_utc;
};
TicketStateRecord g_TicketState[];
ulong             g_StateRecoveryBlockedTickets[];
bool              g_LegacyStateMigrated = false;
bool              g_InstanceOwnsState = true;
bool              g_StatePersistenceBlocked = false;
double            g_InstanceLeaseOwner = 0.0;
int               g_StateCheckpointSeconds = 0;
const int         TICKET_STATE_SCHEMA = 5;

// 挂单不进入持仓逐票文件；运行期每秒复核，重启后从服务器订单池重建。
ulong             g_UnsafeOrderTicket[];
long              g_UnsafeOrderFirstFailedMsc[];
long              g_UnsafeOrderNextRetryMsc[];
int               g_UnsafeOrderRetryCount[];

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

//+------------------------------------------------------------------+
//| 工具函数：点/价格/美金换算                                        |
//+------------------------------------------------------------------+
// 一"点"= 1.0 美金价格单位(黄金),对应报价的整数位波动
double PointsToPrice(double standardPoints)
{
    // 标准点转价格: 1标准点 = 0.01 价格变动
    return standardPoints * 0.01;
}

// 每手每点价值(美金)
double PerPointValuePerLot()
{
    double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickSize <= 0.0) return 0.0;
    return tickVal * (1.0 / tickSize); // 每 1.0 价格 = tickVal / tickSize
}

// 美金 → 点数(给定手数)
double DollarToPoints(double dollars, double lots)
{
    double vpp = PerPointValuePerLot();
    if(vpp <= 0.0 || lots <= 0.0) return 0.0;
    return dollars / (vpp * lots);
}

double NormalizePrice(double price)
{
    if(price == 0.0) return 0.0;
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickSize <= 0.0) tickSize = _Point;
    if(tickSize <= 0.0) return NormalizeDouble(price, _Digits);
    return NormalizeDouble(MathRound(price / tickSize) * tickSize, _Digits);
}

double NormalizeProtectionPrice(double price, ENUM_POSITION_TYPE type)
{
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickSize <= 0.0) tickSize = _Point;
    if(tickSize <= 0.0) return NormalizeDouble(price, _Digits);
    // 最低保护线只能向减小风险的方向取整：多单向上、空单向下。
    double ticks = price / tickSize;
    double aligned = (type == POSITION_TYPE_BUY)
                   ? MathCeil(ticks - 1e-9) * tickSize
                   : MathFloor(ticks + 1e-9) * tickSize;
    return NormalizeDouble(aligned, _Digits);
}

long ProtectionNowMsc()
{
    return (long)TimeGMT() * 1000;
}

bool TradeRetcodeAccepted(uint retcode)
{
    return retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_DONE_PARTIAL ||
           retcode == TRADE_RETCODE_PLACED || retcode == TRADE_RETCODE_NO_CHANGES;
}

double NormalizeLots(double lots)
{
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(step <= 0.0) step = 0.01;
    double v = MathRound(lots / step) * step;
    double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    if(v < vmin) v = vmin;
    if(v > vmax) v = vmax;
    return NormalizeDouble(v, 2);
}

//+------------------------------------------------------------------+
//| 策略识别(按 Magic Number,手动单严格不接管)                      |
//+------------------------------------------------------------------+
ENUM_SOP_ORDER TypeByMagic(long magic)
{
    if(magic == Inp_MagicScalp) return SOP_SCALP;
    if(magic == Inp_MagicTrend) return SOP_TREND;
    return SOP_IGNORE;   // 手动单/其他 EA/基础magic → 不接管
}

// 当前选中持仓的策略类型(需先 PositionSelectByTicket / PositionGetTicket)
ENUM_SOP_ORDER PosType()      { return TypeByMagic(PositionGetInteger(POSITION_MAGIC)); }
// 当前遍历到的历史成交(需先 HistoryDealGetTicket)
ENUM_SOP_ORDER DealType(ulong dealTicket) { return TypeByMagic(HistoryDealGetInteger(dealTicket, DEAL_MAGIC)); }

// 平仓成交的"策略归属"——用于统计分类,兼容手工平仓。
// 关键:手工在 MT5 界面平仓时,平仓成交的 DEAL_MAGIC=0,直接按它分类会把 EA 开的单误判成手动单,
// 脱离原策略统计。故按 DEAL_POSITION_ID 回溯到"开仓成交"取 magic——开仓是 EA 下的,magic 一定正确。
// 这样能精确区分:EA开+手工平(归原策略) vs 用户手动开(开仓magic=0,仍归 IGNORE/规则外手动)。
// 依赖外层已 HistorySelect 选好区间;内部不重新 select,不破坏外层遍历。
// 按注释前缀识别策略(EA 开单时写入 Inp_CommentScalp/Trend;手动单注释为空 → IGNORE)
ENUM_SOP_ORDER TypeByComment(string cmt)
{
    if(cmt == "") return SOP_IGNORE;
    if(Inp_CommentTrend != "" && StringFind(cmt, Inp_CommentTrend) >= 0) return SOP_TREND;
    if(Inp_CommentScalp != "" && StringFind(cmt, Inp_CommentScalp) >= 0) return SOP_SCALP;
    return SOP_IGNORE;
}

// 关键:分类必须以「开仓成交」为准。全局 g_trade 的 magic 会粘连(开剥头皮单后设成剥头皮magic,
// 之后平任何单——含趋势单——的平仓成交都盖上剥头皮magic),所以平仓成交的 magic 完全不可信,
// 只能作最后兜底。开仓成交的 magic/注释才定义这笔仓位的真实策略归属。
ENUM_SOP_ORDER DealStrategyType(ulong dealTicket)
{
    // 1) 优先:按持仓ID回溯到「开仓成交」,用其 magic(最可靠),再退用其注释
    long posId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
    if(posId != 0)
    {
        int deals = HistoryDealsTotal();
        for(int i = 0; i < deals; i++)
        {
            ulong d = HistoryDealGetTicket(i);
            if(d == 0) continue;
            if(HistoryDealGetInteger(d, DEAL_POSITION_ID) != posId) continue;
            if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN) continue; // 开仓成交
            ENUM_SOP_ORDER byMagic = TypeByMagic(HistoryDealGetInteger(d, DEAL_MAGIC));
            if(byMagic != SOP_IGNORE) return byMagic;
            ENUM_SOP_ORDER byCmt = TypeByComment(HistoryDealGetString(d, DEAL_COMMENT));
            if(byCmt != SOP_IGNORE) return byCmt;
            break; // 找到开仓成交但既无策略magic也无策略注释 → 确为手动单
        }
    }

    // 2) 兜底:开仓成交不在选择区间(如跨日单)时,才勉强用平仓成交自身的注释
    //    (平仓 magic 因 g_trade 粘连不可信,不用)
    return TypeByComment(HistoryDealGetString(dealTicket, DEAL_COMMENT));
}

double DealCashValue(ulong dealTicket)
{
    return HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION)
         + HistoryDealGetDouble(dealTicket, DEAL_FEE);
}

bool DealIsExit(ulong dealTicket)
{
    ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
    return entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT;
}

// 出场成交的完整交易结果：出场现金流 + 按本次出场手数分摊的入场佣金/费用。
// 调用方必须已经选择包含对应入场成交的历史区间。
double ExitTradeCashValue(ulong dealTicket)
{
    double result = DealCashValue(dealTicket);
    if(!DealIsExit(dealTicket)) return result;
    long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
    double entryVolume = 0.0, entryCosts = 0.0;
    for(int i = 0; i < HistoryDealsTotal(); i++)
    {
        ulong entryDeal = HistoryDealGetTicket(i);
        if(entryDeal == 0 || HistoryDealGetInteger(entryDeal, DEAL_POSITION_ID) != positionId) continue;
        if(HistoryDealGetInteger(entryDeal, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
        entryVolume += HistoryDealGetDouble(entryDeal, DEAL_VOLUME);
        entryCosts += HistoryDealGetDouble(entryDeal, DEAL_COMMISSION) + HistoryDealGetDouble(entryDeal, DEAL_FEE);
    }
    double exitVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
    if(entryVolume > 0.0) result += entryCosts * MathMin(1.0, exitVolume / entryVolume);
    return result;
}

ENUM_SOP_ORDER DealCashStrategy(ulong dealTicket)
{
    ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
    if(entry == DEAL_ENTRY_IN)
    {
        ENUM_SOP_ORDER byMagic = TypeByMagic(HistoryDealGetInteger(dealTicket, DEAL_MAGIC));
        return byMagic != SOP_IGNORE ? byMagic : TypeByComment(HistoryDealGetString(dealTicket, DEAL_COMMENT));
    }
    return DealStrategyType(dealTicket);
}

// 兼容旧签名:仅用于极少数仍按手数的场景(现已不用于识别)
ENUM_SOP_ORDER GetOrderType(double lots)
{
    if(MathAbs(lots - Inp_ScalpLots) <= Inp_LotsTolerance) return SOP_SCALP;
    if(MathAbs(lots - Inp_TrendLots) <= Inp_LotsTolerance) return SOP_TREND;
    return SOP_IGNORE;
}

//+------------------------------------------------------------------+
//| 时间工具(统一北京时间 UTC+8)                                     |
//+------------------------------------------------------------------+
// 服务器时间相对 GMT 的偏移(秒),四舍五入到整小时避免抖动
int ServerGmtOffset()
{
    if((bool)MQLInfoInteger(MQL_TESTER))
        return Inp_TesterServerUtcOffsetHours * 3600;
    // TimeCurrent 在休市时停在最后一个 tick；TimeTradeServer 会继续前进，
    // 因而用它计算 UTC 偏移可避免周末/盘间得到异常偏移。
    datetime serverNow = TimeTradeServer();
    if(serverNow <= 0) serverNow = TimeCurrent();
    int off = (int)(serverNow - TimeGMT());
    return (int)(MathRound(off / 3600.0) * 3600);
}

// 把服务器时间(datetime,epoch)转换成"北京时间显示用"的 datetime
// 北京 = GMT + 8h;服务器 = GMT + ServerGmtOffset。故 北京 = 服务器 - 偏移 + 8h
datetime ToBeijing(datetime serverTime)
{
    return serverTime - ServerGmtOffset() + 8 * 3600;
}

// 当前北京时间(用于标题栏实时显示)
datetime BeijingNow()
{
    // 统一从服务器时钟换算；测试器使用显式服务器UTC偏移，不能依赖 TimeGMT() 的模拟语义。
    datetime serverNow = TimeTradeServer();
    if(serverNow <= 0) serverNow = TimeCurrent();
    return serverNow - ServerGmtOffset() + 8 * 3600;
}

// 北京时间当日0点,返回对应的服务器 epoch(供 HistorySelect / 跨日判断用)
// 当前统计日起点 = 最近一次"北京时间 重置时:分"的时刻,返回服务器 epoch
datetime TodayStart()
{
    datetime bj = BeijingNow();
    MqlDateTime t; TimeToStruct(bj, t);
    t.hour = Inp_ResetHour; t.min = Inp_ResetMinute; t.sec = 0;
    datetime bjReset = StructToTime(t);             // 今天的重置时刻(北京基准)
    if(bj < bjReset) bjReset -= 86400;              // 还没到今天重置点 → 用昨天的
    // 转回服务器 epoch:server = beijing - 8h + 偏移
    return bjReset - 8 * 3600 + ServerGmtOffset();
}

// 下一次重置时刻(服务器 epoch),供倒计时用
datetime NextResetTime()
{
    return TodayStart() + 86400;
}

// 下一次重置的剩余秒数。界面倒计时必须完全在北京时间域内计算，
// 避免休市时交易服务器 epoch 与持续推进的界面时钟出现偏差。
int SecondsUntilNextResetBeijing()
{
    datetime bjNow = BeijingNow();
    MqlDateTime resetParts;
    TimeToStruct(bjNow, resetParts);
    resetParts.hour = Inp_ResetHour;
    resetParts.min  = Inp_ResetMinute;
    resetParts.sec  = 0;
    datetime nextResetBj = StructToTime(resetParts);
    if(nextResetBj <= bjNow) nextResetBj += 86400;
    return MathMax(0, (int)(nextResetBj - bjNow));
}

// 统计起点 = max(当日0点, 手动重置时间)
datetime StatStart()
{
    datetime ds = TodayStart();
    return (g_ResetTime > ds) ? g_ResetTime : ds;
}

bool InSession()
{
    if(!Inp_UseSession) return true;
    MqlDateTime t; TimeToStruct(BeijingNow(), t);    // 按北京时间判定时段
    int h = t.hour;
    if(Inp_SessionStartHour == Inp_SessionEndHour) return true; // 全天
    if(Inp_SessionStartHour < Inp_SessionEndHour)
        return (h >= Inp_SessionStartHour && h < Inp_SessionEndHour);      // 同日时段
    // 跨午夜时段(如 20:00~04:00):>=开始 或 <结束
    return (h >= Inp_SessionStartHour || h < Inp_SessionEndHour);
}

// 市场是否休市:按券商交易时段(SymbolInfoSessionTrade)判定
// 与"非时段(休息)"区别:休息是本策略人为设定的时段,休市是券商侧根本不接单(周末/节假日/盘间)
// 当前服务器时间不落在任何一个交易时段内 → 休市
bool IsMarketClosed()
{
    // 关键:必须用 TimeTradeServer()(持续前进的当前服务器时间),
    // 不能用 TimeCurrent()——它是"最后一个tick的服务器时间",休市时冻结在收盘时刻,
    // 会被误判成落在上一交易日的时段内 → 永远判不出休市(这是之前无效的根因)。
    datetime srvNow  = TimeTradeServer();
    datetime lastTick = TimeCurrent();

    // 兜底判据:报价静默过久(两者同为服务器时基,差值即静默秒数)。
    // 黄金开市几乎每秒有tick,静默超5分钟基本即休市/断连;对时段表异常的券商也稳。
    if(srvNow > lastTick && (int)(srvNow - lastTick) > 300) return true;

    // 主判据:当前服务器时刻是否落在券商交易时段(SymbolInfoSessionTrade)内
    datetime from, to;
    MqlDateTime t; TimeToStruct(srvNow, t);           // 时段表以服务器时区为准
    ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)t.day_of_week;
    int nowSec = t.hour * 3600 + t.min * 60 + t.sec;  // 当前"距当日0点"的秒数
    for(int i = 0; SymbolInfoSessionTrade(_Symbol, dow, i, from, to); i++)
    {
        if(nowSec >= (int)from && nowSec < (int)to) return false; // 落在某个交易时段内 → 开市
    }
    return true; // 没有任何交易时段覆盖当前时刻 → 休市
}

//+------------------------------------------------------------------+
//| 持仓统计                                                          |
//+------------------------------------------------------------------+
int CountPositions(ENUM_SOP_ORDER kind)
{
    int cnt = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PosType() == kind) cnt++;
    }
    return cnt;
}

int CountScalpPositions() { return CountPositions(SOP_SCALP); }
int CountTrendPositions() { return CountPositions(SOP_TREND); }

// 某策略持仓浮动盈亏
double FloatingPL(ENUM_SOP_ORDER kind)
{
    double sum = 0.0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PosType() != kind) continue;
        sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
    }
    return sum;
}

//+------------------------------------------------------------------+
//| 已实现盈亏(今日/按策略)—— 遍历历史成交                          |
//+------------------------------------------------------------------+
// realized: 已实现净盈亏; lossOut: 已实现亏损(正数); slCountOut: 止损离场次数近似
double RealizedPL(ENUM_SOP_ORDER kind, double &lossOut, int &winCnt, int &lossCnt)
{
    lossOut = 0.0; winCnt = 0; lossCnt = 0;
    double net = 0.0;
    datetime from = StatStart();
    if(!HistorySelect(from, TimeCurrent() + 3600)) return 0.0;

    int deals = HistoryDealsTotal();
    for(int i = 0; i < deals; i++)
    {
        ulong dt = HistoryDealGetTicket(i);
        if(dt == 0) continue;
        if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) continue;
        ENUM_SOP_ORDER dk = DealCashStrategy(dt);
        if(kind != SOP_IGNORE && dk != kind) continue;   // 指定策略
        if(kind == SOP_IGNORE && dk == SOP_IGNORE) continue; // 全部系统单口径:排除手动单

        double profit = DealCashValue(dt);
        net += profit;
        if(!DealIsExit(dt)) continue;
        double tradeResult = ExitTradeCashValue(dt);
        if(tradeResult < 0.0) { lossOut += -tradeResult; lossCnt++; }
        else if(tradeResult > 0.0) winCnt++;
    }
    return net;
}

// 便捷封装
double ScalpRealized() { double l; int w,ls; return RealizedPL(SOP_SCALP, l, w, ls); }
double TrendRealized() { double l; int w,ls; return RealizedPL(SOP_TREND, l, w, ls); }
double ScalpLoss()     { double l; int w,ls; RealizedPL(SOP_SCALP, l, w, ls); return l; }
double TrendLoss()     { double l; int w,ls; RealizedPL(SOP_TREND, l, w, ls); return l; }

// 某策略今日净盈亏(已实现 + 浮动)
double ScalpNetPL() { return ScalpRealized() + FloatingPL(SOP_SCALP); }
double TrendNetPL() { return TrendRealized() + FloatingPL(SOP_TREND); }

// 今日总净盈亏(已实现 + 浮动),系统订单口径
double TodayNetPL()
{
    double l; int w, ls;
    double realized = RealizedPL(SOP_IGNORE, l, w, ls);
    double floating = FloatingPL(SOP_SCALP) + FloatingPL(SOP_TREND);
    return realized + floating;
}

//+------------------------------------------------------------------+
//| 全品种今日净盈亏(不按手数过滤,含任何手动单)——全局风控口径        |
//+------------------------------------------------------------------+
double AllFloatingPL()
{
    double sum = 0.0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
    }
    return sum;
}

double AllRealizedPL()
{
    datetime from = StatStart();
    if(!HistorySelect(from, TimeCurrent() + 3600)) return 0.0;
    double net = 0.0;
    int deals = HistoryDealsTotal();
    for(int i = 0; i < deals; i++)
    {
        ulong dt = HistoryDealGetTicket(i);
        if(dt == 0) continue;
        if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) continue;
        net += DealCashValue(dt);
    }
    return net;
}

// 全局风控净盈亏:含任何手动单(不限手数)
double GlobalNetPL() { return AllRealizedPL() + AllFloatingPL(); }

//+------------------------------------------------------------------+
//| 日内统计聚合(基于今日已平仓成交)                                 |
//+------------------------------------------------------------------+
struct DailyStats
{
    int    trades;
    int    wins;
    int    losses;
    int    evens;
    double grossProfit;
    double grossLoss;
    double net;
    double maxWin;
    double maxLoss;
    double avgHoldSec;
};

struct RecoverySnapshot
{
    bool   history_ok;
    int    deal_count;
    double all_realized;
    double scalp_realized;
    double trend_realized;
    double all_high;
    double scalp_high;
    double trend_high;
    bool   all_high_init;
    bool   scalp_high_init;
    bool   trend_high_init;
    int    consec_loss;
    datetime cooldown_until;
    long   last_deal_msc;
    ulong  last_deal_ticket;
};

void ComputeDailyStatsRange(ENUM_SOP_ORDER kind, datetime statFrom, datetime statTo, DailyStats &s)
{
    s.trades=0; s.wins=0; s.losses=0; s.evens=0;
    s.grossProfit=0; s.grossLoss=0; s.net=0; s.maxWin=0; s.maxLoss=0; s.avgHoldSec=0;

    if(statTo <= statFrom) statTo = statFrom + 1;
    datetime selFrom  = statFrom - 30 * 86400;
    if(selFrom < 0) selFrom = 0;
    if(!HistorySelect(selFrom, statTo)) return;

    int deals = HistoryDealsTotal();
    double holdSum = 0.0; int holdCnt = 0;

    for(int i = 0; i < deals; i++)
    {
        ulong dt = HistoryDealGetTicket(i);
        if(dt == 0) continue;
        if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) continue;
        datetime dealT = (datetime)HistoryDealGetInteger(dt, DEAL_TIME);
        if(dealT < statFrom || dealT >= statTo) continue;
        ENUM_SOP_ORDER cashKind = DealCashStrategy(dt);
        if(kind == SOP_IGNORE || cashKind == kind) s.net += DealCashValue(dt);
        if(!DealIsExit(dt)) continue;
        ENUM_SOP_ORDER dk = DealStrategyType(dt);
        if(kind != SOP_IGNORE && dk != kind) continue;

        double p = DealCashValue(dt);
        datetime closeT = dealT;
        long posId = HistoryDealGetInteger(dt, DEAL_POSITION_ID);
        double entryCosts = 0.0, entryVolume = 0.0;
        datetime openT = closeT;
        for(int j = 0; j < deals; j++)
        {
            ulong dj = HistoryDealGetTicket(j);
            if(dj == 0 || HistoryDealGetInteger(dj, DEAL_POSITION_ID) != posId) continue;
            if(HistoryDealGetInteger(dj, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            entryCosts += HistoryDealGetDouble(dj, DEAL_COMMISSION) + HistoryDealGetDouble(dj, DEAL_FEE);
            entryVolume += HistoryDealGetDouble(dj, DEAL_VOLUME);
            datetime candidateOpen = (datetime)HistoryDealGetInteger(dj, DEAL_TIME);
            if(openT == closeT || candidateOpen < openT) openT = candidateOpen;
        }
        double exitVolume = HistoryDealGetDouble(dt, DEAL_VOLUME);
        if(entryVolume > 0.0) p += entryCosts * MathMin(1.0, exitVolume / entryVolume);
        s.trades++;
        if(p > 0.01)       { s.wins++;   s.grossProfit += p;  if(p > s.maxWin)  s.maxWin = p; }
        else if(p < -0.01) { s.losses++; s.grossLoss  += -p; if(p < s.maxLoss) s.maxLoss = p; }
        else                 s.evens++;

        int secs = (int)(closeT - openT);
        if(secs >= 0) { holdSum += secs; holdCnt++; }
    }
    if(holdCnt > 0) s.avgHoldSec = holdSum / holdCnt;
}

double StatWinRate(DailyStats &s)   { int d = s.wins + s.losses; return d > 0 ? 100.0 * s.wins / d : 0.0; }
double StatAvgWin(DailyStats &s)    { return s.wins   > 0 ? s.grossProfit / s.wins   : 0.0; }
double StatAvgLoss(DailyStats &s)   { return s.losses > 0 ? s.grossLoss   / s.losses : 0.0; }
double StatPayoff(DailyStats &s)    { double al = StatAvgLoss(s); return al > 0 ? StatAvgWin(s) / al : 0.0; }
double StatProfitFactor(DailyStats &s){ return s.grossLoss > 0 ? s.grossProfit / s.grossLoss : (s.grossProfit > 0 ? 999.0 : 0.0); }
double StatExpectancy(DailyStats &s)
{
    int d = s.wins + s.losses; if(d == 0) return 0.0;
    double wr = (double)s.wins / d;
    return wr * StatAvgWin(s) - (1.0 - wr) * StatAvgLoss(s);
}
string FmtHold(double sec)
{
    int s = (int)sec;
    if(s >= 3600) return StringFormat("%dh%dm", s/3600, (s%3600)/60);
    if(s >= 60)   return StringFormat("%dm%ds", s/60, s%60);
    return (string)s + "s";
}

//+------------------------------------------------------------------+
//| 熔断额度                                                          |
//+------------------------------------------------------------------+
double ScalpDrawdownLimit() { return Inp_DailyMaxDrawdown * (Inp_ScalpDrawdownRatio / 100.0); }
double TrendDrawdownLimit() { return Inp_DailyMaxDrawdown * (Inp_TrendDrawdownRatio / 100.0); }
double TotalDrawdownLimit() { return Inp_DailyMaxDrawdown; }

double BufferedRiskPL(double profitAtStop)
{
    if(profitAtStop >= 0.0) return profitAtStop;
    return profitAtStop * (1.0 + MathMax(0.0, Inp_RiskBufferPercent) / 100.0);
}

void ComputeDailyStats(ENUM_SOP_ORDER kind, DailyStats &s)
{
    ComputeDailyStatsRange(kind, StatStart(), RecoveryNowServer() + 1, s);
}

bool ReconstructAccountBalance(datetime from, datetime to, double &startBalance, double &endBalance, double &peakBalance)
{
    datetime now = RecoveryNowServer() + 1;
    if(to <= from) to = from + 1;
    if(!HistorySelect(from, now)) return false;
    double deltaAfterStart = 0.0;
    long times[]; ulong tickets[]; double amounts[];
    for(int i = 0; i < HistoryDealsTotal(); i++)
    {
        ulong deal = HistoryDealGetTicket(i);
        if(deal == 0) continue;
        datetime dealTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
        double amount = DealCashValue(deal);
        deltaAfterStart += amount;
        if(dealTime >= to) continue;
        int n = ArraySize(times);
        ArrayResize(times, n + 1); ArrayResize(tickets, n + 1); ArrayResize(amounts, n + 1);
        times[n] = HistoryDealGetInteger(deal, DEAL_TIME_MSC);
        tickets[n] = deal;
        amounts[n] = amount;
    }
    for(int i = 1; i < ArraySize(times); i++)
    {
        long tm = times[i]; ulong tk = tickets[i]; double amount = amounts[i]; int j = i - 1;
        while(j >= 0 && (times[j] > tm || (times[j] == tm && tickets[j] > tk)))
        {
            times[j + 1] = times[j]; tickets[j + 1] = tickets[j]; amounts[j + 1] = amounts[j]; j--;
        }
        times[j + 1] = tm; tickets[j + 1] = tk; amounts[j + 1] = amount;
    }
    startBalance = AccountInfoDouble(ACCOUNT_BALANCE) - deltaAfterStart;
    double running = startBalance;
    peakBalance = startBalance;
    for(int i = 0; i < ArraySize(amounts); i++)
    {
        running += amounts[i];
        if(running > peakBalance) peakBalance = running;
    }
    endBalance = running;
    return true;
}

ENUM_ORDER_TYPE PositionOrderType(ENUM_POSITION_TYPE type)
{
    return type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

bool IsBuyOrderType(ENUM_ORDER_TYPE type)
{
    return type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT ||
           type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_STOP_LIMIT;
}

bool IsPendingOrderType(ENUM_ORDER_TYPE type)
{
    return type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT ||
           type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP ||
           type == ORDER_TYPE_BUY_STOP_LIMIT || type == ORDER_TYPE_SELL_STOP_LIMIT;
}

bool IsSupportedRiskOrderType(ENUM_ORDER_TYPE type)
{
    return type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL || IsPendingOrderType(type);
}

ENUM_ORDER_TYPE ProfitCalcOrderType(ENUM_ORDER_TYPE type)
{
    return IsBuyOrderType(type) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

bool CalculateStopPL(ENUM_ORDER_TYPE type, double volume, double entryPrice, double stopPrice,
                     double extraCosts, double &stopPL, string &reason)
{
    stopPL = 0.0;
    if(!IsSupportedRiskOrderType(type) || volume <= 0.0 || entryPrice <= 0.0 || stopPrice <= 0.0)
    {
        reason = Lang("方向、止损、价格或手数无效", "Invalid side, stop, price or volume");
        return false;
    }
    double raw = 0.0;
    ResetLastError();
    if(!OrderCalcProfit(ProfitCalcOrderType(type), _Symbol, volume, entryPrice, stopPrice, raw))
    {
        reason = Lang("无法换算止损风险", "Unable to calculate stop risk") + " #" + (string)GetLastError();
        return false;
    }
    stopPL = BufferedRiskPL(raw + extraCosts);
    return true;
}

bool TradeOperationMaterialized(TradeOperation &op)
{
    if(op.order_ticket > 0 && OrderSelect(op.order_ticket)) return true;
    if(op.deal_ticket > 0 && HistoryDealSelect(op.deal_ticket)) return true;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol &&
           StringFind(PositionGetString(POSITION_COMMENT), op.operation_id) >= 0) return true;
    }
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol &&
           StringFind(OrderGetString(ORDER_COMMENT), op.operation_id) >= 0) return true;
    }
    return false;
}

double RealizedCashByScope(ENUM_SOP_ORDER kind)
{
    if(!HistorySelect(StatStart(), RecoveryNowServer() + 1)) return 0.0;
    double result = 0.0;
    for(int i = 0; i < HistoryDealsTotal(); i++)
    {
        ulong deal = HistoryDealGetTicket(i);
        if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
        ENUM_SOP_ORDER dealKind = DealCashStrategy(deal);
        if(kind != SOP_IGNORE && dealKind != kind) continue;
        result += DealCashValue(deal);
    }
    return result;
}

void InvalidateRiskSnapshot(string reason)
{
    if(g_RiskSnapshotValid)
        g_RiskSnapshotReason = reason;
    else if(g_RiskSnapshotReason == "" || g_RiskSnapshotReason == "尚未计算")
        g_RiskSnapshotReason = reason;
    g_RiskSnapshotValid = false;
}

bool UpdateRiskSnapshot(bool force = false)
{
    datetime now = TimeTradeServer();
    if(now <= 0) now = TimeCurrent();
    if(!force && g_LastRiskSnapshotAt == now) return g_RiskSnapshotValid;
    g_LastRiskSnapshotAt = now;
    g_RiskSnapshotValid = true;
    g_RiskSnapshotReason = "";
    g_ScalpProjectedPL = RealizedCashByScope(SOP_SCALP);
    g_TrendProjectedPL = RealizedCashByScope(SOP_TREND);
    g_SymbolProjectedPL = RealizedCashByScope(SOP_IGNORE);
    g_ScalpProjectedRisk = 0.0;
    g_TrendProjectedRisk = 0.0;
    g_SymbolProjectedRisk = 0.0;
    g_ScalpRiskSlots = 0;
    g_TrendRiskSlots = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        ENUM_SOP_ORDER kind = PosType();
        double stopPL = 0.0; string reason = "";
        if(!CalculateStopPL(PositionOrderType((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)),
                            PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_OPEN),
                            PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_SWAP), stopPL, reason))
        {
            InvalidateRiskSnapshot(Lang("持仓 #", "Position #") + (string)ticket + ": " + reason);
            continue;
        }
        g_SymbolProjectedPL += stopPL;
        if(stopPL < 0.0) g_SymbolProjectedRisk += -stopPL;
        if(kind == SOP_SCALP)
        {
            g_ScalpProjectedPL += stopPL; if(stopPL < 0.0) g_ScalpProjectedRisk += -stopPL; g_ScalpRiskSlots++;
        }
        else if(kind == SOP_TREND)
        {
            g_TrendProjectedPL += stopPL; if(stopPL < 0.0) g_TrendProjectedRisk += -stopPL; g_TrendRiskSlots++;
        }
    }

    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(!IsPendingOrderType(type)) continue;
        ENUM_SOP_ORDER kind = TypeByMagic(OrderGetInteger(ORDER_MAGIC));
        double stopPL = 0.0; string reason = "";
        if(!CalculateStopPL(type, OrderGetDouble(ORDER_VOLUME_CURRENT), OrderGetDouble(ORDER_PRICE_OPEN),
                            OrderGetDouble(ORDER_SL), 0.0, stopPL, reason))
        {
            InvalidateRiskSnapshot(Lang("挂单 #", "Order #") + (string)ticket + ": " + reason);
            continue;
        }
        g_SymbolProjectedPL += stopPL;
        if(stopPL < 0.0) g_SymbolProjectedRisk += -stopPL;
        if(kind == SOP_SCALP)
        {
            g_ScalpProjectedPL += stopPL; if(stopPL < 0.0) g_ScalpProjectedRisk += -stopPL; g_ScalpRiskSlots++;
        }
        else if(kind == SOP_TREND)
        {
            g_TrendProjectedPL += stopPL; if(stopPL < 0.0) g_TrendProjectedRisk += -stopPL; g_TrendRiskSlots++;
        }
    }

    for(int i = 0; i < ArraySize(g_TradeOps); i++)
    {
        TradeOperation op = g_TradeOps[i];
        if(TradeOpIsFinal(op.state) ||
           (op.action != TRADE_OP_OPEN_MARKET && op.action != TRADE_OP_OPEN_LIMIT) ||
           TradeOperationMaterialized(op)) continue;
        ENUM_SOP_ORDER kind = TypeByMagic(op.magic);
        double stopPL = 0.0; string reason = "";
        if(op.requested_order_type < 0 ||
           !CalculateStopPL((ENUM_ORDER_TYPE)op.requested_order_type, op.requested_volume,
                            op.requested_entry_price, op.target_sl, 0.0, stopPL, reason))
        {
            InvalidateRiskSnapshot(Lang("未落地开仓请求 ", "Unmaterialized entry ") + op.operation_id + ": " + reason);
            continue;
        }
        g_SymbolProjectedPL += stopPL;
        if(stopPL < 0.0) g_SymbolProjectedRisk += -stopPL;
        if(kind == SOP_SCALP)
        {
            g_ScalpProjectedPL += stopPL; if(stopPL < 0.0) g_ScalpProjectedRisk += -stopPL; g_ScalpRiskSlots++;
        }
        else if(kind == SOP_TREND)
        {
            g_TrendProjectedPL += stopPL; if(stopPL < 0.0) g_TrendProjectedRisk += -stopPL; g_TrendRiskSlots++;
        }
    }
    return g_RiskSnapshotValid;
}

double ActiveProjectedFloor()
{
    double floor = -TotalDrawdownLimit();
    if(Inp_EnableProfitProtect && g_TodayHighProfit >= Inp_ProfitProtect2_Trigger)
        floor = MathMax(floor, g_TodayHighProfit - Inp_ProfitProtect2_Amount);
    else if(Inp_EnableProfitProtect && g_TodayHighProfit >= Inp_ProfitProtect1_Trigger)
        floor = MathMax(floor, g_TodayHighProfit * (1.0 - Inp_ProfitProtect1_Percent / 100.0));
    return floor;
}

bool ValidateQuoteForEntry(MqlTick &tick, string &reason)
{
    if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
    {
        reason = Lang("报价不可用", "Quote unavailable"); return false;
    }
    datetime now = TimeTradeServer(); if(now <= 0) now = TimeCurrent();
    long ageMsc = (long)now * 1000 - tick.time_msc;
    if(ageMsc < 0) ageMsc = 0;
    if(Inp_MaxQuoteAgeSeconds > 0 && ageMsc > (long)Inp_MaxQuoteAgeSeconds * 1000)
    {
        reason = Lang("报价已过期", "Quote is stale"); return false;
    }
    double spreadPoints = (tick.ask - tick.bid) / _Point;
    if(Inp_MaxEntrySpreadPoints > 0 && spreadPoints > Inp_MaxEntrySpreadPoints + 1e-6)
    {
        reason = Lang("点差过大: ", "Spread too wide: ") + DoubleToString(spreadPoints, 1);
        return false;
    }
    return true;
}

bool ValidateNewRiskCandidate(ENUM_SOP_ORDER kind, ENUM_ORDER_TYPE type, double volume,
                              double entryPrice, double stopPrice)
{
    if(!UpdateRiskSnapshot(true))
    {
        Alert(Lang("【拒绝】风险无法完整计算：", "[REJECT] Risk is unknown: ") + g_RiskSnapshotReason);
        return false;
    }
    double candidatePL = 0.0; string reason = "";
    if(!CalculateStopPL(type, volume, entryPrice, stopPrice, 0.0, candidatePL, reason))
    {
        Alert(Lang("【拒绝】新订单风险无法计算：", "[REJECT] Candidate risk is unknown: ") + reason);
        return false;
    }
    int slots = (kind == SOP_SCALP) ? g_ScalpRiskSlots : g_TrendRiskSlots;
    int maxSlots = (kind == SOP_SCALP) ? Inp_ScalpMaxPositions : Inp_TrendMaxPositions;
    double strategyProjected = (kind == SOP_SCALP ? g_ScalpProjectedPL : g_TrendProjectedPL) + candidatePL;
    double strategyFloor = -(kind == SOP_SCALP ? ScalpDrawdownLimit() : TrendDrawdownLimit());
    if(slots + 1 > maxSlots)
    {
        Alert(Lang("【拒绝】持仓、挂单及待确认请求合计已达策略上限", "[REJECT] Strategy capacity includes positions, orders and pending requests"));
        return false;
    }
    if(strategyProjected < strategyFloor - 0.01)
    {
        Alert(Lang("【拒绝】新增订单将使策略预计止损超过分配额度", "[REJECT] Projected strategy stop exceeds its allocation"));
        return false;
    }
    if(g_SymbolProjectedPL + candidatePL < ActiveProjectedFloor() - 0.01)
    {
        Alert(Lang("【拒绝】新增订单将突破当前品种日回撤/利润保护底线", "[REJECT] Projected symbol stop breaches the daily/moat floor"));
        return false;
    }
    double margin = 0.0;
    ResetLastError();
    if(!OrderCalcMargin(ProfitCalcOrderType(type), _Symbol, volume, entryPrice, margin))
    {
        Alert(Lang("【拒绝】无法计算预计保证金", "[REJECT] Unable to calculate projected margin"));
        return false;
    }
    double projectedMargin = AccountInfoDouble(ACCOUNT_MARGIN) + margin;
    double projectedLevel = projectedMargin > 0.0 ? AccountInfoDouble(ACCOUNT_EQUITY) / projectedMargin * 100.0 : 999999.0;
    if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE) + 0.01 || projectedLevel < Inp_MinProjectedMarginLevel)
    {
        Alert(Lang("【拒绝】开仓后的预计保证金水平不足：", "[REJECT] Projected margin level is insufficient: ") +
              DoubleToString(projectedLevel, 1) + "%");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| 趋势 per-ticket 状态管理                                          |
//+------------------------------------------------------------------+
void MarkTicketStateDirty(bool saveNow = true)
{
    g_ArraysDirty = true;
    if(saveNow && g_InstanceOwnsState)
    {
        SaveArrays();
        g_ArraysDirty = false;
    }
}

int TrIndex(ulong ticket)
{
    for(int i = 0; i < ArraySize(g_TrTicket); i++)
        if(g_TrTicket[i] == ticket) return i;
    return -1;
}

int TrEnsure(ulong ticket)
{
    int idx = TrIndex(ticket);
    if(idx >= 0) return idx;
    int n = ArraySize(g_TrTicket);
    ArrayResize(g_TrTicket, n + 1);
    ArrayResize(g_TrReduced, n + 1);
    ArrayResize(g_TrPeakPoints, n + 1);
    g_TrTicket[n]     = ticket;
    g_TrReduced[n]    = false;
    g_TrPeakPoints[n] = 0.0;
    MarkTicketStateDirty();
    return n;
}

// 清理已不存在的持仓状态
void TrCleanup()
{
    for(int i = ArraySize(g_TrTicket) - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(g_TrTicket[i]))
        {
            int last = ArraySize(g_TrTicket) - 1;
            g_TrTicket[i]     = g_TrTicket[last];
            g_TrReduced[i]    = g_TrReduced[last];
            g_TrPeakPoints[i] = g_TrPeakPoints[last];
            ArrayResize(g_TrTicket, last);
            ArrayResize(g_TrReduced, last);
            ArrayResize(g_TrPeakPoints, last);
            MarkTicketStateDirty(false);
        }
    }
}

//+------------------------------------------------------------------+
//| 剥头皮追踪状态管理                                                |
//+------------------------------------------------------------------+
int ScalpTrackIndex(ulong ticket)
{
    for(int i = 0; i < ArraySize(g_ScalpTrackTicket); i++)
        if(g_ScalpTrackTicket[i] == ticket) return i;
    return -1;
}

int ScalpTrackEnsure(ulong ticket)
{
    int idx = ScalpTrackIndex(ticket);
    if(idx >= 0) return idx;
    int n = ArraySize(g_ScalpTrackTicket);
    ArrayResize(g_ScalpTrackTicket, n + 1);
    ArrayResize(g_ScalpTrackPeak, n + 1);
    ArrayResize(g_ScalpTrackLoggedPeak, n + 1);
    g_ScalpTrackTicket[n] = ticket;
    g_ScalpTrackPeak[n]   = 0.0;
    g_ScalpTrackLoggedPeak[n] = 0.0;
    MarkTicketStateDirty(false);
    return n;
}

void ScalpTrackCleanup()
{
    for(int i = ArraySize(g_ScalpTrackTicket) - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(g_ScalpTrackTicket[i]))
        {
            int last = ArraySize(g_ScalpTrackTicket) - 1;
            g_ScalpTrackTicket[i] = g_ScalpTrackTicket[last];
            g_ScalpTrackPeak[i]   = g_ScalpTrackPeak[last];
            g_ScalpTrackLoggedPeak[i] = g_ScalpTrackLoggedPeak[last];
            ArrayResize(g_ScalpTrackTicket, last);
            ArrayResize(g_ScalpTrackPeak, last);
            ArrayResize(g_ScalpTrackLoggedPeak, last);
            MarkTicketStateDirty(false);
        }
    }
}

//+------------------------------------------------------------------+
//| 旧版 promoted 标记仅用于迁移为“追踪持有”，不再产生新记录         |
//+------------------------------------------------------------------+
bool IsPromoted(ulong ticket)
{
    for(int i = 0; i < ArraySize(g_PromotedTickets); i++)
        if(g_PromotedTickets[i] == ticket) return true;
    return false;
}

//+------------------------------------------------------------------+
//| 超时强平取消集合(用户点"取消倒计时"后加入,该单不再超时强平)     |
//+------------------------------------------------------------------+
bool IsTimeoutCancelled(ulong ticket)
{
    for(int i = 0; i < ArraySize(g_TimeoutCancelled); i++)
        if(g_TimeoutCancelled[i] == ticket) return true;
    return false;
}
void AddTimeoutCancelled(ulong ticket)
{
    if(IsTimeoutCancelled(ticket)) return;
    int n = ArraySize(g_TimeoutCancelled);
    ArrayResize(g_TimeoutCancelled, n + 1);
    g_TimeoutCancelled[n] = ticket;
    MarkTicketStateDirty();
}
void TimeoutCancelCleanup()
{
    for(int i = ArraySize(g_TimeoutCancelled) - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(g_TimeoutCancelled[i]))
        {
            int last = ArraySize(g_TimeoutCancelled) - 1;
            g_TimeoutCancelled[i] = g_TimeoutCancelled[last];
            ArrayResize(g_TimeoutCancelled, last);
            MarkTicketStateDirty(false);
        }
    }
}

ENUM_SCALP_PHASE ScalpPhaseForTicket(ulong ticket)
{
    int idx = TicketStateIndex(ticket);
    if(idx < 0) return SCALP_INITIAL;
    return (ENUM_SCALP_PHASE)g_TicketState[idx].scalp_phase;
}

bool IsScalpTrailActive(ulong ticket)
{
    return ScalpPhaseForTicket(ticket) == SCALP_TRAIL_ACTIVE;
}

bool HasScalpExitPending()
{
    for(int i = 0; i < ArraySize(g_TicketState); i++)
    {
        if(g_TicketState[i].closed_utc != 0 || g_TicketState[i].scalp_phase != SCALP_EXIT_PENDING) continue;
        if(PositionSelectByTicket(g_TicketState[i].ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
    }
    return false;
}

string ScalpExitReasonText(int reason)
{
    if(reason == SCALP_EXIT_TIMEOUT) return Lang("超时", "timeout");
    if(reason == SCALP_EXIT_PULLBACK) return Lang("峰值回撤", "peak pullback");
    return Lang("未知", "unknown");
}

//+------------------------------------------------------------------+
//| 服务器保护闭环                                                    |
//+------------------------------------------------------------------+
double MinimumProtectionSL(ENUM_SOP_ORDER kind, ENUM_POSITION_TYPE type, double openPrice)
{
    double slPoints = (kind == SOP_SCALP) ? Inp_ScalpSL_Points : Inp_TrendSL_Points;
    double raw = (type == POSITION_TYPE_BUY)
               ? openPrice - PointsToPrice(slPoints)
               : openPrice + PointsToPrice(slPoints);
    return NormalizeProtectionPrice(raw, type);
}

bool IsSLAtLeastAsSafe(ENUM_POSITION_TYPE type, double actualSL, double requiredSL)
{
    if(actualSL <= 0.0 || requiredSL <= 0.0) return false;
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickSize <= 0.0) tickSize = _Point;
    double tolerance = MathMax(_Point, tickSize) * 0.5;
    return (type == POSITION_TYPE_BUY)
           ? actualSL + tolerance >= requiredSL
           : actualSL - tolerance <= requiredSL;
}

double StrongerSL(ENUM_POSITION_TYPE type, double a, double b)
{
    if(a <= 0.0) return b;
    if(b <= 0.0) return a;
    return (type == POSITION_TYPE_BUY) ? MathMax(a, b) : MathMin(a, b);
}

int ProtectionRetryDelaySeconds(int retryCount)
{
    if(retryCount <= 1) return 1;
    if(retryCount == 2) return 2;
    return 4;
}

bool IsPositionProtectionConfirmed(ulong ticket)
{
    if(!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
    ENUM_SOP_ORDER kind = PosType();
    if(kind == SOP_IGNORE) return false;
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double baseline = MinimumProtectionSL(kind, type, PositionGetDouble(POSITION_PRICE_OPEN));
    int idx = TicketStateIndex(ticket);
    double required = baseline;
    if(idx >= 0) required = StrongerSL(type, required, g_TicketState[idx].last_confirmed_sl);
    return IsSLAtLeastAsSafe(type, PositionGetDouble(POSITION_SL), required);
}

bool TryRepairPositionProtection(ulong ticket, double requiredSL, double requiredTP, uint &retcode)
{
    retcode = 0;
    if(!PositionSelectByTicket(ticket)) return true;
    double curTP = PositionGetDouble(POSITION_TP);
    double targetTP = (requiredTP > 0.0 && curTP <= 0.0) ? requiredTP : curTP;
    int opIdx = TrackModifyOperation(ticket, requiredSL, targetTP, "protection_modify", true);
    if(opIdx >= 0 && g_TradeOps[opIdx].state == TRADE_OP_CREATED) SubmitTradeOperation(opIdx);
    if(opIdx >= 0) retcode = g_TradeOps[opIdx].last_retcode;
    return opIdx >= 0 && TradeOperationSatisfied(opIdx);
}

bool TryEmergencyClosePosition(ulong ticket, uint &retcode)
{
    retcode = 0;
    if(!PositionSelectByTicket(ticket)) return true;
    int opIdx = EnsureCloseOperation(ticket, "protection_exit", NewTradeBatchId("protection_exit"), false);
    if(opIdx >= 0) retcode = g_TradeOps[opIdx].last_retcode;
    PrintFormat("[Protection] 安全退出已纳入交易闭环 ticket=%I64u op=%s retcode=%u",
                ticket, opIdx >= 0 ? g_TradeOps[opIdx].operation_id : "existing", retcode);
    return !PositionSelectByTicket(ticket);
}

int UnsafeOrderIndex(ulong ticket)
{
    for(int i = 0; i < ArraySize(g_UnsafeOrderTicket); i++)
        if(g_UnsafeOrderTicket[i] == ticket) return i;
    return -1;
}

int EnsureUnsafeOrder(ulong ticket, long nowMsc)
{
    int idx = UnsafeOrderIndex(ticket);
    if(idx >= 0) return idx;
    int n = ArraySize(g_UnsafeOrderTicket);
    ArrayResize(g_UnsafeOrderTicket, n + 1);
    ArrayResize(g_UnsafeOrderFirstFailedMsc, n + 1);
    ArrayResize(g_UnsafeOrderNextRetryMsc, n + 1);
    ArrayResize(g_UnsafeOrderRetryCount, n + 1);
    g_UnsafeOrderTicket[n] = ticket;
    g_UnsafeOrderFirstFailedMsc[n] = nowMsc;
    g_UnsafeOrderNextRetryMsc[n] = 0;
    g_UnsafeOrderRetryCount[n] = 0;
    return n;
}

void RemoveUnsafeOrderAt(int idx)
{
    int last = ArraySize(g_UnsafeOrderTicket) - 1;
    if(idx < 0 || idx > last) return;
    g_UnsafeOrderTicket[idx] = g_UnsafeOrderTicket[last];
    g_UnsafeOrderFirstFailedMsc[idx] = g_UnsafeOrderFirstFailedMsc[last];
    g_UnsafeOrderNextRetryMsc[idx] = g_UnsafeOrderNextRetryMsc[last];
    g_UnsafeOrderRetryCount[idx] = g_UnsafeOrderRetryCount[last];
    ArrayResize(g_UnsafeOrderTicket, last);
    ArrayResize(g_UnsafeOrderFirstFailedMsc, last);
    ArrayResize(g_UnsafeOrderNextRetryMsc, last);
    ArrayResize(g_UnsafeOrderRetryCount, last);
}

ENUM_SOP_ORDER SelectedOrderKind()
{
    long magic = OrderGetInteger(ORDER_MAGIC);
    if(magic == Inp_MagicScalp) return SOP_SCALP;
    if(magic == Inp_MagicTrend) return SOP_TREND;
    return SOP_IGNORE;
}

bool SelectedOrderIsBuy()
{
    ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
    return type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_STOP_LIMIT;
}

bool SelectedOrderProtectionSafe(ENUM_SOP_ORDER kind, double &requiredSL, double &requiredTP)
{
    bool isBuy = SelectedOrderIsBuy();
    ENUM_POSITION_TYPE posType = isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    double open = OrderGetDouble(ORDER_PRICE_OPEN);
    requiredSL = MinimumProtectionSL(kind, posType, open);
    requiredTP = 0.0;
    if(kind == SOP_SCALP && Inp_ScalpTP_Points > 0)
        requiredTP = NormalizePrice(isBuy ? open + PointsToPrice(Inp_ScalpTP_Points)
                                          : open - PointsToPrice(Inp_ScalpTP_Points));
    bool slSafe = IsSLAtLeastAsSafe(posType, OrderGetDouble(ORDER_SL), requiredSL);
    bool tpSafe = requiredTP <= 0.0 || OrderGetDouble(ORDER_TP) > 0.0;
    return slSafe && tpSafe;
}

bool TryRepairSelectedOrder(ulong ticket, double requiredSL, double requiredTP, uint &retcode)
{
    retcode = 0;
    if(!OrderSelect(ticket)) return true;
    double tp = requiredTP > 0.0 ? requiredTP : OrderGetDouble(ORDER_TP);
    int opIdx = TrackOrderModifyOperation(ticket, requiredSL, tp, "protection_order_modify");
    if(opIdx >= 0 && g_TradeOps[opIdx].state == TRADE_OP_CREATED) SubmitTradeOperation(opIdx);
    if(opIdx >= 0) retcode = g_TradeOps[opIdx].last_retcode;
    return opIdx >= 0 && TradeOperationSatisfied(opIdx);
}

bool ValidateEntryProtection(ENUM_SOP_ORDER kind, bool isBuy, double entryPrice, bool pendingOrder)
{
    if(!g_AccountModeSupported)
    {
        Alert(Lang("【拒绝】当前版本仅支持对冲账户", "[REJECT] Hedging accounts only"));
        return false;
    }
    int slPoints = (kind == SOP_SCALP) ? Inp_ScalpSL_Points : Inp_TrendSL_Points;
    if(slPoints <= 0)
    {
        Alert(Lang("【拒绝】初始止损必须大于0", "[REJECT] Initial SL must be greater than zero"));
        return false;
    }
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if(entryPrice <= 0.0 || tickSize <= 0.0)
    {
        Alert(Lang("【拒绝】报价或品种最小变动单位无效", "[REJECT] Invalid quote or tick size"));
        return false;
    }
    double minDistance = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    double configured = PointsToPrice(slPoints);
    if(configured + tickSize * 0.5 < minDistance)
    {
        Alert(StringFormat(Lang("【拒绝】配置止损距离 %.2f 小于券商最小距离 %.2f",
                                "[REJECT] Configured SL distance %.2f is below broker minimum %.2f"),
                           configured, minDistance));
        return false;
    }
    if(!pendingOrder)
    {
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        ENUM_POSITION_TYPE type = isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        double sl = MinimumProtectionSL(kind, type, entryPrice);
        double distance = isBuy ? bid - sl : sl - ask;
        if(bid <= 0.0 || ask <= 0.0 || distance + tickSize * 0.5 < minDistance)
        {
            Alert(Lang("【拒绝】当前报价下初始止损不满足券商最小距离", "[REJECT] Initial SL violates broker stop distance"));
            return false;
        }
    }
    return true;
}

void AuditServerProtection()
{
    if(!g_InstanceOwnsState) return;
    long nowMsc = ProtectionNowMsc();
    int issues = 0;
    bool stateChanged = false;

    g_AccountModeSupported = ((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
    if(!g_AccountModeSupported) issues++;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        ENUM_SOP_ORDER kind = PosType();
        if(kind == SOP_IGNORE) continue;

        int idx = EnsureTicketStateRecord(ticket);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double actualSL = PositionGetDouble(POSITION_SL);
        double actualTP = PositionGetDouble(POSITION_TP);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double baseline = MinimumProtectionSL(kind, type, openPrice);
        double required = StrongerSL(type, baseline, g_TicketState[idx].last_confirmed_sl);
        // 若SL已经更优、但只是TP缺失，修复TP时也绝不能把现有SL放宽回初始线。
        if(IsSLAtLeastAsSafe(type, actualSL, required))
            required = StrongerSL(type, required, actualSL);
        if(kind == SOP_SCALP)
        {
            if(g_TicketState[idx].scalp_tp_policy == SCALP_TP_REMOVE_PENDING)
            {
                // 以服务器最终状态收敛；账本仍在处理时不得把异步请求误判为失败。
                if(actualTP == 0.0 && IsSLAtLeastAsSafe(type, actualSL, required))
                {
                    g_TicketState[idx].scalp_tp_policy = SCALP_TP_REMOVED;
                    PrintFormat("[Scalp TP] Ticket=%I64u PENDING -> REMOVED，服务器已确认", ticket);
                    stateChanged = true;
                }
                else
                {
                    int tpOpIdx = ActiveTradeOpIndex(TRADE_OP_MODIFY, ticket);
                    bool requestPending = tpOpIdx >= 0 && g_TradeOps[tpOpIdx].source == "scalp_let_run";
                    if(!requestPending)
                    {
                        g_TicketState[idx].scalp_tp_policy = SCALP_TP_REQUIRED;
                        PrintFormat("[Scalp TP] Ticket=%I64u PENDING -> REQUIRED，撤除未确认", ticket);
                        stateChanged = true;
                    }
                }
            }
            else if(g_TicketState[idx].scalp_tp_policy == SCALP_TP_REMOVED && actualTP > 0.0)
            {
                // 用户重新设置TP后恢复强制保护语义；以后再删除需重新明确授权。
                g_TicketState[idx].scalp_tp_policy = SCALP_TP_REQUIRED;
                stateChanged = true;
                PrintFormat("[Scalp TP] Ticket=%I64u REMOVED -> REQUIRED，检测到用户重新设置TP", ticket);
            }
        }
        bool tpRequired = kind == SOP_SCALP && Inp_ScalpTP_Points > 0 &&
                          g_TicketState[idx].scalp_tp_policy == SCALP_TP_REQUIRED &&
                          ScalpPhaseForTicket(ticket) != SCALP_EXIT_PENDING;
        double requiredTP = tpRequired
                          ? NormalizePrice(type == POSITION_TYPE_BUY
                              ? openPrice + PointsToPrice(Inp_ScalpTP_Points)
                              : openPrice - PointsToPrice(Inp_ScalpTP_Points))
                          : 0.0;
        g_TicketState[idx].minimum_required_sl = required;

        if(IsSLAtLeastAsSafe(type, actualSL, required) && (!tpRequired || actualTP > 0.0))
        {
            double confirmed = StrongerSL(type, g_TicketState[idx].last_confirmed_sl, actualSL);
            if(g_TicketState[idx].protection_status != PROTECTION_CONFIRMED ||
               MathAbs(g_TicketState[idx].last_confirmed_sl - confirmed) > _Point * 0.5)
                stateChanged = true;
            g_TicketState[idx].protection_status = PROTECTION_CONFIRMED;
            g_TicketState[idx].last_confirmed_sl = confirmed;
            g_TicketState[idx].last_confirmed_tp = actualTP;
            g_TicketState[idx].protection_first_failed_utc_msc = 0;
            g_TicketState[idx].protection_next_retry_utc_msc = 0;
            g_TicketState[idx].protection_retry_count = 0;
            g_TicketState[idx].protection_last_retcode = 0;
            continue;
        }

        issues++;
        if(g_TicketState[idx].protection_first_failed_utc_msc <= 0)
        {
            g_TicketState[idx].protection_first_failed_utc_msc = nowMsc;
            g_TicketState[idx].protection_next_retry_utc_msc = 0;
            g_TicketState[idx].protection_retry_count = 0;
            g_TicketState[idx].protection_status = PROTECTION_REPAIR_PENDING;
            stateChanged = true;
            PrintFormat("[Protection] 检测到保护未达标 ticket=%I64u requiredSL=%.5f actualSL=%.5f requiredTP=%.5f actualTP=%.5f",
                        ticket, required, actualSL, requiredTP, actualTP);
        }

        long elapsed = nowMsc - g_TicketState[idx].protection_first_failed_utc_msc;
        if(elapsed < 8000 && nowMsc >= g_TicketState[idx].protection_next_retry_utc_msc)
        {
            uint retcode = 0;
            g_TicketState[idx].protection_retry_count++;
            bool repaired = TryRepairPositionProtection(ticket, required, requiredTP, retcode);
            g_TicketState[idx].protection_last_retcode = retcode;
            g_TicketState[idx].protection_next_retry_utc_msc = nowMsc +
                (long)ProtectionRetryDelaySeconds(g_TicketState[idx].protection_retry_count) * 1000;
            stateChanged = true;
            if(repaired) continue;
        }

        bool firstCloseDue = elapsed >= 8000 &&
                             g_TicketState[idx].protection_status == PROTECTION_REPAIR_PENDING;
        if(elapsed >= 8000 && (firstCloseDue || nowMsc >= g_TicketState[idx].protection_next_retry_utc_msc))
        {
            bool firstClose = g_TicketState[idx].protection_status != PROTECTION_CLOSE_PENDING &&
                              g_TicketState[idx].protection_status != PROTECTION_FAILED;
            g_TicketState[idx].protection_status = (elapsed >= 16000) ? PROTECTION_FAILED : PROTECTION_CLOSE_PENDING;
            uint retcode = 0;
            TryEmergencyClosePosition(ticket, retcode);
            g_TicketState[idx].protection_last_retcode = retcode;
            g_TicketState[idx].protection_next_retry_utc_msc = nowMsc + 4000;
            stateChanged = true;
            if(firstClose)
                Alert(StringFormat(Lang("【保护异常】Ticket %I64u 无法确认止损，正在强制退出",
                                        "[PROTECTION] Ticket %I64u has no confirmed SL; forcing exit"), ticket));
        }
    }

    // 审计本实例策略挂单；不安全挂单修复超时后撤销。
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        ENUM_SOP_ORDER kind = SelectedOrderKind();
        if(kind == SOP_IGNORE) continue;
        double requiredSL, requiredTP;
        if(SelectedOrderProtectionSafe(kind, requiredSL, requiredTP))
        {
            int safeIdx = UnsafeOrderIndex(ticket);
            if(safeIdx >= 0) RemoveUnsafeOrderAt(safeIdx);
            continue;
        }

        issues++;
        int unsafeIdx = EnsureUnsafeOrder(ticket, nowMsc);
        long elapsed = nowMsc - g_UnsafeOrderFirstFailedMsc[unsafeIdx];
        if(elapsed < 8000 && nowMsc >= g_UnsafeOrderNextRetryMsc[unsafeIdx])
        {
            uint retcode = 0;
            g_UnsafeOrderRetryCount[unsafeIdx]++;
            TryRepairSelectedOrder(ticket, requiredSL, requiredTP, retcode);
            g_UnsafeOrderNextRetryMsc[unsafeIdx] = nowMsc +
                (long)ProtectionRetryDelaySeconds(g_UnsafeOrderRetryCount[unsafeIdx]) * 1000;
        }
        else if(elapsed >= 8000 &&
                (g_UnsafeOrderRetryCount[unsafeIdx] >= 0 || nowMsc >= g_UnsafeOrderNextRetryMsc[unsafeIdx]))
        {
            int opIdx = EnsureDeleteOperation(ticket, "protection_delete", NewTradeBatchId("protection_delete"), false);
            uint retcode = (opIdx >= 0) ? g_TradeOps[opIdx].last_retcode : 0;
            PrintFormat("[Protection] 不安全挂单撤销已纳入交易闭环 ticket=%I64u retcode=%u", ticket, retcode);
            g_UnsafeOrderRetryCount[unsafeIdx] = -1; // 标记已进入撤单阶段，后续按4秒节流核对
            g_UnsafeOrderNextRetryMsc[unsafeIdx] = nowMsc + 4000;
        }
    }

    // 清理已经不存在的挂单故障记录。
    for(int i = ArraySize(g_UnsafeOrderTicket) - 1; i >= 0; i--)
        if(!OrderSelect(g_UnsafeOrderTicket[i])) RemoveUnsafeOrderAt(i);

    g_ProtectionIssueCount = issues;
    g_ProtectionBlocksNewRisk = (issues > 0);
    if(!g_AccountModeSupported)
        g_ProtectionReason = Lang("仅支持对冲账户", "Hedging account required");
    else if(issues > 0)
        g_ProtectionReason = Lang("服务器保护异常", "Protection pending");
    else
        g_ProtectionReason = "";

    if(stateChanged)
    {
        g_ArraysDirty = true;
        if(!g_StatePersistenceBlocked) SaveArrays();
    }
}

//+------------------------------------------------------------------+
//| 修改止损                                                          |
//+------------------------------------------------------------------+
bool ModifyPositionSL(ulong ticket, double newSL)
{
    if(!PositionSelectByTicket(ticket)) return false;
    double curTP = PositionGetDouble(POSITION_TP);
    newSL = NormalizePrice(newSL);
    double curSL = PositionGetDouble(POSITION_SL);
    if(MathAbs(curSL - newSL) < _Point) return true; // 无变化
    int opIdx = TrackModifyOperation(ticket, newSL, curTP, "trailing_sl", true);
    if(opIdx >= 0 && g_TradeOps[opIdx].state == TRADE_OP_CREATED) SubmitTradeOperation(opIdx);
    return opIdx >= 0 && TradeOperationSatisfied(opIdx);
}

bool IsScalpLetRunEligible(ulong ticket)
{
    if(!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
    if(PosType() != SOP_SCALP || !IsScalpTrailActive(ticket)) return false;
    int idx = TicketStateIndex(ticket);
    if(idx < 0 || g_TicketState[idx].scalp_tp_policy != SCALP_TP_REQUIRED) return false;
    if(PositionGetDouble(POSITION_TP) == 0.0) return false;
    return IsPositionProtectionConfirmed(ticket);
}

bool HasEligibleScalpLetRun()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && IsScalpLetRunEligible(ticket)) return true;
    }
    return false;
}

// “追踪持有”：用户明确授权后撤除固定TP，订单仍使用剥头皮峰值追踪。
void EnableScalpLetRun()
{
    ulong tickets[];
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || !IsScalpLetRunEligible(ticket)) continue;
        int n = ArraySize(tickets);
        ArrayResize(tickets, n + 1);
        tickets[n] = ticket;
    }

    int eligible = ArraySize(tickets);
    if(eligible == 0)
    {
        Alert(Lang("当前没有可追踪持有的剥头皮订单：需已激活追踪、保留TP且服务器SL已确认。",
                   "No eligible scalp position: trail must be active with TP and confirmed server SL."));
        return;
    }

    string message = StringFormat(
        Lang("将对当前品种 %d 张剥头皮订单启用“追踪持有”。\n\n固定止盈将被撤除，订单继续由峰值回撤和服务器止损管理。MT5或EA停止运行时，动态追踪无法继续。\n\n是否继续？",
             "Enable LET RUN for %d scalp position(s) on this symbol?\n\nFixed TP will be removed. Peak pullback and server SL remain active. Dynamic trailing stops when MT5 or the EA is offline.\n\nContinue?"),
        eligible);
    if(MessageBox(message, Lang("确认追踪持有", "Confirm LET RUN"),
                  MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2) != IDYES)
        return;

    int submitted = 0, failed = 0, skipped = 0;
    for(int i = 0; i < eligible; i++)
    {
        ulong ticket = tickets[i];
        if(!IsScalpLetRunEligible(ticket)) { skipped++; continue; }
        int idx = TicketStateIndex(ticket);
        if(idx < 0 || !PositionSelectByTicket(ticket)) { skipped++; continue; }
        double currentSL = PositionGetDouble(POSITION_SL);

        g_TicketState[idx].scalp_tp_policy = SCALP_TP_REMOVE_PENDING;
        g_TicketState[idx].scalp_tp_requested_utc_msc = ProtectionNowMsc();
        g_TicketState[idx].scalp_tp_last_retcode = 0;
        MarkTicketStateDirty(); // 先持久化意图，避免中断后误判为外部删TP

        int opIdx = TrackModifyOperation(ticket, currentSL, 0.0, "scalp_let_run", true);
        if(opIdx >= 0 && g_TradeOps[opIdx].state == TRADE_OP_CREATED) SubmitTradeOperation(opIdx);
        idx = TicketStateIndex(ticket);
        if(idx < 0) { skipped++; continue; }
        if(opIdx >= 0)
        {
            g_TicketState[idx].scalp_tp_last_retcode = g_TradeOps[opIdx].last_retcode;
            submitted++;
        }
        else failed++;
        MarkTicketStateDirty();
    }

    if(failed > 0) AuditServerProtection();
    Alert(StringFormat(Lang("追踪持有请求：已提交 %d，提交失败 %d，跳过 %d。服务器确认后才会正式生效。",
                            "LET RUN requests: %d submitted, %d failed, %d skipped. Changes take effect only after server confirmation."),
                       submitted, failed, skipped));
}

void ActivateScalpTrail(ulong ticket, double profitPoints)
{
    int trackIdx = ScalpTrackEnsure(ticket);
    g_ScalpTrackPeak[trackIdx] = MathMax(g_ScalpTrackPeak[trackIdx], profitPoints);
    g_ScalpTrackLoggedPeak[trackIdx] = g_ScalpTrackPeak[trackIdx];

    int stateIdx = EnsureTicketStateRecord(ticket);
    g_TicketState[stateIdx].scalp_phase = SCALP_TRAIL_ACTIVE;
    g_TicketState[stateIdx].scalp_track_active = true;
    g_TicketState[stateIdx].scalp_peak_points = g_ScalpTrackPeak[trackIdx];
    g_TicketState[stateIdx].scalp_exit_reason = SCALP_EXIT_NONE;
    g_TicketState[stateIdx].scalp_exit_requested_utc_msc = 0;
    g_TicketState[stateIdx].scalp_exit_next_retry_utc_msc = 0;
    g_TicketState[stateIdx].scalp_exit_retry_count = 0;
    g_TicketState[stateIdx].scalp_exit_last_retcode = 0;
    PrintFormat("[Scalp State] Ticket=%I64u INITIAL -> TRAIL_ACTIVE，首次峰值=%.1f点",
                ticket, g_ScalpTrackPeak[trackIdx]);
    MarkTicketStateDirty(); // 阶段与首次峰值一次原子保存
}

void ProcessScalpExit(ulong ticket)
{
    int idx = TicketStateIndex(ticket);
    if(idx < 0 || g_TicketState[idx].scalp_phase != SCALP_EXIT_PENDING) return;
    if(!PositionSelectByTicket(ticket))
    {
        g_TicketState[idx].scalp_phase = SCALP_CLOSED;
        g_TicketState[idx].closed_utc = TimeGMT();
        PrintFormat("[Scalp State] Ticket=%I64u EXIT_PENDING -> CLOSED，原因=%s",
                    ticket, ScalpExitReasonText(g_TicketState[idx].scalp_exit_reason));
        MarkTicketStateDirty();
        return;
    }

    string source = (g_TicketState[idx].scalp_exit_reason == SCALP_EXIT_TIMEOUT)
                  ? "scalp_timeout" : "scalp_pullback";
    int opIdx = EnsureCloseOperation(ticket, source, NewTradeBatchId(source), false);
    if(opIdx >= 0)
    {
        g_TicketState[idx].scalp_exit_retry_count = g_TradeOps[opIdx].retry_count;
        g_TicketState[idx].scalp_exit_last_retcode = g_TradeOps[opIdx].last_retcode;
        g_TicketState[idx].scalp_exit_next_retry_utc_msc = g_TradeOps[opIdx].next_retry_utc_msc;
    }
    MarkTicketStateDirty();
}

// 即使行情暂时没有新 Tick，也由定时器持续推进已经进入退出阶段的订单。
void ProcessPendingScalpExits()
{
    ulong pendingTickets[];
    for(int i = 0; i < ArraySize(g_TicketState); i++)
    {
        if(g_TicketState[i].closed_utc != 0 ||
           g_TicketState[i].scalp_phase != SCALP_EXIT_PENDING)
            continue;
        int n = ArraySize(pendingTickets);
        ArrayResize(pendingTickets, n + 1);
        pendingTickets[n] = g_TicketState[i].ticket;
    }

    // 使用快照，避免成交回调刷新状态数组时影响当前遍历。
    for(int i = 0; i < ArraySize(pendingTickets); i++)
        ProcessScalpExit(pendingTickets[i]);
}

void BeginScalpExit(ulong ticket, ENUM_SCALP_EXIT_REASON reason, double peakPoints, double profitPoints)
{
    int idx = EnsureTicketStateRecord(ticket);
    if(g_TicketState[idx].scalp_phase == SCALP_CLOSED) return;
    if(g_TicketState[idx].scalp_phase != SCALP_EXIT_PENDING)
    {
        g_TicketState[idx].scalp_phase = SCALP_EXIT_PENDING;
        g_TicketState[idx].scalp_exit_reason = reason;
        g_TicketState[idx].scalp_exit_requested_utc_msc = ProtectionNowMsc();
        g_TicketState[idx].scalp_exit_next_retry_utc_msc = 0;
        g_TicketState[idx].scalp_exit_retry_count = 0;
        g_TicketState[idx].scalp_exit_last_retcode = 0;
        PrintFormat("[Scalp State] Ticket=%I64u -> EXIT_PENDING，原因=%s 峰值=%.1f 当前=%.1f 回撤=%.1f",
                    ticket, ScalpExitReasonText(reason), peakPoints, profitPoints,
                    MathMax(0.0, peakPoints - profitPoints));
        MarkTicketStateDirty();
    }
    ProcessScalpExit(ticket);
}

//+------------------------------------------------------------------+
//| 剥头皮单向状态机：INITIAL -> TRAIL_ACTIVE -> EXIT_PENDING        |
//+------------------------------------------------------------------+
void ManageScalpTrailingStop(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    int stateIdx = EnsureTicketStateRecord(ticket);
    ENUM_SCALP_PHASE phase = (ENUM_SCALP_PHASE)g_TicketState[stateIdx].scalp_phase;
    if(phase == SCALP_CLOSED) return;
    if(phase == SCALP_EXIT_PENDING)
    {
        ProcessScalpExit(ticket);
        return;
    }

    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double open = PositionGetDouble(POSITION_PRICE_OPEN);
    double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double profitPoints = (type == POSITION_TYPE_BUY) ? (bid - open) / 0.01 : (open - ask) / 0.01;

    if(phase == SCALP_INITIAL)
    {
        // 超时只约束尚未进入盈利追踪的订单；截止时间基于服务器开仓时间，重启不重置。
        if(Inp_ScalpTimeLimitOn && !IsTimeoutCancelled(ticket))
        {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            if((int)(TimeCurrent() - openTime) >= Inp_ScalpMaxHoldSecs)
            {
                BeginScalpExit(ticket, SCALP_EXIT_TIMEOUT, 0.0, profitPoints);
                return;
            }
        }
        if(profitPoints < (double)Inp_ScalpBETrigger - 0.5) return;
        ActivateScalpTrail(ticket, profitPoints);
        stateIdx = TicketStateIndex(ticket); // 原子保存可能清理旧记录，重新取得稳定索引
        if(stateIdx < 0) return;
        phase = SCALP_TRAIL_ACTIVE;
    }

    // 激活后不再检查启动阈值；即使当前浮盈跌回阈值以下也继续使用历史峰值。
    if(phase != SCALP_TRAIL_ACTIVE) return;
    int trackIdx = ScalpTrackEnsure(ticket);
    g_ScalpTrackPeak[trackIdx] = MathMax(g_ScalpTrackPeak[trackIdx],
                                         g_TicketState[stateIdx].scalp_peak_points);
    if(profitPoints > g_ScalpTrackPeak[trackIdx])
    {
        double oldPeak = g_ScalpTrackPeak[trackIdx];
        g_ScalpTrackPeak[trackIdx] = profitPoints;
        g_TicketState[stateIdx].scalp_peak_points = profitPoints;
        if(profitPoints - g_ScalpTrackLoggedPeak[trackIdx] >= 10.0)
        {
            PrintFormat("[Scalp Peak] Ticket=%I64u %.1f -> %.1f点", ticket, oldPeak, profitPoints);
            g_ScalpTrackLoggedPeak[trackIdx] = profitPoints;
        }
        MarkTicketStateDirty();
    }

    double peak = g_ScalpTrackPeak[trackIdx];
    double pullback = peak - profitPoints;
    if(pullback >= Inp_ScalpTrailStep)
    {
        BeginScalpExit(ticket, SCALP_EXIT_PULLBACK, peak, profitPoints);
        return;
    }

    double protectedPoints = MathMax(0.0, peak - Inp_ScalpTrailStep);
    double targetSL = (type == POSITION_TYPE_BUY)
                    ? open + PointsToPrice(protectedPoints)
                    : open - PointsToPrice(protectedPoints);
    double curSL = PositionGetDouble(POSITION_SL);
    bool better = (type == POSITION_TYPE_BUY)
                ? targetSL > curSL + _Point
                : (curSL == 0.0 || targetSL < curSL - _Point);
    if(better) ModifyPositionSL(ticket, targetSL);
}

//+------------------------------------------------------------------+
//| 趋势移动止损(SOP 追踪版)                                         |
//+------------------------------------------------------------------+
void ManageTrendTrailingStop(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    long type   = PositionGetInteger(POSITION_TYPE);
    double open = PositionGetDouble(POSITION_PRICE_OPEN);
    double vol  = PositionGetDouble(POSITION_VOLUME);

    double cur = (type == POSITION_TYPE_BUY)
               ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // 当前浮盈点数(标准点: 1点=0.01)
    double profitPoints = (type == POSITION_TYPE_BUY)
                        ? (cur - open) / 0.01
                        : (open - cur) / 0.01;

    int idx = TrEnsure(ticket);

    // ---- 追踪阶段:达触发点后,价格每涨则推止损,回撤达阈值出局 ----
    if(profitPoints >= Inp_TrendTrailTrigger)
    {
        // 记录浮盈峰值(用于判定回撤)
        if(profitPoints > g_TrPeakPoints[idx]) { g_TrPeakPoints[idx] = profitPoints; MarkTicketStateDirty(); }

        // 回撤达阈值 → 平仓离场
        if(g_TrPeakPoints[idx] - profitPoints >= Inp_TrendTrailStep)
        {
            EnsureCloseOperation(ticket, "trend_pullback", NewTradeBatchId("trend_pullback"), false);
            return;
        }

        // 动态推止损:价格每涨则推,距当前价固定距离(跟涨不跟跌)
        double trailDist = PointsToPrice(Inp_TrendTrailStep); // 止损距当前价的固定距离
        double targetSL = (type == POSITION_TYPE_BUY)
                        ? cur - trailDist    // 多单:止损在当前Bid下方N点
                        : cur + trailDist;   // 空单:止损在当前Ask上方N点
        double curSL = PositionGetDouble(POSITION_SL);

        // 只有新止损"更优"(多单更高/空单更低)才修改
        bool better = (type == POSITION_TYPE_BUY)
                    ? (targetSL > curSL + _Point)           // 多单:新SL比旧SL高
                    : (curSL == 0.0 || targetSL < curSL - _Point); // 空单:新SL比旧SL低
        if(better) ModifyPositionSL(ticket, targetSL);

        return; // 追踪阶段优先级最高,处理完直接返回,不再执行下面的阶梯锁损
    }

    // ---- 阶梯锁损(锁定点数已是标准点) ----
    double lockPoints = -1.0; // <0 表示不动
    if(profitPoints >= Inp_TrendBE3_Trigger)      lockPoints = Inp_TrendBE3_Lock; // +5档
    else if(profitPoints >= Inp_TrendBE2_Trigger) lockPoints = Inp_TrendBE2_Lock; // +2档
    else if(profitPoints >= Inp_TrendBE1_Trigger) lockPoints = 0.0;               // 成本价

    if(lockPoints >= 0.0)
    {
        double lockPrice = (type == POSITION_TYPE_BUY)
                         ? open + PointsToPrice(lockPoints)
                         : open - PointsToPrice(lockPoints);
        double curSL = PositionGetDouble(POSITION_SL);
        bool better = (type == POSITION_TYPE_BUY) ? (lockPrice > curSL + _Point)
                                                  : (curSL == 0.0 || lockPrice < curSL - _Point);
        if(better) ModifyPositionSL(ticket, lockPrice);
    }

    // ---- 减仓(达 +8 档触发一次)----
    if(!g_TrReduced[idx] && profitPoints >= Inp_TrendBE3_Trigger && Inp_TrendReducePercent > 0.0)
    {
        double closeVol = NormalizeLots(vol * (Inp_TrendReducePercent / 100.0));
        double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        if(closeVol >= vmin && closeVol < vol)
        {
            double targetRemaining = NormalizeDouble(vol - closeVol, 2);
            EnsurePartialCloseOperation(ticket, targetRemaining, "trend_reduce");
        }
        else
        {
            g_TrReduced[idx] = true; MarkTicketStateDirty(); // 无法再拆(手数太小),标记避免反复尝试
        }
    }
}

//+------------------------------------------------------------------+
//| 移动止损总入口                                                    |
//+------------------------------------------------------------------+
void ManageAllTrailingStops()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(IsTicketRecoveryBlocked(tk)) continue;
        ENUM_SOP_ORDER kind = PosType();

        if(kind == SOP_SCALP) ManageScalpTrailingStop(tk);
        else if(kind == SOP_TREND) ManageTrendTrailingStop(tk);
    }
    TrCleanup();
    ScalpTrackCleanup();
    TimeoutCancelCleanup();
    if(g_ArraysDirty) { SaveArrays(); g_ArraysDirty = false; } // 仅在变化时落盘
}

//+------------------------------------------------------------------+
//| 跨日重置                                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 导出全部已平仓订单明细(表格)到已打开的文件句柄                   |
//+------------------------------------------------------------------+
void ExportDealTable(int h, datetime statFrom, datetime statTo)
{
    FileWrite(h, "## 全部订单明细(今日已平仓)");
    FileWrite(h, "");
    FileWrite(h, "| 平仓时间 | 类型 | 方向 | 手数 | 开仓价 | 平仓价 | 持时 | 盈亏 |");
    FileWrite(h, "|----------|------|------|------|--------|--------|------|------|");

    datetime selFrom = statFrom - 30 * 86400;
    if(!HistorySelect(selFrom, statTo)) { FileWrite(h, "| (无数据) | | | | | | | |"); return; }

    int deals = HistoryDealsTotal();
    int rows = 0;
    for(int i = 0; i < deals; i++)
    {
        ulong dt = HistoryDealGetTicket(i);
        if(dt == 0) continue;
        if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) continue;
        if(!DealIsExit(dt)) continue;
        datetime closeT = (datetime)HistoryDealGetInteger(dt, DEAL_TIME);
        if(closeT < statFrom || closeT >= statTo) continue;

        double vol = HistoryDealGetDouble(dt, DEAL_VOLUME);
        ENUM_SOP_ORDER k = DealStrategyType(dt);         // 回溯开仓magic,兼容手工平仓
        string ktxt = (k == SOP_SCALP) ? "剥头皮" : (k == SOP_TREND ? "趋势" : "手动");
        long dtype  = HistoryDealGetInteger(dt, DEAL_TYPE);
        string dir  = (dtype == DEAL_TYPE_SELL) ? "BUY" : "SELL"; // 平仓成交反向 = 原持仓方向
        double closePx = HistoryDealGetDouble(dt, DEAL_PRICE);
        double pnl  = DealCashValue(dt);

        // 配对 IN 成交拿开仓价与持时
        long posId = HistoryDealGetInteger(dt, DEAL_POSITION_ID);
        double openPx = closePx; datetime openT = closeT;
        double entryCosts = 0.0, entryVolume = 0.0;
        for(int j = 0; j < deals; j++)
        {
            ulong dj = HistoryDealGetTicket(j);
            if(dj == 0) continue;
            if(HistoryDealGetInteger(dj, DEAL_POSITION_ID) != posId) continue;
            if(HistoryDealGetInteger(dj, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            openPx = HistoryDealGetDouble(dj, DEAL_PRICE);
            datetime candidateOpen = (datetime)HistoryDealGetInteger(dj, DEAL_TIME);
            if(openT == closeT || candidateOpen < openT) openT = candidateOpen;
            entryCosts += HistoryDealGetDouble(dj, DEAL_COMMISSION) + HistoryDealGetDouble(dj, DEAL_FEE);
            entryVolume += HistoryDealGetDouble(dj, DEAL_VOLUME);
        }
        if(entryVolume > 0.0) pnl += entryCosts * MathMin(1.0, vol / entryVolume);
        int secs = (int)(closeT - openT); if(secs < 0) secs = 0;

        FileWrite(h, "| " + TimeToString(ToBeijing(closeT), TIME_MINUTES|TIME_SECONDS)
                    + " | " + ktxt
                    + " | " + dir
                    + " | " + DoubleToString(vol, 2)
                    + " | " + DoubleToString(openPx, _Digits)
                    + " | " + DoubleToString(closePx, _Digits)
                    + " | " + FmtHold(secs)
                    + " | " + DoubleToString(pnl, 2) + " |");
        rows++;
    }
    if(rows == 0) FileWrite(h, "| (今日无平仓记录) | | | | | | | |");
    FileWrite(h, "");
    FileWrite(h, "> 共 " + (string)rows + " 笔平仓记录 | 报告由 Gold SOP EA 自动生成");
}

//+------------------------------------------------------------------+
//| 导出当日统计 + 全部订单明细到本地 Markdown 文件                    |
//| 在每日重置动作之前调用(此时 StatStart 仍指向将结束的交易日)       |
//+------------------------------------------------------------------+
bool ExportDailyReport(datetime statFrom, datetime statTo, string trigger)
{
    if(!Inp_ExportOnReset) return true;

    // 报告归属日期:用统计起点的北京日期命名
    string dayStr = TimeToString(ToBeijing(statFrom), TIME_DATE); // yyyy.mm.dd
    StringReplace(dayStr, ".", "");
    long   acct = AccountInfoInteger(ACCOUNT_LOGIN);
    string serverHash = (string)StableTextHash(AccountInfoString(ACCOUNT_SERVER));
    string periodId = dayStr + StringFormat("_%02d%02d", Inp_ResetHour, Inp_ResetMinute);
    string fname = "TradeEZ_" + serverHash + "_" + (string)acct + "_" + NormalizeNamespacePart(_Symbol) + "_" +
                   NormalizeNamespacePart(Inp_InstanceId) + "_" + periodId + ".md";
    string tempName = fname + ".tmp";

    double periodStartBalance = 0.0, periodEndBalance = 0.0, periodPeakBalance = 0.0;
    if(!ReconstructAccountBalance(statFrom, statTo, periodStartBalance, periodEndBalance, periodPeakBalance))
    {
        PrintFormat("[Period] 无法重建报告余额 %s ~ %s", TimeToString(statFrom), TimeToString(statTo));
        return false;
    }

    int h = FileOpen(tempName, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(h == INVALID_HANDLE) { Print("导出失败,无法创建临时文件: ", tempName); return false; }

    // ---- 统计汇总 ----
    DailyStats all, sc, tr;
    ComputeDailyStatsRange(SOP_IGNORE, statFrom, statTo, all);
    ComputeDailyStatsRange(SOP_SCALP,  statFrom, statTo, sc);
    ComputeDailyStatsRange(SOP_TREND,  statFrom, statTo, tr);
    double manNet = all.net - sc.net - tr.net;
    int    manCnt = all.trades - sc.trades - tr.trades;
    double peakProfit = periodPeakBalance - periodStartBalance;

    FileWrite(h, "# TradeEZ-SOP 日内交易报告");
    FileWrite(h, "");
    FileWrite(h, "| 项目 | 值 |");
    FileWrite(h, "|------|------|");
    FileWrite(h, "| 交易日(北京) | " + TimeToString(ToBeijing(statFrom), TIME_DATE) + " |");
    FileWrite(h, "| 统计区间(北京) | " + TimeToString(ToBeijing(statFrom), TIME_DATE|TIME_MINUTES) + " ~ " + TimeToString(ToBeijing(statTo), TIME_DATE|TIME_MINUTES) + " |");
    FileWrite(h, "| 生成原因 | " + trigger + " |");
    FileWrite(h, "| 时间边界完整性 | " + (g_TimeBoundaryUncertain ? "保守：离线期间服务器UTC偏移发生变化" : "已验证") + " |");
    FileWrite(h, "| 账户 | " + (string)acct + " |");
    FileWrite(h, "| 品种 | " + _Symbol + " |");
    FileWrite(h, "| 周期初账户余额 | $" + DoubleToString(periodStartBalance, 2) + " |");
    FileWrite(h, "| 周期末账户余额 | $" + DoubleToString(periodEndBalance, 2) + " |");
    if(g_ResetTime > statFrom && g_ResetTime < statTo)
        FileWrite(h, "| 当期手动风控重置 | " + TimeToString(ToBeijing(g_ResetTime), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + " |");
    FileWrite(h, "");

    FileWrite(h, "## 盈亏概览");
    FileWrite(h, "");
    FileWrite(h, "| 指标 | 数值 |");
    FileWrite(h, "|------|------|");
    FileWrite(h, "| 已实现净盈亏 | " + DoubleToString(all.net, 2) + " |");
    FileWrite(h, "| 毛盈利 | " + DoubleToString(all.grossProfit, 2) + " |");
    FileWrite(h, "| 毛亏损 | " + DoubleToString(all.grossLoss, 2) + " |");
    FileWrite(h, "| 周期末浮动盈亏 | 历史无法精确还原 |");
    FileWrite(h, "| 账户余额峰值增量 | " + DoubleToString(peakProfit, 2) + " |");
    FileWrite(h, "| 日盈利目标 | " + DoubleToString(Inp_DailyProfitTarget, 0) + " |");
    FileWrite(h, "");

    FileWrite(h, "## 交易质量");
    FileWrite(h, "");
    FileWrite(h, "| 指标 | 数值 |");
    FileWrite(h, "|------|------|");
    FileWrite(h, "| 总平仓笔数 | " + (string)all.trades + " |");
    FileWrite(h, "| 盈利/亏损/保本 | " + (string)all.wins + " / " + (string)all.losses + " / " + (string)all.evens + " |");
    FileWrite(h, "| 胜率(%) | " + DoubleToString(StatWinRate(all), 1) + " |");
    FileWrite(h, "| 盈亏比 | " + DoubleToString(StatPayoff(all), 2) + " |");
    FileWrite(h, "| 盈利因子 | " + DoubleToString(StatProfitFactor(all), 2) + " |");
    FileWrite(h, "| 单笔期望值 | " + DoubleToString(StatExpectancy(all), 2) + " |");
    FileWrite(h, "| 平均盈利 | " + DoubleToString(StatAvgWin(all), 2) + " |");
    FileWrite(h, "| 平均亏损 | " + DoubleToString(StatAvgLoss(all), 2) + " |");
    FileWrite(h, "| 最大单笔盈利 | " + DoubleToString(all.maxWin, 2) + " |");
    FileWrite(h, "| 最大单笔亏损 | " + DoubleToString(all.maxLoss, 2) + " |");
    FileWrite(h, "| 平均持仓时长 | " + FmtHold(all.avgHoldSec) + " |");
    FileWrite(h, "");

    FileWrite(h, "## 分策略拆解");
    FileWrite(h, "");
    FileWrite(h, "| 策略 | 净盈亏 | 笔数 | 胜率% | 均持时 |");
    FileWrite(h, "|------|--------|------|-------|--------|");
    FileWrite(h, "| 剥头皮 | " + DoubleToString(sc.net,2) + " | " + (string)sc.trades + " | " + DoubleToString(StatWinRate(sc),1) + " | " + FmtHold(sc.avgHoldSec) + " |");
    FileWrite(h, "| 趋势 | " + DoubleToString(tr.net,2) + " | " + (string)tr.trades + " | " + DoubleToString(StatWinRate(tr),1) + " | " + FmtHold(tr.avgHoldSec) + " |");
    FileWrite(h, "| 规则外(手动) | " + DoubleToString(manNet,2) + " | " + (string)manCnt + " | - | - |");
    FileWrite(h, "");

    FileWrite(h, "## 纪律执行");
    FileWrite(h, "");
    FileWrite(h, "| 项目 | 值 |");
    FileWrite(h, "|------|------|");
    FileWrite(h, "| 连亏阈值 | " + (string)Inp_ConsecLossLimit + " |");
    FileWrite(h, "| 冷却分钟 | " + (string)Inp_CooldownMinutes + " |");
    FileWrite(h, "| 日回撤上限 | " + DoubleToString(Inp_DailyMaxDrawdown, 0) + " |");
    FileWrite(h, "");

    ExportDealTable(h, statFrom, statTo);   // 全部订单明细

    FileFlush(h);
    FileClose(h);
    if(!FileMove(tempName, 0, fname, FILE_REWRITE))
    {
        PrintFormat("[Period] 日报原子替换失败 %s error=%d", fname, GetLastError());
        FileDelete(tempName);
        return false;
    }
    Print("[Period] 已导出当日报告: ", fname);
    return true;
}

void SchedulePendingReports(datetime firstPeriod, datetime currentPeriod)
{
    if(firstPeriod <= 0 || firstPeriod >= currentPeriod) return;
    // 已成功落盘的周期不重复排队；中断恢复时从下一周期继续。
    if(g_LastReportedPeriod >= firstPeriod)
        firstPeriod = g_LastReportedPeriod + 86400;
    if(firstPeriod >= currentPeriod) return;
    int limit = MathMax(1, Inp_RecoveryLookbackDays);
    datetime earliest = currentPeriod - limit * 86400;
    if(firstPeriod < earliest)
    {
        PrintFormat("[Period] 补报区间超过 %d 天，仅保留最近范围；更早周期记录为审计缺口", limit);
        firstPeriod = earliest;
    }
    if(g_PendingReportPeriod == 0 || firstPeriod < g_PendingReportPeriod)
        g_PendingReportPeriod = firstPeriod;
}

bool RetryPendingReports(datetime currentPeriod, bool force = false)
{
    if(g_PendingReportPeriod <= 0 || g_PendingReportPeriod >= currentPeriod) return true;
    datetime nowUtc = TimeGMT();
    if(!force && g_LastReportRetryUtc > 0 && nowUtc - g_LastReportRetryUtc < MathMax(5, Inp_RecoveryRetrySeconds))
        return false;
    g_LastReportRetryUtc = nowUtc;
    while(g_PendingReportPeriod > 0 && g_PendingReportPeriod < currentPeriod)
    {
        datetime period = g_PendingReportPeriod;
        if(!ExportDailyReport(period, period + 86400, "幂等周期补报"))
        {
            Print("[Period] 日报仍待补：", TimeToString(ToBeijing(period), TIME_DATE|TIME_MINUTES));
            return false;
        }
        g_LastReportedPeriod = period;
        g_PendingReportPeriod = period + 86400;
        if(g_PendingReportPeriod >= currentPeriod) g_PendingReportPeriod = 0;
        // 恢复阶段不得用尚未完成重建的内存值覆盖完整状态，只提交报告游标。
        PVSet("ReportedPeriod", (double)g_LastReportedPeriod);
        PVSet("PendingReportPeriod", (double)g_PendingReportPeriod);
        GlobalVariablesFlush();
    }
    return true;
}

bool RebuildCurrentPeriod(datetime periodStart)
{
    RecoverySnapshot snapshot;
    datetime now = RecoveryNowServer() + 1;
    if(!BuildRecoverySnapshot(periodStart, now, snapshot)) return false;
    double startBalance = 0.0, endBalance = 0.0, peakBalance = 0.0;
    if(!ReconstructAccountBalance(periodStart, now, startBalance, endBalance, peakBalance)) return false;

    g_DayStart = periodStart;
    g_ResetTime = periodStart;
    g_ScalpBlocked = false; g_TrendBlocked = false; g_TotalBlocked = false;
    g_MoatLiquidated = false; g_DailyLiquidationActive = false; g_MoatDrawHit = false;
    g_ScalpReason = ""; g_TrendReason = ""; g_TotalReason = "";
    g_InitBalance = startBalance;
    g_PeakBalance = peakBalance;
    g_ScalpHighProfit = snapshot.scalp_high;
    g_TrendHighProfit = snapshot.trend_high;
    g_GlobalRealHigh = snapshot.all_high;
    g_ScalpHiInit = snapshot.scalp_high_init;
    g_TrendHiInit = snapshot.trend_high_init;
    g_GlobalHiInit = snapshot.all_high_init;
    double currentNet = snapshot.all_realized + AllFloatingPL();
    g_TodayHighProfit = snapshot.all_high_init ? MathMax(snapshot.all_high, currentNet) : currentNet;
    g_HighInit = true;
    g_ConsecLoss = snapshot.consec_loss;
    g_CooldownUntil = snapshot.cooldown_until > RecoveryNowServer() ? snapshot.cooldown_until : 0;
    g_LastDealTimeMsc = snapshot.last_deal_msc > 0 ? snapshot.last_deal_msc : (long)periodStart * 1000;
    g_LastDealTicket = snapshot.last_deal_ticket;
    g_LastDealTime = (datetime)(g_LastDealTimeMsc / 1000);
    g_LastCompletedPeriod = periodStart;
    g_WeeklyCacheSecond = 0;
    SaveState(); // 最后提交周期完成标志；逐票持仓管理状态不清零。
    return true;
}

void CheckDayRollover()
{
    if(g_RecoveryStatus == RECOVERY_CHECKING || g_RecoveryStatus == RECOVERY_FAILED) return;
    datetime currentPeriod = TodayStart();
    if(g_DayStart != currentPeriod)
    {
        datetime previousPeriod = g_DayStart;
        if(previousPeriod > 0) SchedulePendingReports(previousPeriod, currentPeriod);
        if(!RebuildCurrentPeriod(currentPeriod))
        {
            g_RecoveryStatus = RECOVERY_FAILED;
            g_RecoveryReason = Lang("跨日历史重建失败，已只平不开并等待重试", "Period rebuild failed; exit-only pending retry");
            g_LastRecoveryAttempt = TimeGMT();
            return;
        }
    }
    RetryPendingReports(currentPeriod);
}

//+------------------------------------------------------------------+
//| 利润护城河:返回有效回撤限额;并按高水位判定是否禁开                |
//+------------------------------------------------------------------+
// 返回"有效最大回撤限额"(供面板显示);g_TotalBlocked 可能被本函数置位
double CheckProfitProtection(double netPL)
{
    double effectiveLimit = Inp_DailyMaxDrawdown;
    g_MoatDrawHit = false;   // 每次重算:本tick回撤保护是否触发(供强平判定)
    if(!Inp_EnableProfitProtect) { g_EffectiveLimit = effectiveLimit; return effectiveLimit; }

    // 高水位更新(允许为负,首次直接赋值)
    if(!g_HighInit) { g_TodayHighProfit = netPL; g_HighInit = true; }
    else if(netPL > g_TodayHighProfit) g_TodayHighProfit = netPL;
    double hi = g_TodayHighProfit;

    // 强制停止 / 清盘:达阈值即禁开新仓
    if(hi >= Inp_ProfitShutdown || hi >= Inp_ProfitLiquidation)
    {
        g_TotalBlocked = true;
        g_TotalReason  = Lang("利润护城河-清盘保护", "Profit lock — shutdown");
    }

    // 回撤容忍:从高水位回落超阈值 → 禁开新仓
    double drawFromHi = hi - netPL; // 已回落金额
    if(hi >= Inp_ProfitProtect2_Trigger)
    {
        // 最多回撤固定金额
        if(drawFromHi >= Inp_ProfitProtect2_Amount) { g_TotalBlocked = true; g_TotalReason = Lang("利润护城河-回撤保护", "Profit moat — drawdown"); g_MoatDrawHit = true; }
        effectiveLimit = Inp_ProfitProtect2_Amount;
    }
    else if(hi >= Inp_ProfitProtect1_Trigger)
    {
        double allow = hi * (Inp_ProfitProtect1_Percent / 100.0);
        if(drawFromHi >= allow) { g_TotalBlocked = true; g_TotalReason = Lang("利润护城河-回撤保护", "Profit moat — drawdown"); g_MoatDrawHit = true; }
        effectiveLimit = allow;
    }
    g_EffectiveLimit = effectiveLimit;
    return effectiveLimit;
}

//+------------------------------------------------------------------+
//| 分控熔断检查(仅禁开)                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 连续亏损统计(含手动单):扫描自上次以来的新平仓成交               |
//| 每笔平仓:亏损→计数+1,盈利/保本→清零。达阈值启动时间熔断          |
//+------------------------------------------------------------------+
void UpdateConsecutiveLoss()
{
    datetime from = StatStart();
    if(!HistorySelect(from, RecoveryNowServer() + 1)) return;

    ulong tickets[]; long timesMsc[]; double profits[];
    int deals = HistoryDealsTotal();
    for(int i = 0; i < deals; i++)
    {
        ulong deal = HistoryDealGetTicket(i);
        if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
        if(!DealIsExit(deal)) continue;
        long dealMsc = HistoryDealGetInteger(deal, DEAL_TIME_MSC);
        if(dealMsc < g_LastDealTimeMsc ||
           (dealMsc == g_LastDealTimeMsc && deal <= g_LastDealTicket)) continue;
        int n = ArraySize(tickets);
        ArrayResize(tickets, n + 1); ArrayResize(timesMsc, n + 1); ArrayResize(profits, n + 1);
        tickets[n] = deal; timesMsc[n] = dealMsc;
        profits[n] = ExitTradeCashValue(deal);
    }
    for(int i = 1; i < ArraySize(tickets); i++)
    {
        ulong tk = tickets[i]; long tm = timesMsc[i]; double pnl = profits[i]; int j = i - 1;
        while(j >= 0 && (timesMsc[j] > tm || (timesMsc[j] == tm && tickets[j] > tk)))
        {
            tickets[j + 1] = tickets[j]; timesMsc[j + 1] = timesMsc[j]; profits[j + 1] = profits[j]; j--;
        }
        tickets[j + 1] = tk; timesMsc[j + 1] = tm; profits[j + 1] = pnl;
    }
    for(int i = 0; i < ArraySize(tickets); i++)
    {
        if(profits[i] < 0.0) g_ConsecLoss++;
        else g_ConsecLoss = 0;
        g_LastDealTimeMsc = timesMsc[i];
        g_LastDealTicket = tickets[i];
        g_LastDealTime = (datetime)(timesMsc[i] / 1000);

        if(Inp_ConsecLossLimit > 0 && g_ConsecLoss >= Inp_ConsecLossLimit)
        {
            g_CooldownUntil = (datetime)(timesMsc[i] / 1000) + Inp_CooldownMinutes * 60;
            g_ConsecLoss = 0;
            if(Inp_AlertOnBreaker)
                Alert(Lang("【连亏熔断】连续亏损达上限,冷却 ", "[STREAK BREAKER] Consecutive losses — cooldown ")
                      + (string)Inp_CooldownMinutes + Lang(" 分钟", " min"));
        }
    }
}

// 是否处于连亏冷却中
bool InCooldown() { return (g_CooldownUntil > RecoveryNowServer()); }

bool EnsureRuntimeHistoryAvailable()
{
    if(HistorySelect(StatStart(), RecoveryNowServer() + 1)) return true;
    if(g_RecoveryStatus != RECOVERY_FAILED)
        PrintFormat("[Recovery] 运行中成交历史不可用，切换为只平不开，错误=%d", GetLastError());
    g_RecoveryStatus = RECOVERY_FAILED;
    g_RecoveryReason = Lang("成交历史暂不可用，已禁止开仓并等待自动重试", "Deal history unavailable; entries disabled pending retry");
    g_LastRecoveryAttempt = TimeGMT();
    g_RecoveryCompletedUtc = g_LastRecoveryAttempt;
    PVSet("RecoveryCompletedUtc", (double)g_RecoveryCompletedUtc);
    PVSet("RecoveryResult", (double)g_RecoveryStatus);
    GlobalVariablesFlush();
    return false;
}

void CheckAllRiskControl()
{
    if(!EnsureRuntimeHistoryAvailable()) return;
    CheckDayRollover();
    UpdateConsecutiveLoss();
    UpdateRiskSnapshot(true);

    // 各分项净盈亏 + 高水位更新
    double scalpNet = ScalpNetPL();
    double trendNet = TrendNetPL();
    double globalNet = GlobalNetPL();  // 全局口径:含任何手动单
    // 各分项"今日最高盈利":只按已平仓(已实现)口径,允许为负(首次直接赋值)
    double scalpReal = ScalpRealized();
    double trendReal = TrendRealized();
    if(!g_ScalpHiInit) { g_ScalpHighProfit = scalpReal; g_ScalpHiInit = true; }
    else if(scalpReal > g_ScalpHighProfit) g_ScalpHighProfit = scalpReal;
    if(!g_TrendHiInit) { g_TrendHighProfit = trendReal; g_TrendHiInit = true; }
    else if(trendReal > g_TrendHighProfit) g_TrendHighProfit = trendReal;
    // 全局今日最高盈利:全部已平仓累计盈亏高水位(允许为负)
    double allReal = AllRealizedPL();
    if(!g_GlobalHiInit) { g_GlobalRealHigh = allReal; g_GlobalHiInit = true; }
    else if(allReal > g_GlobalRealHigh) g_GlobalRealHigh = allReal;

    // 今日最高净盈利(允许为负):首次直接赋值,之后取更大
    if(!g_HighInit) { g_TodayHighProfit = globalNet; g_HighInit = true; }
    else if(globalNet > g_TodayHighProfit) g_TodayHighProfit = globalNet;

    // 账户余额峰值(用于"最高权益回撤基准")
    double curBal = AccountInfoDouble(ACCOUNT_BALANCE);
    if(curBal > g_PeakBalance) g_PeakBalance = curBal;

    if(!Inp_EnableCircuitBreaker)
    {
        CheckProfitProtection(globalNet);
        EnforceMoatLiquidation();   // 阈值触及0则强平并锁定
        SaveState();
        return;
    }

    bool prevScalp = g_ScalpBlocked;
    bool prevTrend = g_TrendBlocked;
    bool prevTotal = g_TotalBlocked;

    // 净亏损口径:每次都重新判定（盈利后自动解除熔断）
    // 关键：先清零再判定，避免"一次触发永久锁定"的BUG
    g_ScalpBlocked = false;
    g_TrendBlocked = false;
    g_TotalBlocked = false;
    g_ScalpReason  = "";
    g_TrendReason  = "";
    g_TotalReason  = "";

    // 净盈亏跌破 -额度 即熔断
    if(-scalpNet  >= ScalpDrawdownLimit()) { g_ScalpBlocked = true; g_ScalpReason = Lang("剥头皮回撤风控熔断", "Scalp drawdown breaker"); }
    if(-trendNet  >= TrendDrawdownLimit()) { g_TrendBlocked = true; g_TrendReason = Lang("波段趋势回撤风控熔断", "Trend drawdown breaker"); }
    bool dailyDrawdownHit = (-globalNet >= TotalDrawdownLimit());
    if(dailyDrawdownHit) { g_TotalBlocked = true; g_TotalReason = Lang("日回撤阈值熔断", "Daily drawdown breaker"); }

    // 护城河(用全局净盈亏含浮动 + 手动单)
    CheckProfitProtection(globalNet);
    EnforceMoatLiquidation();   // 动态回撤阈值触及0 → 强平本品种全部持仓并锁定当日

    // 熔断先撤销尚未成交的受管风险；策略熔断绝不主动平仓。
    if(g_ScalpBlocked) CancelManagedPendingOrders(SOP_SCALP, "scalp_breaker");
    if(g_TrendBlocked) CancelManagedPendingOrders(SOP_TREND, "trend_breaker");
    if(InCooldown() || dailyDrawdownHit) CancelManagedPendingOrders(SOP_IGNORE, dailyDrawdownHit ? "daily_breaker" : "streak_breaker");
    if(dailyDrawdownHit && Inp_CloseOnDailyDrawdown && !g_DailyLiquidationActive)
    {
        g_DailyLiquidationActive = true;
        SaveState();
        if(Inp_AlertOnBreaker)
            Alert(Lang("【日回撤强平】已触发，系统会持续核对直至当前品种全部仓位与挂单清理完成。",
                       "[DAILY LIQUIDATION] Triggered; reconciliation continues until this symbol is flat."));
    }
    EnforceDailyDrawdownLiquidation();

    if(Inp_AlertOnBreaker)
    {
        if(!prevScalp && g_ScalpBlocked) Alert(Lang("【熔断】", "[BREAKER] ") + g_ScalpReason);
        if(!prevTrend && g_TrendBlocked) Alert(Lang("【熔断】", "[BREAKER] ") + g_TrendReason);
        if(!prevTotal && g_TotalBlocked) Alert(Lang("【全局熔断】", "[GLOBAL] ") + g_TotalReason);
    }

    SaveState();   // 持续保存关键风控状态,切周期/重载后可恢复
}

// 连亏冷却期间,所有开仓一律禁止
bool RecoveryAllowsNewRisk()
{
    return g_RecoveryStatus == RECOVERY_EXACT ||
           (g_RecoveryStatus == RECOVERY_CONSERVATIVE && g_RecoveryAcknowledged);
}
bool ProjectedRiskAllows(ENUM_SOP_ORDER kind)
{
    if(!g_RiskSnapshotValid || g_SymbolProjectedPL < ActiveProjectedFloor() - 0.01) return false;
    if(kind == SOP_SCALP) return g_ScalpProjectedPL >= -ScalpDrawdownLimit() - 0.01;
    if(kind == SOP_TREND) return g_TrendProjectedPL >= -TrendDrawdownLimit() - 0.01;
    return false;
}
bool IsScalpAllowed() { return g_InstanceOwnsState && g_AccountModeSupported && ProjectedRiskAllows(SOP_SCALP) && !g_ProtectionBlocksNewRisk && !HasScalpExitPending() && RecoveryAllowsNewRisk() && !g_ScalpBlocked && !g_TotalBlocked && !InCooldown() && g_ScalpRiskSlots < Inp_ScalpMaxPositions; }
bool IsTrendAllowed() { return g_InstanceOwnsState && g_AccountModeSupported && ProjectedRiskAllows(SOP_TREND) && !g_ProtectionBlocksNewRisk && RecoveryAllowsNewRisk() && !g_TrendBlocked && !g_TotalBlocked && !InCooldown() && g_TrendRiskSlots < Inp_TrendMaxPositions; }

//+------------------------------------------------------------------+
//| 周目标提示(仅建议,不自动改参数)                                 |
//+------------------------------------------------------------------+
// 自然周起点(北京时间周一 00:00)对应的服务器 epoch
datetime WeekStart()
{
    datetime bj = BeijingNow();
    MqlDateTime t; TimeToStruct(bj, t);
    int dow = t.day_of_week;                 // 0=周日,1=周一...
    int backDays = (dow == 0) ? 6 : (dow - 1);
    t.hour = 0; t.min = 0; t.sec = 0;
    datetime bjMidnight = StructToTime(t);   // 北京今天0点
    datetime bjMonday   = bjMidnight - backDays * 86400; // 北京本周一0点
    return bjMonday - 8 * 3600 + ServerGmtOffset();      // 转服务器 epoch
}

// 返回自然周(周一起)全部订单已实现净盈亏(不限手数,含手动单)
double WeekRealized()
{
    datetime cacheSecond = RecoveryNowServer();
    if(g_WeeklyCacheSecond == cacheSecond) return g_WeeklyCachedPL;
    datetime weekStart = WeekStart();
    if(!HistorySelect(weekStart, RecoveryNowServer() + 1)) return g_WeeklyCachedPL;
    double net = 0.0;
    int deals = HistoryDealsTotal();
    for(int i = 0; i < deals; i++)
    {
        ulong dt = HistoryDealGetTicket(i);
        if(dt == 0) continue;
        if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) continue;
        net += DealCashValue(dt);
    }
    g_WeeklyCachedPL = net;
    g_WeeklyCacheSecond = cacheSecond;
    return g_WeeklyCachedPL;
}

string WeeklyHint()
{
    double wk = WeekRealized();
    if(wk >= Inp_WeeklyPlan3_Level) return Lang("已达周高:建议降频/休息", "Peak: reduce freq / rest");
    if(wk >= Inp_WeeklyPlan2_Level) return Lang("建议日回撤调至$", "Set daily DD $") + DoubleToString(Inp_WeeklyPlan2_DD, 0);
    if(wk >= Inp_WeeklyPlan1_Level) return Lang("建议日回撤调至$", "Set daily DD $") + DoubleToString(Inp_WeeklyPlan1_DD, 0);
    return Lang("进行中", "In progress");
}

// 周目标进度文本:已完成 / 目标
string WeeklyProgress()
{
    double wk = WeekRealized();
    return FmtMoney(wk) + " / $" + DoubleToString(Inp_WeeklyProfitTarget, 0);
}

//+------------------------------------------------------------------+
//| 动态回撤基准(具体金额,口径与 CheckProfitProtection 真实触发一致) |
//| - 未达第1档:今日初始金额 - 日最大回撤                             |
//| - 第1档:今日初始金额 + 高水位×(1-回撤%)                          |
//| - 第2档:今日初始金额 + (高水位 - 最多回撤额)                      |
//+------------------------------------------------------------------+
double DrawdownBase()
{
    double hi = g_TodayHighProfit;   // 今日最高净盈利高水位(含浮动)
    double protectFloor;             // 保底利润(相对初始金额)

    // 口径必须与 CheckProfitProtection 的真实熔断判定一致:用「真实高水位 hi」算保底地板,
    // 而不是用档位触发额。这样面板"动态回撤阈值 = 净值 - 基准"跌破 0 时,正好等于实际触发。
    if(Inp_EnableProfitProtect && hi >= Inp_ProfitProtect2_Trigger)
    {
        // 第2档:从高水位最多回撤固定额 → 保底净盈亏 = hi - 最多回撤额
        protectFloor = hi - Inp_ProfitProtect2_Amount;
    }
    else if(Inp_EnableProfitProtect && hi >= Inp_ProfitProtect1_Trigger)
    {
        // 第1档:从高水位最多回撤百分比 → 保底净盈亏 = hi × (1 - 回撤%)
        protectFloor = hi * (1.0 - Inp_ProfitProtect1_Percent / 100.0);
    }
    else
    {
        // 未达档:初始金额 - 日最大回撤
        return g_InitBalance - Inp_DailyMaxDrawdown;
    }
    return g_InitBalance + protectFloor;
}

//+------------------------------------------------------------------+
//| 开仓校验:持仓上限 + 熔断/护城河 + 时段                            |
//+------------------------------------------------------------------+
bool ValidateOpenConditions(ENUM_SOP_ORDER kind)
{
    MqlTick gateTick; string gateReason = "";
    if(!ValidateQuoteForEntry(gateTick, gateReason))
    {
        Alert(Lang("【拒绝】", "[REJECT] ") + gateReason);
        return false;
    }
    if(!UpdateRiskSnapshot(true))
    {
        Alert(Lang("【拒绝】风险无法完整计算：", "[REJECT] Risk is unknown: ") + g_RiskSnapshotReason);
        return false;
    }
    if(HasUnfinishedNewRiskOperation())
    {
        Alert(Lang("【拒绝】上一笔开仓请求仍在核对中，请等待服务器确认。",
                   "[REJECT] A previous entry request is still being reconciled."));
        return false;
    }
    if(!g_AccountModeSupported)
    {
        Alert(Lang("【拒绝】当前版本仅支持对冲账户", "[REJECT] Hedging accounts only"));
        return false;
    }
    if(g_ProtectionBlocksNewRisk)
    {
        Alert(Lang("【拒绝】服务器保护尚未全部确认，请先处理保护异常",
                   "[REJECT] Server protection is not fully confirmed"));
        return false;
    }
    if(IsMarketClosed())
    {
        Alert(Lang("【拒绝】当前休市,无法建仓", "[REJECT] Market closed"));
        return false;
    }
    if(Inp_UseSession && !InSession())
    {
        Alert(Lang("【拒绝】当前非交易时段", "[REJECT] Off-session"));
        return false;
    }
    if(kind == SOP_SCALP)
    {
        if(!IsScalpAllowed())
        {
            Alert(Lang("【拒绝】剥头皮已熔断/受限", "[REJECT] Scalping blocked"));
            return false;
        }
        if(g_ScalpRiskSlots >= Inp_ScalpMaxPositions)
        {
            Alert(Lang("【拒绝】剥头皮仓位/挂单/待确认请求已达上限", "[REJECT] Scalping capacity reached"));
            return false;
        }
    }
    else if(kind == SOP_TREND)
    {
        if(!IsTrendAllowed())
        {
            Alert(Lang("【拒绝】趋势已熔断/受限", "[REJECT] Trend blocked"));
            return false;
        }
        if(g_TrendRiskSlots >= Inp_TrendMaxPositions)
        {
            Alert(Lang("【拒绝】趋势仓位/挂单/待确认请求已达上限", "[REJECT] Trend capacity reached"));
            return false;
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| 交易请求结果闭环                                                  |
//+------------------------------------------------------------------+
bool TradeOpIsFinal(int state)
{
    return state == TRADE_OP_CONFIRMED || state == TRADE_OP_FAILED ||
           state == TRADE_OP_CANCELLED;
}

string WeeklySummary()
{
    return WeeklyProgress() + " · " + WeeklyHint();
}

string NewTradeOperationId(string prefix)
{
    g_TradeOpSequence++;
    return prefix + "-" + (string)ProtectionNowMsc() + "-" + (string)g_TradeOpSequence;
}

string NewTradeBatchId(string source)
{
    return NewTradeOperationId("B-" + source);
}

int ActiveTradeOpIndex(int action, ulong targetTicket)
{
    for(int i = ArraySize(g_TradeOps) - 1; i >= 0; i--)
        if(g_TradeOps[i].action == action && g_TradeOps[i].target_ticket == targetTicket &&
           !TradeOpIsFinal(g_TradeOps[i].state))
            return i;
    return -1;
}

int TradeOpIndexByRequest(ulong requestId)
{
    if(requestId == 0) return -1;
    for(int i = ArraySize(g_TradeOps) - 1; i >= 0; i--)
        if(g_TradeOps[i].request_id == requestId && !TradeOpIsFinal(g_TradeOps[i].state))
            return i;
    return -1;
}

int ActiveTradeOperationCount()
{
    int count = 0;
    for(int i = 0; i < ArraySize(g_TradeOps); i++)
        if(!TradeOpIsFinal(g_TradeOps[i].state)) count++;
    return count;
}

string TradeOperationStatusText(color &statusColor)
{
    int active = 0, ambiguous = 0, partial = 0;
    long nowMsc = ProtectionNowMsc();
    bool recentFailure = false, recentConfirmed = false;
    for(int i = 0; i < ArraySize(g_TradeOps); i++)
    {
        bool background = g_TradeOps[i].source == "trailing_sl" ||
                          g_TradeOps[i].source == "protection_modify" ||
                          g_TradeOps[i].source == "protection_order_modify";
        if(background) continue;
        if(!TradeOpIsFinal(g_TradeOps[i].state))
        {
            active++;
            if(g_TradeOps[i].state == TRADE_OP_AMBIGUOUS) ambiguous++;
            if(g_TradeOps[i].state == TRADE_OP_PARTIAL) partial++;
        }
        else if(g_TradeOps[i].state == TRADE_OP_FAILED && nowMsc - g_TradeOps[i].updated_utc_msc <= 30000)
            recentFailure = true;
        else if(g_TradeOps[i].state == TRADE_OP_CONFIRMED && nowMsc - g_TradeOps[i].updated_utc_msc <= 5000)
            recentConfirmed = true;
    }
    if(ambiguous > 0)
    {
        statusColor = COLOR_SIGNAL_LOSS;
        return Lang("交易待确认 (", "TRADE AMBIGUOUS (") + (string)ambiguous + ")";
    }
    if(partial > 0)
    {
        statusColor = COLOR_SIGNAL_WARNING;
        return Lang("交易部分完成 (", "TRADE PARTIAL (") + (string)active + ")";
    }
    if(active > 0)
    {
        statusColor = COLOR_SIGNAL_WARNING;
        return Lang("交易处理中 (", "TRADE PROCESSING (") + (string)active + ")";
    }
    if(recentFailure)
    {
        statusColor = COLOR_SIGNAL_LOSS;
        return Lang("交易请求失败", "TRADE FAILED");
    }
    if(recentConfirmed)
    {
        statusColor = COLOR_SIGNAL_PROFIT;
        return Lang("服务器已确认", "SERVER CONFIRMED");
    }
    statusColor = COLOR_SIGNAL_PROFIT;
    return "";
}

bool HasUnfinishedNewRiskOperation()
{
    for(int i = 0; i < ArraySize(g_TradeOps); i++)
        if((g_TradeOps[i].action == TRADE_OP_OPEN_MARKET || g_TradeOps[i].action == TRADE_OP_OPEN_LIMIT) &&
           !TradeOpIsFinal(g_TradeOps[i].state))
            return true;
    return false;
}

string TradeLedgerFolderForSchema(int schema) { return "TradeEZ\\requests\\v" + IntegerToString(schema); }
string TradeLedgerFolder() { return TradeLedgerFolderForSchema(TRADE_LEDGER_SCHEMA); }
string TradeLedgerFileNameForSchema(int schema)
{
    return TradeLedgerFolderForSchema(schema) + "\\" + (string)StableTextHash(AccountInfoString(ACCOUNT_SERVER)) + "_" +
           (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" + NormalizeNamespacePart(_Symbol) + "_" +
           NormalizeNamespacePart(Inp_InstanceId) + ".csv";
}
string TradeLedgerFileName() { return TradeLedgerFileNameForSchema(TRADE_LEDGER_SCHEMA); }

void EnsureTradeLedgerFolder()
{
    FolderCreate("TradeEZ");
    FolderCreate("TradeEZ\\requests");
    FolderCreate(TradeLedgerFolder());
}

void SaveTradeLedger()
{
    if(!g_InstanceOwnsState) return;
    long keepAfterMsc = ((long)TimeGMT() - 7 * 86400) * 1000;
    for(int i = ArraySize(g_TradeOps) - 1; i >= 0; i--)
    {
        if(!TradeOpIsFinal(g_TradeOps[i].state) || g_TradeOps[i].updated_utc_msc >= keepAfterMsc) continue;
        int last = ArraySize(g_TradeOps) - 1;
        g_TradeOps[i] = g_TradeOps[last];
        ArrayResize(g_TradeOps, last);
    }
    EnsureTradeLedgerFolder();
    string finalPath = TradeLedgerFileName();
    string tempPath = finalPath + ".tmp";
    int h = FileOpen(tempPath, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
    if(h == INVALID_HANDLE)
    {
        PrintFormat("[Trade Ledger] 临时文件写入失败 error=%d", GetLastError());
        return;
    }
    FileWrite(h, "META", TRADE_LEDGER_SCHEMA, TicketStateNamespace(), (long)TimeGMT());
    for(int i = 0; i < ArraySize(g_TradeOps); i++)
    {
        TradeOperation op = g_TradeOps[i];
        FileWrite(h, "OP", op.operation_id, op.batch_id, op.source, op.action, op.state,
                  (long)op.target_ticket, (long)op.target_position_id, op.magic,
                  op.requested_order_type, op.requested_entry_price,
                  op.requested_volume, op.target_remaining_volume, op.target_sl, op.target_tp,
                  (long)op.request_id, (long)op.order_ticket, (long)op.deal_ticket,
                  (long)op.last_retcode, op.retry_count, op.created_utc_msc,
                  op.last_submit_utc_msc, op.next_retry_utc_msc, op.updated_utc_msc,
                  op.critical_exit ? 1 : 0, op.continuous_batch ? 1 : 0);
    }
    FileFlush(h);
    FileClose(h);
    if(!FileMove(tempPath, 0, finalPath, FILE_REWRITE))
    {
        PrintFormat("[Trade Ledger] 原子替换失败 error=%d", GetLastError());
        FileDelete(tempPath);
        return;
    }
    g_TradeLedgerDirty = false;
}

void LoadTradeLedger()
{
    ArrayResize(g_TradeOps, 0);
    string path = TradeLedgerFileName();
    bool migrateV1 = false;
    if(!FileIsExist(path) && FileIsExist(TradeLedgerFileNameForSchema(1)))
    {
        path = TradeLedgerFileNameForSchema(1);
        migrateV1 = true;
    }
    if(!FileIsExist(path)) return;
    int h = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
    if(h == INVALID_HANDLE) { PrintFormat("[Trade Ledger] 读取失败 error=%d", GetLastError()); return; }
    string tag = FileReadString(h);
    int schema = (int)FileReadNumber(h);
    string ns = FileReadString(h);
    FileReadNumber(h);
    if(tag != "META" || (schema != TRADE_LEDGER_SCHEMA && schema != 1) || ns != TicketStateNamespace())
    {
        Print("[Trade Ledger] 文件头或命名空间不匹配，忽略旧账本");
        FileClose(h);
        return;
    }
    datetime keepAfter = TimeGMT() - 7 * 86400;
    while(!FileIsEnding(h))
    {
        tag = FileReadString(h);
        if(tag == "") break;
        if(tag != "OP") break;
        TradeOperation op;
        op.operation_id = FileReadString(h);
        op.batch_id = FileReadString(h);
        op.source = FileReadString(h);
        op.action = (int)FileReadNumber(h);
        op.state = (int)FileReadNumber(h);
        op.target_ticket = (ulong)FileReadNumber(h);
        op.target_position_id = (ulong)FileReadNumber(h);
        op.magic = (long)FileReadNumber(h);
        op.requested_order_type = (schema >= 2) ? (int)FileReadNumber(h) : -1;
        op.requested_entry_price = (schema >= 2) ? FileReadNumber(h) : 0.0;
        op.requested_volume = FileReadNumber(h);
        op.target_remaining_volume = FileReadNumber(h);
        op.target_sl = FileReadNumber(h);
        op.target_tp = FileReadNumber(h);
        op.request_id = (ulong)FileReadNumber(h);
        op.order_ticket = (ulong)FileReadNumber(h);
        op.deal_ticket = (ulong)FileReadNumber(h);
        op.last_retcode = (uint)(long)FileReadNumber(h);
        op.retry_count = (int)FileReadNumber(h);
        op.created_utc_msc = (long)FileReadNumber(h);
        op.last_submit_utc_msc = (long)FileReadNumber(h);
        op.next_retry_utc_msc = (long)FileReadNumber(h);
        op.updated_utc_msc = (long)FileReadNumber(h);
        op.critical_exit = ((int)FileReadNumber(h) != 0);
        op.continuous_batch = ((int)FileReadNumber(h) != 0);
        if(!TradeOpIsFinal(op.state) || op.updated_utc_msc / 1000 >= (long)keepAfter)
        {
            int n = ArraySize(g_TradeOps);
            ArrayResize(g_TradeOps, n + 1);
            g_TradeOps[n] = op;
        }
    }
    FileClose(h);
    PrintFormat("[Trade Ledger] 已恢复 %d 条操作记录", ArraySize(g_TradeOps));
    if(migrateV1)
    {
        g_TradeLedgerDirty = true;
        SaveTradeLedger();
        Print("[Trade Ledger] V1 已迁移至 V2；旧版未完成开仓缺少方向/价格时将按未知风险禁止新增交易");
    }
}

int CreateTradeOperation(int action, string source, string batchId, ulong ticket,
                         double requestedVolume, double targetRemaining,
                         double targetSL, double targetTP,
                         bool criticalExit, bool continuousBatch)
{
    int existing = ActiveTradeOpIndex(action, ticket);
    if(existing >= 0) return existing;
    TradeOperation op;
    op.operation_id = NewTradeOperationId("OP");
    op.batch_id = batchId;
    op.source = source;
    op.action = action;
    op.state = TRADE_OP_CREATED;
    op.target_ticket = ticket;
    op.target_position_id = 0;
    op.magic = 0;
    op.requested_order_type = -1;
    op.requested_entry_price = 0.0;
    if(ticket > 0 && PositionSelectByTicket(ticket))
    {
        op.target_position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
        op.magic = PositionGetInteger(POSITION_MAGIC);
    }
    else if(ticket > 0 && OrderSelect(ticket))
        op.magic = OrderGetInteger(ORDER_MAGIC);
    op.requested_volume = requestedVolume;
    op.target_remaining_volume = targetRemaining;
    op.target_sl = targetSL;
    op.target_tp = targetTP;
    op.request_id = 0;
    op.order_ticket = 0;
    op.deal_ticket = 0;
    op.last_retcode = 0;
    op.retry_count = 0;
    op.created_utc_msc = ProtectionNowMsc();
    op.last_submit_utc_msc = 0;
    op.next_retry_utc_msc = 0;
    op.updated_utc_msc = op.created_utc_msc;
    op.critical_exit = criticalExit;
    op.continuous_batch = continuousBatch;
    int n = ArraySize(g_TradeOps);
    ArrayResize(g_TradeOps, n + 1);
    g_TradeOps[n] = op;
    g_TradeLedgerDirty = true;
    if(!g_TradeLedgerDeferSave) SaveTradeLedger(); // 单笔先保存意图；批量由调用方统一原子保存。
    return n;
}

long TradeRetryDelayMsc(int retryCount)
{
    if(retryCount <= 1) return 1000;
    if(retryCount == 2) return 2000;
    if(retryCount == 3) return 4000;
    if(retryCount == 4) return 8000;
    return 15000;
}

void ApplyTradeSubmissionResult(int idx, bool sent, const MqlTradeResult &result)
{
    if(idx < 0 || idx >= ArraySize(g_TradeOps)) return;
    long nowMsc = ProtectionNowMsc();
    g_TradeOps[idx].request_id = result.request_id;
    if(result.order > 0) g_TradeOps[idx].order_ticket = result.order;
    if(result.deal > 0) g_TradeOps[idx].deal_ticket = result.deal;
    g_TradeOps[idx].last_retcode = result.retcode;
    g_TradeOps[idx].last_submit_utc_msc = nowMsc;
    g_TradeOps[idx].updated_utc_msc = nowMsc;
    g_TradeOps[idx].retry_count++;
    if(sent)
    {
        g_TradeOps[idx].state = TRADE_OP_SUBMITTED;
        g_TradeOps[idx].next_retry_utc_msc = nowMsc + TradeRetryDelayMsc(g_TradeOps[idx].retry_count);
    }
    else if(g_TradeOps[idx].critical_exit)
    {
        g_TradeOps[idx].state = TRADE_OP_AMBIGUOUS;
        g_TradeOps[idx].next_retry_utc_msc = nowMsc + TradeRetryDelayMsc(g_TradeOps[idx].retry_count);
    }
    else
    {
        g_TradeOps[idx].state = TRADE_OP_FAILED;
        g_TradeOps[idx].next_retry_utc_msc = 0;
    }
    g_TradeLedgerDirty = true;
    if(!g_TradeLedgerDeferSave) SaveTradeLedger();
}

ENUM_ORDER_TYPE_FILLING RequestFillingMode(string symbol)
{
    long mode = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
    if((mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
    if((mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
    return ORDER_FILLING_RETURN;
}

bool SubmitTradeOperation(int idx)
{
    if(idx < 0 || idx >= ArraySize(g_TradeOps) || TradeOpIsFinal(g_TradeOps[idx].state)) return false;
    TradeOperation op = g_TradeOps[idx];
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    bool targetPresent = false;

    if(op.action == TRADE_OP_CLOSE || op.action == TRADE_OP_PARTIAL_CLOSE)
    {
        if(!PositionSelectByTicket(op.target_ticket)) return true;
        string symbol = PositionGetString(POSITION_SYMBOL);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double currentVolume = PositionGetDouble(POSITION_VOLUME);
        double volume = currentVolume;
        double vmin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        if(op.action == TRADE_OP_PARTIAL_CLOSE)
        {
            double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
            if(step <= 0.0) step = 0.01;
            double rawDifference = MathMax(0.0, currentVolume - op.target_remaining_volume);
            volume = NormalizeDouble(MathFloor((rawDifference + step * 0.001) / step) * step, 8);
            if(volume < vmin)
            {
                g_TradeOps[idx].state = TRADE_OP_FAILED;
                g_TradeOps[idx].updated_utc_msc = ProtectionNowMsc();
                g_TradeOps[idx].last_retcode = TRADE_RETCODE_INVALID_VOLUME;
                g_TradeLedgerDirty = true;
                SaveTradeLedger();
                PrintFormat("[Trade Ledger] 部分平仓剩余差额低于最小手数，停止重试 ticket=%I64u difference=%.8f",
                            op.target_ticket, rawDifference);
                return false;
            }
        }
        request.action = TRADE_ACTION_DEAL;
        request.position = op.target_ticket;
        request.symbol = symbol;
        request.volume = MathMin(currentVolume, volume);
        request.magic = (ulong)PositionGetInteger(POSITION_MAGIC);
        request.deviation = (ulong)Inp_Slippage;
        request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(symbol, request.type == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID);
        request.type_filling = RequestFillingMode(symbol);
        request.comment = (op.action == TRADE_OP_CLOSE) ? "TradeEZ close" : "TradeEZ partial";
        targetPresent = true;
    }
    else if(op.action == TRADE_OP_DELETE_ORDER)
    {
        if(!OrderSelect(op.target_ticket)) return true;
        request.action = TRADE_ACTION_REMOVE;
        request.order = op.target_ticket;
        targetPresent = true;
    }
    else if(op.action == TRADE_OP_MODIFY)
    {
        if(!PositionSelectByTicket(op.target_ticket)) return true;
        request.action = TRADE_ACTION_SLTP;
        request.position = op.target_ticket;
        request.symbol = PositionGetString(POSITION_SYMBOL);
        request.sl = NormalizePrice(op.target_sl);
        request.tp = NormalizePrice(op.target_tp);
        targetPresent = true;
    }
    else if(op.action == TRADE_OP_MODIFY_ORDER)
    {
        if(!OrderSelect(op.target_ticket)) return true;
        request.action = TRADE_ACTION_MODIFY;
        request.order = op.target_ticket;
        request.symbol = OrderGetString(ORDER_SYMBOL);
        request.price = OrderGetDouble(ORDER_PRICE_OPEN);
        request.stoplimit = OrderGetDouble(ORDER_PRICE_STOPLIMIT);
        request.sl = NormalizePrice(op.target_sl);
        request.tp = NormalizePrice(op.target_tp);
        request.type_time = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
        request.expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
        targetPresent = true;
    }
    if(!targetPresent) return false;
    ResetLastError();
    bool sent = OrderSendAsync(request, result);
    ApplyTradeSubmissionResult(idx, sent, result);
    PrintFormat("[Trade Ledger] submit op=%s action=%d ticket=%I64u attempt=%d sent=%s request=%I64u retcode=%u error=%d",
                g_TradeOps[idx].operation_id, g_TradeOps[idx].action, g_TradeOps[idx].target_ticket,
                g_TradeOps[idx].retry_count, sent ? "true" : "false", result.request_id,
                result.retcode, GetLastError());
    if(g_TradeOps[idx].critical_exit && g_TradeOps[idx].retry_count == 5)
        Alert(StringFormat(Lang("【交易执行告警】Ticket %I64u 尚未完成，系统将每15秒持续重试。",
                                "[TRADE ALERT] Ticket %I64u is still pending; retrying every 15 seconds."),
                           g_TradeOps[idx].target_ticket));
    return sent;
}

bool TradeOperationSatisfied(int idx)
{
    if(idx < 0 || idx >= ArraySize(g_TradeOps)) return false;
    TradeOperation op = g_TradeOps[idx];
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(step <= 0.0) step = 0.01;
    if(op.action == TRADE_OP_CLOSE) return !PositionSelectByTicket(op.target_ticket);
    if(op.action == TRADE_OP_DELETE_ORDER) return !OrderSelect(op.target_ticket);
    if(op.action == TRADE_OP_PARTIAL_CLOSE)
    {
        if(!PositionSelectByTicket(op.target_ticket)) return true;
        return PositionGetDouble(POSITION_VOLUME) <= op.target_remaining_volume + step * 0.5;
    }
    if(op.action == TRADE_OP_MODIFY)
    {
        if(!PositionSelectByTicket(op.target_ticket)) return true;
        double actualSL = PositionGetDouble(POSITION_SL);
        double actualTP = PositionGetDouble(POSITION_TP);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        bool slOK = (op.target_sl <= 0.0) ? actualSL <= 0.0 : IsSLAtLeastAsSafe(type, actualSL, op.target_sl);
        bool tpOK = (op.target_tp <= 0.0) ? actualTP <= 0.0 : MathAbs(actualTP - op.target_tp) <= MathMax(_Point, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
        return slOK && tpOK;
    }
    if(op.action == TRADE_OP_MODIFY_ORDER)
    {
        if(!OrderSelect(op.target_ticket)) return true;
        double tick = MathMax(_Point, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
        double actualSL = OrderGetDouble(ORDER_SL);
        double actualTP = OrderGetDouble(ORDER_TP);
        ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        ENUM_POSITION_TYPE posType = (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_STOP_LIMIT)
                                   ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        bool slOK = (op.target_sl <= 0.0) ? actualSL <= 0.0 : IsSLAtLeastAsSafe(posType, actualSL, op.target_sl);
        bool tpOK = (op.target_tp <= 0.0) ? actualTP <= 0.0 : MathAbs(actualTP - op.target_tp) <= tick;
        return slOK && tpOK;
    }
    if(op.action == TRADE_OP_OPEN_MARKET)
    {
        if(op.deal_ticket > 0 && HistoryDealSelect(op.deal_ticket)) return true;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
            if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == op.magic &&
               StringFind(PositionGetString(POSITION_COMMENT), op.operation_id) >= 0)
                return true;
        if(HistorySelect((datetime)(op.created_utc_msc / 1000 - 60), TimeCurrent() + 60))
            for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
            {
                ulong deal = HistoryDealGetTicket(i);
                if(deal > 0 && HistoryDealGetInteger(deal, DEAL_MAGIC) == op.magic &&
                   StringFind(HistoryDealGetString(deal, DEAL_COMMENT), op.operation_id) >= 0)
                {
                    g_TradeOps[idx].deal_ticket = deal;
                    return true;
                }
            }
        return false;
    }
    if(op.action == TRADE_OP_OPEN_LIMIT)
    {
        if(op.order_ticket > 0 && OrderSelect(op.order_ticket)) return true;
        if(op.order_ticket > 0 && HistoryOrderSelect(op.order_ticket)) return true;
        for(int i = OrdersTotal() - 1; i >= 0; i--)
            if(OrderGetTicket(i) > 0 && OrderGetInteger(ORDER_MAGIC) == op.magic &&
               StringFind(OrderGetString(ORDER_COMMENT), op.operation_id) >= 0)
                return true;
        if(HistorySelect((datetime)(op.created_utc_msc / 1000 - 60), TimeCurrent() + 60))
            for(int i = HistoryOrdersTotal() - 1; i >= 0; i--)
            {
                ulong order = HistoryOrderGetTicket(i);
                if(order > 0 && HistoryOrderGetInteger(order, ORDER_MAGIC) == op.magic &&
                   StringFind(HistoryOrderGetString(order, ORDER_COMMENT), op.operation_id) >= 0)
                {
                    g_TradeOps[idx].order_ticket = order;
                    return true;
                }
            }
        return false;
    }
    return false;
}

void OnTradeOperationConfirmed(int idx)
{
    if(idx < 0 || idx >= ArraySize(g_TradeOps)) return;
    ulong ticket = g_TradeOps[idx].target_ticket;
    if(g_TradeOps[idx].action == TRADE_OP_PARTIAL_CLOSE)
    {
        int trIdx = TrIndex(ticket);
        if(trIdx >= 0) g_TrReduced[trIdx] = true;
        int stateIdx = TicketStateIndex(ticket);
        if(stateIdx >= 0) g_TicketState[stateIdx].trend_reduced = true;
        MarkTicketStateDirty(false);
    }
    if(g_TradeOps[idx].action == TRADE_OP_CLOSE)
    {
        int stateIdx = TicketStateIndex(ticket);
        if(stateIdx >= 0 && g_TicketState[stateIdx].scalp_phase == SCALP_EXIT_PENDING)
        {
            g_TicketState[stateIdx].scalp_phase = SCALP_CLOSED;
            g_TicketState[stateIdx].closed_utc = TimeGMT();
            MarkTicketStateDirty(false);
        }
    }
    if(g_TradeOps[idx].action == TRADE_OP_MODIFY && PositionSelectByTicket(ticket))
    {
        int stateIdx = TicketStateIndex(ticket);
        if(stateIdx >= 0)
        {
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double actualSL = PositionGetDouble(POSITION_SL);
            g_TicketState[stateIdx].last_confirmed_sl = StrongerSL(type, g_TicketState[stateIdx].last_confirmed_sl, actualSL);
            g_TicketState[stateIdx].last_confirmed_tp = PositionGetDouble(POSITION_TP);
            g_TicketState[stateIdx].protection_status = PROTECTION_CONFIRMED;
            if(g_TradeOps[idx].source == "scalp_let_run" && PositionGetDouble(POSITION_TP) == 0.0)
            {
                g_TicketState[stateIdx].scalp_tp_policy = SCALP_TP_REMOVED;
                g_TicketState[stateIdx].scalp_tp_last_retcode = g_TradeOps[idx].last_retcode;
                PrintFormat("[Scalp TP] Ticket=%I64u REQUIRED -> REMOVED，服务器已确认追踪持有", ticket);
            }
            MarkTicketStateDirty(false);
        }
    }
}

void ReconcileTradeOperations()
{
    long nowMsc = ProtectionNowMsc();
    bool changed = false;
    for(int i = 0; i < ArraySize(g_TradeOps); i++)
    {
        if(TradeOpIsFinal(g_TradeOps[i].state)) continue;
        if(TradeOperationSatisfied(i))
        {
            g_TradeOps[i].state = TRADE_OP_CONFIRMED;
            g_TradeOps[i].updated_utc_msc = nowMsc;
            g_TradeOps[i].next_retry_utc_msc = 0;
            OnTradeOperationConfirmed(i);
            PrintFormat("[Trade Ledger] CONFIRMED op=%s action=%d ticket=%I64u request=%I64u",
                        g_TradeOps[i].operation_id, g_TradeOps[i].action,
                        g_TradeOps[i].target_ticket, g_TradeOps[i].request_id);
            changed = true;
            continue;
        }

        if((g_TradeOps[i].action == TRADE_OP_CLOSE || g_TradeOps[i].action == TRADE_OP_PARTIAL_CLOSE) &&
           PositionSelectByTicket(g_TradeOps[i].target_ticket))
        {
            double currentVolume = PositionGetDouble(POSITION_VOLUME);
            double initialVolume = g_TradeOps[i].requested_volume + g_TradeOps[i].target_remaining_volume;
            double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            if(step <= 0.0) step = 0.01;
            if(currentVolume < initialVolume - step * 0.5 && g_TradeOps[i].state != TRADE_OP_PARTIAL)
            {
                g_TradeOps[i].state = TRADE_OP_PARTIAL;
                g_TradeOps[i].updated_utc_msc = nowMsc;
                changed = true;
            }
        }

        bool entryAction = g_TradeOps[i].action == TRADE_OP_OPEN_MARKET ||
                           g_TradeOps[i].action == TRADE_OP_OPEN_LIMIT;
        if(entryAction)
        {
            if(g_TradeOps[i].state != TRADE_OP_AMBIGUOUS &&
               g_TradeOps[i].last_submit_utc_msc > 0 && nowMsc - g_TradeOps[i].last_submit_utc_msc >= 15000)
            {
                g_TradeOps[i].state = TRADE_OP_AMBIGUOUS;
                g_TradeOps[i].updated_utc_msc = nowMsc;
                changed = true; // 新增风险状态不明时绝不自动重发。
            }
            continue;
        }
        if(g_TradeOps[i].next_retry_utc_msc == 0 || nowMsc >= g_TradeOps[i].next_retry_utc_msc)
            SubmitTradeOperation(i);
    }
    if(changed) { g_TradeLedgerDirty = true; SaveTradeLedger(); }
}

void HandleTradeRequestTransaction(const MqlTradeTransaction &trans,
                                   const MqlTradeRequest &request,
                                   const MqlTradeResult &result)
{
    if(trans.type != TRADE_TRANSACTION_REQUEST) return;
    int idx = TradeOpIndexByRequest(result.request_id);
    if(idx < 0) return;
    g_TradeOps[idx].last_retcode = result.retcode;
    if(result.order > 0) g_TradeOps[idx].order_ticket = result.order;
    if(result.deal > 0) g_TradeOps[idx].deal_ticket = result.deal;
    g_TradeOps[idx].updated_utc_msc = ProtectionNowMsc();
    if(result.retcode == TRADE_RETCODE_DONE_PARTIAL)
        g_TradeOps[idx].state = TRADE_OP_PARTIAL;
    else if(TradeRetcodeAccepted(result.retcode))
        g_TradeOps[idx].state = TRADE_OP_ACCEPTED;
    else if(g_TradeOps[idx].critical_exit)
    {
        g_TradeOps[idx].state = TRADE_OP_AMBIGUOUS;
        g_TradeOps[idx].next_retry_utc_msc = ProtectionNowMsc() + TradeRetryDelayMsc(g_TradeOps[idx].retry_count);
    }
    else
        g_TradeOps[idx].state = TRADE_OP_FAILED;
    g_TradeLedgerDirty = true;
}

int EnsureCloseOperation(ulong ticket, string source, string batchId, bool continuousBatch)
{
    if(ticket == 0 || !PositionSelectByTicket(ticket)) return -1;
    int idx = ActiveTradeOpIndex(TRADE_OP_CLOSE, ticket);
    if(idx >= 0) return idx;
    double volume = PositionGetDouble(POSITION_VOLUME);
    idx = CreateTradeOperation(TRADE_OP_CLOSE, source, batchId, ticket, volume, 0.0, 0.0, 0.0, true, continuousBatch);
    SubmitTradeOperation(idx);
    return idx;
}

int EnsureDeleteOperation(ulong ticket, string source, string batchId, bool continuousBatch)
{
    if(ticket == 0 || !OrderSelect(ticket)) return -1;
    int idx = ActiveTradeOpIndex(TRADE_OP_DELETE_ORDER, ticket);
    if(idx >= 0) return idx;
    idx = CreateTradeOperation(TRADE_OP_DELETE_ORDER, source, batchId, ticket, 0.0, 0.0, 0.0, 0.0, true, continuousBatch);
    SubmitTradeOperation(idx);
    return idx;
}

int EnsurePartialCloseOperation(ulong ticket, double targetRemaining, string source)
{
    if(ticket == 0 || !PositionSelectByTicket(ticket)) return -1;
    int idx = ActiveTradeOpIndex(TRADE_OP_PARTIAL_CLOSE, ticket);
    if(idx >= 0) return idx;
    double currentVolume = PositionGetDouble(POSITION_VOLUME);
    idx = CreateTradeOperation(TRADE_OP_PARTIAL_CLOSE, source, NewTradeBatchId(source), ticket,
                               MathMax(0.0, currentVolume - targetRemaining), targetRemaining,
                               0.0, 0.0, true, false);
    SubmitTradeOperation(idx);
    return idx;
}

int TrackModifyOperation(ulong ticket, double targetSL, double targetTP, string source,
                         bool criticalExit = true)
{
    int idx = ActiveTradeOpIndex(TRADE_OP_MODIFY, ticket);
    if(idx >= 0)
    {
        // 更安全的新止损覆盖旧目标；下一次核销/重试将采用最新保护目标。
        if(PositionSelectByTicket(ticket))
        {
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            g_TradeOps[idx].target_sl = StrongerSL(type, g_TradeOps[idx].target_sl, NormalizePrice(targetSL));
        }
        g_TradeOps[idx].target_tp = NormalizePrice(targetTP);
        if(source == "scalp_let_run") g_TradeOps[idx].source = source;
        g_TradeLedgerDirty = true;
        SaveTradeLedger();
        return idx;
    }
    return CreateTradeOperation(TRADE_OP_MODIFY, source, NewTradeBatchId(source), ticket,
                                0.0, 0.0, NormalizePrice(targetSL), NormalizePrice(targetTP),
                                criticalExit, false);
}

int TrackOrderModifyOperation(ulong ticket, double targetSL, double targetTP, string source)
{
    int idx = ActiveTradeOpIndex(TRADE_OP_MODIFY_ORDER, ticket);
    if(idx >= 0)
    {
        g_TradeOps[idx].target_sl = NormalizePrice(targetSL);
        g_TradeOps[idx].target_tp = NormalizePrice(targetTP);
        g_TradeLedgerDirty = true;
        SaveTradeLedger();
        return idx;
    }
    return CreateTradeOperation(TRADE_OP_MODIFY_ORDER, source, NewTradeBatchId(source), ticket,
                                0.0, 0.0, NormalizePrice(targetSL), NormalizePrice(targetTP),
                                true, false);
}

// 异步提交一组平仓请求；返回值仅表示纳入闭环的目标数，不代表已成交。
int ClosePositionsAsync(const ulong &tickets[], string source = "manual_close", string batchId = "", bool continuousBatch = false)
{
    if(batchId == "") batchId = NewTradeBatchId(source);
    int tracked = 0;
    int newOps[];
    g_TradeLedgerDeferSave = true;
    for(int i = 0; i < ArraySize(tickets); i++)
    {
        ulong ticket = tickets[i];
        if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
        int existing = ActiveTradeOpIndex(TRADE_OP_CLOSE, ticket);
        if(existing < 0)
        {
            int idx = CreateTradeOperation(TRADE_OP_CLOSE, source, batchId, ticket,
                                           PositionGetDouble(POSITION_VOLUME), 0.0,
                                           0.0, 0.0, true, continuousBatch);
            int n = ArraySize(newOps);
            ArrayResize(newOps, n + 1);
            newOps[n] = idx;
        }
        tracked++;
    }
    g_TradeLedgerDeferSave = false;
    if(ArraySize(newOps) > 0) SaveTradeLedger(); // 整批意图必须先于任何服务器请求落盘。
    g_TradeLedgerDeferSave = true;
    for(int i = 0; i < ArraySize(newOps); i++) SubmitTradeOperation(newOps[i]);
    g_TradeLedgerDeferSave = false;
    if(ArraySize(newOps) > 0) SaveTradeLedger();
    return tracked;
}

bool DeleteOrderAsync(ulong ticket, string source = "manual_delete", string batchId = "", bool continuousBatch = false)
{
    if(batchId == "") batchId = NewTradeBatchId(source);
    return EnsureDeleteOperation(ticket, source, batchId, continuousBatch) >= 0;
}

int DeleteOrdersAsync(const ulong &tickets[], string source, string batchId, bool continuousBatch)
{
    int tracked = 0;
    int newOps[];
    g_TradeLedgerDeferSave = true;
    for(int i = 0; i < ArraySize(tickets); i++)
    {
        ulong ticket = tickets[i];
        if(ticket == 0 || !OrderSelect(ticket)) continue;
        int existing = ActiveTradeOpIndex(TRADE_OP_DELETE_ORDER, ticket);
        if(existing < 0)
        {
            int idx = CreateTradeOperation(TRADE_OP_DELETE_ORDER, source, batchId, ticket,
                                           0.0, 0.0, 0.0, 0.0, true, continuousBatch);
            int n = ArraySize(newOps);
            ArrayResize(newOps, n + 1);
            newOps[n] = idx;
        }
        tracked++;
    }
    g_TradeLedgerDeferSave = false;
    if(ArraySize(newOps) > 0) SaveTradeLedger();
    g_TradeLedgerDeferSave = true;
    for(int i = 0; i < ArraySize(newOps); i++) SubmitTradeOperation(newOps[i]);
    g_TradeLedgerDeferSave = false;
    if(ArraySize(newOps) > 0) SaveTradeLedger();
    return tracked;
}

void CancelManagedPendingOrders(ENUM_SOP_ORDER kind, string source)
{
    ulong tickets[];
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        ENUM_SOP_ORDER orderKind = TypeByMagic(OrderGetInteger(ORDER_MAGIC));
        if(orderKind == SOP_IGNORE) continue;
        if(kind != SOP_IGNORE && orderKind != kind) continue;
        int n = ArraySize(tickets);
        ArrayResize(tickets, n + 1);
        tickets[n] = ticket;
    }
    if(ArraySize(tickets) > 0)
        DeleteOrdersAsync(tickets, source, NewTradeBatchId(source), true);
}

void EnforceDailyDrawdownLiquidation()
{
    if(!g_DailyLiquidationActive) return;
    g_TotalBlocked = true;
    if(SymbolIsFlat())
    {
        g_TotalReason = Lang("日回撤强平完成", "Daily liquidation completed");
        return;
    }
    g_TotalReason = Lang("日回撤强平处理中", "Daily liquidation in progress");
    CloseAllOrders("daily_liquidation", "", true);
}

bool SymbolIsFlat()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
        if(PositionGetTicket(i) > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol) return false;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
        if(OrderGetTicket(i) > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol) return false;
    return true;
}

void CloseAllOrders(string source = "manual_all", string batchId = "", bool continuousBatch = false)
{
    if(batchId == "") batchId = NewTradeBatchId(source);
    ulong tickets[];
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        int n = ArraySize(tickets);
        ArrayResize(tickets, n + 1);
        tickets[n] = tk;
    }
    ClosePositionsAsync(tickets, source, batchId, continuousBatch);

    ulong orderTickets[];
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong tk = OrderGetTicket(i);
        if(tk == 0) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        int n = ArraySize(orderTickets);
        ArrayResize(orderTickets, n + 1);
        orderTickets[n] = tk;
    }
    DeleteOrdersAsync(orderTickets, source, batchId, continuousBatch);
}

//+------------------------------------------------------------------+
//| 利润护城河回撤保护:动态回撤阈值触及0 → 强平本品种全部持仓+挂单     |
//| 当日只执行一次,之后保持全局锁定(不再开仓),跨日重置时自愈           |
//+------------------------------------------------------------------+
void EnforceMoatLiquidation()
{
    // 已锁定后仍持续扫描服务器事实，直到本品种真实空仓且无挂单。
    if(g_MoatLiquidated)
    {
        g_TotalBlocked = true;
        if(SymbolIsFlat())
            g_TotalReason = Lang("利润护城河-清盘完成", "Profit moat — cleared");
        else
        {
            g_TotalReason = Lang("利润护城河-清盘处理中", "Profit moat — clearing");
            if(g_MoatBatchId == "") g_MoatBatchId = NewTradeBatchId("moat");
            CloseAllOrders("moat", g_MoatBatchId, true);
        }
        return;
    }
    if(!g_MoatDrawHit) return;   // 本tick未触发回撤保护条件

    // 首次触发：先持久化锁定，再持续清理本品种全部持仓和挂单。
    g_MoatLiquidated = true;
    g_TotalBlocked   = true;
    g_TotalReason    = Lang("利润护城河-清盘处理中", "Profit moat — clearing");
    g_MoatBatchId = NewTradeBatchId("moat");
    SaveState();
    CloseAllOrders("moat", g_MoatBatchId, true);
    if(Inp_AlertOnBreaker)
        Alert(Lang("【护城河强平】动态回撤阈值已触发，正在持续核对并清理全部持仓与挂单。",
                   "[MOAT] Drawdown floor hit. Positions and orders are being reconciled until cleared."));
}

// 平掉指定策略的所有持仓(剥头皮/趋势)
void CloseByKind(ENUM_SOP_ORDER kind)
{
    string source = (kind == SOP_SCALP) ? "manual_scalp" : "manual_trend";
    string batchId = NewTradeBatchId(source);
    ulong tickets[];
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PosType() != kind) continue;
        int n = ArraySize(tickets);
        ArrayResize(tickets, n + 1);
        tickets[n] = tk;
    }
    ClosePositionsAsync(tickets, source, batchId, false);
}

// 只平当前浮盈>0 的持仓(锁定利润单)
void CloseProfitable()
{
    string batchId = NewTradeBatchId("manual_profit");
    ulong tickets[];
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        if(pl <= 0.0) continue;
        int n = ArraySize(tickets);
        ArrayResize(tickets, n + 1);
        tickets[n] = tk;
    }
    ClosePositionsAsync(tickets, "manual_profit", batchId, false);
}

//+------------------------------------------------------------------+
//| 市价开仓                                                          |
//+------------------------------------------------------------------+
void OpenMarket(ENUM_SOP_ORDER kind, bool isBuy)
{
    if(!ValidateOpenConditions(kind)) return;

    double lots   = (kind == SOP_SCALP) ? Inp_ScalpLots : Inp_TrendLots;
    double slPts  = (kind == SOP_SCALP) ? Inp_ScalpSL_Points : Inp_TrendSL_Points;
    double tpPts  = (kind == SOP_SCALP) ? Inp_ScalpTP_Points : 0.0; // 趋势不挂固定TP,靠移动止损
    lots = NormalizeLots(lots);

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double price = isBuy ? ask : bid;
    if(!ValidateEntryProtection(kind, isBuy, price, false)) return;

    double sl = 0.0, tp = 0.0;
    if(slPts > 0.0)
        sl = MinimumProtectionSL(kind, isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, price);
    if(tpPts > 0.0)
        tp = isBuy ? price + PointsToPrice(tpPts) : price - PointsToPrice(tpPts);
    ENUM_ORDER_TYPE orderType = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    if(!ValidateNewRiskCandidate(kind, orderType, lots, price, sl)) return;

    long magic = (kind == SOP_SCALP) ? Inp_MagicScalp : Inp_MagicTrend;
    string cmt = (kind == SOP_SCALP) ? Inp_CommentScalp : Inp_CommentTrend;
    g_TradeLedgerDeferSave = true;
    int opIdx = CreateTradeOperation(TRADE_OP_OPEN_MARKET, "manual_entry", NewTradeBatchId("entry"),
                                     0, lots, 0.0, sl, tp, false, false);
    g_TradeOps[opIdx].magic = magic;
    g_TradeOps[opIdx].requested_order_type = (int)orderType;
    g_TradeOps[opIdx].requested_entry_price = price;
    g_TradeLedgerDeferSave = false;
    g_TradeLedgerDirty = true;
    SaveTradeLedger(); // 完整开仓意图必须先于服务器请求落盘。
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lots;
    request.magic = (ulong)magic;
    request.deviation = (ulong)Inp_Slippage;
    request.type = orderType;
    request.price = price;
    request.sl = NormalizePrice(sl);
    request.tp = NormalizePrice(tp);
    request.type_filling = RequestFillingMode(_Symbol);
    request.comment = StringSubstr(cmt + "|" + g_TradeOps[opIdx].operation_id, 0, 31);
    ResetLastError();
    bool sent = OrderSendAsync(request, result);
    ApplyTradeSubmissionResult(opIdx, sent, result);
    if(!sent)
        Alert(Lang("下单请求未能提交，请查看专家日志。", "Entry request could not be submitted; check the Experts log."));
    else
        PrintFormat("[Trade Ledger] 开仓已提交，等待服务器确认 op=%s request=%I64u", g_TradeOps[opIdx].operation_id, result.request_id);
}

//+------------------------------------------------------------------+
//| 限价挂单                                                          |
//+------------------------------------------------------------------+
void OpenLimit(ENUM_SOP_ORDER kind, bool isBuy, double limitPrice)
{
    string dir = isBuy ? "限价多BUYLIMIT" : "限价空SELLLIMIT";
    string ks  = (kind == SOP_SCALP) ? "剥头皮" : "趋势";
    PrintFormat("[挂单开始] 策略=%s 方向=%s 传入价格=%.5f", ks, dir, limitPrice);

    if(!ValidateOpenConditions(kind))
    {
        Print("[挂单拒绝] 未通过开仓校验(持仓上限/熔断/时段)");
        return;
    }
    if(limitPrice <= 0.0)
    {
        PrintFormat("[挂单拒绝] 价格无效:limitPrice=%.5f(输入框可能未提交/为空)", limitPrice);
        Alert(Lang("【拒绝】挂单价格无效", "[REJECT] Invalid limit price"));
        return;
    }

    double lots  = NormalizeLots((kind == SOP_SCALP) ? Inp_ScalpLots : Inp_TrendLots);
    double slPts = (kind == SOP_SCALP) ? Inp_ScalpSL_Points : Inp_TrendSL_Points;
    double tpPts = (kind == SOP_SCALP) ? Inp_ScalpTP_Points : 0.0;
    limitPrice = NormalizePrice(limitPrice);
    if(!ValidateEntryProtection(kind, isBuy, limitPrice, true)) return;

    // 方向 + 最小挂单距离校验(避免 10015 INVALID_PRICE)
    double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    long   stopsLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDist  = stopsLvl * _Point;
    PrintFormat("[挂单校验] 归一价=%.5f Bid=%.5f Ask=%.5f 最小距离点=%d(%.5f) 手数=%.2f",
                limitPrice, bid, ask, (int)stopsLvl, minDist, lots);

    if(isBuy)
    {
        // BUY LIMIT 必须低于当前 Ask,且距离 ≥ 最小距离
        if(limitPrice >= ask - minDist)
        {
            PrintFormat("[挂单拒绝] 限价多须低于 %.5f,实际=%.5f", ask - minDist, limitPrice);
            Alert(Lang("【拒绝】限价多须低于现价 ", "[REJECT] BUY LIMIT must be below ") +
                  DoubleToString(ask - minDist, _Digits));
            return;
        }
    }
    else
    {
        // SELL LIMIT 必须高于当前 Bid,且距离 ≥ 最小距离
        if(limitPrice <= bid + minDist)
        {
            PrintFormat("[挂单拒绝] 限价空须高于 %.5f,实际=%.5f", bid + minDist, limitPrice);
            Alert(Lang("【拒绝】限价空须高于现价 ", "[REJECT] SELL LIMIT must be above ") +
                  DoubleToString(bid + minDist, _Digits));
            return;
        }
    }

    double sl = 0.0, tp = 0.0;
    if(slPts > 0.0)
        sl = MinimumProtectionSL(kind, isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, limitPrice);
    if(tpPts > 0.0)
        tp = isBuy ? limitPrice + PointsToPrice(tpPts) : limitPrice - PointsToPrice(tpPts);
    ENUM_ORDER_TYPE orderType = isBuy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
    if(!ValidateNewRiskCandidate(kind, orderType, lots, limitPrice, sl)) return;

    long magic = (kind == SOP_SCALP) ? Inp_MagicScalp : Inp_MagicTrend;
    string cmt = (kind == SOP_SCALP) ? Inp_CommentScalp : Inp_CommentTrend;
    g_TradeLedgerDeferSave = true;
    int opIdx = CreateTradeOperation(TRADE_OP_OPEN_LIMIT, "manual_limit", NewTradeBatchId("limit"),
                                     0, lots, 0.0, sl, tp, false, false);
    g_TradeOps[opIdx].magic = magic;
    g_TradeOps[opIdx].requested_order_type = (int)orderType;
    g_TradeOps[opIdx].requested_entry_price = limitPrice;
    g_TradeLedgerDeferSave = false;
    g_TradeLedgerDirty = true;
    SaveTradeLedger(); // 完整挂单意图必须先于服务器请求落盘。
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    request.action = TRADE_ACTION_PENDING;
    request.symbol = _Symbol;
    request.volume = lots;
    request.magic = (ulong)magic;
    request.type = orderType;
    request.price = limitPrice;
    request.sl = NormalizePrice(sl);
    request.tp = NormalizePrice(tp);
    request.type_time = ORDER_TIME_GTC;
    request.type_filling = ORDER_FILLING_RETURN;
    request.comment = StringSubstr(cmt + "|" + g_TradeOps[opIdx].operation_id, 0, 31);
    ResetLastError();
    bool sent = OrderSendAsync(request, result);
    ApplyTradeSubmissionResult(opIdx, sent, result);

    PrintFormat("[挂单结果] %s 价格=%.5f SL=%.5f TP=%.5f 已提交=%s request=%I64u retcode=%u",
                dir, limitPrice, sl, tp, sent ? "是" : "否", result.request_id, result.retcode);
    if(!sent)
        Alert(Lang("挂单请求未能提交，请查看专家日志。", "Limit request could not be submitted; check the Experts log."));
}

// 现价偏移挂单:在当前价基础上 ± offsetUSD 美金处挂多/空(限价单)
// isBuy=true 时价格 = Ask - |offset|(挂低买);isBuy=false 时价格 = Bid + |offset|(挂高卖)
void OpenOffsetLimit(ENUM_SOP_ORDER kind, bool isBuy, double offsetUSD)
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double px  = isBuy ? (ask - MathAbs(offsetUSD)) : (bid + MathAbs(offsetUSD));
    OpenLimit(kind, isBuy, NormalizePrice(px));
}

// 读取输入框价格:优先控件实时文本,为空则用已提交缓存 fallbackTxt
double ReadEditPrice(string editName, string fallbackTxt)
{
    string full = Prefix + editName;
    bool exists = (ObjectFind(0, full) >= 0);
    string live = ObjectGetString(0, full, OBJPROP_TEXT);
    string used = live;
    if(StringToDouble(live) <= 0.0 && StringToDouble(fallbackTxt) > 0.0)
        used = fallbackTxt; // 控件读不到(未失焦),用 ENDEDIT 缓存
    double val = StringToDouble(used);
    PrintFormat("[挂单读取] 对象=%s 存在=%s 控件文本=\"%s\" 缓存文本=\"%s\" 采用=\"%s\" 解析值=%.5f",
                full, (exists ? "是" : "否"), live, fallbackTxt, used, val);
    return val;
}

//+------------------------------------------------------------------+
//| UI 基础组件                                                       |
//+------------------------------------------------------------------+
void CreatePanel(string name, int x, int y, int w, int h, color bg_color, color border_color)
{
    string objName = Prefix + name;
    EnsureUIObject(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg_color);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, border_color);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

// 用 4 条金色实心矩形模拟粗边框(RECTANGLE_LABEL 自带边框仅1px,不明显)
void ColorBar(string name, int x, int y, int w, int h, color c, int z)
{
    string objName = Prefix + name;
    EnsureUIObject(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, c);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, c);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, z);
}

// 命名 + 颜色可指定的模拟边框
void DrawGoldBorderNamed(string tag, int x, int y, int w, int h, int t, color c)
{
    ColorBar(tag + "_BdT", x,         y,         w, t, c, 200);
    ColorBar(tag + "_BdB", x,         y + h - t, w, t, c, 200);
    ColorBar(tag + "_BdL", x,         y,         t, h, c, 200);
    ColorBar(tag + "_BdR", x + w - t, y,         t, h, c, 200);
}

void DrawGoldBorder(int x, int y, int w, int h, int t)
{
    DrawGoldBorderNamed("Panel", x, y, w, h, t, COLOR_GOLD);
}

void CreateCard(string name, int x, int y, int w, int h, color accent_color)
{
    string bgName  = Prefix + name + "_Bg";
    string barName = Prefix + name + "_Bar";

    EnsureUIObject(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, COLOR_CARD_BG);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, COLOR_CARD_BORDER);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);

    EnsureUIObject(0, barName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, barName, OBJPROP_XDISTANCE, x + 2);
    ObjectSetInteger(0, barName, OBJPROP_YDISTANCE, y + 2);
    ObjectSetInteger(0, barName, OBJPROP_XSIZE, 3);
    ObjectSetInteger(0, barName, OBJPROP_YSIZE, h - 4);
    ObjectSetInteger(0, barName, OBJPROP_BGCOLOR, accent_color);
    ObjectSetInteger(0, barName, OBJPROP_BORDER_COLOR, accent_color);
    ObjectSetInteger(0, barName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, barName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, barName, OBJPROP_SELECTABLE, false);
}

void CreateLabel(string name, int x, int y, string text, color clr, double fontSize = 9, bool isBold = false)
{
    string objName = Prefix + name;
    EnsureUIObject(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetString(0, objName, OBJPROP_FONT, isBold ? PANEL_FONT " Bold" : PANEL_FONT);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, ScaledFont(fontSize));
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

// 垂直居中的左对齐标签(y 为文字中线)
void CreateLabelMid(string name, int x, int y, string text, color clr, double fontSize = 9, bool isBold = false)
{
    string objName = Prefix + name;
    EnsureUIObject(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetString(0, objName, OBJPROP_FONT, isBold ? PANEL_FONT " Bold" : PANEL_FONT);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, ScaledFont(fontSize));
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT); // 左对齐+垂直居中
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

// 通用锚点标签(x,y 为锚点像素;anchor 决定对齐方式)
void CreateLabelAnchor(string name, int x, int y, string text, color clr, double fontSize, bool isBold, int anchor)
{
    string objName = Prefix + name;
    EnsureUIObject(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetString(0, objName, OBJPROP_FONT, isBold ? PANEL_FONT " Bold" : PANEL_FONT);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, ScaledFont(fontSize));
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

// 右对齐标签:rightX 为右边界像素X
void CreateLabelRightAt(string name, int rightX, int y, string text, color clr, double fontSize = 9, bool isBold = false)
{
    string objName = Prefix + name;
    EnsureUIObject(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, rightX);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetString(0, objName, OBJPROP_FONT, isBold ? PANEL_FONT " Bold" : PANEL_FONT);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, ScaledFont(fontSize));
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

// 卡片内两端对齐:cardX 为卡片左上角X
void CreateRowLR(string name, int cardX, int y, string leftText, string rightText, color leftColor, color rightColor, bool rightBold = false)
{
    CreateLabel(name + "_Left", cardX + LeftPad, y, leftText, leftColor, 8.5);
    CreateLabelRightAt(name + "_Right", cardX + CardW - RightPad, y, rightText, rightColor, 9, rightBold);
}

void CreateButton(string name, int x, int y, int w, int h, string text, color bg_color, color border_color, color text_clr, double fontSize = 9, bool isBold = false)
{
    // 系统与持仓管理按钮统一采用语言按钮样式，完整/缩小布局共用。
    bool closeAction = name == "Btn_Close_All" || name == "Btn_Close_Scalp" ||
                       name == "Btn_Close_Trend" || name == "Btn_Close_Profit";
    bool operationalAction = closeAction || name == "Btn_Reset_All" ||
                             StringFind(name, "Btn_Sc_") == 0 || StringFind(name, "Btn_Tr_") == 0 ||
                             StringFind(name, "Btn_SCDCancel_") == 0;
    bool recoveryLocksManagement = g_RecoveryStatus == RECOVERY_CHECKING || g_RecoveryStatus == RECOVERY_FAILED ||
                                   (g_RecoveryStatus == RECOVERY_CONSERVATIVE && !g_RecoveryAcknowledged);
    if((!g_InstanceOwnsState && operationalAction) ||
       (g_InstanceOwnsState && recoveryLocksManagement && operationalAction && !closeAction))
    {
        bg_color = COLOR_BTN_DISABLED_BG;
        border_color = COLOR_BTN_DISABLED_BG;
        text_clr = COLOR_BTN_DISABLED_TXT;
    }
    bool systemAction = closeAction || name == "Btn_Stat_Open" ||
                        name == "Btn_Reset_All" || name == "Btn_Sc_LetRun";
    if(systemAction && text_clr != COLOR_BTN_DISABLED_TXT)
    {
        bg_color = COLOR_BTN_SYS_BG;
        border_color = COLOR_BTN_SYS_BORDER;
        text_clr = COLOR_TEXT_HEADER;
    }
    bool importantAction = name == "Btn_Reset_All" ||
                           name == "Btn_Close_Profit";
    if(importantAction && text_clr != COLOR_BTN_DISABLED_TXT)
    {
        bg_color = COLOR_BTN_SYS_BG;
        border_color = COLOR_SIGNAL_WARNING;
        text_clr = COLOR_SIGNAL_WARNING;
    }
    if(closeAction) h = Scale(30); // 与市价做空/做多按钮等高
    string objName = Prefix + name;
    EnsureUIObject(0, objName, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetString(0, objName, OBJPROP_FONT, isBold ? PANEL_FONT " Bold" : PANEL_FONT);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, ScaledFont(fontSize));
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg_color);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, border_color);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, text_clr);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_STATE, false);
}

// 删除本EA所有对象。输入框内容已先缓存,随后按“卡片→输入槽边框→输入框”顺序完整重建。
bool g_UIRenderPass = false;
string g_UITouched[];

// 常规刷新复用现有图表对象，避免销毁悬停目标导致系统光标回退。
bool EnsureUIObject(long chart, string name, ENUM_OBJECT type, int subwindow, datetime time, double price)
{
    if(g_UIRenderPass)
    {
        int n = ArraySize(g_UITouched);
        ArrayResize(g_UITouched, n + 1);
        g_UITouched[n] = name;
    }
    if(ObjectFind(chart, name) >= 0) return true;
    return ObjectCreate(chart, name, type, subwindow, time, price);
}

// 内嵌现有品牌素材；仅首次/缩放变化时重采样，常规刷新复用位图。
void RenderBrandLogo(int x, int y, int size)
{
    static int cachedSize = 0;
    string resource = "TradeEZHeaderLogo";
    if(cachedSize != size)
    {
        uint source[], width, height;
        if(!ResourceReadImage("::website-design\\logo\\ea-logo.bmp", source, width, height)) return;
        uint pixels[];
        ArrayResize(pixels, size * size);
        for(int dy = 0; dy < size; dy++)
        for(int dx = 0; dx < size; dx++)
        {
            int x0 = dx * (int)width / size;
            int x1 = MathMax(x0 + 1, (dx + 1) * (int)width / size);
            int y0 = dy * (int)height / size;
            int y1 = MathMax(y0 + 1, (dy + 1) * (int)height / size);
            uint r = 0, g = 0, b = 0, count = 0;
            for(int sy = y0; sy < y1; sy++)
            for(int sx = x0; sx < x1; sx++)
            {
                uint pixel = source[sy * (int)width + sx];
                r += (pixel >> 16) & 255;
                g += (pixel >> 8) & 255;
                b += pixel & 255;
                count++;
            }
            pixels[dy * size + dx] = 0xFF000000 | ((r/count) << 16) | ((g/count) << 8) | (b/count);
        }
        if(!ResourceCreate(resource, pixels, size, size, 0, 0, size, COLOR_FORMAT_ARGB_NORMALIZE)) return;
        cachedSize = size;
    }
    string name = Prefix + "BrandLogo";
    EnsureUIObject(0, name, OBJ_BITMAP_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_BMPFILE, 0, "::" + resource);
    ObjectSetString(0, name, OBJPROP_BMPFILE, 1, "::" + resource);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, size);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, size);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, Lang("查看更新日志", "View release notes"));
}

void BeginUIRefresh()
{
    ArrayResize(g_UITouched, 0);
    g_UIRenderPass = true;
}

void EndUIRefresh()
{
    g_UIRenderPass = false;
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, Prefix) != 0) continue;
        bool used = false;
        for(int j = 0; j < ArraySize(g_UITouched); j++)
        {
            if(g_UITouched[j] == nm) { used = true; break; }
        }
        if(!used) ObjectDelete(0, nm);
    }
}

//+------------------------------------------------------------------+
//| 报价条:卖价靠左 / 买价靠右 / 点差居中,整数小、小数大,底部对齐    |
//+------------------------------------------------------------------+
void GetQuoteBarGeometry(int &x, int &y, int &h, int &halfW, int &rightX, int &midY)
{
    x = Col1X;
    y = StartY + Scale(16) + Scale(36);  // 与 RenderPerfectUI 的顶栏高度保持同步
    h = Scale(44);

    int fullW  = g_Collapsed ? CardW : Col2X + CardW - x;
    int gapMid = Scale(40); // 一体报价条中央的点差数值区
    halfW  = (fullW - gapMid) / 2;
    rightX = x + halfW + gapMid;
    midY   = y + h / 2;
}

void GetSplitPriceGeometry(int leftX, int blockW, int midY, int intLen, int decLen, int align,
                           int &startX, int &decX, int &intY, int &decY)
{
    int intCharW = Scale(12);
    int gap      = Scale(4);
    int decCharW = Scale(18);
    int edgePad  = Scale(18);
    int intOffY  = Scale(5);

    int intPx  = intLen * intCharW;
    int decPx  = decLen * decCharW;
    int priceW = intPx + gap + decPx;

    if(align < 0) startX = leftX + blockW - edgePad - priceW;
    else          startX = leftX + edgePad;

    decX = startX + intPx + gap;
    // 字体框中线与可见数字中线有偏差，整体上移3px补偿，保留大小字基线关系。
    intY = midY + intOffY - Scale(3);
    decY = midY - Scale(3);
}

// 画一个价格:整数常规 + 末两位放大,垂直居中(midY 为中线)。
// align: -1=靠右(leftX+blockW 为右边界), +1=靠左(leftX 为左边界)
void DrawSplitPrice(string name, int leftX, int blockW, int midY, double price, color txtColor, int align)
{
    string s0 = DoubleToString(price, _Digits);
    int dot = StringFind(s0, ".");
    string intPart = s0, decPart = "";
    if(dot >= 0) { intPart = StringSubstr(s0, 0, dot); decPart = StringSubstr(s0, dot + 1); }

    int startX, decX, intY, decY;
    GetSplitPriceGeometry(leftX, blockW, midY, StringLen(intPart), StringLen(decPart), align,
                          startX, decX, intY, decY);

    CreateLabelAnchor(name + "_Int", startX, intY, intPart, txtColor, 16, true, ANCHOR_LEFT);
    CreateLabelAnchor(name + "_Dec", decX,   decY, decPart, txtColor, 26, true, ANCHOR_LEFT);
}

// 左右两侧各缓存红/蓝渐变；仅外侧圆角，中间平直衔接点差区。
void RenderQuoteBackground(string tag, int x, int y, int w, int h, bool rising)
{
    static int cachedW = 0, cachedH = 0;
    if(cachedW != w || cachedH != h)
    {
        uint pixels[];
        ArrayResize(pixels, w*h);
        double radius = MathMin(Scale(4), MathMin(w, h)/2.0);
        for(int variant = 0; variant < 4; variant++)
        {
            int theme = variant % 2;
            bool leftSide = variant < 2;
            for(int row = 0; row < h; row++)
            {
                double t = (double)row / MathMax(1, h-1);
                int r = theme == 0 ? (int)(65*(1-t)) : (int)(255-65*t);
                int g = theme == 0 ? (int)(65*(1-t)) : (int)(65*(1-t));
                int b = theme == 0 ? (int)(255-75*t) : (int)(65*(1-t));
                uint argb = 0xFF000000 | ((uint)r << 16) | ((uint)g << 8) | (uint)b;
                for(int col = 0; col < w; col++)
                {
                    // 4px 轻圆角，边缘一像素抗锯齿；仅生成缓存时计算。
                    double px = col + 0.5, py = row + 0.5;
                    double dx = MathMax(leftSide ? radius-px : px-(w-radius), 0.0);
                    double dy = MathMax(MathMax(radius-py, py-(h-radius)), 0.0);
                    double coverage = MathMax(0.0, MathMin(1.0, radius + 0.5 - MathSqrt(dx*dx + dy*dy)));
                    uint alpha = (uint)MathRound(255.0 * coverage);
                    pixels[row*w+col] = (alpha << 24) | (argb & 0x00FFFFFF);
                }
            }
            string resourceName = (leftSide ? "QuoteLeft" : "QuoteRight") + (theme == 0 ? "Blue" : "Red");
            if(!ResourceCreate(resourceName,
                               pixels, w, h, 0, 0, w, COLOR_FORMAT_ARGB_NORMALIZE))
                return;
        }
        cachedW = w;
        cachedH = h;
    }
    string name = Prefix + tag;
    EnsureUIObject(0, name, OBJ_BITMAP_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    string resource = (tag == "PxSell_Bg" ? "::QuoteLeft" : "::QuoteRight") + (rising ? "Blue" : "Red");
    ObjectSetString(0, name, OBJPROP_BMPFILE, 0, resource);
    ObjectSetString(0, name, OBJPROP_BMPFILE, 1, resource);
}

void RenderQuoteBar(double bid, double ask)
{
    int x, y, h, halfW, rightX, cy;
    GetQuoteBarGeometry(x, y, h, halfW, rightX, cy);

    RenderQuoteBackground("PxSell_Bg", x, y, halfW, h, g_BidDir > 0);
    RenderQuoteBackground("PxBuy_Bg", rightX, y, halfW, h, g_AskDir > 0);

    // 同高深色中段连接左右报价，无空隙；淡色边界区分报价与点差。
    int middleX = x + halfW;
    int middleW = rightX - middleX;
    CreatePanel("PxSpread_Bg", middleX, y, middleW, h, COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BG);
    CreatePanel("PxSpread_EdgeL", middleX, y, Scale(1), h, COLOR_BTN_SYS_BORDER, COLOR_BTN_SYS_BORDER);
    CreatePanel("PxSpread_EdgeR", rightX - Scale(1), y, Scale(1), h, COLOR_BTN_SYS_BORDER, COLOR_BTN_SYS_BORDER);

    DrawSplitPrice("PxSell", x,      halfW, cy, bid, C'255,255,255', -1);
    DrawSplitPrice("PxBuy",  rightX, halfW, cy, ask, C'255,255,255', +1);

    double spread = (ask - bid) / _Point;
    int cx = (x + halfW + rightX) / 2;
    CreateLabelAnchor("PxSpread", cx, cy, DoubleToString(spread, 0), COLOR_TEXT_HEADER, 11, true, ANCHOR_CENTER);
    ObjectSetString(0, Prefix + "PxSpread", OBJPROP_TOOLTIP,
                    Lang("买卖价差（报价点）", "Bid/ask spread (points)"));
}

//+------------------------------------------------------------------+
//| K线收盘倒计时                                                     |
//+------------------------------------------------------------------+
string BarCountdown()
{
    int tf = PeriodSeconds(PERIOD_CURRENT);
    if(tf <= 0) return "--";
    datetime barOpen = iTime(_Symbol, PERIOD_CURRENT, 0);
    if(barOpen == 0) barOpen = TimeCurrent();
    int elapsed = (int)(TimeCurrent() - barOpen);
    int remain  = tf - elapsed;
    if(remain < 0) remain = 0;
    int hh = remain / 3600;
    int mm = (remain % 3600) / 60;
    int ss = remain % 60;
    if(hh > 0) return StringFormat("%d:%02d:%02d", hh, mm, ss);
    return StringFormat("%02d:%02d", mm, ss);
}

//+------------------------------------------------------------------+
//| 单独更新报价条(每tick调用,不重建整个面板)                        |
//+------------------------------------------------------------------+
void UpdateQuoteBar()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    // 仅在报价事件中比较；每秒 UI 重绘不得将同一笔报价再次判为持平。
    g_BidDir = (g_PrevBid > 0 && bid > g_PrevBid) ? 1 : -1;
    g_AskDir = (g_PrevAsk > 0 && ask > g_PrevAsk) ? 1 : -1;
    g_PrevBid = bid;
    g_PrevAsk = ask;

    string bidStr = DoubleToString(bid, _Digits);
    string askStr = DoubleToString(ask, _Digits);
    int bidDot = StringFind(bidStr, "."), askDot = StringFind(askStr, ".");
    string bidInt = bidStr, bidDec = "", askInt = askStr, askDec = "";
    if(bidDot >= 0) { bidInt = StringSubstr(bidStr, 0, bidDot); bidDec = StringSubstr(bidStr, bidDot + 1); }
    if(askDot >= 0) { askInt = StringSubstr(askStr, 0, askDot); askDec = StringSubstr(askStr, askDot + 1); }

    int x, y, h, halfW, rightX, cy;
    GetQuoteBarGeometry(x, y, h, halfW, rightX, cy);
    RenderQuoteBackground("PxSell_Bg", x, y, halfW, h, g_BidDir > 0);
    RenderQuoteBackground("PxBuy_Bg", rightX, y, halfW, h, g_AskDir > 0);

    int startX, decX, intY, decY;
    GetSplitPriceGeometry(x, halfW, cy, StringLen(bidInt), StringLen(bidDec), -1,
                          startX, decX, intY, decY);
    ObjectSetString(0, Prefix + "PxSell_Int", OBJPROP_TEXT, bidInt);
    ObjectSetString(0, Prefix + "PxSell_Dec", OBJPROP_TEXT, bidDec);
    ObjectSetInteger(0, Prefix + "PxSell_Int", OBJPROP_XDISTANCE, startX);
    ObjectSetInteger(0, Prefix + "PxSell_Int", OBJPROP_YDISTANCE, intY);
    ObjectSetInteger(0, Prefix + "PxSell_Dec", OBJPROP_XDISTANCE, decX);
    ObjectSetInteger(0, Prefix + "PxSell_Dec", OBJPROP_YDISTANCE, decY);

    GetSplitPriceGeometry(rightX, halfW, cy, StringLen(askInt), StringLen(askDec), +1,
                          startX, decX, intY, decY);
    ObjectSetString(0, Prefix + "PxBuy_Int", OBJPROP_TEXT, askInt);
    ObjectSetString(0, Prefix + "PxBuy_Dec", OBJPROP_TEXT, askDec);
    ObjectSetInteger(0, Prefix + "PxBuy_Int", OBJPROP_XDISTANCE, startX);
    ObjectSetInteger(0, Prefix + "PxBuy_Int", OBJPROP_YDISTANCE, intY);
    ObjectSetInteger(0, Prefix + "PxBuy_Dec", OBJPROP_XDISTANCE, decX);
    ObjectSetInteger(0, Prefix + "PxBuy_Dec", OBJPROP_YDISTANCE, decY);

    double spread = (ask - bid) / _Point;
    ObjectSetString(0, Prefix + "PxSpread", OBJPROP_TEXT, DoubleToString(spread, 0));

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| 格式化工具                                                        |
//+------------------------------------------------------------------+
string FmtMoney(double v)
{
    string s = DoubleToString(MathAbs(v), 2);
    if(v < 0.0)     return "-$ " + s;
    return "+$ " + s;
}
string FmtMoneyPlain(double v) { return "$ " + DoubleToString(v, 2); }

color PLColor(double v)
{
    if(v > 0.0)  return COLOR_SIGNAL_PROFIT;
    if(v < 0.0)  return COLOR_SIGNAL_LOSS;
    return COLOR_TEXT_BODY;
}

// 熔断间距颜色:剩余越少越危险
color GapColor(double loss, double limit)
{
    if(limit <= 0.0) return COLOR_TEXT_BODY;
    double used = loss / limit;
    if(used < 0.30) return COLOR_SIGNAL_PROFIT;
    if(used < 0.60) return COLOR_SIGNAL_WARNING;
    return COLOR_SIGNAL_LOSS;
}

//+------------------------------------------------------------------+
//| 侧拉历史明细舱                                                    |
//+------------------------------------------------------------------+
void RenderHistoryCabin()
{
    // 先统计行数,按行数动态定高
    BuildClosedRows(g_DetailSide);
    int rowCnt = ArraySize(g_Rows);
    int maxRows = 30;                               // 最多显示行数
    int showRows = (rowCnt < maxRows) ? rowCnt : maxRows;

    int cabX = StartX + PanelWidth + 10;
    int cabY = StartY;
    int cabW = 510;
    int headH = 71;                                 // 标题+表头+分割线区
    int footH = 30;                                 // 底部提示区
    int bodyH = (showRows > 0 ? showRows : 1) * 24; // 数据行区
    int cabH = headH + bodyH + footH;
    if(cabH < 150) cabH = 150;

    CreatePanel("Cab_Bg", cabX, cabY, cabW, cabH, COLOR_CARD_BG, COLOR_CARD_BORDER);

    // 左侧科技指示线
    string barName = Prefix + "Cab_Bar";
    EnsureUIObject(0, barName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, barName, OBJPROP_XDISTANCE, cabX + 2);
    ObjectSetInteger(0, barName, OBJPROP_YDISTANCE, cabY + 2);
    ObjectSetInteger(0, barName, OBJPROP_XSIZE, 4);
    ObjectSetInteger(0, barName, OBJPROP_YSIZE, cabH - 4);
    ObjectSetInteger(0, barName, OBJPROP_BGCOLOR, COLOR_SIGNAL_PROFIT);
    ObjectSetInteger(0, barName, OBJPROP_BORDER_COLOR, COLOR_SIGNAL_PROFIT);
    ObjectSetInteger(0, barName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, barName, OBJPROP_CORNER, CORNER_LEFT_UPPER);

    string sideName = g_DetailAll ? Lang("全部", "ALL")
                    : ((g_DetailSide == SOP_SCALP) ? Lang("剥头皮", "SCALP") : Lang("趋势", "TREND"));
    CreateLabel("Cab_Title", cabX + 20, cabY + 14, Lang("今日已平仓明细舱 · ", "CLOSED AUDIT · ") + sideName, COLOR_TEXT_HEADER, 10, true);
    CreateButton("Btn_Cab_Close", cabX + cabW - 35, cabY + 10, 25, 20, "X", COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BORDER, COLOR_SIGNAL_LOSS, 8.5, true);

    int rowY = cabY + 45;
    CreateLabel("H_Time", cabX + 18,  rowY, Lang("成交时间", "TIME"), COLOR_TEXT_MUTED, 8);
    CreateLabel("H_Strat",cabX + 90,  rowY, Lang("策略", "STRAT"), COLOR_TEXT_MUTED, 8);
    CreateLabel("H_Dir",  cabX + 132, rowY, Lang("方向", "DIR"),  COLOR_TEXT_MUTED, 8);
    CreateLabel("H_Lots", cabX + 175, rowY, Lang("手数", "LOTS"), COLOR_TEXT_MUTED, 8);
    CreateLabel("H_Pr",   cabX + 222, rowY, Lang("开仓价 -> 平仓价", "ROUTE"), COLOR_TEXT_MUTED, 8);
    CreateLabel("H_Dur",  cabX + 360, rowY, Lang("持时", "DURATION"), COLOR_TEXT_MUTED, 8);
    CreateLabel("H_Pnl",  cabX + 435, rowY, Lang("盈/亏金额", "PNL"), COLOR_TEXT_MUTED, 8);

    string sepName = Prefix + "Cab_Sep";
    EnsureUIObject(0, sepName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, sepName, OBJPROP_XDISTANCE, cabX + 15);
    ObjectSetInteger(0, sepName, OBJPROP_YDISTANCE, rowY + 16);
    ObjectSetInteger(0, sepName, OBJPROP_XSIZE, cabW - 30);
    ObjectSetInteger(0, sepName, OBJPROP_YSIZE, 1);
    ObjectSetInteger(0, sepName, OBJPROP_BGCOLOR, COLOR_CARD_BORDER);
    ObjectSetInteger(0, sepName, OBJPROP_BORDER_COLOR, COLOR_CARD_BORDER);
    ObjectSetInteger(0, sepName, OBJPROP_CORNER, CORNER_LEFT_UPPER);

    rowY += 26;

    if(rowCnt == 0)
    {
        CreateLabel("Cab_Empty", cabX + 20, rowY, g_DetailAll ? Lang("今日暂无平仓记录", "No closed records today")
                                                              : Lang("今日暂无该策略平仓记录", "No closed records today"), COLOR_TEXT_MUTED, 8.5);
    }
    for(int i = 0; i < showRows; i++)
    {
        color dirColor = (g_Rows[i].type == "BUY") ? COLOR_SIGNAL_PROFIT : COLOR_SIGNAL_LOSS;
        color pnlColor = (g_Rows[i].pnl >= 0) ? COLOR_SIGNAL_PROFIT : COLOR_SIGNAL_LOSS;
        string pnlStr  = FmtMoney(g_Rows[i].pnl);

        string ix = (string)i;
        CreateLabel("Row_T_" + ix,  cabX + 18,  rowY, g_Rows[i].time, COLOR_TEXT_BODY, 8.5);
        CreateLabel("Row_S_" + ix,  cabX + 90,  rowY, g_Rows[i].strat, COLOR_TEXT_MUTED, 8.5);
        CreateLabel("Row_D_" + ix,  cabX + 132, rowY, g_Rows[i].type, dirColor, 8.5, true);
        CreateLabel("Row_L_" + ix,  cabX + 175, rowY, DoubleToString(g_Rows[i].lots, 2), COLOR_TEXT_BODY, 8.5);
        string route = DoubleToString(g_Rows[i].open_price, 2) + " -> " + DoubleToString(g_Rows[i].close_price, 2);
        CreateLabel("Row_R_" + ix,  cabX + 222, rowY, route, COLOR_TEXT_BODY, 8.5);
        CreateLabel("Row_Du_" + ix, cabX + 360, rowY, g_Rows[i].duration, COLOR_TEXT_BODY, 8.5);
        CreateLabel("Row_P_" + ix,  cabX + 435, rowY, pnlStr, pnlColor, 8.5, true);
        rowY += 24;
    }

    CreateLabel("Cab_Tip", cabX + 20, cabY + cabH - 24, Lang("* 数据来自 MT5 账户历史,开平仓自动同步", "* Auto-synced with MT5 account history"), COLOR_TEXT_MUTED, 7.5);
}

//+------------------------------------------------------------------+
//| 构建今日某策略已平仓明细(配对开仓/平仓成交)                       |
//+------------------------------------------------------------------+
void BuildClosedRows(ENUM_SOP_ORDER kind)
{
    ArrayResize(g_Rows, 0);
    datetime statFrom = StatStart();
    // 选择更宽的窗口(往前 30 天),保证跨重置点开仓的 IN 成交也在内以便配对
    datetime selFrom  = statFrom - 30 * 86400;
    if(!HistorySelect(selFrom, TimeCurrent() + 3600)) return;

    int deals = HistoryDealsTotal();
    for(int i = 0; i < deals; i++)
    {
        ulong dt = HistoryDealGetTicket(i);
        if(dt == 0) continue;
        if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) continue;
        if(!DealIsExit(dt)) continue;
        // 仅统计"今日起点之后平仓"的成交
        if((datetime)HistoryDealGetInteger(dt, DEAL_TIME) < statFrom) continue;
        ENUM_SOP_ORDER dk = DealStrategyType(dt);        // 回溯开仓magic,兼容手工平仓
        if(!g_DetailAll && dk != kind) continue;         // 单策略模式才过滤;全部模式全收

        int n = ArraySize(g_Rows);
        ArrayResize(g_Rows, n + 1);

        datetime closeT = (datetime)HistoryDealGetInteger(dt, DEAL_TIME);
        long dtype = HistoryDealGetInteger(dt, DEAL_TYPE);
        // 平仓成交方向与持仓方向相反:平多=SELL成交
        g_Rows[n].type        = (dtype == DEAL_TYPE_SELL) ? "BUY" : "SELL";
        g_Rows[n].lots        = HistoryDealGetDouble(dt, DEAL_VOLUME); // 下单手数
        g_Rows[n].strat       = (dk == SOP_SCALP) ? Lang("剥头皮","SC")
                              : (dk == SOP_TREND ? Lang("趋势","TR") : Lang("手动","MAN"));
        g_Rows[n].close_price = HistoryDealGetDouble(dt, DEAL_PRICE);
        g_Rows[n].open_price  = HistoryDealGetDouble(dt, DEAL_PRICE); // 无入场价时退化显示
        g_Rows[n].pnl         = DealCashValue(dt);
        g_Rows[n].time        = TimeToString(ToBeijing(closeT), TIME_MINUTES | TIME_SECONDS); // 北京时间

        // 尝试用 position id 找入场价与持时
        long posId = HistoryDealGetInteger(dt, DEAL_POSITION_ID);
        datetime openT = closeT;
        double entryVolume = 0.0;
        double entryPriceVolume = 0.0;
        double entryCosts = 0.0;
        for(int j = 0; j < deals; j++)
        {
            ulong dj = HistoryDealGetTicket(j);
            if(dj == 0) continue;
            if(HistoryDealGetInteger(dj, DEAL_POSITION_ID) != posId) continue;
            if(HistoryDealGetInteger(dj, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            double entryDealVolume = HistoryDealGetDouble(dj, DEAL_VOLUME);
            entryVolume += entryDealVolume;
            entryPriceVolume += HistoryDealGetDouble(dj, DEAL_PRICE) * entryDealVolume;
            entryCosts += HistoryDealGetDouble(dj, DEAL_COMMISSION) + HistoryDealGetDouble(dj, DEAL_FEE);
            datetime entryT = (datetime)HistoryDealGetInteger(dj, DEAL_TIME);
            if(openT == closeT || entryT < openT) openT = entryT;
        }
        if(entryVolume > 0.0)
        {
            g_Rows[n].open_price = entryPriceVolume / entryVolume;
            g_Rows[n].pnl += entryCosts * MathMin(1.0, g_Rows[n].lots / entryVolume);
        }
        int secs = (int)(closeT - openT);
        if(secs < 0) secs = 0;
        g_Rows[n].duration = (string)(secs / 60) + "m " + (string)(secs % 60) + "s";
    }
}

//+------------------------------------------------------------------+
//| 策略卡片:下单按钮 + 限价行(卡片相对坐标)                         |
//+------------------------------------------------------------------+
void RenderStrategyCardButtons(string tag, int cardX, int contentY, string title, ENUM_SOP_ORDER kind, bool allowed)
{
    color buyBg  = allowed ? COLOR_BTN_BUY_BG  : COLOR_BTN_DISABLED_BG;
    color sellBg = allowed ? COLOR_BTN_SELL_BG : COLOR_BTN_DISABLED_BG;
    color buyTx  = allowed ? COLOR_SIGNAL_PROFIT : COLOR_BTN_DISABLED_TXT;
    color sellTx = allowed ? COLOR_SIGNAL_LOSS   : COLOR_BTN_DISABLED_TXT;
    color buyBd  = allowed ? COLOR_BTN_BUY_BORDER  : COLOR_BTN_DISABLED_BG;
    color sellBd = allowed ? COLOR_BTN_SELL_BORDER : COLOR_BTN_DISABLED_BG;
    int leftX = cardX + LeftPad;
    int marketH = Scale(30);
    if(kind == SOP_SCALP)
    {
        int marketGap = Scale(4);
        // 剥头皮:做空 / 做多 / 极速单(规划占位) / 追踪持有
        int bw = (CardW - LeftPad - RightPad - 3 * marketGap) / 4;
        CreateButton("Btn_" + tag + "_Sell", leftX,             contentY, bw, marketH, Lang("做空", "SELL"), sellBg, sellBd, sellTx, 9, true);
        CreateButton("Btn_" + tag + "_Buy",  leftX + bw + marketGap,    contentY, bw, marketH, Lang("做多", "BUY"),  buyBg,  buyBd,  buyTx,  9, true);
        CreateButton("Btn_Sc_SpeedPlan", leftX + 2*(bw+marketGap), contentY, bw, marketH,
                     Lang("极速单", "SPEED"), COLOR_BTN_DISABLED_BG, COLOR_BTN_DISABLED_BG,
                     COLOR_BTN_DISABLED_TXT, 9, true);
        // 追踪持有不新增仓位且不撤销服务器 SL，风险未知或熔断时仍允许管理既有仓位。
        bool letRunEnabled = g_InstanceOwnsState && HasEligibleScalpLetRun();
        color letRunBg = letRunEnabled ? COLOR_BTN_SYS_BG : COLOR_BTN_DISABLED_BG;
        color letRunTx = letRunEnabled ? COLOR_SIGNAL_WARNING : COLOR_BTN_DISABLED_TXT;
        color letRunBd = letRunEnabled ? COLOR_SIGNAL_WARNING : COLOR_BTN_DISABLED_BG;
        CreateButton("Btn_Sc_LetRun", leftX + 3*(bw+marketGap), contentY, bw, marketH,
                     Lang("追踪持有", "LET RUN"), letRunBg, letRunBd, letRunTx, 9, true);
    }
    else
    {
        // 趋势:做空(左) / 做多(右,两按钮均分)
        int marketGap = Scale(12);
        int bw = (CardW - LeftPad - RightPad - marketGap) / 2;
        int rightX = cardX + CardW - RightPad - bw;
        CreateButton("Btn_" + tag + "_Sell", leftX,  contentY, bw, marketH, Lang(title + " 做空", "TREND SELL"), sellBg, sellBd, sellTx, 9, true);
        CreateButton("Btn_" + tag + "_Buy",  rightX, contentY, bw, marketH, Lang(title + " 做多", "TREND BUY"),  buyBg,  buyBd,  buyTx,  9, true);
    }
    if(!g_Collapsed)
    {
    contentY += Scale(38);

    // 限价挂单行：标签 + 银灰白输入槽 + 两个限价按钮
    int rowH  = Scale(30);
    int lbtnW = Scale(78);
    CreateLabel(tag + "_Limit_Lbl", cardX + LeftPad, contentY + Scale(9), Lang("挂单价", "PX"), COLOR_TEXT_MUTED, 8);
    int editX = cardX + LeftPad + Scale(46);
    int editW = lbtnW;  // 与后面的限价空/限价多按钮同宽

    // 读取输入框当前内容(含正在输入未提交的)
    string editName = Prefix + "Edt_" + tag + "_Price";
    string liveText = "";
    if(ObjectFind(0, editName) >= 0)
        liveText = ObjectGetString(0, editName, OBJPROP_TEXT);

    // 决定显示内容:实时输入 > 已提交缓存 > 空白
    string editVal = "";
    if(liveText != "")
        editVal = liveText;
    else if((kind == SOP_SCALP && g_ScPriceTxt != "") || (kind == SOP_TREND && g_TrPriceTxt != ""))
        editVal = (kind == SOP_SCALP) ? g_ScPriceTxt : g_TrPriceTxt;

    // 灰白描边 + 内嵌编辑框的"数值输入槽"风格
    // 外层绘制灰白细边,内层编辑框显式设置同色背景,避免默认黑底白框
    string bgName = Prefix + "Edt_" + tag + "_PriceBg";
    EnsureUIObject(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, editX);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, contentY);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, editW);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, rowH);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, COLOR_INPUT_BG);     // 与编辑控件同色,无双层色差
    ObjectSetInteger(0, bgName, OBJPROP_COLOR, COLOR_INPUT_BORDER); // 矩形标签的平面边框颜色
    ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, bgName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, bgName, OBJPROP_ZORDER, 99);

    // 编辑控件内缩一像素,内边框与底色一致,仅保留外层细描边
    EnsureUIObject(0, editName, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, editName, OBJPROP_XDISTANCE, editX + Scale(1));
    ObjectSetInteger(0, editName, OBJPROP_YDISTANCE, contentY + Scale(1));
    ObjectSetInteger(0, editName, OBJPROP_XSIZE, editW - 2 * Scale(1));
    ObjectSetInteger(0, editName, OBJPROP_YSIZE, rowH - 2 * Scale(1));
    ObjectSetString(0, editName, OBJPROP_TEXT, editVal);
    ObjectSetString(0, editName, OBJPROP_FONT, PANEL_FONT);
    ObjectSetInteger(0, editName, OBJPROP_FONTSIZE, ScaledFont(12));
    ObjectSetInteger(0, editName, OBJPROP_ALIGN, ALIGN_CENTER);
    ObjectSetInteger(0, editName, OBJPROP_COLOR, COLOR_TEXT_HEADER);
    ObjectSetInteger(0, editName, OBJPROP_BGCOLOR, COLOR_INPUT_BG);
    ObjectSetInteger(0, editName, OBJPROP_BORDER_COLOR, COLOR_INPUT_BG);
    ObjectSetInteger(0, editName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, editName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, editName, OBJPROP_READONLY, false);
    ObjectSetInteger(0, editName, OBJPROP_ZORDER, 100);
    int lbuyX  = cardX + CardW - RightPad - lbtnW;   // 限价多在右
    int lsellX = lbuyX - lbtnW - Scale(8);                   // 限价空在左
    CreateButton("Btn_" + tag + "_LSell", lsellX, contentY, lbtnW, rowH, Lang("限价空", "LIMIT SELL"), sellBg, sellBd, sellTx, 9, true);
    CreateButton("Btn_" + tag + "_LBuy",  lbuyX,  contentY, lbtnW, rowH, Lang("限价多", "LIMIT BUY"),  buyBg,  buyBd,  buyTx,  9, true);
    contentY += Scale(38);   // 与上两排按钮等距
    }
    else contentY += Scale(38); // 缩小模式保留快捷偏移挂单，不显示价格输入行

    // 现价偏移快捷挂单:+2空 +3空 +5空 -2多 -3多 -5多(6 小按钮,整组右对齐卡片右侧)
    int obH   = Scale(22);
    int obGap = Scale(4);
    int obW  = (CardW - LeftPad - RightPad - 5 * obGap) / 6;
    int obGroupW = 6 * obW + 5 * obGap;
    int obX  = cardX + CardW - RightPad - obGroupW;  // 右边界与上方按钮右侧对齐
    // 三个"加价挂空"(现价+N)
    CreateButton("Btn_" + tag + "_S2", obX,                  contentY, obW, obH, "+2" + Lang("空","S"), sellBg, sellBd, sellTx, 9, true);
    CreateButton("Btn_" + tag + "_S3", obX + (obW+obGap),    contentY, obW, obH, "+3" + Lang("空","S"), sellBg, sellBd, sellTx, 9, true);
    CreateButton("Btn_" + tag + "_S5", obX + 2*(obW+obGap),  contentY, obW, obH, "+5" + Lang("空","S"), sellBg, sellBd, sellTx, 9, true);
    // 三个"减价挂多"(现价-N)
    CreateButton("Btn_" + tag + "_B2", obX + 3*(obW+obGap),  contentY, obW, obH, "-2" + Lang("多","L"), buyBg,  buyBd,  buyTx,  9, true);
    CreateButton("Btn_" + tag + "_B3", obX + 4*(obW+obGap),  contentY, obW, obH, "-3" + Lang("多","L"), buyBg,  buyBd,  buyTx,  9, true);
    CreateButton("Btn_" + tag + "_B5", obX + 5*(obW+obGap),  contentY, obW, obH, "-5" + Lang("多","L"), buyBg,  buyBd,  buyTx,  9, true);
}

//+------------------------------------------------------------------+
//| 策略卡片渲染(剥头皮/趋势通用)                                    |
//+------------------------------------------------------------------+
void RenderStrategyCard(string tag, int cardX, int currentY, int cardH, color accent,
                        string title, ENUM_SOP_ORDER kind)
{
    CreateCard("Card_" + tag, cardX, currentY, CardW, cardH, accent);
    int contentY = currentY + Scale(12);

    double lots   = (kind == SOP_SCALP) ? Inp_ScalpLots : Inp_TrendLots;
    int maxPos    = (kind == SOP_SCALP) ? Inp_ScalpMaxPositions : Inp_TrendMaxPositions;
    int posCnt    = (kind == SOP_SCALP) ? g_ScalpRiskSlots : g_TrendRiskSlots;
    double realized = (kind == SOP_SCALP) ? ScalpRealized() : TrendRealized();
    double floatPL  = FloatingPL(kind);
    double netPL    = (kind == SOP_SCALP) ? ScalpNetPL() : TrendNetPL();
    double hiProfit = (kind == SOP_SCALP) ? g_ScalpHighProfit : g_TrendHighProfit;
    double usedLoss = (netPL < 0.0) ? -netPL : 0.0; // 净亏损口径
    double limit    = (kind == SOP_SCALP) ? ScalpDrawdownLimit() : TrendDrawdownLimit();
    bool   allowed  = (kind == SOP_SCALP) ? IsScalpAllowed() : IsTrendAllowed();

    double ll; int winCnt, lossCnt; RealizedPL(kind, ll, winCnt, lossCnt);

    CreateLabel(tag + "_Title", cardX + LeftPad, contentY, title, COLOR_TEXT_HEADER, 9.5, true);
    CreateLabelRightAt(tag + "_Lots", cardX + CardW - RightPad, contentY, Lang("标准手数: ", "LOTS: ") + DoubleToString(lots, 2), COLOR_TEXT_HEADER, 8.5, true);
    contentY += Scale(28);

    // 状态
    string stTxt; color stClr;
    // 熔断原因(优先级:连亏冷却 > 全局 > 本策略)
    string blkReason = "";
    if(kind == SOP_SCALP && HasScalpExitPending()) blkReason = Lang("剥头皮退出处理中", "Scalp exit pending");
    else if(!g_RiskSnapshotValid) blkReason = Lang("风险未知: ", "Risk unknown: ") + g_RiskSnapshotReason;
    else if(g_ProtectionBlocksNewRisk) blkReason = g_ProtectionReason +
        (g_ProtectionIssueCount > 0 ? " (" + (string)g_ProtectionIssueCount + ")" : "");
    else if(InCooldown())       blkReason = Lang("连亏熔断", "Streak breaker");
    else if(g_TotalBlocked) blkReason = g_TotalReason;
    else if(kind == SOP_SCALP && g_ScalpBlocked) blkReason = g_ScalpReason;
    else if(kind == SOP_TREND && g_TrendBlocked) blkReason = g_TrendReason;

    if(!allowed)               { stTxt = (blkReason != "" ? blkReason : Lang("熔断 (禁开)", "BLOCKED")); stClr = COLOR_SIGNAL_LOSS; }
    else if(IsMarketClosed())  { stTxt = Lang("休市 (禁开)", "MARKET CLOSED"); stClr = COLOR_SIGNAL_LOSS; }
    else if(posCnt >= maxPos)  { stTxt = Lang("满仓", "MAX POSITION"); stClr = COLOR_SIGNAL_WARNING; }
    else if(Inp_UseSession && !InSession()) { stTxt = Lang("休息 (非时段)", "OFF-SESSION"); stClr = COLOR_TEXT_MUTED; }
    else                       { stTxt = Lang("就绪 (可开仓)", "READY"); stClr = COLOR_SIGNAL_PROFIT; }
    // 与持仓行共用样式：左侧说明 8.5，右侧状态/数值 9，不额外加粗。
    CreateRowLR(tag + "_Status", cardX, contentY,
                Lang("策略运行状态", "Strategy Status"), stTxt, COLOR_TEXT_MUTED, stClr);
    contentY += Scale(22);

    CreateRowLR(tag + "_Pos", cardX, contentY, Lang("风险占用单元", "Risk Capacity"),
                (string)posCnt + " / " + (string)maxPos + Lang(" 单元", " Slots"),
                COLOR_TEXT_MUTED, COLOR_TEXT_BODY);
    contentY += Scale(22);

    string perf = Lang("盈 ", "W ") + (string)winCnt + Lang(" | 亏 ", " | L ") + (string)lossCnt;
    CreateRowLR(tag + "_Orders", cardX, contentY, Lang("今日胜负平统计 🔍", "Daily Performance 🔍"), perf, COLOR_TEXT_MUTED, COLOR_SIGNAL_PROFIT, true);
    contentY += Scale(22);

    CreateRowLR(tag + "_Profit", cardX, contentY, Lang("今日已实现盈亏", "Realized PNL"), FmtMoney(realized), COLOR_TEXT_MUTED, PLColor(realized), true);
    contentY += Scale(22);

    CreateRowLR(tag + "_Float", cardX, contentY, Lang("策略浮动盈亏", "Unrealized PNL"), FmtMoney(floatPL), COLOR_TEXT_MUTED, PLColor(floatPL), true);
    contentY += Scale(22);

    CreateRowLR(tag + "_Hi", cardX, contentY, Lang("今日最高盈利", "Peak Profit"), FmtMoney(hiProfit), COLOR_TEXT_MUTED, PLColor(hiProfit), true);
    contentY += Scale(22);

    double projectedRisk = (kind == SOP_SCALP) ? g_ScalpProjectedRisk : g_TrendProjectedRisk;
    string riskText = g_RiskSnapshotValid
                    ? FmtMoneyPlain(projectedRisk) + " / " + FmtMoneyPlain(limit)
                    : Lang("未知", "UNKNOWN");
    CreateRowLR(tag + "_Melt", cardX, contentY, Lang("预计止损风险", "Projected Stop Risk"),
                riskText, COLOR_TEXT_MUTED,
                g_RiskSnapshotValid ? GapColor(projectedRisk, limit) : COLOR_SIGNAL_LOSS);
    contentY += Scale(28);
    RenderStrategyCardButtons(tag, cardX, contentY, title, kind, allowed);
}

//+------------------------------------------------------------------+
//| 更新日志舱：首次发布说明与功能卡片                                 |
//+------------------------------------------------------------------+
// 新版本按从新到旧加入此数据表；界面自动限制为最近10条。
struct ReleaseNote
{
    string version;
    string date;
    string title;
    string summary;
    string features[4];
    string details[4];
};
int g_ReleaseSelected = 0;
const int RELEASE_HISTORY_LIMIT = 10;

void LoadReleaseNotes(ReleaseNote &notes[])
{
    ArrayResize(notes, 2);
    notes[0].version = "02";
    notes[0].date = "2026-09-18";
    notes[0].title = Lang("第二版更新说明", "Second release");
    notes[0].summary = Lang("从交易执行，到系统化复盘。", "From execution to structured review.");
    notes[0].features[0] = Lang("复盘系统数据同步", "REVIEW SYSTEM SYNC");
    notes[0].details[0] = Lang("支持将交易数据同步至复盘系统，连接执行与复盘。", "Sync trading data to connect execution and review.");
    notes[0].features[1] = Lang("账户与成交记录", "ACCOUNT & DEAL DATA");
    notes[0].details[1] = Lang("同步成交、账户快照与配置，支持后续统计分析。", "Sync deals, account snapshots and settings for analysis.");
    notes[0].features[2] = Lang("界面布局优化", "REFINED INTERFACE");
    notes[0].details[2] = Lang("调整顶栏对齐与间距，提供紧凑面板和快捷操作。", "Aligned header, compact panel and quick controls.");
    notes[0].features[3] = Lang("同步状态提示", "SYNC STATUS");
    notes[0].details[3] = Lang("请求期间显示红色同步提示，结束后恢复空闲状态。", "Red status during requests; idle status when finished.");

    notes[1].version = "01";
    notes[1].date = "2026-09-01";
    notes[1].title = Lang("第一版上线说明", "Initial release");
    notes[1].summary = Lang("让执行更清晰，让风险有边界。", "Clear execution. Defined risk.");
    notes[1].features[0] = Lang("双策略执行", "DUAL STRATEGIES");
    notes[1].details[0] = Lang("剥头皮与趋势独立管理，支持市价及限价下单。", "Separate scalp and trend strategies; market and limit entries.");
    notes[1].features[1] = Lang("多层风险控制", "RISK CONTROLS");
    notes[1].details[1] = Lang("连续亏损冷却、分策略熔断与利润护城河保护。", "Loss cooldowns, strategy breakers and profit protection.");
    notes[1].features[2] = Lang("持仓精细管理", "POSITION MANAGEMENT");
    notes[1].details[2] = Lang("保本移损、峰值追踪、减仓与分类平仓。", "Break-even, peak trailing, reduction and filtered exits.");
    notes[1].features[3] = Lang("交易统计与复盘", "STATISTICS & REVIEW");
    notes[1].details[3] = Lang("查看账户与策略表现，支持成交明细及报告导出。", "Account metrics, strategy results, deal history and exports.");
}

void RenderChangelogPanel()
{
    ReleaseNote notes[];
    LoadReleaseNotes(notes);
    int count = MathMin(ArraySize(notes), RELEASE_HISTORY_LIMIT);
    if(count == 0) return;
    g_ReleaseSelected = MathMax(0, MathMin(g_ReleaseSelected, count - 1));
    int cx = StartX + PanelWidth + Scale(12), cy = StartY;
    int cw = Scale(640), ch = Scale(510);
    int x = cx + Scale(24);
    CreatePanel("CL_Bg", cx, cy, cw, ch, COLOR_APP_BG, COLOR_CARD_BORDER);
    CreatePanel("CL_Accent", cx, cy, cw, Scale(3), COLOR_GOLD, COLOR_GOLD);
    CreateLabel("CL_Eyebrow", x, cy + Scale(22), "TRADEEZ-SOP  /  RELEASE NOTES", COLOR_GOLD, 8, true);
    CreateButton("Btn_CL_Close", cx + cw - Scale(44), cy + Scale(18), Scale(26), Scale(26),
                 "X", COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BORDER, COLOR_TEXT_MUTED, 9, true);
    CreateLabel("CL_Heading", x, cy + Scale(52), Lang("版本更新", "Release history"), COLOR_TEXT_HEADER, 18, true);
    CreateLabel("CL_Hint", x, cy + Scale(86), Lang("持续打磨交易体验 · 展示最近10个版本", "Refining the trading experience · Latest 10 releases"), COLOR_TEXT_MUTED, 8.5);
    CreatePanel("CL_Divider", x, cy + Scale(114), cw - Scale(48), Scale(1), COLOR_CARD_BORDER, COLOR_CARD_BORDER);

    // 左侧十行固定容量，新增版本不改变面板尺寸。
    for(int i = 0; i < count; i++)
    {
        bool active = (i == g_ReleaseSelected);
        CreateButton("Btn_CL_Select_" + (string)i, x, cy + Scale(134 + i * 30), Scale(134), Scale(26),
                     notes[i].version + "  /  " + notes[i].date,
                     active ? COLOR_BTN_SYS_BG : COLOR_APP_BG,
                     active ? COLOR_GOLD : COLOR_CARD_BORDER,
                     active ? COLOR_GOLD : COLOR_TEXT_MUTED, 8, active);
    }
    int dx = x + Scale(156), dw = cw - Scale(204);
    CreateLabel("CL_Title", dx, cy + Scale(134), notes[g_ReleaseSelected].title, COLOR_TEXT_HEADER, 14, true);
    CreateLabel("CL_Date", dx, cy + Scale(164), notes[g_ReleaseSelected].date, COLOR_GOLD, 8.5);
    CreateLabel("CL_Summary", dx, cy + Scale(189), notes[g_ReleaseSelected].summary, COLOR_TEXT_MUTED, 9);
    for(int j = 0; j < 4; j++)
    {
        string key = "CL_Feature_" + (string)j;
        int y = cy + Scale(222 + j * 56);
        CreatePanel(key, dx, y, dw, Scale(50), COLOR_CARD_BG, COLOR_CARD_BORDER);
        CreateLabel(key + "_Title", dx + Scale(12), y + Scale(7), notes[g_ReleaseSelected].features[j], COLOR_TEXT_HEADER, 9, true);
        CreateLabel(key + "_Detail", dx + Scale(12), y + Scale(28), notes[g_ReleaseSelected].details[j], COLOR_TEXT_MUTED, 8);
    }
    CreatePanel("CL_FooterLine", x, cy + Scale(466), cw - Scale(48), Scale(1), COLOR_CARD_BORDER, COLOR_CARD_BORDER);
    CreateLabel("CL_Footer", x, cy + Scale(482), Lang("TradeEZ 官方网站", "TRADEEZ WEBSITE"), COLOR_TEXT_MUTED, 8);
    CreateButton("CL_Website", cx + cw - Scale(258), cy + Scale(477), Scale(234), Scale(24),
                 "https://www.tradeez.cn", COLOR_APP_BG, COLOR_CARD_BORDER, COLOR_GOLD, 9, true);
    string link = Prefix + "CL_Website";
    ObjectSetString(0, link, OBJPROP_TOOLTIP, Lang("点击使用默认浏览器打开官网", "Open website in your default browser"));
}

//+------------------------------------------------------------------+
//| 主渲染                                                            |
//+------------------------------------------------------------------+
void RenderPerfectUI()
{
    // 编辑期间只保留当前画面,避免每秒重建卡片后把旧输入框压到背景层。
    // 风控、追踪止损和同步计时仍由 OnTick/OnTimer 正常执行。
    if(g_PriceEditActive) return;

    // 重绘前抓取输入内容,再删除并按正确层级完整重建所有对象。
    if(ObjectFind(0, Prefix + "Edt_Sc_Price") >= 0)
        g_ScPriceTxt = ObjectGetString(0, Prefix + "Edt_Sc_Price", OBJPROP_TEXT);
    if(ObjectFind(0, Prefix + "Edt_Tr_Price") >= 0)
        g_TrPriceTxt = ObjectGetString(0, Prefix + "Edt_Tr_Price", OBJPROP_TEXT);
    BeginUIRefresh();

    // 底层背景
    int displayHeight = g_Collapsed ? Scale(404) : PanelHeight;
    int displayWidth = g_Collapsed ? PanelWidth/2 : PanelWidth;
    CreatePanel("AppBg", StartX, StartY, displayWidth, displayHeight, COLOR_APP_BG, COLOR_GOLD);
    DrawGoldBorder(StartX, StartY, displayWidth, displayHeight, 3);

    int currentY = StartY + Scale(16);

    // LOGO + 版本号 + 北京时间 + 收线倒计时 + 语言切换
    int logoX     = StartX + Scale(12);
    int logoSize  = Scale(32); // 原图留白内的标志约19px，与标题可见字高接近。
    int titleX    = logoX + logoSize + Scale(4);
    int titleW    = Scale(118);
    int versionX  = titleX + titleW + Scale(2);
    int versionW  = Scale(42);
    int headerMidY = currentY + Scale(10);
    int titleBottomY = headerMidY + Scale(9);
    RenderBrandLogo(logoX, headerMidY - logoSize/2, logoSize);
    // 大字号字体框底部留白更多，下移补偿以对齐可见字形底部。
    CreateLabelAnchor("Title", titleX, titleBottomY + Scale(2), "TradeEZ-SOP", COLOR_TEXT_HEADER, 13, true, ANCHOR_LEFT_LOWER);
    CreateLabelAnchor("Version", versionX, titleBottomY, "v1.03", COLOR_SIGNAL_PROFIT, 9, true, ANCHOR_LEFT_LOWER);
    if(!g_InstanceOwnsState)
        CreateLabelAnchor("ReadOnlyWarning", versionX + versionW + Scale(8), titleBottomY,
                          Lang("实例冲突 · 只读", "INSTANCE CONFLICT · READ ONLY"),
                          COLOR_SIGNAL_LOSS, 8, true, ANCHOR_LEFT_LOWER);
    else if(g_RecoveryStatus == RECOVERY_CONSERVATIVE && !g_RecoveryAcknowledged)
    {
        CreateButton("Btn_Recovery_Ack", versionX + versionW + Scale(8), currentY - Scale(1),
                     Scale(92), Scale(22), Lang("确认恢复", "REVIEW"),
                     COLOR_BTN_SYS_BG, COLOR_SIGNAL_WARNING, COLOR_SIGNAL_WARNING, 8, true);
        ObjectSetString(0, Prefix + "Btn_Recovery_Ack", OBJPROP_TOOLTIP, g_RecoveryReason);
    }
    else if(g_RecoveryStatus == RECOVERY_FAILED || g_RecoveryStatus == RECOVERY_CHECKING)
        CreateLabelAnchor("RecoveryWarning", versionX + versionW + Scale(8), titleBottomY,
                          g_RecoveryStatus == RECOVERY_FAILED ? Lang("恢复失败 · 只平不开", "RECOVERY FAILED · EXIT ONLY")
                                                              : Lang("状态恢复中", "RECOVERING"),
                          COLOR_SIGNAL_LOSS, 8, true, ANCHOR_LEFT_LOWER);
    else if(g_RecoveryStatus == RECOVERY_CONSERVATIVE)
        CreateLabelAnchor("RecoveryWarning", versionX + versionW + Scale(8), titleBottomY,
                          Lang("保守恢复", "CONSERVATIVE"), COLOR_SIGNAL_WARNING, 8, true, ANCHOR_LEFT_LOWER);

    int foldSize = Scale(44);
    int foldX    = StartX + displayWidth - Scale(14) - foldSize;
    int langW    = Scale(92);
    int langGap  = Scale(6);
    int langX    = foldX - langGap - langW;
    CreateButton("Btn_Fold", foldX, currentY - Scale(2), foldSize, Scale(24), g_Collapsed ? ">" : "<", COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BORDER, COLOR_TEXT_HEADER, 10, true);
    if(!g_Collapsed)
    {
    CreateButton("Btn_Lang_Toggle", langX, currentY - Scale(2), langW, Scale(24), g_Language_ZH ? "LANG: 中文" : "LANG: EN", COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BORDER, COLOR_TEXT_HEADER, 8, true);

    int cdRight      = langX - Scale(12);
    int cdTimeW      = Scale(64);
    int cdGap        = Scale(2);
    int cdLabelRight = cdRight - cdTimeW - cdGap;
    // 时钟锚定面板几何中心，不随两侧可选控件变化。
    int clockCx = StartX + PanelWidth / 2;
    CreateLabelAnchor("Clock", clockCx, currentY + Scale(10), TimeToString(BeijingNow(), TIME_MINUTES | TIME_SECONDS), COLOR_TEXT_HEADER, 16, true, ANCHOR_CENTER);
    if(IsMarketClosed())
        CreateLabelAnchor("ClockClosed", clockCx + Scale(52), headerMidY, Lang("休市", "CLOSED"), COLOR_SIGNAL_LOSS, 9, true, ANCHOR_LEFT);
    else
        ObjectDelete(0, Prefix + "ClockClosed");

    int cdBottomY = headerMidY + Scale(12);
    CreateLabelAnchor("BarCD", cdRight, cdBottomY + Scale(3), BarCountdown(), COLOR_SIGNAL_WARNING, 16, true, ANCHOR_RIGHT_LOWER);
    CreateLabelAnchor("BarCD_Lbl", cdLabelRight, cdBottomY, Lang("收线", "BAR"), COLOR_TEXT_MUTED, 9, true, ANCHOR_RIGHT_LOWER);
    }
    currentY += Scale(36);

    // 紧凑状态保留顶栏、实时报价、策略标题/手数及市价操作。
    if(g_Collapsed)
    {
        ObjectDelete(0, Prefix + "Edt_Sc_Price");
        ObjectDelete(0, Prefix + "Edt_Tr_Price");
        RenderQuoteBar(SymbolInfoDouble(_Symbol, SYMBOL_BID), SymbolInfoDouble(_Symbol, SYMBOL_ASK));
        int compactY = currentY + Scale(44) + Scale(14);
        for(int side = 0; side < 2; side++)
        {
            bool scalp = (side == 0);
            string tag = scalp ? "Sc" : "Tr";
            int x = Col1X;
            int strategyY = compactY + side * Scale(120);
            ENUM_SOP_ORDER kind = scalp ? SOP_SCALP : SOP_TREND;
            string title = scalp ? Lang("极速剥头皮策略", "SCALPING STRATEGY") : Lang("波段趋势策略", "TREND STRATEGY");
            double lots = scalp ? Inp_ScalpLots : Inp_TrendLots;
            CreateCard("Card_" + tag, x, strategyY, CardW, Scale(110), scalp ? COLOR_SIGNAL_PROFIT : COLOR_SIGNAL_LOSS);
            CreateLabelAnchor(tag + "_Title", x + LeftPad, strategyY + Scale(20), title, COLOR_TEXT_HEADER, 9.5, true, ANCHOR_LEFT);
            CreateLabelAnchor(tag + "_Lots", x + CardW - RightPad, strategyY + Scale(20), Lang("标准手数: ", "LOTS: ") + DoubleToString(lots, 2), COLOR_TEXT_HEADER, 8.5, true, ANCHOR_RIGHT);
            RenderStrategyCardButtons(tag, x, strategyY + Scale(40), title, kind, scalp ? IsScalpAllowed() : IsTrendAllowed());
        }
        // 独立底栏：全局平仓操作不归属于某个策略。
        CreatePanel("Compact_ActionDivider", Col1X, compactY + Scale(236),
                    CardW, Scale(1), C'190,196,204', C'190,196,204');
        // RECTANGLE_LABEL 的平面边框使用 COLOR；1px 高时边框覆盖整个填充。
        ObjectSetInteger(0, Prefix + "Compact_ActionDivider", OBJPROP_COLOR, C'190,196,204');
        ObjectSetInteger(0, Prefix + "Compact_ActionDivider", OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, Prefix + "Compact_ActionDivider", OBJPROP_WIDTH, 1);
        int actionY = compactY + Scale(248);
        int actionW = Scale(100);
        int actionGap = Scale(12);
        int actionX = StartX + (displayWidth - actionW*2 - actionGap)/2;
        CreateButton("Btn_Close_All", actionX, actionY, actionW, Scale(24),
                     Lang("一键全平", "CLOSE ALL"), COLOR_BTN_SELL_BG, COLOR_BTN_SELL_BORDER, COLOR_SIGNAL_LOSS, 8, true);
        CreateButton("Btn_Close_Profit", actionX + actionW + actionGap, actionY, actionW, Scale(24),
                     Lang("平盈利单", "CLOSE PROFIT"), COLOR_BTN_BUY_BG, COLOR_BTN_BUY_BORDER, COLOR_SIGNAL_PROFIT, 8, true);
        if(g_ShowChangelog) RenderChangelogPanel();
        EndUIRefresh();
        ChartRedraw();
        return;
    }

    // ===== 买卖价格条(卖左/买右/点差居中,底部对齐) =====
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    int priceH = Scale(44);
    RenderQuoteBar(bid, ask);
    currentY += priceH + Scale(14);

    // ===== 行1:账户核心(左) + 全局风控(右) =====
    int rowA_Y = currentY;
    int rowA_H = Scale(236);

    // --- 账户核心数据(7项)---
    CreateCard("Card1", Col1X, rowA_Y, CardW, rowA_H, clrWhite);
    int cY = rowA_Y + Scale(12);
    CreateLabel("C1_Title", Col1X + LeftPad, cY, Lang("账户与品种数据", "ACCOUNT & SYMBOL"), COLOR_TEXT_HEADER, 9.5, true);
    cY += Scale(28);
    double bal = AccountInfoDouble(ACCOUNT_BALANCE);
    double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
    double floatTotal = AllFloatingPL();
    double realTotal  = AllRealizedPL();
    // 1 今日初始金额
    CreateRowLR("C1_Init", Col1X, cY, Lang("今日初始金额", "Day Start Balance"), "$ " + DoubleToString(g_InitBalance, 2), COLOR_TEXT_MUTED, COLOR_TEXT_BODY);
    cY += Scale(26);
    // 2 当前账户余额
    CreateRowLR("C1_Bal", Col1X, cY, Lang("当前账户余额", "Account Balance"), "$ " + DoubleToString(bal, 2), COLOR_TEXT_MUTED, COLOR_TEXT_BODY);
    cY += Scale(26);
    // 3 今日实现盈亏(可点击,展开今日全部平仓明细)
    CreateRowLR("C1_Real", Col1X, cY, Lang("本品种今日实现 🔍", "Symbol Realized 🔍"), FmtMoney(realTotal), COLOR_TEXT_MUTED, PLColor(realTotal), true);
    cY += Scale(26);
    // 4 实时账户净值
    CreateRowLR("C1_Eq", Col1X, cY, Lang("实时账户净值", "Real-time Equity"), "$ " + DoubleToString(eq, 2), COLOR_TEXT_MUTED, (eq >= bal ? COLOR_SIGNAL_PROFIT : COLOR_SIGNAL_LOSS), true);
    cY += Scale(26);
    // 5 账户浮动盈亏
    CreateRowLR("C1_Float", Col1X, cY, Lang("本品种浮动盈亏", "Symbol Floating"), FmtMoney(floatTotal), COLOR_TEXT_MUTED, PLColor(floatTotal), true);
    cY += Scale(26);
    // 6 系统激活时段
    string sess = StringFormat("%02d:00 ~ %02d:00 ", Inp_SessionStartHour, Inp_SessionEndHour)
                + (InSession() ? Lang("(已激活)", "(ACTIVE)") : Lang("(休息)", "(OFF)"));
    CreateRowLR("C1_Time", Col1X, cY, Lang("系统激活时段", "Active Session"), sess, COLOR_TEXT_MUTED, (InSession() ? COLOR_SIGNAL_PROFIT : COLOR_TEXT_MUTED));
    cY += Scale(26);
    // 7 重置倒计时
    int remain = SecondsUntilNextResetBeijing();
    string cd = (string)(remain / 3600) + Lang(" 小时 ", " Hrs ") + (string)((remain % 3600) / 60) + Lang(" 分钟", " Mins");
    CreateRowLR("C1_Reset", Col1X, cY, Lang("重置倒计时", "Reset Countdown"), cd, COLOR_TEXT_MUTED, COLOR_SIGNAL_WARNING, true);
    if(Inp_ShowResetBtn)
    {
        // 固定倒计时文本区，避免位数变化导致按钮跳动。
        int resetW = Scale(44);
        int countdownW = Scale(g_Language_ZH ? 100 : 122);
        int resetX = Col1X + CardW - RightPad - countdownW - Scale(6) - resetW;
        CreateButton("Btn_Reset_All", resetX, cY - Scale(2), resetW, Scale(19),
                     Lang("重置", "RESET"), COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BORDER, COLOR_SIGNAL_WARNING, 8.5);
    }

    // --- 全局风控数据(6项 + 4平仓按钮)---
    CreateCard("Card4", Col2X, rowA_Y, CardW, rowA_H, COLOR_SIGNAL_WARNING);
    cY = rowA_Y + Scale(12);
    CreateLabel("C4_Title", Col2X + LeftPad, cY, Lang("风控核心数据", "RISK METRICS"), COLOR_TEXT_HEADER, 9.5, true);
    // 日统计入口按钮(标题右侧)
    CreateButton("Btn_Stat_Open", Col2X + CardW - RightPad - 70, cY - 3, 70, 20, Lang("日统计 »", "STATS »"), COLOR_BTN_SYS_BG, COLOR_SIGNAL_PROFIT, COLOR_SIGNAL_PROFIT, 8, true);
    cY += Scale(28);

    // 1 今日最高盈利(已平仓口径,可为负)
    double peakProfit = g_GlobalRealHigh;
    CreateRowLR("C4_Hi", Col2X, cY, Lang("今日最高盈利", "Peak Profit"), FmtMoney(peakProfit), COLOR_TEXT_MUTED, PLColor(peakProfit), true);
    cY += Scale(24);
    // 2 当前品种实际盈亏的生效底线，与真实熔断/护城河判定保持同一口径。
    double activeFloor = ActiveProjectedFloor();
    CreateRowLR("C4_Base", Col2X, cY, Lang("本品种生效底线", "Symbol Active Floor"), FmtMoney(activeFloor), COLOR_TEXT_MUTED, COLOR_TEXT_BODY, true);
    cY += Scale(24);
    // 3 当前品种实际净盈亏距离生效底线的剩余金额。
    double ddRemain = GlobalNetPL() - activeFloor;
    // 口径与真实触发一致:阈值 > 0 = 尚有缓冲(蓝);≤ 0 = 已触及/跌破基准(红)
    color  thClr = (ddRemain > 0.0) ? COLOR_SIGNAL_PROFIT : COLOR_SIGNAL_LOSS;
    CreateRowLR("C4_Thr", Col2X, cY, Lang("本品种回撤余量", "Symbol Drawdown Room"), FmtMoney(ddRemain), COLOR_TEXT_MUTED, thClr, true);
    cY += Scale(24);
    // 4 周目标进度
    double weeklyPL = WeekRealized();
    CreateRowLR("C4_WeekP", Col2X, cY, Lang("周计划", "Weekly Plan"), WeeklySummary(), COLOR_TEXT_MUTED, PLColor(weeklyPL), true);
    cY += Scale(24);
    // 5 当前品种预计止损风险(含持仓、挂单、未落地开仓请求)
    string symbolRisk = g_RiskSnapshotValid
                      ? FmtMoneyPlain(g_SymbolProjectedRisk) + " / " + FmtMoneyPlain(TotalDrawdownLimit())
                      : Lang("未知", "UNKNOWN");
    CreateRowLR("C4_Week", Col2X, cY, Lang("当前品种预计风险", "Symbol Projected Risk"), symbolRisk,
                COLOR_TEXT_MUTED, g_RiskSnapshotValid ? GapColor(g_SymbolProjectedRisk, TotalDrawdownLimit()) : COLOR_SIGNAL_LOSS, true);
    cY += Scale(24);
    // 6 系统安全状态(显示熔断原因)
    string secTxt; color secClr;
    string tradeStatus = TradeOperationStatusText(secClr);
    if(!g_RiskSnapshotValid) { secTxt = Lang("风险未知: ", "Risk unknown: ") + g_RiskSnapshotReason; secClr = COLOR_SIGNAL_LOSS; }
    else if(tradeStatus != "")  { secTxt = tradeStatus; }
    else if(InCooldown())   { secTxt = Lang("连亏熔断-冷却中", "STREAK BREAKER"); secClr = COLOR_SIGNAL_LOSS; }
    else if(g_TotalBlocked) { secTxt = g_TotalReason;  secClr = COLOR_SIGNAL_LOSS; }
    else if(g_ScalpBlocked && g_TrendBlocked) { secTxt = Lang("双策略熔断", "Both blocked"); secClr = COLOR_SIGNAL_LOSS; }
    else if(g_ScalpBlocked) { secTxt = g_ScalpReason;  secClr = COLOR_SIGNAL_WARNING; }
    else if(g_TrendBlocked) { secTxt = g_TrendReason;  secClr = COLOR_SIGNAL_WARNING; }
    else                    { secTxt = Lang("运行正常 (STABLE)", "SECURED (STABLE)"); secClr = COLOR_SIGNAL_PROFIT; }
    CreateRowLR("C4_Status", Col2X, cY, Lang("当前品种风险状态", "Symbol Risk Status"), secTxt, COLOR_TEXT_MUTED, secClr, true);
    cY += Scale(28);
    // 4 平仓按钮:一键全平 / 平剥头皮 / 平趋势 / 平盈利
    int cbW = (CardW - LeftPad - RightPad - 3 * 6) / 4;
    int cbX0 = Col2X + LeftPad;
    CreateButton("Btn_Close_All",    cbX0,                 cY, cbW, 24, Lang("一键全平", "ALL"),    COLOR_BTN_SELL_BG, COLOR_BTN_SELL_BORDER, COLOR_SIGNAL_LOSS,   8, true);
    CreateButton("Btn_Close_Scalp",  cbX0 + (cbW+6),       cY, cbW, 24, Lang("平剥头皮", "SCALP"),  COLOR_BTN_SYS_BG,  COLOR_BTN_SYS_BORDER,  COLOR_TEXT_HEADER,   8, true);
    CreateButton("Btn_Close_Trend",  cbX0 + 2*(cbW+6),     cY, cbW, 24, Lang("平趋势单", "TREND"),  COLOR_BTN_SYS_BG,  COLOR_BTN_SYS_BORDER,  COLOR_TEXT_HEADER,   8, true);
    CreateButton("Btn_Close_Profit", cbX0 + 3*(cbW+6),     cY, cbW, 24, Lang("平盈利单", "PROFIT"), COLOR_BTN_BUY_BG,  COLOR_BTN_BUY_BORDER,  COLOR_SIGNAL_PROFIT, 8, true);

    currentY += rowA_H + Scale(14);

    // ===== 行2:剥头皮(左) + 趋势(右) =====
    int rowB_H = Scale(310);
    RenderStrategyCard("Sc", Col1X, currentY, rowB_H, COLOR_SIGNAL_PROFIT, Lang("极速剥头皮策略", "SCALPING STRATEGY"), SOP_SCALP);
    RenderStrategyCard("Tr", Col2X, currentY, rowB_H, COLOR_SIGNAL_LOSS,   Lang("波段趋势策略", "TREND STRATEGY"), SOP_TREND);
    currentY += rowB_H + Scale(12);

    // ===== 底部:策略参数专业说明 =====
    RenderParamFooter(currentY);

    // 明细舱
    if(g_ShowDetails) RenderHistoryCabin();

    // 日统计舱
    if(g_ShowStats) RenderStatsPanel();

    // 更新日志舱
    if(g_ShowChangelog) RenderChangelogPanel();

    // 连亏熔断遮罩(覆盖面板中间,显示恢复倒计时)
    if(InCooldown()) RenderCooldownMask();

    // 剥头皮持仓超时平仓倒计时遮罩(主面板正下方)
    if(Inp_ScalpTimeLimitOn) RenderScalpCountdown();

    EndUIRefresh();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| 日统计舱                                                          |
//+------------------------------------------------------------------+
void StatRow(string name, int x, int w, int y, string lbl, string val, color valClr)
{
    CreateLabel("St_" + name + "_L", x + 18, y, lbl, COLOR_TEXT_MUTED, 8.5);
    CreateLabelRightAt("St_" + name + "_R", x + w - 18, y, val, valClr, 9, true);
}
void StatSection(string name, int x, int w, int y, string title)
{
    CreateLabel("StSec_" + name, x + 18, y, title, COLOR_GOLD, 8.5, true);
    ColorBar("StSecL_" + name, x + 18, y + 15, w - 36, 1, COLOR_CARD_BORDER, 96);
}

void RenderStatsQuality(int sx, int sw, int y, DailyStats &all, DailyStats &sc, DailyStats &tr)
{
    StatSection("ql", sx, sw, y, Lang("交易质量", "QUALITY")); y += 24;
    double wr = StatWinRate(all);
    StatRow("wr",  sx, sw, y, Lang("胜率 (盈/亏笔)", "Win Rate"),
            DoubleToString(wr,1) + "%  (" + (string)all.wins + "/" + (string)all.losses + ")",
            (wr>=50?COLOR_SIGNAL_PROFIT:COLOR_SIGNAL_WARNING)); y += 22;
    double pf = StatProfitFactor(all);
    StatRow("pf",  sx, sw, y, Lang("盈亏比 / 盈利因子", "Payoff / PF"),
            DoubleToString(StatPayoff(all),2) + " / " + DoubleToString(pf,2),
            (pf>=1.5?COLOR_SIGNAL_PROFIT:(pf>=1.0?COLOR_SIGNAL_WARNING:COLOR_SIGNAL_LOSS))); y += 22;
    double exx = StatExpectancy(all);
    StatRow("exp", sx, sw, y, Lang("单笔期望值", "Expectancy"), FmtMoney(exx) + Lang("/单","/t"), PLColor(exx)); y += 22;
    StatRow("avg", sx, sw, y, Lang("均盈 / 均亏", "Avg W / L"),
            "+$" + DoubleToString(StatAvgWin(all),1) + " / -$" + DoubleToString(StatAvgLoss(all),1), COLOR_TEXT_BODY); y += 22;
    StatRow("ext", sx, sw, y, Lang("最大盈 / 最大亏", "Max W / L"),
            "+$" + DoubleToString(all.maxWin,1) + " / -$" + DoubleToString(-all.maxLoss,1), COLOR_TEXT_BODY); y += 28;

    StatSection("st", sx, sw, y, Lang("分策略拆解", "BY STRATEGY")); y += 24;
    StatRow("sc",  sx, sw, y, Lang("剥头皮 净/胜率/均时", "Scalp N/WR/Hold"),
            FmtMoney(sc.net) + "  " + DoubleToString(StatWinRate(sc),0) + "%  " + FmtHold(sc.avgHoldSec), PLColor(sc.net)); y += 22;
    StatRow("tr",  sx, sw, y, Lang("趋势 净/胜率/均时", "Trend N/WR/Hold"),
            FmtMoney(tr.net) + "  " + DoubleToString(StatWinRate(tr),0) + "%  " + FmtHold(tr.avgHoldSec), PLColor(tr.net)); y += 22;
    double manNet = all.net - sc.net - tr.net;
    int    manCnt = all.trades - sc.trades - tr.trades;
    StatRow("man", sx, sw, y, Lang("规则外(手动)净/笔", "Off-rule Net/N"),
            FmtMoney(manNet) + "  (" + (string)manCnt + ")", (manCnt>0?COLOR_SIGNAL_WARNING:COLOR_TEXT_MUTED)); y += 28;

    StatSection("di", sx, sw, y, Lang("纪律执行", "DISCIPLINE")); y += 24;
    StatRow("cl",  sx, sw, y, Lang("当前连亏 / 阈值", "Consec Loss"),
            (string)g_ConsecLoss + " / " + (string)Inp_ConsecLossLimit,
            (g_ConsecLoss>=Inp_ConsecLossLimit?COLOR_SIGNAL_LOSS:COLOR_TEXT_BODY)); y += 22;
    string cdTxt = InCooldown() ? StringFormat("%02d:%02d", (int)(g_CooldownUntil-TimeCurrent())/60, (int)(g_CooldownUntil-TimeCurrent())%60) : Lang("未触发","None");
    StatRow("cd",  sx, sw, y, Lang("连亏熔断冷却", "Cooldown"), cdTxt, (InCooldown()?COLOR_SIGNAL_LOSS:COLOR_SIGNAL_PROFIT)); y += 22;
    string secTxt = g_TotalBlocked ? Lang("已熔断","BLOCKED") : (g_ScalpBlocked||g_TrendBlocked ? Lang("部分熔断","PARTIAL") : Lang("正常","OK"));
    StatRow("sec", sx, sw, y, Lang("当前风控状态", "Risk State"), secTxt, (g_TotalBlocked?COLOR_SIGNAL_LOSS:(g_ScalpBlocked||g_TrendBlocked?COLOR_SIGNAL_WARNING:COLOR_SIGNAL_PROFIT)));
}

void RenderStatsPanel()
{
    int sw = 320;
    int sx = StartX + PanelWidth + 12;
    int sy = StartY;
    if(g_ShowDetails) sy = StartY + 300;
    int sh = 512;

    CreatePanel("Stat_Bg", sx, sy, sw, sh, COLOR_CARD_BG, COLOR_CARD_BORDER);
    DrawGoldBorderNamed("Stat", sx, sy, sw, sh, 2, COLOR_GOLD);

    CreateLabel("Stat_Title", sx + 18, sy + 12, Lang("日内交易统计", "INTRADAY STATISTICS"), COLOR_TEXT_HEADER, 10.5, true);
    CreateLabel("Stat_Date",  sx + 18, sy + 30, TimeToString(BeijingNow(), TIME_DATE) + Lang("  (北京)", "  (BJ)"), COLOR_TEXT_MUTED, 8);
    CreateButton("Btn_Stat_Close", sx + sw - 34, sy + 10, 24, 20, "X", COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BORDER, COLOR_SIGNAL_LOSS, 8.5, true);

    DailyStats all, sc, tr;
    ComputeDailyStats(SOP_IGNORE, all);
    ComputeDailyStats(SOP_SCALP,  sc);
    ComputeDailyStats(SOP_TREND,  tr);
    double floatAll = AllFloatingPL();

    int y = sy + 52;
    StatSection("ov", sx, sw, y, Lang("盈亏概览", "OVERVIEW")); y += 24;
    StatRow("net",  sx, sw, y, Lang("已实现净盈亏", "Realized Net"), FmtMoney(all.net), PLColor(all.net)); y += 22;
    StatRow("gp",   sx, sw, y, Lang("毛盈利 / 毛亏损", "Gross W / L"), "+$" + DoubleToString(all.grossProfit,2) + " / -$" + DoubleToString(all.grossLoss,2), COLOR_TEXT_BODY); y += 22;
    StatRow("flt",  sx, sw, y, Lang("当前浮动盈亏", "Floating"), FmtMoney(floatAll), PLColor(floatAll)); y += 22;
    double tgtPct = (Inp_DailyProfitTarget > 0) ? 100.0 * all.net / Inp_DailyProfitTarget : 0.0;
    StatRow("tgt",  sx, sw, y, Lang("日目标完成度", "Target Done"), DoubleToString(tgtPct,1) + "%  / $" + DoubleToString(Inp_DailyProfitTarget,0), (tgtPct>=100?COLOR_SIGNAL_PROFIT:COLOR_SIGNAL_WARNING)); y += 28;

    RenderStatsQuality(sx, sw, y, all, sc, tr);
}

//+------------------------------------------------------------------+
//| 剥头皮超时平仓倒计时遮罩(主面板正下方,支持多单,倒计时醒目)     |
//+------------------------------------------------------------------+
// 遮罩仅在剩余 ≤ 此秒数时弹出:刚下单不打扰,进入最后冲刺才醒目提示
#define SCALP_CD_POPUP_SECS 30

void RenderScalpCountdown()
{
    // 收集"即将超时"的剥头皮持仓:仅纳入 未取消倒计时 且 剩余 ≤ SCALP_CD_POPUP_SECS 的单
    int popup = (Inp_ScalpMaxHoldSecs < SCALP_CD_POPUP_SECS) ? Inp_ScalpMaxHoldSecs : SCALP_CD_POPUP_SECS;
    ulong  tks[]; ArrayResize(tks, 0);
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PosType() != SOP_SCALP) continue;
        if(IsTimeoutCancelled(tk)) continue;                       // 用户已取消该单倒计时 → 不弹
        datetime openT = (datetime)PositionGetInteger(POSITION_TIME);
        int remain = Inp_ScalpMaxHoldSecs - (int)(TimeCurrent() - openT);
        if(remain > popup) continue;                               // 还没进入最后冲刺 → 不弹
        int n = ArraySize(tks); ArrayResize(tks, n+1); tks[n] = tk;
    }
    int cnt = ArraySize(tks);
    if(cnt == 0) return;   // 无"即将超时"的剥头皮持仓则不显示遮罩

    int rowH = 40;
    int pad  = 8;
    int cw   = 300;
    int cx   = StartX + PanelWidth + 12;           // 主面板右侧,避免超出屏幕底部
    int cy   = StartY + 170;                        // 让开右上角的明细/统计/冷却区
    int ch   = 30 + cnt * (rowH + pad) + 8;

    CreatePanel("SCD_Bg", cx, cy, cw, ch, C'26,18,10', COLOR_SIGNAL_WARNING);
    DrawGoldBorderNamed("SCD", cx, cy, cw, ch, 2, COLOR_SIGNAL_WARNING);
    CreateLabel("SCD_Title", cx + 14, cy + 8, Lang("⏱ 剥头皮超时平仓", "⏱ SCALP TIME-STOP"), COLOR_SIGNAL_WARNING, 10, true);

    int y = cy + 30;
    for(int i = 0; i < cnt; i++)
    {
        ulong tk = tks[i];
        if(!PositionSelectByTicket(tk)) continue;
        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
        int elapsed = (int)(TimeCurrent() - openTime);
        int remain  = Inp_ScalpMaxHoldSecs - elapsed;
        bool cancelled = IsTimeoutCancelled(tk);

        string sfx = (string)tk;
        // 行背景
        CreatePanel("SCD_Row_" + sfx, cx + 8, y, cw - 16, rowH, COLOR_CARD_BG, COLOR_CARD_BORDER);

        long type = PositionGetInteger(POSITION_TYPE);
        string dir = (type == POSITION_TYPE_BUY) ? Lang("多", "BUY") : Lang("空", "SELL");
        double vol = PositionGetDouble(POSITION_VOLUME);
        CreateLabel("SCD_Info_" + sfx, cx + 16, y + 5, dir + " " + DoubleToString(vol,2) + Lang("手", "lot"), COLOR_TEXT_BODY, 8, true);

        if(cancelled)
        {
            CreateLabel("SCD_CD_" + sfx, cx + 16, y + 21, Lang("倒计时已取消", "CANCELLED"), COLOR_TEXT_MUTED, 9, true);
        }
        else
        {
            if(remain < 0) remain = 0;
            color cc = (remain <= 10) ? COLOR_SIGNAL_LOSS : (remain <= 30 ? COLOR_SIGNAL_WARNING : COLOR_SIGNAL_PROFIT);
            CreateLabel("SCD_CD_" + sfx, cx + 16, y + 20, StringFormat("%02d:%02d", remain/60, remain%60), cc, 16, true);
            CreateButton("Btn_SCDCancel_" + sfx, cx + cw - 96, y + 9, 84, rowH - 18, Lang("取消平仓", "CANCEL"), COLOR_BTN_SYS_BG, COLOR_SIGNAL_WARNING, COLOR_SIGNAL_WARNING, 8, true);
        }
        y += rowH + pad;
    }
}

//+------------------------------------------------------------------+
//| 连亏熔断遮罩面板:居中覆盖,显示恢复倒计时                          |
//+------------------------------------------------------------------+
void RenderCooldownMask()
{
    int mw = 300, mh = 150;
    int mx = StartX + PanelWidth + 12;              // 主面板右侧,不遮挡
    int my = StartY + (g_ShowDetails ? 300 : 0);     // 若明细舱已开则下移避让

    // 深色底 + 红框(独立面板,置于主面板右侧)
    CreatePanel("Mask_Bg", mx, my, mw, mh, C'18,10,12', COLOR_SIGNAL_LOSS);
    ObjectSetInteger(0, Prefix + "Mask_Bg", OBJPROP_ZORDER, 200);
    DrawGoldBorderNamed("Mask", mx, my, mw, mh, 2, COLOR_SIGNAL_LOSS);

    CreateLabelAnchor("Mask_T1", mx + mw/2, my + 30, Lang("⚠ 连续亏损熔断", "⚠ CONSECUTIVE-LOSS BREAKER"), COLOR_SIGNAL_LOSS, 13, true, ANCHOR_CENTER);
    CreateLabelAnchor("Mask_T2", mx + mw/2, my + 58, Lang("已暂停所有开仓,请冷却休息", "All trading paused — cool down"), COLOR_TEXT_BODY, 9, false, ANCHOR_CENTER);

    int remain = (int)(g_CooldownUntil - TimeCurrent());
    if(remain < 0) remain = 0;
    string cdStr = StringFormat("%02d:%02d", remain / 60, remain % 60);
    CreateLabelAnchor("Mask_Lbl", mx + mw/2, my + 88, Lang("恢复倒计时", "RESUME IN"), COLOR_TEXT_MUTED, 8, true, ANCHOR_CENTER);
    CreateLabelAnchor("Mask_CD",  mx + mw/2, my + 118, cdStr, COLOR_SIGNAL_WARNING, 22, true, ANCHOR_CENTER);
}

//+------------------------------------------------------------------+
//| 底部参数说明(止盈止损 / 移动止损 专业术语描述)                    |
//+------------------------------------------------------------------+
void RenderParamFooter(int y)
{
    int fx = Col1X;
    int fw = Col2X + CardW - Col1X;
    CreatePanel("Foot_Sep", fx, y, fw, Scale(1), COLOR_GOLD, COLOR_GOLD);
    CreateLabel("Foot_Title", fx, y + Scale(10),
                Lang("策略执行参数", "STRATEGY EXECUTION"), COLOR_GOLD, 8, true);
    CreateLabel("Foot_Units", Col2X, y + Scale(10),
                Lang("单位：标准点（1 点 = 0.01 价格单位）", "Unit: standard point = 0.01 price"),
                COLOR_TEXT_MUTED, 8);

    // 与上方策略卡片保持同列；每行只说明一个执行阶段。
    int top = y + Scale(34);
    int row = Scale(20);
    CreateLabel("Foot_ScTitle", fx, top, Lang("剥头皮策略", "SCALPING"), COLOR_TEXT_BODY, 9, true);
    CreateLabel("Foot_TrTitle", Col2X, top, Lang("趋势策略", "TREND"), COLOR_TEXT_BODY, 9, true);
    string scSL = Inp_ScalpSL_Points > 0 ? (string)Inp_ScalpSL_Points : Lang("未设置", "Off");
    string scTP = Inp_ScalpTP_Points > 0 ? (string)Inp_ScalpTP_Points : Lang("未设置", "Off");
    string trSL = Inp_TrendSL_Points > 0 ? (string)Inp_TrendSL_Points : Lang("未设置", "Off");

    CreateLabel("Foot_ScInitial", fx, top + row,
                Lang("初始保护  ·  止损 ", "Initial  ·  SL ") + scSL
                + Lang("  /  止盈 ", "  /  TP ") + scTP, COLOR_TEXT_BODY, 8);
    CreateLabel("Foot_ScActivate", fx, top + row*2,
                Lang("追踪启动  ·  浮盈达到 +", "Activate  ·  Profit +") + (string)Inp_ScalpBETrigger,
                COLOR_TEXT_BODY, 8);
    CreateLabel("Foot_ScExit", fx, top + row*3,
                Lang("回撤退出  ·  距浮盈峰值回撤 ", "Exit  ·  Peak pullback ") + (string)Inp_ScalpTrailStep,
                COLOR_TEXT_BODY, 8);
    CreateLabel("Foot_ScTime", fx, top + row*4,
                Lang("持仓时限  ·  ", "Time stop  ·  ")
                + (Inp_ScalpTimeLimitOn
                   ? (string)Inp_ScalpMaxHoldSecs + Lang(" 秒后强制平仓", " seconds")
                   : Lang("未启用超时平仓", "Disabled")),
                COLOR_TEXT_MUTED, 8);

    CreateLabel("Foot_TrInitial", Col2X, top + row,
                Lang("初始保护  ·  止损 ", "Initial  ·  SL ") + trSL
                + Lang("  /  分级锁盈", "  /  Stepped protection"), COLOR_TEXT_BODY, 8);
    CreateLabel("Foot_TrLocks", Col2X, top + row*2,
                Lang("锁盈阶梯  ·  +", "SL steps  ·  +") + (string)Inp_TrendBE1_Trigger
                + Lang("→保本", "→BE") + "  /  +" + (string)Inp_TrendBE2_Trigger
                + "→+" + (string)Inp_TrendBE2_Lock + "  /  +" + (string)Inp_TrendBE3_Trigger
                + "→+" + (string)Inp_TrendBE3_Lock, COLOR_TEXT_BODY, 8);
    CreateLabel("Foot_TrReduce", Col2X, top + row*3,
                Lang("分批止盈  ·  浮盈 +", "Partial exit  ·  Profit +") + (string)Inp_TrendBE3_Trigger
                + Lang(" 时减仓 ", " → reduce ") + DoubleToString(Inp_TrendReducePercent, 1) + "%",
                COLOR_TEXT_BODY, 8);
    CreateLabel("Foot_TrTrail", Col2X, top + row*4,
                Lang("峰值追踪  ·  +", "Peak trail  ·  +") + (string)Inp_TrendTrailTrigger
                + Lang(" 启动  /  回撤 ", " activate  /  pullback ") + (string)Inp_TrendTrailStep
                + Lang(" 退出", " exit"), COLOR_TEXT_BODY, 8);

    // 紧随内容收口，缩放时同步调整主面板及金色边框。
    int fittedHeight = top + row*4 - StartY + Scale(28);
    ObjectSetInteger(0, Prefix + "AppBg", OBJPROP_YSIZE, fittedHeight);
    DrawGoldBorder(StartX, StartY, PanelWidth, fittedHeight, 3);
}

//+------------------------------------------------------------------+
//| 生命周期                                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 版本化状态命名空间与实例租约                                      |
//+------------------------------------------------------------------+
string NormalizeNamespacePart(string value)
{
    string result = "";
    for(int i = 0; i < StringLen(value); i++)
    {
        ushort c = (ushort)StringGetCharacter(value, i);
        bool allowed = (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') ||
                       (c >= 'a' && c <= 'z') || c == '-' || c == '_';
        result += allowed ? StringSubstr(value, i, 1) : "_";
    }
    if(result == "") result = "default";
    return result;
}

uint StableTextHash(string value)
{
    uint hash = 2166136261;
    for(int i = 0; i < StringLen(value); i++)
        hash = (hash ^ (uint)StringGetCharacter(value, i)) * 16777619;
    return hash;
}

string StateNamespaceForSchema(int schema)
{
    return IntegerToString(schema) + "|" + AccountInfoString(ACCOUNT_SERVER) + "|" +
           (string)AccountInfoInteger(ACCOUNT_LOGIN) + "|" + _Symbol + "|" +
           NormalizeNamespacePart(Inp_InstanceId);
}
// 每日风控全局变量继续沿用 V2 命名空间，逐票文件升级不得导致风控检查点失联。
string StateNamespace() { return StateNamespaceForSchema(2); }
string TicketStateNamespace() { return StateNamespaceForSchema(TICKET_STATE_SCHEMA); }

string StateNamespaceHash() { return (string)StableTextHash(StateNamespace()); }
string ManagementScope()
{
    return AccountInfoString(ACCOUNT_SERVER) + "|" +
           (string)AccountInfoInteger(ACCOUNT_LOGIN) + "|" + _Symbol + "|" +
           (string)Inp_MagicScalp + "|" + (string)Inp_MagicTrend;
}
string ManagementScopeHash() { return (string)StableTextHash(ManagementScope()); }
string InstanceLeaseOwnerKey() { return "GSOP2.L." + ManagementScopeHash() + ".O"; }
string InstanceLeaseBeatKey()  { return "GSOP2.L." + ManagementScopeHash() + ".B"; }

bool AcquireInstanceLease()
{
    double now = (double)TimeGMT();
    if(!GlobalVariableCheck(InstanceLeaseOwnerKey()))
        GlobalVariableSet(InstanceLeaseOwnerKey(), 0.0);
    if(!GlobalVariableCheck(InstanceLeaseBeatKey()))
        GlobalVariableSet(InstanceLeaseBeatKey(), 0.0);

    double owner = GlobalVariableCheck(InstanceLeaseOwnerKey()) ? GlobalVariableGet(InstanceLeaseOwnerKey()) : 0.0;
    double beat  = GlobalVariableCheck(InstanceLeaseBeatKey())  ? GlobalVariableGet(InstanceLeaseBeatKey())  : 0.0;
    g_InstanceLeaseOwner = (double)ChartID();
    if(owner != 0.0 && owner != g_InstanceLeaseOwner && now - beat < 30.0)
        return false;

    // CAS 抢占租约，防止两个图表在同一时刻都判断为空并同时成为管理者。
    if(owner != g_InstanceLeaseOwner &&
       !GlobalVariableSetOnCondition(InstanceLeaseOwnerKey(), g_InstanceLeaseOwner, owner))
        return false;
    GlobalVariableSet(InstanceLeaseBeatKey(), now);
    GlobalVariablesFlush();
    return true;
}

void RenewInstanceLease()
{
    if(!g_InstanceOwnsState) return;
    if(!GlobalVariableCheck(InstanceLeaseOwnerKey()) ||
       GlobalVariableGet(InstanceLeaseOwnerKey()) != g_InstanceLeaseOwner)
    {
        g_InstanceOwnsState = false;
        Print("[State V2] 管理租约已丢失，停止持仓管理和状态写入: ", ManagementScope());
        return;
    }
    GlobalVariableSet(InstanceLeaseBeatKey(), (double)TimeGMT());
}

void ReleaseInstanceLease()
{
    if(!g_InstanceOwnsState) return;
    if(GlobalVariableCheck(InstanceLeaseOwnerKey()) &&
       GlobalVariableGet(InstanceLeaseOwnerKey()) == g_InstanceLeaseOwner)
    {
        GlobalVariableDel(InstanceLeaseOwnerKey());
        GlobalVariableDel(InstanceLeaseBeatKey());
    }
}

//+------------------------------------------------------------------+
//| 每日风控状态(终端全局变量，使用完整实例命名空间)                  |
//+------------------------------------------------------------------+
string PVKey(string k) { return "GSOP2.P." + StateNamespaceHash() + "." + k; }
string LegacyPVKey(string k)
{
    return StringFormat("GSOP_%I64d_%s", AccountInfoInteger(ACCOUNT_LOGIN), k);
}
void PVSet(string k, double v)
{
    if(g_InstanceOwnsState) GlobalVariableSet(PVKey(k), v);
}
bool   PVHas(string k) { return GlobalVariableCheck(PVKey(k)); }
double PVGet(string k) { return GlobalVariableGet(PVKey(k)); }

void PVSetUlong(string k, ulong value)
{
    PVSet(k + "Hi", (double)(uint)(value >> 32));
    PVSet(k + "Lo", (double)(uint)(value & 0xFFFFFFFF));
}

ulong PVGetUlong(string k)
{
    ulong hi = (ulong)(uint)PVGet(k + "Hi");
    ulong lo = (ulong)(uint)PVGet(k + "Lo");
    return (hi << 32) | lo;
}

void SaveState()
{
    if(!g_InstanceOwnsState) return;
    g_LastStateCheckpointUtc = 0; // 旧版没有可信检查点时间，交由恢复流程判定是否保守接管
    PVSet("StatDay",    (double)g_DayStart);
    PVSet("ResetTime",  (double)g_ResetTime);
    PVSet("Cooldown",   (double)g_CooldownUntil);
    PVSet("ConsecLoss", (double)g_ConsecLoss);
    PVSet("LastDeal",   (double)g_LastDealTime);
    PVSet("LastDealMsc", (double)g_LastDealTimeMsc);
    PVSetUlong("LastDealTicket", g_LastDealTicket);
    PVSet("CheckpointUtc", (double)g_LastStateCheckpointUtc);
    PVSet("RecoveryStartedUtc", (double)g_RecoveryStartedUtc);
    PVSet("RecoveryCompletedUtc", (double)g_RecoveryCompletedUtc);
    PVSet("RecoveryResult", (double)g_RecoveryStatus);
    PVSet("RecoveryNeedsAck", (g_RecoveryStatus == RECOVERY_CONSERVATIVE && !g_RecoveryAcknowledged) ? 1.0 : 0.0);
    PVSet("CompletedPeriod", (double)g_LastCompletedPeriod);
    PVSet("ReportedPeriod", (double)g_LastReportedPeriod);
    PVSet("PendingReportPeriod", (double)g_PendingReportPeriod);
    PVSet("PeriodServerOffset", (double)ServerGmtOffset());
    PVSet("InitBalance", g_InitBalance);
    PVSet("PeakBalance", g_PeakBalance);
    PVSet("TodayHi",    g_TodayHighProfit);   PVSet("HiInit",   g_HighInit    ? 1 : 0);
    PVSet("ScalpHi",    g_ScalpHighProfit);   PVSet("ScHiInit", g_ScalpHiInit ? 1 : 0);
    PVSet("TrendHi",    g_TrendHighProfit);   PVSet("TrHiInit", g_TrendHiInit ? 1 : 0);
    PVSet("GlobalHi",   g_GlobalRealHigh);    PVSet("GbHiInit", g_GlobalHiInit? 1 : 0);
    PVSet("MoatLiq",    g_MoatLiquidated ? 1 : 0);
    PVSet("DailyLiq",   g_DailyLiquidationActive ? 1 : 0);
    GlobalVariablesFlush();
}

bool LoadLegacyDailyState()
{
    if(NormalizeNamespacePart(Inp_InstanceId) != "primary") return false;
    if(!GlobalVariableCheck(LegacyPVKey("StatDay"))) return false;
    if((datetime)(long)GlobalVariableGet(LegacyPVKey("StatDay")) != g_DayStart) return false;

    g_ResetTime       = (datetime)(long)GlobalVariableGet(LegacyPVKey("ResetTime"));
    g_CooldownUntil   = (datetime)(long)GlobalVariableGet(LegacyPVKey("Cooldown"));
    g_ConsecLoss      = (int)GlobalVariableGet(LegacyPVKey("ConsecLoss"));
    g_LastDealTime    = (datetime)(long)GlobalVariableGet(LegacyPVKey("LastDeal"));
    g_LastDealTimeMsc = (long)g_LastDealTime * 1000;
    g_LastDealTicket  = 0;
    g_LastStateCheckpointUtc = TimeGMT();
    g_LastCompletedPeriod = g_DayStart;
    g_LastReportedPeriod = 0;
    g_PendingReportPeriod = 0;
    g_TodayHighProfit = GlobalVariableGet(LegacyPVKey("TodayHi"));
    g_HighInit        = (GlobalVariableGet(LegacyPVKey("HiInit")) > 0.5);
    g_ScalpHighProfit = GlobalVariableGet(LegacyPVKey("ScalpHi"));
    g_ScalpHiInit     = (GlobalVariableGet(LegacyPVKey("ScHiInit")) > 0.5);
    g_TrendHighProfit = GlobalVariableGet(LegacyPVKey("TrendHi"));
    g_TrendHiInit     = (GlobalVariableGet(LegacyPVKey("TrHiInit")) > 0.5);
    g_GlobalRealHigh  = GlobalVariableGet(LegacyPVKey("GlobalHi"));
    g_GlobalHiInit    = (GlobalVariableGet(LegacyPVKey("GbHiInit")) > 0.5);
    g_MoatLiquidated  = (GlobalVariableGet(LegacyPVKey("MoatLiq")) > 0.5);
    g_DailyLiquidationActive = false;
    Print("[State V2] 已迁移当前统计日的旧版全局状态");
    return true;
}

bool LoadState()
{
    if(!PVHas("StatDay")) return LoadLegacyDailyState();
    if((datetime)(long)PVGet("StatDay") != g_DayStart) return false;

    g_ResetTime       = (datetime)(long)PVGet("ResetTime");
    g_CooldownUntil   = (datetime)(long)PVGet("Cooldown");
    g_ConsecLoss      = (int)PVGet("ConsecLoss");
    g_LastDealTime    = (datetime)(long)PVGet("LastDeal");
    g_LastDealTimeMsc = PVHas("LastDealMsc") ? (long)PVGet("LastDealMsc") : (long)g_LastDealTime * 1000;
    g_LastDealTicket  = (PVHas("LastDealTicketHi") && PVHas("LastDealTicketLo")) ? PVGetUlong("LastDealTicket") : 0;
    g_LastStateCheckpointUtc = PVHas("CheckpointUtc") ? (datetime)(long)PVGet("CheckpointUtc") : 0;
    g_RecoveryStartedUtc = PVHas("RecoveryStartedUtc") ? (datetime)(long)PVGet("RecoveryStartedUtc") : 0;
    g_RecoveryCompletedUtc = PVHas("RecoveryCompletedUtc") ? (datetime)(long)PVGet("RecoveryCompletedUtc") : 0;
    g_LastCompletedPeriod = PVHas("CompletedPeriod") ? (datetime)(long)PVGet("CompletedPeriod") : g_DayStart;
    g_LastReportedPeriod = PVHas("ReportedPeriod") ? (datetime)(long)PVGet("ReportedPeriod") : 0;
    g_PendingReportPeriod = PVHas("PendingReportPeriod") ? (datetime)(long)PVGet("PendingReportPeriod") : 0;
    if(PVHas("InitBalance")) g_InitBalance = PVGet("InitBalance");
    if(PVHas("PeakBalance")) g_PeakBalance = PVGet("PeakBalance");
    g_TodayHighProfit = PVGet("TodayHi");   g_HighInit    = (PVGet("HiInit")   > 0.5);
    g_ScalpHighProfit = PVGet("ScalpHi");   g_ScalpHiInit = (PVGet("ScHiInit") > 0.5);
    g_TrendHighProfit = PVGet("TrendHi");   g_TrendHiInit = (PVGet("TrHiInit") > 0.5);
    g_GlobalRealHigh  = PVGet("GlobalHi");  g_GlobalHiInit= (PVGet("GbHiInit") > 0.5);
    g_MoatLiquidated  = (PVGet("MoatLiq") > 0.5);
    g_DailyLiquidationActive = PVHas("DailyLiq") && PVGet("DailyLiq") > 0.5;
    return true;
}

//+------------------------------------------------------------------+
//| 逐票状态 V5：增加显式TP策略；兼容迁移 V2/V3/V4                  |
//+------------------------------------------------------------------+
string StateFolderForSchema(int schema)
{
    return "TradeEZ\\state\\v" + IntegerToString(schema);
}
string StateFolder() { return StateFolderForSchema(TICKET_STATE_SCHEMA); }

string StateFileNameForSchema(int schema)
{
    string serverHash = (string)StableTextHash(AccountInfoString(ACCOUNT_SERVER));
    return StateFolderForSchema(schema) + "\\" + serverHash + "_" +
           (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" +
           NormalizeNamespacePart(_Symbol) + "_" +
           NormalizeNamespacePart(Inp_InstanceId) + ".csv";
}
string StateFileName() { return StateFileNameForSchema(TICKET_STATE_SCHEMA); }

string LegacyStateFileName()
{
    return StringFormat("GSOP_state_%I64d.csv", AccountInfoInteger(ACCOUNT_LOGIN));
}

void EnsureStateFolder()
{
    FolderCreate("TradeEZ");
    FolderCreate("TradeEZ\\state");
    FolderCreate(StateFolder());
}

int TicketStateIndex(ulong ticket)
{
    for(int i = 0; i < ArraySize(g_TicketState); i++)
        if(g_TicketState[i].ticket == ticket) return i;
    return -1;
}

bool IsTicketRecoveryBlocked(ulong ticket)
{
    for(int i = 0; i < ArraySize(g_StateRecoveryBlockedTickets); i++)
        if(g_StateRecoveryBlockedTickets[i] == ticket) return true;
    return false;
}

void BlockTicketStateRecovery(ulong ticket, string reason)
{
    if(ticket == 0 || IsTicketRecoveryBlocked(ticket)) return;
    int n = ArraySize(g_StateRecoveryBlockedTickets);
    ArrayResize(g_StateRecoveryBlockedTickets, n + 1);
    g_StateRecoveryBlockedTickets[n] = ticket;
    PrintFormat("[State V5] Ticket=%I64u 暂停自动管理：%s；等待恢复策略处理", ticket, reason);
}

int EnsureTicketStateRecord(ulong ticket)
{
    int idx = TicketStateIndex(ticket);
    if(idx >= 0) return idx;
    int n = ArraySize(g_TicketState);
    ArrayResize(g_TicketState, n + 1);
    g_TicketState[n].ticket = ticket;
    g_TicketState[n].scalp_phase = SCALP_INITIAL;
    g_TicketState[n].scalp_exit_reason = SCALP_EXIT_NONE;
    g_TicketState[n].scalp_exit_requested_utc_msc = 0;
    g_TicketState[n].scalp_exit_next_retry_utc_msc = 0;
    g_TicketState[n].scalp_exit_retry_count = 0;
    g_TicketState[n].scalp_exit_last_retcode = 0;
    g_TicketState[n].scalp_tp_policy = SCALP_TP_REQUIRED;
    g_TicketState[n].scalp_tp_requested_utc_msc = 0;
    g_TicketState[n].scalp_tp_last_retcode = 0;
    g_TicketState[n].protection_status = PROTECTION_CHECKING;
    g_TicketState[n].minimum_required_sl = 0.0;
    g_TicketState[n].last_confirmed_sl = 0.0;
    g_TicketState[n].last_confirmed_tp = 0.0;
    g_TicketState[n].protection_first_failed_utc_msc = 0;
    g_TicketState[n].protection_next_retry_utc_msc = 0;
    g_TicketState[n].protection_retry_count = 0;
    g_TicketState[n].protection_last_retcode = 0;
    g_TicketState[n].closed_utc = 0;
    return n;
}

void ClearRuntimeTicketArrays()
{
    ArrayResize(g_TimeoutCancelled, 0);
    ArrayResize(g_PromotedTickets, 0);
    ArrayResize(g_TrTicket, 0);
    ArrayResize(g_TrReduced, 0);
    ArrayResize(g_TrPeakPoints, 0);
    ArrayResize(g_ScalpTrackTicket, 0);
    ArrayResize(g_ScalpTrackPeak, 0);
    ArrayResize(g_ScalpTrackLoggedPeak, 0);
}

void AddRuntimeTicket(ulong &tickets[], ulong ticket)
{
    for(int i = 0; i < ArraySize(tickets); i++)
        if(tickets[i] == ticket) return;
    int n = ArraySize(tickets);
    ArrayResize(tickets, n + 1);
    tickets[n] = ticket;
}

bool ValidateTicketIdentity(const TicketStateRecord &record)
{
    if(!PositionSelectByTicket(record.ticket)) return false;
    if(PositionGetString(POSITION_SYMBOL) != record.symbol || record.symbol != _Symbol) return false;
    if((ulong)PositionGetInteger(POSITION_IDENTIFIER) != record.position_id) return false;
    if(PositionGetInteger(POSITION_MAGIC) != record.magic) return false;
    if((long)PositionGetInteger(POSITION_TIME_MSC) != record.open_time_msc) return false;
    return true;
}

bool ValidateTicketStateValues(const TicketStateRecord &record)
{
    if(record.ticket == 0 || record.position_id == 0 || record.open_time_msc <= 0) return false;
    if(record.management_mode < 1 || record.management_mode > 2) return false;
    if(!MathIsValidNumber(record.scalp_peak_points) || record.scalp_peak_points < 0.0) return false;
    if(!MathIsValidNumber(record.trend_peak_points) || record.trend_peak_points < 0.0) return false;
    if(!MathIsValidNumber(record.last_volume) || record.last_volume < 0.0) return false;
    if(record.scalp_phase < SCALP_INITIAL || record.scalp_phase > SCALP_CLOSED) return false;
    if(record.scalp_exit_reason < SCALP_EXIT_NONE || record.scalp_exit_reason > SCALP_EXIT_PULLBACK) return false;
    if(record.scalp_exit_retry_count < 0) return false;
    if(record.scalp_tp_policy < SCALP_TP_REQUIRED || record.scalp_tp_policy > SCALP_TP_REMOVED) return false;
    if(record.protection_status < PROTECTION_CHECKING || record.protection_status > PROTECTION_FAILED) return false;
    if(!MathIsValidNumber(record.minimum_required_sl) || record.minimum_required_sl < 0.0) return false;
    if(!MathIsValidNumber(record.last_confirmed_sl) || record.last_confirmed_sl < 0.0) return false;
    if(!MathIsValidNumber(record.last_confirmed_tp) || record.last_confirmed_tp < 0.0) return false;
    if(record.protection_retry_count < 0) return false;
    return true;
}

void HydrateRuntimeFromRecord(const TicketStateRecord &record)
{
    if(record.timeout_cancelled) AddRuntimeTicket(g_TimeoutCancelled, record.ticket);
    if(record.scalp_phase == SCALP_TRAIL_ACTIVE)
    {
        int n = ArraySize(g_ScalpTrackTicket);
        ArrayResize(g_ScalpTrackTicket, n + 1);
        ArrayResize(g_ScalpTrackPeak, n + 1);
        ArrayResize(g_ScalpTrackLoggedPeak, n + 1);
        g_ScalpTrackTicket[n] = record.ticket;
        g_ScalpTrackPeak[n] = MathMax(0.0, record.scalp_peak_points);
        g_ScalpTrackLoggedPeak[n] = g_ScalpTrackPeak[n];
    }

    if(record.management_mode == 2 || record.trend_reduced || record.trend_peak_points > 0.0)
    {
        int n = ArraySize(g_TrTicket);
        ArrayResize(g_TrTicket, n + 1);
        ArrayResize(g_TrReduced, n + 1);
        ArrayResize(g_TrPeakPoints, n + 1);
        g_TrTicket[n] = record.ticket;
        g_TrReduced[n] = record.trend_reduced;
        g_TrPeakPoints[n] = MathMax(0.0, record.trend_peak_points);
    }
}

void RefreshTicketStateRecords()
{
    datetime nowUtc = TimeGMT();

    for(int i = 0; i < ArraySize(g_TicketState); i++)
    {
        if(g_TicketState[i].closed_utc != 0) continue;
        if(!PositionSelectByTicket(g_TicketState[i].ticket) ||
           PositionGetString(POSITION_SYMBOL) != _Symbol ||
           (ulong)PositionGetInteger(POSITION_IDENTIFIER) != g_TicketState[i].position_id)
        {
            g_TicketState[i].closed_utc = nowUtc;
            g_TicketState[i].scalp_phase = SCALP_CLOSED;
            g_TicketState[i].updated_utc = nowUtc;
        }
    }

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(IsTicketRecoveryBlocked(ticket)) continue;
        ENUM_SOP_ORDER kind = PosType();
        if(kind == SOP_IGNORE) continue;

        int idx = EnsureTicketStateRecord(ticket);
        g_TicketState[idx].ticket = ticket;
        g_TicketState[idx].position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
        g_TicketState[idx].symbol = _Symbol;
        g_TicketState[idx].magic = PositionGetInteger(POSITION_MAGIC);
        g_TicketState[idx].open_time_msc = (long)PositionGetInteger(POSITION_TIME_MSC);
        if(kind == SOP_SCALP && IsPromoted(ticket) &&
           g_TicketState[idx].scalp_tp_policy == SCALP_TP_REQUIRED)
            g_TicketState[idx].scalp_tp_policy = SCALP_TP_REMOVED; // 仅兼容最旧PRO迁移
        g_TicketState[idx].management_mode = (int)kind;
        g_TicketState[idx].timeout_cancelled = IsTimeoutCancelled(ticket);
        int scIdx = ScalpTrackIndex(ticket);
        if(scIdx >= 0)
        {
            g_TicketState[idx].scalp_track_active = true;
            g_TicketState[idx].scalp_peak_points = MathMax(g_TicketState[idx].scalp_peak_points,
                                                            g_ScalpTrackPeak[scIdx]);
            if(g_TicketState[idx].scalp_phase == SCALP_INITIAL)
                g_TicketState[idx].scalp_phase = SCALP_TRAIL_ACTIVE;
        }
        int trIdx = TrIndex(ticket);
        g_TicketState[idx].trend_reduced = (trIdx >= 0 ? g_TrReduced[trIdx] : false);
        g_TicketState[idx].trend_peak_points = (trIdx >= 0 ? g_TrPeakPoints[trIdx] : 0.0);
        g_TicketState[idx].last_volume = PositionGetDouble(POSITION_VOLUME);
        g_TicketState[idx].updated_utc = nowUtc;
        g_TicketState[idx].closed_utc = 0;
    }

    const int retentionSeconds = 7 * 86400;
    for(int i = ArraySize(g_TicketState) - 1; i >= 0; i--)
    {
        if(g_TicketState[i].closed_utc == 0 || nowUtc - g_TicketState[i].closed_utc <= retentionSeconds)
            continue;
        int last = ArraySize(g_TicketState) - 1;
        g_TicketState[i] = g_TicketState[last];
        ArrayResize(g_TicketState, last);
    }
}

void SaveArrays()
{
    if(!g_InstanceOwnsState || g_StatePersistenceBlocked) return;
    RefreshTicketStateRecords();
    EnsureStateFolder();

    string finalPath = StateFileName();
    string tempPath = finalPath + ".tmp";
    int h = FileOpen(tempPath, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
    if(h == INVALID_HANDLE)
    {
        PrintFormat("[State V5] 无法写入临时文件，错误=%d", GetLastError());
        return;
    }

    FileWrite(h, "META", TICKET_STATE_SCHEMA, TicketStateNamespace(), (long)TimeGMT(),
              g_LegacyStateMigrated ? 1 : 0);
    for(int i = 0; i < ArraySize(g_TicketState); i++)
    {
        TicketStateRecord r = g_TicketState[i];
        FileWrite(h, "REC", (long)r.ticket, (long)r.position_id, r.symbol, r.magic,
                  r.open_time_msc, r.management_mode, r.timeout_cancelled ? 1 : 0,
                  r.scalp_track_active ? 1 : 0, r.scalp_peak_points,
                  r.trend_reduced ? 1 : 0, r.trend_peak_points, r.last_volume,
                  r.scalp_phase, r.scalp_exit_reason,
                  r.scalp_exit_requested_utc_msc, r.scalp_exit_next_retry_utc_msc,
                  r.scalp_exit_retry_count, (long)r.scalp_exit_last_retcode,
                  r.scalp_tp_policy, r.scalp_tp_requested_utc_msc, (long)r.scalp_tp_last_retcode,
                  r.protection_status, r.minimum_required_sl, r.last_confirmed_sl, r.last_confirmed_tp,
                  r.protection_first_failed_utc_msc, r.protection_next_retry_utc_msc,
                  r.protection_retry_count, (long)r.protection_last_retcode,
                  (long)r.updated_utc, (long)r.closed_utc);
    }
    FileFlush(h);
    FileClose(h);

    if(!FileMove(tempPath, 0, finalPath, FILE_REWRITE))
    {
        PrintFormat("[State V5] 原子替换失败，错误=%d", GetLastError());
        FileDelete(tempPath);
        return;
    }
    g_ArraysDirty = false;
}

bool LoadLegacyArrays()
{
    if(NormalizeNamespacePart(Inp_InstanceId) != "primary") return false;
    if(!FileIsExist(LegacyStateFileName())) return false;
    int h = FileOpen(LegacyStateFileName(), FILE_READ | FILE_CSV | FILE_ANSI, ',');
    if(h == INVALID_HANDLE) return false;

    string firstTag = FileReadString(h);
    if(firstTag != "DAY") { FileClose(h); return false; }
    FileReadNumber(h); // 旧统计日只作为来源信息，不再阻止仍在持仓的票据迁移。
    int loaded = 0;

    while(!FileIsEnding(h))
    {
        string tag = FileReadString(h);
        if(tag == "") break;
        ulong ticket = (ulong)FileReadNumber(h);
        bool valid = PositionSelectByTicket(ticket) &&
                     PositionGetString(POSITION_SYMBOL) == _Symbol &&
                     PosType() != SOP_IGNORE;

        if(tag == "TOC")
        {
            if(valid) { AddRuntimeTicket(g_TimeoutCancelled, ticket); loaded++; }
        }
        else if(tag == "PRO")
        {
            if(valid) { AddRuntimeTicket(g_PromotedTickets, ticket); loaded++; }
        }
        else if(tag == "TRK")
        {
            long reduced = (long)FileReadNumber(h);
            double peak = FileReadNumber(h);
            if(valid)
            {
                int n = ArraySize(g_TrTicket);
                ArrayResize(g_TrTicket, n + 1);
                ArrayResize(g_TrReduced, n + 1);
                ArrayResize(g_TrPeakPoints, n + 1);
                g_TrTicket[n] = ticket;
                g_TrReduced[n] = (reduced != 0);
                g_TrPeakPoints[n] = MathMax(0.0, peak);
                loaded++;
            }
        }
        else if(tag == "SCT")
        {
            double peak = FileReadNumber(h);
            if(valid)
            {
                int n = ArraySize(g_ScalpTrackTicket);
                ArrayResize(g_ScalpTrackTicket, n + 1);
                ArrayResize(g_ScalpTrackPeak, n + 1);
                ArrayResize(g_ScalpTrackLoggedPeak, n + 1);
                g_ScalpTrackTicket[n] = ticket;
                g_ScalpTrackPeak[n] = MathMax(0.0, peak);
                g_ScalpTrackLoggedPeak[n] = g_ScalpTrackPeak[n];
                loaded++;
            }
        }
    }
    FileClose(h);
    g_LegacyStateMigrated = true;
    PrintFormat("[State V2] 旧版逐票状态迁移完成，有效记录=%d；旧文件已保留", loaded);
    return true;
}

bool LoadTicketStateV2()
{
    string loadPath = StateFileName();
    int migratingFrom = 0;
    if(!FileIsExist(loadPath))
    {
        loadPath = StateFileNameForSchema(4);
        if(FileIsExist(loadPath)) migratingFrom = 4;
        else
        {
            loadPath = StateFileNameForSchema(3);
            if(FileIsExist(loadPath)) migratingFrom = 3;
            else
            {
                loadPath = StateFileNameForSchema(2);
                if(FileIsExist(loadPath)) migratingFrom = 2;
            }
        }
    }
    if(!FileIsExist(loadPath)) return false;
    int h = FileOpen(loadPath, FILE_READ | FILE_CSV | FILE_ANSI, ',');
    if(h == INVALID_HANDLE)
    {
        g_StatePersistenceBlocked = true;
        PrintFormat("[State V5] 状态文件存在但无法读取；为保护原文件，本次运行禁止覆盖，错误=%d", GetLastError());
        return true;
    }

    string meta = FileReadString(h);
    int schema = (int)FileReadNumber(h);
    string storedNamespace = FileReadString(h);
    FileReadNumber(h); // saved_utc
    g_LegacyStateMigrated = ((int)FileReadNumber(h) != 0);
    if(meta != "META" || (schema != TICKET_STATE_SCHEMA && schema != 4 && schema != 3 && schema != 2) ||
       storedNamespace != StateNamespaceForSchema(schema))
    {
        Print("[State V5] 文件头或命名空间不匹配，拒绝恢复: ", loadPath);
        FileClose(h);
        g_StatePersistenceBlocked = true;
        return true;
    }

    ArrayResize(g_TicketState, 0);
    ClearRuntimeTicketArrays();
    int restored = 0;
    int rejected = 0;

    while(!FileIsEnding(h))
    {
        string tag = FileReadString(h);
        if(tag == "") break;
        if(tag != "REC")
        {
            rejected++;
            g_StatePersistenceBlocked = true;
            Print("[State V5] 检测到无法识别的记录；为保护原文件，本次运行禁止覆盖: ", loadPath);
            break;
        }

        TicketStateRecord r;
        r.ticket = (ulong)FileReadNumber(h);
        r.position_id = (ulong)FileReadNumber(h);
        r.symbol = FileReadString(h);
        r.magic = (long)FileReadNumber(h);
        r.open_time_msc = (long)FileReadNumber(h);
        r.management_mode = (int)FileReadNumber(h);
        r.timeout_cancelled = ((int)FileReadNumber(h) != 0);
        r.scalp_track_active = ((int)FileReadNumber(h) != 0);
        r.scalp_peak_points = FileReadNumber(h);
        r.trend_reduced = ((int)FileReadNumber(h) != 0);
        r.trend_peak_points = FileReadNumber(h);
        r.last_volume = FileReadNumber(h);
        r.scalp_phase = r.scalp_track_active ? SCALP_TRAIL_ACTIVE : SCALP_INITIAL;
        r.scalp_exit_reason = SCALP_EXIT_NONE;
        r.scalp_exit_requested_utc_msc = 0;
        r.scalp_exit_next_retry_utc_msc = 0;
        r.scalp_exit_retry_count = 0;
        r.scalp_exit_last_retcode = 0;
        if(schema >= 4)
        {
            r.scalp_phase = (int)FileReadNumber(h);
            r.scalp_exit_reason = (int)FileReadNumber(h);
            r.scalp_exit_requested_utc_msc = (long)FileReadNumber(h);
            r.scalp_exit_next_retry_utc_msc = (long)FileReadNumber(h);
            r.scalp_exit_retry_count = (int)FileReadNumber(h);
            r.scalp_exit_last_retcode = (uint)(long)FileReadNumber(h);
        }
        r.scalp_tp_policy = SCALP_TP_REQUIRED;
        r.scalp_tp_requested_utc_msc = 0;
        r.scalp_tp_last_retcode = 0;
        if(schema >= 5)
        {
            r.scalp_tp_policy = (int)FileReadNumber(h);
            r.scalp_tp_requested_utc_msc = (long)FileReadNumber(h);
            r.scalp_tp_last_retcode = (uint)(long)FileReadNumber(h);
        }
        r.protection_status = PROTECTION_CHECKING;
        r.minimum_required_sl = 0.0;
        r.last_confirmed_sl = 0.0;
        r.last_confirmed_tp = 0.0;
        r.protection_first_failed_utc_msc = 0;
        r.protection_next_retry_utc_msc = 0;
        r.protection_retry_count = 0;
        r.protection_last_retcode = 0;
        if(schema >= 3)
        {
            r.protection_status = (int)FileReadNumber(h);
            r.minimum_required_sl = FileReadNumber(h);
            r.last_confirmed_sl = FileReadNumber(h);
            r.last_confirmed_tp = FileReadNumber(h);
            r.protection_first_failed_utc_msc = (long)FileReadNumber(h);
            r.protection_next_retry_utc_msc = (long)FileReadNumber(h);
            r.protection_retry_count = (int)FileReadNumber(h);
            r.protection_last_retcode = (uint)(long)FileReadNumber(h);
        }
        r.updated_utc = (datetime)(long)FileReadNumber(h);
        r.closed_utc = (datetime)(long)FileReadNumber(h);
        if(r.closed_utc != 0) r.scalp_phase = SCALP_CLOSED;

        if(schema < 5 && TypeByMagic(r.magic) == SOP_SCALP)
        {
            bool legacyPromoted = (r.management_mode == 3);
            if(legacyPromoted)
            {
                r.management_mode = SOP_SCALP;
                r.scalp_tp_policy = SCALP_TP_REMOVED;
            }
            else if(r.scalp_phase == SCALP_TRAIL_ACTIVE && PositionSelectByTicket(r.ticket) &&
                    PositionGetDouble(POSITION_TP) == 0.0)
            {
                r.scalp_tp_policy = SCALP_TP_REMOVED;
                PrintFormat("[State V5] Ticket=%I64u 旧版追踪持仓无TP，保留现状并标记历史意图不确定", r.ticket);
            }
        }

        int n = ArraySize(g_TicketState);
        ArrayResize(g_TicketState, n + 1);
        g_TicketState[n] = r;

        if(r.closed_utc == 0)
        {
            if(ValidateTicketStateValues(r) && ValidateTicketIdentity(r))
            {
                HydrateRuntimeFromRecord(r);
                restored++;
            }
            else
            {
                rejected++;
                if(PositionSelectByTicket(r.ticket))
                    BlockTicketStateRecovery(r.ticket, "状态字段无效或身份与当前持仓不匹配");
                PrintFormat("[State V5] 拒绝恢复无效或身份不匹配记录 Ticket=%I64u", r.ticket);
            }
        }
    }
    FileClose(h);

    // 版本化逐票文件理应覆盖所有在管持仓；缺失时不猜测历史阶段。
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PosType() == SOP_IGNORE) continue;
        if(TicketStateIndex(ticket) < 0)
        {
            rejected++;
            BlockTicketStateRecovery(ticket, "新版状态文件缺少该持仓记录");
        }
    }
    PrintFormat("[State V5] 恢复完成，有效持仓=%d，拒绝=%d，迁移来源V%d", restored, rejected, migratingFrom);
    if(migratingFrom > 0 && !g_StatePersistenceBlocked && rejected == 0)
        SaveArrays(); // 原文件保留，只在新 v5 目录写入迁移后的原子文件。
    return true;
}

void LoadArrays()
{
    if(LoadTicketStateV2()) return;
    ClearRuntimeTicketArrays();
    bool migrated = LoadLegacyArrays();
    if(!migrated)
    {
        // 没有任何可验证来源时，不把空数组直接当作真实历史状态。
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PosType() == SOP_IGNORE) continue;
            BlockTicketStateRecovery(ticket, "未找到新版或可迁移的旧版逐票状态");
        }
    }
    if(ArraySize(g_StateRecoveryBlockedTickets) == 0)
        SaveArrays(); // 无在管票据缺口时建立当前命名空间 V5 文件；旧文件始终保留。
}

//+------------------------------------------------------------------+
//| 启动恢复：成交历史精确重放与缺失逐票状态保守接管                |
//+------------------------------------------------------------------+
datetime RecoveryNowServer()
{
    datetime now = TimeTradeServer();
    if(now <= 0) now = TimeCurrent();
    return now;
}

bool BuildRecoverySnapshot(datetime from, datetime to, RecoverySnapshot &snapshot)
{
    ZeroMemory(snapshot);
    if(to <= from) to = from + 1;
    datetime selectFrom = from - 365 * 86400;
    if(selectFrom < 0) selectFrom = 0;
    if(!HistorySelect(selectFrom, to))
    {
        PrintFormat("[Recovery] HistorySelect 失败：%s ~ %s，错误=%d",
                    TimeToString(from, TIME_DATE|TIME_MINUTES),
                    TimeToString(to, TIME_DATE|TIME_MINUTES), GetLastError());
        return false;
    }

    ulong tickets[];
    long timesMsc[];
    double profits[];
    double exitTradeProfits[];
    int kinds[];
    bool exits[];
    int total = HistoryDealsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong deal = HistoryDealGetTicket(i);
        if(deal == 0) continue;
        if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
        long dealMsc = HistoryDealGetInteger(deal, DEAL_TIME_MSC);
        datetime dealTime = (datetime)(dealMsc / 1000);
        if(dealTime < from || dealTime >= to) continue;

        int n = ArraySize(tickets);
        ArrayResize(tickets, n + 1);
        ArrayResize(timesMsc, n + 1);
        ArrayResize(profits, n + 1);
        ArrayResize(exitTradeProfits, n + 1);
        ArrayResize(kinds, n + 1);
        ArrayResize(exits, n + 1);
        tickets[n] = deal;
        timesMsc[n] = dealMsc;
        profits[n] = DealCashValue(deal);
        exitTradeProfits[n] = DealIsExit(deal) ? ExitTradeCashValue(deal) : profits[n];
        kinds[n] = (int)DealCashStrategy(deal);
        exits[n] = DealIsExit(deal);
    }

    // 稳定排序：毫秒时间相同则按 deal ticket，保证重复重放结果一致。
    for(int i = 1; i < ArraySize(tickets); i++)
    {
        ulong tk = tickets[i]; long tm = timesMsc[i]; double pnl = profits[i]; double tradePnl = exitTradeProfits[i]; int kind = kinds[i]; bool isExit = exits[i];
        int j = i - 1;
        while(j >= 0 && (timesMsc[j] > tm || (timesMsc[j] == tm && tickets[j] > tk)))
        {
            tickets[j + 1] = tickets[j]; timesMsc[j + 1] = timesMsc[j];
            profits[j + 1] = profits[j]; exitTradeProfits[j + 1] = exitTradeProfits[j]; kinds[j + 1] = kinds[j]; exits[j + 1] = exits[j]; j--;
        }
        tickets[j + 1] = tk; timesMsc[j + 1] = tm; profits[j + 1] = pnl; exitTradeProfits[j + 1] = tradePnl; kinds[j + 1] = kind; exits[j + 1] = isExit;
    }

    int closedCount = 0;
    for(int i = 0; i < ArraySize(tickets); i++)
    {
        double pnl = profits[i];
        snapshot.all_realized += pnl;
        if(!snapshot.all_high_init) { snapshot.all_high = snapshot.all_realized; snapshot.all_high_init = true; }
        else if(snapshot.all_realized > snapshot.all_high) snapshot.all_high = snapshot.all_realized;

        if(kinds[i] == SOP_SCALP)
        {
            snapshot.scalp_realized += pnl;
            if(!snapshot.scalp_high_init) { snapshot.scalp_high = snapshot.scalp_realized; snapshot.scalp_high_init = true; }
            else if(snapshot.scalp_realized > snapshot.scalp_high) snapshot.scalp_high = snapshot.scalp_realized;
        }
        else if(kinds[i] == SOP_TREND)
        {
            snapshot.trend_realized += pnl;
            if(!snapshot.trend_high_init) { snapshot.trend_high = snapshot.trend_realized; snapshot.trend_high_init = true; }
            else if(snapshot.trend_realized > snapshot.trend_high) snapshot.trend_high = snapshot.trend_realized;
        }

        if(exits[i])
        {
            closedCount++;
            if(exitTradeProfits[i] < 0.0) snapshot.consec_loss++;
            else snapshot.consec_loss = 0;
            if(Inp_ConsecLossLimit > 0 && snapshot.consec_loss >= Inp_ConsecLossLimit)
            {
                snapshot.cooldown_until = (datetime)(timesMsc[i] / 1000) + Inp_CooldownMinutes * 60;
                snapshot.consec_loss = 0;
            }
            snapshot.last_deal_msc = timesMsc[i];
            snapshot.last_deal_ticket = tickets[i];
        }
    }
    snapshot.deal_count = closedCount;
    snapshot.history_ok = true;
    return true;
}

bool ReplayMissedPeriods(datetime savedPeriod, datetime currentPeriod)
{
    if(savedPeriod <= 0 || savedPeriod >= currentPeriod) return true;
    // 官方日报始终覆盖完整统计周期；手动风控重置不得截断报告。
    SchedulePendingReports(savedPeriod, currentPeriod);
    RetryPendingReports(currentPeriod, true); // 报告失败保留待补，不阻断当前周期恢复。
    return true;
}

double CurrentPositionProfitPoints()
{
    double open = PositionGetDouble(POSITION_PRICE_OPEN);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double current = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double step = PointsToPrice(1.0);
    if(step <= 0.0) return 0.0;
    return (type == POSITION_TYPE_BUY) ? (current - open) / step : (open - current) / step;
}

bool AdoptMissingTicketStates()
{
    int blocked = ArraySize(g_StateRecoveryBlockedTickets);
    if(blocked == 0) return false;
    ulong tickets[];
    ArrayCopy(tickets, g_StateRecoveryBlockedTickets);
    ArrayResize(g_StateRecoveryBlockedTickets, 0);

    for(int i = 0; i < ArraySize(tickets); i++)
    {
        ulong ticket = tickets[i];
        if(!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        ENUM_SOP_ORDER kind = PosType();
        double peak = MathMax(0.0, CurrentPositionProfitPoints());
        if(kind == SOP_SCALP)
        {
            AddRuntimeTicket(g_TimeoutCancelled, ticket); // 避免恢复瞬间触发超时强平
            if(peak >= Inp_ScalpBETrigger)
            {
                int n = ArraySize(g_ScalpTrackTicket);
                ArrayResize(g_ScalpTrackTicket, n + 1);
                ArrayResize(g_ScalpTrackPeak, n + 1);
                ArrayResize(g_ScalpTrackLoggedPeak, n + 1);
                g_ScalpTrackTicket[n] = ticket;
                g_ScalpTrackPeak[n] = peak;
                g_ScalpTrackLoggedPeak[n] = peak;
            }
        }
        else if(kind == SOP_TREND)
        {
            int n = ArraySize(g_TrTicket);
            ArrayResize(g_TrTicket, n + 1); ArrayResize(g_TrReduced, n + 1); ArrayResize(g_TrPeakPoints, n + 1);
            double volume = PositionGetDouble(POSITION_VOLUME);
            bool ambiguous = (volume > Inp_TrendLots + Inp_LotsTolerance);
            g_TrTicket[n] = ticket;
            g_TrReduced[n] = ambiguous || volume < Inp_TrendLots - Inp_LotsTolerance;
            g_TrPeakPoints[n] = peak;
        }
        PrintFormat("[Recovery] Ticket=%I64u 已按当前可验证状态保守接管，历史峰值不作推断", ticket);
    }
    SaveArrays();
    return true;
}

int CurrentSymbolPositionCount()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        count++;
    }
    return count;
}

int UnverifiablePriorTicketCount()
{
    int count = 0;
    for(int i = 0; i < ArraySize(g_TicketState); i++)
    {
        if(g_TicketState[i].closed_utc != 0) continue;
        if(!PositionSelectByTicket(g_TicketState[i].ticket)) count++;
    }
    return count;
}

bool AttemptStartupRecovery()
{
    if(!g_InstanceOwnsState) return false;
    g_LastRecoveryAttempt = TimeGMT();
    g_RecoveryStartedUtc = g_LastRecoveryAttempt;
    g_RecoveryCompletedUtc = 0;
    g_RecoveryStatus = RECOVERY_CHECKING;
    g_RecoveryReason = Lang("正在核对成交历史与状态检查点", "Checking deal history and state checkpoints");
    PVSet("RecoveryStartedUtc", (double)g_RecoveryStartedUtc);
    PVSet("RecoveryCompletedUtc", 0.0);
    PVSet("RecoveryResult", (double)RECOVERY_CHECKING);
    GlobalVariablesFlush();

    datetime currentPeriod = TodayStart();
    datetime savedPeriod = PVHas("StatDay") ? (datetime)(long)PVGet("StatDay") : 0;
    int persistedServerOffset = PVHas("PeriodServerOffset") ? (int)PVGet("PeriodServerOffset") : ServerGmtOffset();
    if(PVHas("ReportedPeriod")) g_LastReportedPeriod = (datetime)(long)PVGet("ReportedPeriod");
    bool priorNeedsAck = PVHas("RecoveryNeedsAck") && PVGet("RecoveryNeedsAck") > 0.5;
    bool scheduleChanged = savedPeriod > 0 &&
                           ((savedPeriod > currentPeriod && savedPeriod - currentPeriod <= 86400) ||
                            (currentPeriod >= savedPeriod && (currentPeriod - savedPeriod) % 86400 != 0));
    bool loadedCurrent = (!scheduleChanged && savedPeriod == currentPeriod && LoadState());
    // LoadState 会读取上一次审计时间；本轮恢复必须重新写入自己的起止时间。
    g_RecoveryStartedUtc = g_LastRecoveryAttempt;
    g_RecoveryCompletedUtc = 0;

    int serverOffset = ServerGmtOffset();
    g_TimeBoundaryUncertain = savedPeriod > 0 && savedPeriod < currentPeriod && persistedServerOffset != serverOffset;
    if(g_TimeBoundaryUncertain)
        PrintFormat("[Recovery] 离线期间服务器UTC偏移由 %d 变为 %d 小时，历史日界按保守模式处理",
                    persistedServerOffset / 3600, serverOffset / 3600);
    if(currentPeriod <= 0 || MathAbs(serverOffset) > 14 * 3600 || savedPeriod > currentPeriod + 86400)
    {
        g_RecoveryStatus = RECOVERY_FAILED;
        g_RecoveryReason = Lang("时间基准或重置参数发生异常，已禁止开仓", "Invalid time basis or reset configuration; entries disabled");
        g_RecoveryCompletedUtc = TimeGMT();
        PVSet("RecoveryCompletedUtc", (double)g_RecoveryCompletedUtc);
        PVSet("RecoveryResult", (double)g_RecoveryStatus);
        GlobalVariablesFlush();
        return false;
    }

    if(scheduleChanged)
    {
        Print("[Recovery] 检测到每日重置时间配置变化；旧周期不自动补报，当前周期按成交历史重建并要求用户确认");
        savedPeriod = 0;
    }

    if(!ReplayMissedPeriods(savedPeriod, currentPeriod))
    {
        g_RecoveryStatus = RECOVERY_FAILED;
        g_RecoveryReason = Lang("历史报告补做失败，已禁止开仓", "Missed-period recovery failed; entries disabled");
        g_RecoveryCompletedUtc = TimeGMT();
        PVSet("RecoveryCompletedUtc", (double)g_RecoveryCompletedUtc);
        PVSet("RecoveryResult", (double)g_RecoveryStatus);
        GlobalVariablesFlush();
        return false;
    }

    g_DayStart = currentPeriod;
    if(!loadedCurrent)
    {
        g_ResetTime = currentPeriod;
        g_HighInit = false; g_ScalpHiInit = false; g_TrendHiInit = false; g_GlobalHiInit = false;
        g_MoatLiquidated = false; g_MoatDrawHit = false; g_DailyLiquidationActive = false;
        g_ScalpBlocked = false; g_TrendBlocked = false; g_TotalBlocked = false;
        g_ScalpReason = ""; g_TrendReason = ""; g_TotalReason = "";
        g_ConsecLoss = 0; g_CooldownUntil = 0;
        g_LastDealTime = currentPeriod; g_LastDealTimeMsc = (long)currentPeriod * 1000; g_LastDealTicket = 0;
        g_LastCompletedPeriod = currentPeriod;
    }

    RecoverySnapshot snapshot;
    if(!BuildRecoverySnapshot(StatStart(), RecoveryNowServer() + 1, snapshot))
    {
        g_RecoveryStatus = RECOVERY_FAILED;
        g_RecoveryReason = Lang("成交历史尚不可用，已禁止开仓并等待重试", "Deal history unavailable; entries disabled pending retry");
        g_RecoveryCompletedUtc = TimeGMT();
        PVSet("RecoveryCompletedUtc", (double)g_RecoveryCompletedUtc);
        PVSet("RecoveryResult", (double)g_RecoveryStatus);
        GlobalVariablesFlush();
        return false;
    }

    double savedNetHigh = loadedCurrent && g_HighInit ? g_TodayHighProfit : -DBL_MAX;
    double savedScalpHigh = loadedCurrent && g_ScalpHiInit ? g_ScalpHighProfit : -DBL_MAX;
    double savedTrendHigh = loadedCurrent && g_TrendHiInit ? g_TrendHighProfit : -DBL_MAX;
    double savedGlobalHigh = loadedCurrent && g_GlobalHiInit ? g_GlobalRealHigh : -DBL_MAX;
    double savedPeakBalance = loadedCurrent ? g_PeakBalance : 0.0;

    g_ConsecLoss = snapshot.consec_loss;
    g_CooldownUntil = snapshot.cooldown_until > RecoveryNowServer() ? snapshot.cooldown_until : 0;
    g_LastDealTimeMsc = snapshot.last_deal_msc > 0 ? snapshot.last_deal_msc : (long)StatStart() * 1000;
    g_LastDealTicket = snapshot.last_deal_ticket;
    g_LastDealTime = (datetime)(g_LastDealTimeMsc / 1000);

    g_ScalpHighProfit = snapshot.scalp_high_init ? MathMax(snapshot.scalp_high, savedScalpHigh) : (savedScalpHigh > -DBL_MAX ? savedScalpHigh : 0.0);
    g_TrendHighProfit = snapshot.trend_high_init ? MathMax(snapshot.trend_high, savedTrendHigh) : (savedTrendHigh > -DBL_MAX ? savedTrendHigh : 0.0);
    g_GlobalRealHigh = snapshot.all_high_init ? MathMax(snapshot.all_high, savedGlobalHigh) : (savedGlobalHigh > -DBL_MAX ? savedGlobalHigh : 0.0);
    g_ScalpHiInit = snapshot.scalp_high_init || savedScalpHigh > -DBL_MAX;
    g_TrendHiInit = snapshot.trend_high_init || savedTrendHigh > -DBL_MAX;
    g_GlobalHiInit = snapshot.all_high_init || savedGlobalHigh > -DBL_MAX;

    double rebuiltStartBalance = 0.0, rebuiltEndBalance = 0.0, rebuiltPeakBalance = 0.0;
    if(!ReconstructAccountBalance(StatStart(), RecoveryNowServer() + 1,
                                  rebuiltStartBalance, rebuiltEndBalance, rebuiltPeakBalance))
    {
        g_RecoveryStatus = RECOVERY_FAILED;
        g_RecoveryReason = Lang("账户余额历史尚不可用，已禁止开仓并等待重试", "Account balance history unavailable; entries disabled pending retry");
        g_RecoveryCompletedUtc = TimeGMT();
        PVSet("RecoveryCompletedUtc", (double)g_RecoveryCompletedUtc);
        PVSet("RecoveryResult", (double)g_RecoveryStatus);
        GlobalVariablesFlush();
        return false;
    }
    g_InitBalance = rebuiltStartBalance;
    g_PeakBalance = MathMax(rebuiltPeakBalance, savedPeakBalance);
    double currentNet = snapshot.all_realized + AllFloatingPL();
    double knownHigh = snapshot.all_high_init ? snapshot.all_high : currentNet;
    knownHigh = MathMax(knownHigh, currentNet);
    if(savedNetHigh > -DBL_MAX) knownHigh = MathMax(knownHigh, savedNetHigh);
    g_TodayHighProfit = knownHigh;
    g_HighInit = true;

    LoadArrays();
    if(g_StatePersistenceBlocked)
    {
        g_RecoveryStatus = RECOVERY_FAILED;
        g_RecoveryReason = Lang("逐票状态文件异常，已保护原文件并禁止开仓", "Ticket-state file error; original protected and entries disabled");
        g_RecoveryCompletedUtc = TimeGMT();
        PVSet("RecoveryCompletedUtc", (double)g_RecoveryCompletedUtc);
        PVSet("RecoveryResult", (double)g_RecoveryStatus);
        GlobalVariablesFlush();
        return false;
    }
    int priorOfflineTickets = UnverifiablePriorTicketCount();
    bool adopted = AdoptMissingTicketStates();

    datetime checkpointUtc = g_LastStateCheckpointUtc;
    int gapSeconds = checkpointUtc > 0 ? (int)(TimeGMT() - checkpointUtc) : 0;
    bool uncertainGap = (CurrentSymbolPositionCount() > 0 || priorOfflineTickets > 0) &&
                        (!loadedCurrent || checkpointUtc == 0 || gapSeconds > MathMax(15, Inp_RefreshSeconds * 3));
    if(adopted || uncertainGap || priorNeedsAck || scheduleChanged || g_TimeBoundaryUncertain)
    {
        g_RecoveryStatus = RECOVERY_CONSERVATIVE;
        g_RecoveryAcknowledged = false;
        g_RecoveryReason = g_TimeBoundaryUncertain
            ? Lang("离线期间服务器时区偏移发生变化，历史日界需保守确认", "Server UTC offset changed while offline; historical boundaries require confirmation")
            : (scheduleChanged
            ? Lang("每日重置时间已变化，当前周期已重建；请确认恢复摘要", "Daily reset schedule changed; current period rebuilt, please confirm")
            : (adopted
            ? Lang("存在缺失逐票状态，已保守接管；请确认恢复摘要", "Missing ticket state adopted conservatively; review and confirm")
            : (uncertainGap
               ? Lang("离线期间存在持仓，浮盈峰值无法验证；请确认恢复摘要", "Positions existed while offline; peak profit is unverifiable; please confirm")
               : Lang("上次保守恢复尚未确认；请检查持仓后确认", "Previous conservative recovery still requires confirmation"))));
    }
    else
    {
        g_RecoveryStatus = RECOVERY_EXACT;
        g_RecoveryAcknowledged = true;
        g_RecoveryReason = Lang("恢复完成", "Recovery complete");
    }
    g_LastCompletedPeriod = currentPeriod;
    g_RecoveryCompletedUtc = TimeGMT();
    SaveState();
    SaveArrays();
    PrintFormat("[Recovery] 完成：status=%d deals=%d period=%s reason=%s",
                (int)g_RecoveryStatus, snapshot.deal_count,
                TimeToString(currentPeriod, TIME_DATE|TIME_MINUTES), g_RecoveryReason);
    return true;
}



//+------------------------------------------------------------------+
//| 发布无密钥实例清单，供独立 tradeEZSync EA 读取                    |
//+------------------------------------------------------------------+
string ManifestJsonEscape(string value)
{
    StringReplace(value, "\\", "\\\\");
    StringReplace(value, "\"", "\\\"");
    StringReplace(value, "\r", "\\r");
    StringReplace(value, "\n", "\\n");
    StringReplace(value, "\t", "\\t");
    return value;
}

string ManifestBool(bool value) { return value ? "true" : "false"; }

string InstanceManifestPath()
{
    return "TradeEZ\\instances\\" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "_" +
           (string)ChartID() + ".json";
}

bool PublishInstanceManifest()
{
    FolderCreate("TradeEZ");
    FolderCreate("TradeEZ\\instances");

    string settings = "{";
    settings += "\"basic\":{";
    settings += "\"magic\":" + (string)Inp_Magic + ",";
    settings += "\"magic_scalp\":" + (string)Inp_MagicScalp + ",";
    settings += "\"magic_trend\":" + (string)Inp_MagicTrend + ",";
    settings += "\"comment_scalp\":\"" + ManifestJsonEscape(Inp_CommentScalp) + "\",";
    settings += "\"comment_trend\":\"" + ManifestJsonEscape(Inp_CommentTrend) + "\",";
    settings += "\"slippage\":" + (string)Inp_Slippage + ",";
    settings += "\"refresh_seconds\":" + (string)Inp_RefreshSeconds + ",";
    settings += "\"ui_scale\":" + DoubleToString(Inp_UIScale, 2) + ",";
    settings += "\"use_session\":" + ManifestBool(Inp_UseSession) + ",";
    settings += "\"session_start\":" + (string)Inp_SessionStartHour + ",";
    settings += "\"session_end\":" + (string)Inp_SessionEndHour + ",";
    settings += "\"reset_hour\":" + (string)Inp_ResetHour + ",";
    settings += "\"reset_minute\":" + (string)Inp_ResetMinute + ",";
    settings += "\"recovery_lookback_days\":" + (string)Inp_RecoveryLookbackDays + ",";
    settings += "\"recovery_retry_seconds\":" + (string)Inp_RecoveryRetrySeconds + ",";
    settings += "\"tester_server_utc_offset_hours\":" + (string)Inp_TesterServerUtcOffsetHours + ",";
    settings += "\"export_on_reset\":" + ManifestBool(Inp_ExportOnReset) + "},";
    settings += "\"risk\":{";
    settings += "\"daily_max_drawdown\":" + DoubleToString(Inp_DailyMaxDrawdown, 2) + ",";
    settings += "\"daily_profit_target\":" + DoubleToString(Inp_DailyProfitTarget, 2) + ",";
    settings += "\"scalp_drawdown_ratio\":" + DoubleToString(Inp_ScalpDrawdownRatio, 2) + ",";
    settings += "\"trend_drawdown_ratio\":" + DoubleToString(Inp_TrendDrawdownRatio, 2) + ",";
    settings += "\"weekly_profit_target\":" + DoubleToString(Inp_WeeklyProfitTarget, 2) + ",";
    settings += "\"consec_loss_limit\":" + (string)Inp_ConsecLossLimit + ",";
    settings += "\"cooldown_minutes\":" + (string)Inp_CooldownMinutes + ",";
    settings += "\"enable_circuit_breaker\":" + ManifestBool(Inp_EnableCircuitBreaker) + ",";
    settings += "\"alert_on_breaker\":" + ManifestBool(Inp_AlertOnBreaker) + ",";
    settings += "\"close_on_daily_drawdown\":" + ManifestBool(Inp_CloseOnDailyDrawdown) + ",";
    settings += "\"risk_buffer_percent\":" + DoubleToString(Inp_RiskBufferPercent, 2) + ",";
    settings += "\"max_entry_spread_points\":" + (string)Inp_MaxEntrySpreadPoints + ",";
    settings += "\"max_quote_age_seconds\":" + (string)Inp_MaxQuoteAgeSeconds + ",";
    settings += "\"min_projected_margin_level\":" + DoubleToString(Inp_MinProjectedMarginLevel, 2) + "},";
    settings += "\"scalp\":{";
    settings += "\"lots\":" + DoubleToString(Inp_ScalpLots, 2) + ",";
    settings += "\"max_positions\":" + (string)Inp_ScalpMaxPositions + ",";
    settings += "\"sl_points\":" + (string)Inp_ScalpSL_Points + ",";
    settings += "\"tp_points\":" + (string)Inp_ScalpTP_Points + ",";
    settings += "\"be_trigger\":" + (string)Inp_ScalpBETrigger + ",";
    settings += "\"trail_step\":" + (string)Inp_ScalpTrailStep + ",";
    settings += "\"time_limit_on\":" + ManifestBool(Inp_ScalpTimeLimitOn) + ",";
    settings += "\"max_hold_secs\":" + (string)Inp_ScalpMaxHoldSecs + "},";
    settings += "\"trend\":{";
    settings += "\"lots\":" + DoubleToString(Inp_TrendLots, 2) + ",";
    settings += "\"max_positions\":" + (string)Inp_TrendMaxPositions + ",";
    settings += "\"sl_points\":" + (string)Inp_TrendSL_Points + ",";
    settings += "\"be1_trigger\":" + (string)Inp_TrendBE1_Trigger + ",";
    settings += "\"be2_trigger\":" + (string)Inp_TrendBE2_Trigger + ",";
    settings += "\"be2_lock\":" + (string)Inp_TrendBE2_Lock + ",";
    settings += "\"be3_trigger\":" + (string)Inp_TrendBE3_Trigger + ",";
    settings += "\"be3_lock\":" + (string)Inp_TrendBE3_Lock + ",";
    settings += "\"reduce_percent\":" + DoubleToString(Inp_TrendReducePercent, 2) + ",";
    settings += "\"trail_trigger\":" + (string)Inp_TrendTrailTrigger + ",";
    settings += "\"trail_step\":" + (string)Inp_TrendTrailStep + "},";
    settings += "\"moat\":{";
    settings += "\"enable\":" + ManifestBool(Inp_EnableProfitProtect) + ",";
    settings += "\"p1_trigger\":" + DoubleToString(Inp_ProfitProtect1_Trigger, 2) + ",";
    settings += "\"p1_percent\":" + DoubleToString(Inp_ProfitProtect1_Percent, 2) + ",";
    settings += "\"p2_trigger\":" + DoubleToString(Inp_ProfitProtect2_Trigger, 2) + ",";
    settings += "\"p2_amount\":" + DoubleToString(Inp_ProfitProtect2_Amount, 2) + ",";
    settings += "\"liquidation\":" + DoubleToString(Inp_ProfitLiquidation, 2) + ",";
    settings += "\"shutdown\":" + DoubleToString(Inp_ProfitShutdown, 2) + "}}";

    string utcNow = IntegerToString((long)TimeGMT());
    string body = "{";
    body += "\"schema_version\":1,";
    body += "\"instance_id\":\"" + ManifestJsonEscape(NormalizeNamespacePart(Inp_InstanceId)) + "\",";
    body += "\"account_login\":" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + ",";
    body += "\"server\":\"" + ManifestJsonEscape(AccountInfoString(ACCOUNT_SERVER)) + "\",";
    body += "\"symbol\":\"" + ManifestJsonEscape(_Symbol) + "\",";
    body += "\"ea_version\":\"1.03\",";
    body += "\"updated_utc\":" + utcNow + ",";
    body += "\"settings\":" + settings + "}";

    string finalPath = InstanceManifestPath();
    string tempPath = finalPath + ".tmp";
    int handle = FileOpen(tempPath, FILE_WRITE | FILE_TXT | FILE_ANSI, 0, CP_UTF8);
    if(handle == INVALID_HANDLE)
    {
        PrintFormat("[Instance Manifest] 写入失败，错误=%d", GetLastError());
        return false;
    }
    FileWriteString(handle, body);
    FileFlush(handle);
    FileClose(handle);
    if(!FileMove(tempPath, 0, finalPath, FILE_REWRITE))
    {
        PrintFormat("[Instance Manifest] 原子替换失败，错误=%d", GetLastError());
        FileDelete(tempPath);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| 入口函数                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    if(Inp_ResetHour < 0 || Inp_ResetHour > 23 || Inp_ResetMinute < 0 || Inp_ResetMinute > 59 ||
       Inp_RecoveryLookbackDays < 1 || Inp_RecoveryRetrySeconds < 5 ||
       Inp_ScalpSL_Points <= 0 || Inp_TrendSL_Points <= 0 || Inp_ScalpTP_Points < 0 ||
       Inp_ScalpBETrigger <= 0 || Inp_ScalpTrailStep <= 0 ||
       Inp_RiskBufferPercent < 0.0 || Inp_MaxEntrySpreadPoints < 0 ||
       Inp_MaxQuoteAgeSeconds < 1 || Inp_MinProjectedMarginLevel <= 0.0 ||
       Inp_TesterServerUtcOffsetHours < -12 || Inp_TesterServerUtcOffsetHours > 14 ||
       Inp_WeeklyProfitTarget < 0.0 || Inp_WeeklyPlan1_Level < 0.0 ||
       Inp_WeeklyPlan2_Level < Inp_WeeklyPlan1_Level || Inp_WeeklyPlan3_Level < Inp_WeeklyPlan2_Level ||
       Inp_WeeklyPlan1_DD < 0.0 || Inp_WeeklyPlan2_DD < 0.0 ||
       (Inp_ScalpTimeLimitOn && Inp_ScalpMaxHoldSecs <= 0))
    {
        Print("[Init] 参数无效：重置/恢复参数越界，或策略保护、追踪、超时参数不符合要求");
        return INIT_PARAMETERS_INCORRECT;
    }
    g_Language_ZH = Inp_DefaultChinese;
    g_DayStart    = TodayStart();
    PrintFormat("[Clock] server=%s tick=%s gmt=%s offset=%d bj=%s period=%s reset=%02d:%02d remain=%d",
                TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS),
                TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                TimeToString(TimeGMT(), TIME_DATE|TIME_SECONDS), ServerGmtOffset(),
                TimeToString(BeijingNow(), TIME_DATE|TIME_SECONDS),
                TimeToString(ToBeijing(g_DayStart), TIME_DATE|TIME_SECONDS),
                Inp_ResetHour, Inp_ResetMinute, SecondsUntilNextResetBeijing());
    g_AccountModeSupported = ((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
    g_InstanceOwnsState = AcquireInstanceLease();

    if(!g_InstanceOwnsState)
    {
        Print("[State V2] 检测到同账户/品种/Magic 的活动实例，本实例进入只读模式: ", ManagementScope());
        Alert(Lang("检测到另一套相同配置的 TradeEZ-SOP 正在运行。\n本图表已进入只读模式，不会开仓、平仓或管理持仓。",
                   "Another TradeEZ-SOP instance with the same account/symbol/magic is active.\nThis chart is read-only and will not trade or manage positions."));
        g_RecoveryStatus = RECOVERY_FAILED;
        g_RecoveryReason = Lang("重复实例只读", "Duplicate instance: read only");
    }

    if(g_InstanceOwnsState)
    {
        LoadTradeLedger();
        AttemptStartupRecovery();
        ReconcileTradeOperations();
    }

    if(MathAbs(Inp_ScalpDrawdownRatio + Inp_TrendDrawdownRatio - 100.0) > 0.01)
        Print("提示:剥头皮+趋势回撤占比之和不等于100%,请确认参数。");

    g_trade.SetExpertMagicNumber(Inp_Magic);
    g_trade.SetDeviationInPoints((ulong)Inp_Slippage);
    g_trade.SetTypeFillingBySymbol(_Symbol);

    if(!g_AccountModeSupported)
    {
        g_ProtectionBlocksNewRisk = true;
        g_ProtectionReason = Lang("仅支持对冲账户", "Hedging account required");
        Alert(Lang("当前版本仅支持对冲账户。本图表将保留查看和平仓能力，但禁止新增交易。",
                   "This version supports hedging accounts only. Viewing and closing remain available; new entries are disabled."));
    }

    if(g_InstanceOwnsState) AuditServerProtection();

    ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

    if(g_InstanceOwnsState && g_RecoveryStatus != RECOVERY_FAILED) CheckAllRiskControl();
    RenderPerfectUI();
    if(g_InstanceOwnsState) PublishInstanceManifest();

    // 交易保护与退出重试固定由 1 秒安全时钟驱动；面板仍按 Inp_RefreshSeconds 节流刷新。
    EventSetTimer(1);

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    EventKillTimer();
    if(g_InstanceOwnsState)
    {
        if(g_RecoveryStatus != RECOVERY_CHECKING && g_RecoveryStatus != RECOVERY_FAILED)
        {
            SaveArrays();
            SaveState();
        }
        if(g_TradeLedgerDirty) SaveTradeLedger();
        ReleaseInstanceLease();
    }
    ObjectsDeleteAll(0, Prefix);
    ChartRedraw();
}

void OnTick()
{
    if(!g_InstanceOwnsState || g_RecoveryStatus == RECOVERY_CHECKING || g_RecoveryStatus == RECOVERY_FAILED)
    {
        UpdateQuoteBar();
        return;
    }
    CheckAllRiskControl();
    if(g_RecoveryStatus == RECOVERY_FAILED)
    {
        UpdateQuoteBar();
        return;
    }
    ManageAllTrailingStops();

    // 每tick更新报价条(不重建整个面板,避免打字被打断)
    UpdateQuoteBar(); // 紧凑面板也需要实时报价
}

void OnTimer()
{
    static int manifestSeconds = 0;
    static int uiSeconds = 0;
    RenewInstanceLease();
    if(g_InstanceOwnsState && g_RecoveryStatus == RECOVERY_FAILED && !g_StatePersistenceBlocked &&
       (g_LastRecoveryAttempt == 0 || TimeGMT() - g_LastRecoveryAttempt >= MathMax(5, Inp_RecoveryRetrySeconds)))
        AttemptStartupRecovery();
    if(g_InstanceOwnsState)
    {
        ReconcileTradeOperations();
        if(g_TradeLedgerDirty) SaveTradeLedger();
        AuditServerProtection();
        ProcessPendingScalpExits();
        if(g_RecoveryStatus != RECOVERY_CHECKING && g_RecoveryStatus != RECOVERY_FAILED)
        {
            CheckAllRiskControl();
            if(g_RecoveryStatus != RECOVERY_FAILED)
            {
                g_StateCheckpointSeconds++;
                if(g_StateCheckpointSeconds >= 30)
                {
                    g_StateCheckpointSeconds = 0;
                    SaveArrays();
                }
            }
        }
    }
    uiSeconds++;
    if(uiSeconds >= MathMax(1, Inp_RefreshSeconds))
    {
        uiSeconds = 0;
        RenderPerfectUI();
    }
    manifestSeconds++;
    if(g_InstanceOwnsState && manifestSeconds >= 60)
    {
        manifestSeconds = 0;
        PublishInstanceManifest();
    }
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
    if(g_InstanceOwnsState)
        HandleTradeRequestTransaction(trans, request, result);
    if(g_InstanceOwnsState && g_RecoveryStatus != RECOVERY_CHECKING && g_RecoveryStatus != RECOVERY_FAILED &&
       (trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_POSITION))
        g_ArraysDirty = true; // 回调只记脏标志；核销、持久化、风控和UI统一由1秒安全时钟处理。
}

//+------------------------------------------------------------------+
//| 图表事件:按钮点击                                                |
//+------------------------------------------------------------------+
// 在实际控件矩形内显示手型；文字命中范围按其锚点换算。
void UpdateHoverCursor(int mouseX, int mouseY)
{
    if(!MQLInfoInteger(MQL_DLLS_ALLOWED))
    {
        static bool notified = false;
        if(!notified)
        {
            Print("[UI Cursor] 手型鼠标需要在 EA 属性中启用允许 DLL 导入。");
            notified = true;
        }
        return;
    }
    bool hand = false;
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string obj = ObjectName(0, i);
        if(StringFind(obj, Prefix) != 0) continue;
        string name = StringSubstr(obj, StringLen(Prefix));
        ENUM_OBJECT type = (ENUM_OBJECT)ObjectGetInteger(0, obj, OBJPROP_TYPE);
        bool clickable = (type == OBJ_BUTTON) || name == "Title" || name == "Version" ||
                         name == "C1_Real_Left" || name == "C1_Real_Right" ||
                         name == "Sc_Orders_Left" || name == "Sc_Orders_Right" ||
                         name == "Tr_Orders_Left" || name == "Tr_Orders_Right";
        if(!clickable || (color)ObjectGetInteger(0, obj, OBJPROP_COLOR) == COLOR_BTN_DISABLED_TXT) continue;
        int x = (int)ObjectGetInteger(0, obj, OBJPROP_XDISTANCE);
        int y = (int)ObjectGetInteger(0, obj, OBJPROP_YDISTANCE);
        int w = (int)ObjectGetInteger(0, obj, OBJPROP_XSIZE);
        int h = (int)ObjectGetInteger(0, obj, OBJPROP_YSIZE);
        if(type == OBJ_LABEL)
        {
            int anchor = (int)ObjectGetInteger(0, obj, OBJPROP_ANCHOR);
            if(anchor == ANCHOR_RIGHT || anchor == ANCHOR_RIGHT_UPPER || anchor == ANCHOR_RIGHT_LOWER) x -= w;
            else if(anchor == ANCHOR_CENTER || anchor == ANCHOR_UPPER || anchor == ANCHOR_LOWER) x -= w / 2;
            if(anchor == ANCHOR_LEFT_LOWER || anchor == ANCHOR_LOWER || anchor == ANCHOR_RIGHT_LOWER) y -= h;
            else if(anchor == ANCHOR_LEFT || anchor == ANCHOR_CENTER || anchor == ANCHOR_RIGHT) y -= h / 2;
        }
        if(mouseX >= x && mouseX < x + w && mouseY >= y && mouseY < y + h)
        {
            hand = true;
            break;
        }
    }
    static long handCursor = 0, arrowCursor = 0;
    if(handCursor == 0) handCursor = LoadCursorW(0, 32649); // IDC_HAND
    if(arrowCursor == 0) arrowCursor = LoadCursorW(0, 32512); // IDC_ARROW
    long cursor = hand ? handCursor : arrowCursor;
    if(cursor == 0) return;
    // EA 工作线程与图表 UI 线程不同，临时共享输入状态后设置窗口鼠标。
    // 立即解除连接，不将交易事件线程长期绑定到 UI 线程。
    uint processId = 0;
    uint uiThread = GetWindowThreadProcessId(ChartGetInteger(0, CHART_WINDOW_HANDLE), processId);
    uint eaThread = GetCurrentThreadId();
    if(uiThread == 0) return;
    if(uiThread == eaThread) { SetCursor(cursor); return; }
    if(AttachThreadInput(eaThread, uiThread, 1) != 0)
    {
        SetCursor(cursor);
        AttachThreadInput(eaThread, uiThread, 0);
    }
    else
    {
        static bool attachReported = false;
        if(!attachReported)
        {
            Print("[UI Cursor] 无法连接图表输入线程，手型切换未生效。");
            attachReported = true;
        }
    }
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_MOUSE_MOVE)
    {
        // MT5 的窗口光标处理会覆盖 EA 线程的 SetCursor，造成手型/箭头交替闪烁。
        // 停用该路径，等待窗口级光标处理实现后再启用手型。
        return;
    }

    // 点击价格输入框后进入编辑保护状态。在收到 ENDEDIT 前不重建整套UI。
    if(id == CHARTEVENT_OBJECT_CLICK &&
       (sparam == Prefix + "Edt_Sc_Price" || sparam == Prefix + "Edt_Tr_Price"))
    {
        g_PriceEditActive = true;
        return;
    }

    // 输入框编辑结束(回车/失焦):把值实时存入全局
    if(id == CHARTEVENT_OBJECT_ENDEDIT)
    {
        bool priceEditEnded = false;
        if(sparam == Prefix + "Edt_Sc_Price")
        {
            g_ScPriceTxt = ObjectGetString(0, Prefix + "Edt_Sc_Price", OBJPROP_TEXT);
            PrintFormat("[输入框提交] 剥头皮挂单价=\"%s\"", g_ScPriceTxt);
            priceEditEnded = true;
        }
        else if(sparam == Prefix + "Edt_Tr_Price")
        {
            g_TrPriceTxt = ObjectGetString(0, Prefix + "Edt_Tr_Price", OBJPROP_TEXT);
            PrintFormat("[输入框提交] 趋势挂单价=\"%s\"", g_TrPriceTxt);
            priceEditEnded = true;
        }

        if(priceEditEnded)
        {
            g_PriceEditActive = false;
            RenderPerfectUI(); // 失焦后按正确创建顺序重建,输入框不会再被卡片背景覆盖
        }
        return;
    }

    if(id != CHARTEVENT_OBJECT_CLICK) return;

    // 语言切换
    if(sparam == Prefix + "Btn_Lang_Toggle")
    {
        g_Language_ZH = !g_Language_ZH;
        RenderPerfectUI();
        return;
    }

    // 折叠/展开
    if(sparam == Prefix + "Btn_Fold")
    {
        // 仅在切换布局时重建对象，确保背景不会覆盖复用的旧按钮。
        ObjectsDeleteAll(0, Prefix);
        g_Collapsed = !g_Collapsed;
        if(g_Collapsed) g_ShowDetails = false;
        RenderPerfectUI();
        return;
    }

    // 日统计舱开/关
    if(sparam == Prefix + "Btn_Stat_Open")  { g_ShowStats = !g_ShowStats; ResetBtn(sparam); RenderPerfectUI(); return; }
    if(sparam == Prefix + "Btn_Stat_Close") { g_ShowStats = false; ResetBtn(sparam); RenderPerfectUI(); return; }

    // 更新日志舱开/关（点击标题或版本号）
    if(sparam == Prefix + "Version" || sparam == Prefix + "Title" || sparam == Prefix + "BrandLogo")
    {
        g_ShowChangelog = !g_ShowChangelog;
        RenderPerfectUI();
        return;
    }
    if(sparam == Prefix + "CL_Website")
    {
        ResetBtn(sparam);
        if(!MQLInfoInteger(MQL_DLLS_ALLOWED))
        {
            Alert(Lang("打开官网需要在 EA 属性中勾选允许 DLL 导入。官网：https://www.tradeez.cn",
                       "Enable Allow DLL imports in EA properties to open https://www.tradeez.cn"));
            return;
        }
        long result = ShellExecuteW(0, "open", "https://www.tradeez.cn", "", "", 1);
        if(result <= 32)
            Alert(Lang("无法打开默认浏览器，请手动访问 https://www.tradeez.cn，错误码：",
                       "Unable to open browser. Visit https://www.tradeez.cn manually. Error: ") + (string)result);
        return;
    }
    if(sparam == Prefix + "Btn_CL_Close") { g_ShowChangelog = false; ResetBtn(sparam); RenderPerfectUI(); return; }
    if(StringFind(sparam, Prefix + "Btn_CL_Select_") == 0)
    {
        int selected = (int)StringToInteger(StringSubstr(sparam, StringLen(Prefix + "Btn_CL_Select_")));
        ReleaseNote notes[];
        LoadReleaseNotes(notes);
        if(selected >= 0 && selected < MathMin(ArraySize(notes), RELEASE_HISTORY_LIMIT))
            g_ReleaseSelected = selected;
        ResetBtn(sparam);
        RenderPerfectUI();
        return;
    }


    // 明细舱:点击"今日实现盈亏"→ 展示今日全部平仓单(含手动)
    if(sparam == Prefix + "C1_Real_Left" || sparam == Prefix + "C1_Real_Right")
    {
        if(g_ShowDetails && g_DetailAll) g_ShowDetails = false;
        else { g_ShowDetails = true; g_DetailAll = true; }
        RenderPerfectUI();
        return;
    }
    // 明细舱:点击胜负平统计(左/右标签)
    if(sparam == Prefix + "Sc_Orders_Left" || sparam == Prefix + "Sc_Orders_Right")
    {
        if(g_ShowDetails && !g_DetailAll && g_DetailSide == SOP_SCALP) g_ShowDetails = false;
        else { g_ShowDetails = true; g_DetailAll = false; g_DetailSide = SOP_SCALP; }
        RenderPerfectUI();
        return;
    }
    if(sparam == Prefix + "Tr_Orders_Left" || sparam == Prefix + "Tr_Orders_Right")
    {
        if(g_ShowDetails && !g_DetailAll && g_DetailSide == SOP_TREND) g_ShowDetails = false;
        else { g_ShowDetails = true; g_DetailAll = false; g_DetailSide = SOP_TREND; }
        RenderPerfectUI();
        return;
    }
    if(sparam == Prefix + "Btn_Cab_Close")
    {
        g_ShowDetails = false;
        RenderPerfectUI();
        return;
    }

    if(sparam == Prefix + "Btn_Recovery_Ack")
    {
        ResetBtn(sparam);
        string message = Lang("系统已根据成交历史和当前持仓完成保守恢复。\n\n无法精确还原终端关闭期间的浮盈最高点；缺失逐票状态已按防止重复减仓、避免启动瞬间强平的原则接管。\n\n确认后将恢复开仓功能。请先检查当前持仓、止损和止盈是否符合预期。",
                              "The system completed a conservative recovery from deal history and current positions.\n\nPeak floating profit while the terminal was offline cannot be reconstructed exactly. Missing ticket state was adopted to avoid duplicate reductions or an immediate timeout close.\n\nConfirm to re-enable entries after checking current positions, stops and targets.");
        if(MessageBox(message, Lang("确认恢复结果", "Confirm recovery result"), MB_OKCANCEL | MB_ICONWARNING) == IDOK)
        {
            g_RecoveryAcknowledged = true;
            g_RecoveryReason = Lang("用户已确认保守恢复结果", "Conservative recovery acknowledged");
            SaveState();
        }
        RenderPerfectUI();
        return;
    }

    // 同账户/品种/Magic 的第二实例只允许查看，禁止一切交易与状态变更。
    if(!g_InstanceOwnsState)
    {
        ResetBtn(sparam);
        Alert(Lang("当前图表处于只读模式。请先关闭另一套相同账户、品种和 Magic 配置的 TradeEZ-SOP，再进行交易操作。",
                   "This chart is read-only. Close the other TradeEZ-SOP instance with the same account, symbol and magic settings before trading."));
        RenderPerfectUI();
        return;
    }

    // 市价单(先复位按钮状态,去抖防重复)
    if(sparam == Prefix + "Btn_Sc_Buy")  { ResetBtn(sparam); if(OrderDebounceOK()) { OpenMarket(SOP_SCALP, true);  RenderPerfectUI(); } return; }
    if(sparam == Prefix + "Btn_Sc_Sell") { ResetBtn(sparam); if(OrderDebounceOK()) { OpenMarket(SOP_SCALP, false); RenderPerfectUI(); } return; }
    if(sparam == Prefix + "Btn_Tr_Buy")  { ResetBtn(sparam); if(OrderDebounceOK()) { OpenMarket(SOP_TREND, true);  RenderPerfectUI(); } return; }
    if(sparam == Prefix + "Btn_Tr_Sell") { ResetBtn(sparam); if(OrderDebounceOK()) { OpenMarket(SOP_TREND, false); RenderPerfectUI(); } return; }

    // 极速单在全部商业化重构项目完成后单独开发；当前仅保留布局入口。
    if(sparam == Prefix + "Btn_Sc_SpeedPlan")
    {
        ResetBtn(sparam);
        Alert(Lang("极速单功能正在规划中，当前版本暂未开放。",
                   "SPEED mode is planned and is not available in this version."));
        return;
    }

    // 追踪持有：明确授权撤除固定TP，继续使用剥头皮峰值追踪。
    if(sparam == Prefix + "Btn_Sc_LetRun")
    {
        ResetBtn(sparam);
        if(g_InstanceOwnsState && HasEligibleScalpLetRun()) EnableScalpLetRun();
        RenderPerfectUI();
        return;
    }

    // 取消某剥头皮单的超时平仓倒计时(按钮名带 ticket)
    if(StringFind(sparam, Prefix + "Btn_SCDCancel_") == 0)
    {
        string tkStr = StringSubstr(sparam, StringLen(Prefix + "Btn_SCDCancel_"));
        ulong tk = (ulong)StringToInteger(tkStr);
        if(tk > 0) AddTimeoutCancelled(tk);
        ResetBtn(sparam);
        RenderPerfectUI();
        return;
    }

    // 限价单(优先读控件实时值,读不到则用已提交缓存)
    if(sparam == Prefix + "Btn_Sc_LBuy")  { ResetBtn(sparam); if(OrderDebounceOK()) OpenLimit(SOP_SCALP, true,  ReadEditPrice("Edt_Sc_Price", g_ScPriceTxt)); return; }
    if(sparam == Prefix + "Btn_Sc_LSell") { ResetBtn(sparam); if(OrderDebounceOK()) OpenLimit(SOP_SCALP, false, ReadEditPrice("Edt_Sc_Price", g_ScPriceTxt)); return; }
    if(sparam == Prefix + "Btn_Tr_LBuy")  { ResetBtn(sparam); if(OrderDebounceOK()) OpenLimit(SOP_TREND, true,  ReadEditPrice("Edt_Tr_Price", g_TrPriceTxt)); return; }
    if(sparam == Prefix + "Btn_Tr_LSell") { ResetBtn(sparam); if(OrderDebounceOK()) OpenLimit(SOP_TREND, false, ReadEditPrice("Edt_Tr_Price", g_TrPriceTxt)); return; }

    // 现价偏移快捷挂单:+N空(现价+N挂空) / -N多(现价-N挂多)—— 剥头皮
    if(sparam == Prefix + "Btn_Sc_S2") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_SCALP, false, 2.0); return; }
    if(sparam == Prefix + "Btn_Sc_S3") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_SCALP, false, 3.0); return; }
    if(sparam == Prefix + "Btn_Sc_S5") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_SCALP, false, 5.0); return; }
    if(sparam == Prefix + "Btn_Sc_B2") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_SCALP, true,  2.0); return; }
    if(sparam == Prefix + "Btn_Sc_B3") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_SCALP, true,  3.0); return; }
    if(sparam == Prefix + "Btn_Sc_B5") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_SCALP, true,  5.0); return; }
    // 现价偏移快捷挂单 —— 趋势
    if(sparam == Prefix + "Btn_Tr_S2") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_TREND, false, 2.0); return; }
    if(sparam == Prefix + "Btn_Tr_S3") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_TREND, false, 3.0); return; }
    if(sparam == Prefix + "Btn_Tr_S5") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_TREND, false, 5.0); return; }
    if(sparam == Prefix + "Btn_Tr_B2") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_TREND, true,  2.0); return; }
    if(sparam == Prefix + "Btn_Tr_B3") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_TREND, true,  3.0); return; }
    if(sparam == Prefix + "Btn_Tr_B5") { ResetBtn(sparam); if(OrderDebounceOK()) OpenOffsetLimit(SOP_TREND, true,  5.0); return; }

    // 平仓功能:全平 / 平剥头皮 / 平趋势 / 平盈利单
    if(sparam == Prefix + "Btn_Close_All")
    {
        CloseAllOrders(); ResetBtn(sparam); RenderPerfectUI();
        Print("[Trade Ledger] 一键全平已纳入闭环，最终结果以服务器事实为准");
        return;
    }
    if(sparam == Prefix + "Btn_Close_Scalp")
    {
        CloseByKind(SOP_SCALP); ResetBtn(sparam); RenderPerfectUI();
        Print("[Trade Ledger] 剥头皮平仓已提交，等待服务器确认");
        return;
    }
    if(sparam == Prefix + "Btn_Close_Trend")
    {
        CloseByKind(SOP_TREND); ResetBtn(sparam); RenderPerfectUI();
        Print("[Trade Ledger] 趋势平仓已提交，等待服务器确认");
        return;
    }
    if(sparam == Prefix + "Btn_Close_Profit")
    {
        CloseProfitable(); ResetBtn(sparam); RenderPerfectUI();
        Print("[Trade Ledger] 盈利单平仓已提交，等待服务器确认");
        return;
    }

    // 重置统计基线
    if(sparam == Prefix + "Btn_Reset_All")
    {
        ResetBtn(sparam);
        if(g_RecoveryStatus == RECOVERY_CHECKING || g_RecoveryStatus == RECOVERY_FAILED ||
           (g_RecoveryStatus == RECOVERY_CONSERVATIVE && !g_RecoveryAcknowledged))
        {
            Alert(Lang("当前恢复尚未成功。为避免用不完整历史覆盖风控状态，暂时不能重置；平仓操作仍可使用。",
                       "Recovery has not completed. Reset is disabled to avoid overwriting risk state with incomplete history; closing remains available."));
            RenderPerfectUI();
            return;
        }
        string confirmation = Lang(
            "您想从现在开始，重新记录本轮交易表现吗？\n\n"
            "重置后，将以当前账户余额作为新的统计基准，重新累计本轮盈亏与盈利高点，并清除连亏计数、冷却时间及风控锁定。\n\n"
            "请放心，这不会平仓、撤单、修改已有止损止盈，也不会删除账户交易记录。已有持仓的浮动盈亏仍会参与风控，必要时可能再次触发限制。\n\n"
            "温馨提示：确认窗口停留期间，本 EA 的动态风控会暂停处理，请及时选择；如有持仓，建议先取消，待合适时再操作。\n\n"
            "确认开始新的统计吗？选择“否”将保持现状。",
            "Would you like to start a fresh tracking period now?\n\n"
            "This uses the current balance as the new baseline, restarts tracked P/L and peaks, and clears the loss streak, cooldown and risk locks.\n\n"
            "No positions or pending orders will be closed, SL/TP will stay unchanged, and account trade history will be preserved. Existing floating P/L still counts toward risk limits and may trigger them again.\n\n"
            "Please respond promptly: this dialog pauses this EA's dynamic risk handling. With open positions, consider cancelling and returning later.\n\n"
            "Start fresh? Choose No to leave everything unchanged.");
        if(MessageBox(confirmation, Lang("重新开始统计", "Start a fresh tracking period"),
                      MB_YESNO | MB_ICONQUESTION | MB_DEFBUTTON2) != IDYES)
            return;
        g_ResetTime       = TimeCurrent();
        g_TodayHighProfit = 0.0;
        g_HighInit        = false;
        g_ScalpHighProfit = 0.0;
        g_TrendHighProfit = 0.0;
        g_ScalpHiInit     = false;
        g_TrendHiInit     = false;
        g_GlobalRealHigh  = 0.0;
        g_GlobalHiInit    = false;
        g_InitBalance     = AccountInfoDouble(ACCOUNT_BALANCE);
        g_PeakBalance     = g_InitBalance;
        g_ScalpBlocked    = false;
        g_TrendBlocked    = false;
        g_TotalBlocked    = false;
        g_MoatLiquidated  = false;   // 手动重置基线:解除护城河清盘锁定
        g_DailyLiquidationActive = false;
        g_MoatDrawHit     = false;
        g_ScalpReason     = "";
        g_TrendReason     = "";
        g_TotalReason     = "";
        g_ConsecLoss      = 0;
        g_CooldownUntil   = 0;
        g_LastDealTime    = TimeCurrent();
        g_LastDealTimeMsc = (long)g_LastDealTime * 1000;
        g_LastDealTicket  = 0;
        g_LastCompletedPeriod = g_DayStart;
        g_RecoveryStatus = RECOVERY_EXACT;
        g_RecoveryAcknowledged = true;
        g_RecoveryReason = Lang("用户已手动重置统计", "Statistics manually reset by user");
        SaveState();      // 立即持久化重置后的状态
        Alert(Lang("【风控系统】今日统计已归零重置。", "[RISK ENGINE] Daily statistics reset."));
        ResetBtn(sparam);
        RenderPerfectUI();
        return;
    }

    if(StringFind(sparam, Prefix + "Btn_") == 0) ResetBtn(sparam);
}

void ResetBtn(string objName)
{
    ObjectSetInteger(0, objName, OBJPROP_STATE, false);
}

// 下单去抖:400ms 内的重复点击忽略(防一次点击触发两单)
bool OrderDebounceOK()
{
    ulong now = GetTickCount64();
    if(now - g_LastOrderMs < 400) return false;
    g_LastOrderMs = now;
    return true;
}
