//+------------------------------------------------------------------+
//|                                           TradeEZ_SOP_EA.mq5      |
//|                    TradeEZ-SOP 分控 EA (UI 1:1 复刻 UI-TEST)      |
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
input string   Inp_CommentScalp      = "TradeEZ-SC"; // 剥头皮订单备注
input string   Inp_CommentTrend      = "TradeEZ-TR"; // 趋势订单备注
input int      Inp_Slippage          = 30;       // 滑点(点)
input double   Inp_LotsTolerance     = 0.001;    // 手数匹配容差(备用)
input int      Inp_RefreshSeconds    = 1;        // 面板刷新间隔(秒)
input bool     Inp_DefaultChinese    = true;     // 默认中文

input group "===== 界面适配(高DPI屏幕) ====="
input double   Inp_UIScale           = 1.00;     // 全局UI缩放系数(0.7~1.5,默认1.0)

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

input group "===== 数据同步 Data Sync ====="
input bool   Inp_EnableSync        = false;                        // 启用订单同步
input string Inp_ApiBaseURL        = "https://api.tradeez.cn"; // API基础地址
input string Inp_SecretKey         = "";                           // 账户密钥(从服务器获取)
input int    Inp_SyncIntervalMin   = 5;                            // 常规同步频率(分钟)
input int    Inp_AlignIntervalHours= 6;                            // 哈希校准频率(小时)
input int    Inp_RequestTimeoutMS  = 10000;                        // HTTP请求超时(毫秒)
input int    Inp_MaxBatchSize      = 100;                          // 单批次最大订单数
input bool   Inp_DebugSync         = false;                        // 调试模式(详细日志)

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

// 全局变量 - 数据同步状态
int      g_SyncTimerCounter = 0;        // 同步定时器计数器(秒)
int      g_AlignTimerCounter = 0;       // 校准定时器计数器(秒)
datetime g_LastSyncTime = 0;            // 上次同步时间戳
datetime g_LastAlignTime = 0;           // 上次校准时间戳
bool     g_SyncInProgress = false;      // 同步进行中标志

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
    return NormalizeDouble(price, _Digits);
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
    int off = (int)(TimeCurrent() - TimeGMT());
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
    return TimeGMT() + 8 * 3600;
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
        if(HistoryDealGetInteger(dt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue; // 只统计平仓成交

        ENUM_SOP_ORDER dk = DealStrategyType(dt);        // 回溯开仓magic,兼容手工平仓
        if(kind != SOP_IGNORE && dk != kind) continue;   // 指定策略
        if(kind == SOP_IGNORE && dk == SOP_IGNORE) continue; // 全部系统单口径:排除手动单

        double profit = HistoryDealGetDouble(dt, DEAL_PROFIT)
                      + HistoryDealGetDouble(dt, DEAL_SWAP)
                      + HistoryDealGetDouble(dt, DEAL_COMMISSION);
        net += profit;
        if(profit < 0.0) { lossOut += -profit; lossCnt++; }
        else if(profit > 0.0) winCnt++;
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
        if(HistoryDealGetInteger(dt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
        net += HistoryDealGetDouble(dt, DEAL_PROFIT)
             + HistoryDealGetDouble(dt, DEAL_SWAP)
             + HistoryDealGetDouble(dt, DEAL_COMMISSION);
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

void ComputeDailyStats(ENUM_SOP_ORDER kind, DailyStats &s)
{
    s.trades=0; s.wins=0; s.losses=0; s.evens=0;
    s.grossProfit=0; s.grossLoss=0; s.net=0; s.maxWin=0; s.maxLoss=0; s.avgHoldSec=0;

    datetime statFrom = StatStart();
    datetime selFrom  = statFrom - 30 * 86400;
    if(!HistorySelect(selFrom, TimeCurrent() + 3600)) return;

    int deals = HistoryDealsTotal();
    double holdSum = 0.0; int holdCnt = 0;

    for(int i = 0; i < deals; i++)
    {
        ulong dt = HistoryDealGetTicket(i);
        if(dt == 0) continue;
        if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) continue;
        if(HistoryDealGetInteger(dt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
        datetime closeT = (datetime)HistoryDealGetInteger(dt, DEAL_TIME);
        if(closeT < statFrom) continue;

        ENUM_SOP_ORDER dk = DealStrategyType(dt);        // 回溯开仓magic,兼容手工平仓
        // SOP_IGNORE = 全部订单口径(含手动单);指定策略则只统计该策略
        if(kind != SOP_IGNORE && dk != kind) continue;

        double p = HistoryDealGetDouble(dt, DEAL_PROFIT)
                 + HistoryDealGetDouble(dt, DEAL_SWAP)
                 + HistoryDealGetDouble(dt, DEAL_COMMISSION);
        s.trades++;
        s.net += p;
        if(p > 0.01)       { s.wins++;   s.grossProfit += p;  if(p > s.maxWin)  s.maxWin = p; }
        else if(p < -0.01) { s.losses++; s.grossLoss  += -p; if(p < s.maxLoss) s.maxLoss = p; }
        else                 s.evens++;

        long posId = HistoryDealGetInteger(dt, DEAL_POSITION_ID);
        for(int j = 0; j < deals; j++)
        {
            ulong dj = HistoryDealGetTicket(j);
            if(dj == 0) continue;
            if(HistoryDealGetInteger(dj, DEAL_POSITION_ID) != posId) continue;
            if(HistoryDealGetInteger(dj, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            int secs = (int)(closeT - (datetime)HistoryDealGetInteger(dj, DEAL_TIME));
            if(secs >= 0) { holdSum += secs; holdCnt++; }
            break;
        }
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

//+------------------------------------------------------------------+
//| 趋势 per-ticket 状态管理                                          |
//+------------------------------------------------------------------+
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
    g_ArraysDirty = true;
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
            g_ArraysDirty = true;
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
    g_ScalpTrackTicket[n] = ticket;
    g_ScalpTrackPeak[n]   = 0.0;
    g_ArraysDirty = true;
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
            ArrayResize(g_ScalpTrackTicket, last);
            ArrayResize(g_ScalpTrackPeak, last);
            g_ArraysDirty = true;
        }
    }
}

//+------------------------------------------------------------------+
//| 快速移损:剥头皮持仓提升为趋势逻辑管理                             |
//+------------------------------------------------------------------+
bool IsPromoted(ulong ticket)
{
    for(int i = 0; i < ArraySize(g_PromotedTickets); i++)
        if(g_PromotedTickets[i] == ticket) return true;
    return false;
}

void AddPromoted(ulong ticket)
{
    if(IsPromoted(ticket)) return;
    int n = ArraySize(g_PromotedTickets);
    ArrayResize(g_PromotedTickets, n + 1);
    g_PromotedTickets[n] = ticket;
    g_ArraysDirty = true;
}

// 清理已平仓的提升标记
void PromotedCleanup()
{
    for(int i = ArraySize(g_PromotedTickets) - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(g_PromotedTickets[i]))
        {
            int last = ArraySize(g_PromotedTickets) - 1;
            g_PromotedTickets[i] = g_PromotedTickets[last];
            ArrayResize(g_PromotedTickets, last);
            g_ArraysDirty = true;
        }
    }
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
    g_ArraysDirty = true;
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
            g_ArraysDirty = true;
        }
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
    for(int attempt = 0; attempt < 3; attempt++)
    {
        if(g_trade.PositionModify(ticket, newSL, curTP)) return true;
    }
    return false;
}

// 修改止损并清除止盈(带重试)
bool ModifySLClearTP(ulong ticket, double newSL)
{
    if(!PositionSelectByTicket(ticket)) return false;
    newSL = NormalizePrice(newSL);
    for(int attempt = 0; attempt < 3; attempt++)
        if(g_trade.PositionModify(ticket, newSL, 0.0)) return true;
    return false;
}

//+------------------------------------------------------------------+
//| 剥头皮撤止盈:仅清除已进入峰值追踪的持仓的止盈,保留止损            |
//+------------------------------------------------------------------+
void ClearScalpTP()
{
    int found = 0, cleared = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PosType() != SOP_SCALP) continue;

        // 必须已进入峰值追踪(在 g_ScalpTrackTicket 名单中)
        int idx = ScalpTrackIndex(tk);
        if(idx < 0) continue;  // 未进入峰值追踪,跳过

        found++;

        double curSL = PositionGetDouble(POSITION_SL);
        double curTP = PositionGetDouble(POSITION_TP);
        if(curTP == 0.0) continue;  // 已无止盈,跳过

        // 清除止盈,保留止损
        if(g_trade.PositionModify(tk, curSL, 0.0))
            cleared++;
    }

    if(found == 0)
        Alert(Lang("无剥头皮持仓已进入峰值追踪", "No scalp in peak trail"));
    else if(cleared > 0)
        Alert(StringFormat(Lang("已清除 %d 单止盈", "Cleared %d TP"), cleared));
}

//+------------------------------------------------------------------+
//| 剥头皮一键改趋势单:必须盈利达趋势第一目标才允许转换              |
//+------------------------------------------------------------------+
void ConvertScalpToTrend()
{
    int found = 0, converted = 0, skipped = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PosType() != SOP_SCALP) continue;

        found++;

        // 计算实际浮盈点数
        long type   = PositionGetInteger(POSITION_TYPE);
        double open = PositionGetDouble(POSITION_PRICE_OPEN);
        double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double profitPoints = (type == POSITION_TYPE_BUY)
                            ? (bid - open) / 0.01
                            : (open - ask) / 0.01;

        // 必须达到趋势第一目标（移成本价触发点）才允许转换
        if(profitPoints < Inp_TrendBE1_Trigger)
        {
            skipped++;
            continue;
        }

        // 取消止盈(保留原止损不动)
        double curSL = PositionGetDouble(POSITION_SL);
        if(g_trade.PositionModify(tk, curSL, 0.0))
        {
            AddPromoted(tk);  // 纳入趋势逻辑管理
            converted++;
        }
    }

    if(found == 0)
        Alert(Lang("无剥头皮持仓可转换", "No scalp position to convert"));
    else if(converted == 0 && skipped > 0)
        Alert(StringFormat(Lang("无达标持仓:需盈利≥%d点", "No position: require profit ≥%d pts"), Inp_TrendBE1_Trigger));
    else if(converted > 0)
        Alert(StringFormat(Lang("已转换 %d 单为趋势单", "Converted %d positions to trend"), converted));
}

//+------------------------------------------------------------------+
//| 剥头皮移动止损:达第一目标后改用峰值回撤逻辑(保留止盈)            |
//+------------------------------------------------------------------+
void ManageScalpTrailingStop(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;
    long type   = PositionGetInteger(POSITION_TYPE);
    double open = PositionGetDouble(POSITION_PRICE_OPEN);
    double vol  = PositionGetDouble(POSITION_VOLUME);
    double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // 超时强平:持仓超过阈值秒数且未止盈/止损,强制平仓(用户可取消)
    if(Inp_ScalpTimeLimitOn && !IsTimeoutCancelled(ticket))
    {
        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
        if((int)(TimeCurrent() - openTime) >= Inp_ScalpMaxHoldSecs)
        {
            g_trade.PositionClose(ticket);
            return;
        }
    }

    // 实际浮盈点数判断(有向计算:多单=bid-open,空单=open-ask)
    double profitPoints = (type == POSITION_TYPE_BUY)
                        ? (bid - open) / 0.01
                        : (open - ask) / 0.01;

    // 【调试日志】记录每次计算的浮盈点数（仅在接近触发点时打印，避免刷屏）
    if(profitPoints >= 250.0 || profitPoints < -100.0)  // 接近300点或明显亏损时才打印
    {
        PrintFormat("[剥头皮追踪] Ticket=%I64u 方向=%s 开仓价=%.2f 当前Ask=%.5f Bid=%.5f 浮盈点数=%.1f 触发阈值=%d",
                    ticket, (type==POSITION_TYPE_BUY?"多":"空"), open, ask, bid, profitPoints, Inp_ScalpBETrigger);
    }

    // ---- 阶段1:未达第一目标,使用保本锁定逻辑 ----
    if(profitPoints < (double)Inp_ScalpBETrigger - 0.5)  // 减0.5容错,避免恰好300点不触发
        return;  // 亏损或浮盈不足不触发

    // ---- 阶段2:达到或接近第一目标,改用峰值回撤逻辑(保留止盈) ----
    int idx = ScalpTrackEnsure(ticket);

    // 【调试日志】触发峰值追踪时打印
    PrintFormat("[剥头皮峰值追踪启动] Ticket=%I64u 浮盈=%.1f点 当前峰值=%.1f点",
                ticket, profitPoints, g_ScalpTrackPeak[idx]);

    // 记录峰值
    if(profitPoints > g_ScalpTrackPeak[idx])
    {
        PrintFormat("[峰值更新] Ticket=%I64u 旧峰值=%.1f点 → 新峰值=%.1f点",
                    ticket, g_ScalpTrackPeak[idx], profitPoints);
        g_ScalpTrackPeak[idx] = profitPoints;
        g_ArraysDirty = true;
    }

    // 回撤达阈值 → 平仓离场
    double pullback = g_ScalpTrackPeak[idx] - profitPoints;
    if(pullback >= Inp_ScalpTrailStep)  // 使用剥头皮专用回撤阈值
    {
        g_trade.PositionClose(ticket);
        return;
    }

    // 动态推止损:基于峰值的保护性止损（跟涨不跟跌）
    // 止损位 = 开仓价 + (峰值 - 回撤阈值) 的距离
    // 例：多单开仓价2342.21，峰值350点，阈值150点 → 止损 = 2342.21 + (350-150)*0.01 = 2344.21
    // 例：空单开仓价2348.76，峰值350点，阈值150点 → 止损 = 2348.76 - (350-150)*0.01 = 2346.76
    double protectedPoints = g_ScalpTrackPeak[idx] - Inp_ScalpTrailStep;  // 峰值 - 回撤阈值
    if(protectedPoints < 0.0) protectedPoints = 0.0;  // 最低保护0点（不低于/高于开仓价）

    double targetSL = (type == POSITION_TYPE_BUY)
                    ? open + PointsToPrice(protectedPoints)  // 多单：开仓价 + 保护距离
                    : open - PointsToPrice(protectedPoints); // 空单：开仓价 - 保护距离

    double curSL = PositionGetDouble(POSITION_SL);
    double curTP = PositionGetDouble(POSITION_TP);  // 保留原止盈

    // 只有新止损"更优"才修改（只推进不回撤）
    // 多单：新止损必须比旧止损高（向上推，锁更多利润）
    // 空单：新止损必须比旧止损低（向下推，锁更多利润）—— 修复：第一次推损或新止损确实更低时才推
    bool better = false;
    if(type == POSITION_TYPE_BUY)
    {
        // 多单：新止损更高才推
        better = (targetSL > curSL + _Point);
    }
    else
    {
        // 空单：新止损更低才推（修复：初次推损curSL==0时也推；之后只有targetSL确实更低才推）
        if(curSL == 0.0) better = true;  // 初次推损
        else better = (targetSL < curSL - _Point);  // 新止损确实更低（更接近开仓价方向=锁更多利润）
    }

    // 【调试日志】止损推进决策
    if(better)
    {
        PrintFormat("[止损推进] Ticket=%I64u 类型=%s 旧止损=%.5f → 新止损=%.5f (保护点数=%.1f)",
                    ticket, (type==POSITION_TYPE_BUY?"多":"空"), curSL, targetSL, protectedPoints);
        g_trade.PositionModify(ticket, NormalizePrice(targetSL), curTP);  // 保留止盈
    }
    else
    {
        PrintFormat("[止损不推进] Ticket=%I64u 类型=%s 当前止损=%.5f 计算止损=%.5f (不满足推进条件)",
                    ticket, (type==POSITION_TYPE_BUY?"多":"空"), curSL, targetSL);
    }
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
        if(profitPoints > g_TrPeakPoints[idx]) { g_TrPeakPoints[idx] = profitPoints; g_ArraysDirty = true; }

        // 回撤达阈值 → 平仓离场
        if(g_TrPeakPoints[idx] - profitPoints >= Inp_TrendTrailStep)
        {
            g_trade.PositionClose(ticket);
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
            if(g_trade.PositionClosePartial(ticket, closeVol))
                { g_TrReduced[idx] = true; g_ArraysDirty = true; }
        }
        else
        {
            g_TrReduced[idx] = true; g_ArraysDirty = true; // 无法再拆(手数太小),标记避免反复尝试
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
        ENUM_SOP_ORDER kind = PosType();

        // 关键：已点"改趋势单"的剥头皮持仓 → 仍用剥头皮峰值追踪（而非趋势逻辑）
        // 理由：用户点"改趋势单"只是想取消止盈让利润奔跑，
        //      但仍希望用剥头皮的峰值回撤参数（300点触发，150点回撤）
        if(IsPromoted(tk))
        {
            if(kind == SOP_SCALP)  ManageScalpTrailingStop(tk);  // 用剥头皮参数
            else                   ManageTrendTrailingStop(tk);   // 真正的趋势单
        }
        else if(kind == SOP_SCALP) ManageScalpTrailingStop(tk);
        else if(kind == SOP_TREND) ManageTrendTrailingStop(tk);
    }
    TrCleanup();
    PromotedCleanup();
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
void ExportDealTable(int h, datetime statFrom)
{
    FileWrite(h, "## 全部订单明细(今日已平仓)");
    FileWrite(h, "");
    FileWrite(h, "| 平仓时间 | 类型 | 方向 | 手数 | 开仓价 | 平仓价 | 持时 | 盈亏 |");
    FileWrite(h, "|----------|------|------|------|--------|--------|------|------|");

    datetime selFrom = statFrom - 30 * 86400;
    if(!HistorySelect(selFrom, TimeCurrent() + 3600)) { FileWrite(h, "| (无数据) | | | | | | | |"); return; }

    int deals = HistoryDealsTotal();
    int rows = 0;
    for(int i = 0; i < deals; i++)
    {
        ulong dt = HistoryDealGetTicket(i);
        if(dt == 0) continue;
        if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) continue;
        if(HistoryDealGetInteger(dt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
        datetime closeT = (datetime)HistoryDealGetInteger(dt, DEAL_TIME);
        if(closeT < statFrom) continue;

        double vol = HistoryDealGetDouble(dt, DEAL_VOLUME);
        ENUM_SOP_ORDER k = DealStrategyType(dt);         // 回溯开仓magic,兼容手工平仓
        string ktxt = (k == SOP_SCALP) ? "剥头皮" : (k == SOP_TREND ? "趋势" : "手动");
        long dtype  = HistoryDealGetInteger(dt, DEAL_TYPE);
        string dir  = (dtype == DEAL_TYPE_SELL) ? "BUY" : "SELL"; // 平仓成交反向 = 原持仓方向
        double closePx = HistoryDealGetDouble(dt, DEAL_PRICE);
        double pnl  = HistoryDealGetDouble(dt, DEAL_PROFIT) + HistoryDealGetDouble(dt, DEAL_SWAP) + HistoryDealGetDouble(dt, DEAL_COMMISSION);

        // 配对 IN 成交拿开仓价与持时
        long posId = HistoryDealGetInteger(dt, DEAL_POSITION_ID);
        double openPx = closePx; datetime openT = closeT;
        for(int j = 0; j < deals; j++)
        {
            ulong dj = HistoryDealGetTicket(j);
            if(dj == 0) continue;
            if(HistoryDealGetInteger(dj, DEAL_POSITION_ID) != posId) continue;
            if(HistoryDealGetInteger(dj, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            openPx = HistoryDealGetDouble(dj, DEAL_PRICE);
            openT  = (datetime)HistoryDealGetInteger(dj, DEAL_TIME);
            break;
        }
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
void ExportDailyReport()
{
    if(!Inp_ExportOnReset) return;

    datetime statFrom = StatStart();
    // 报告归属日期:用统计起点的北京日期命名
    string dayStr = TimeToString(ToBeijing(statFrom), TIME_DATE); // yyyy.mm.dd
    StringReplace(dayStr, ".", "");
    long   acct = AccountInfoInteger(ACCOUNT_LOGIN);
    string fname = StringFormat("TradeEZ_%I64d_%s.md", acct, dayStr);

    int h = FileOpen(fname, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(h == INVALID_HANDLE) { Print("导出失败,无法创建文件: ", fname); return; }

    // ---- 统计汇总 ----
    DailyStats all, sc, tr;
    ComputeDailyStats(SOP_IGNORE, all);
    ComputeDailyStats(SOP_SCALP,  sc);
    ComputeDailyStats(SOP_TREND,  tr);
    double manNet = all.net - sc.net - tr.net;
    int    manCnt = all.trades - sc.trades - tr.trades;
    double peakProfit = g_PeakBalance - g_InitBalance;

    FileWrite(h, "# TradeEZ-SOP 日内交易报告");
    FileWrite(h, "");
    FileWrite(h, "| 项目 | 值 |");
    FileWrite(h, "|------|------|");
    FileWrite(h, "| 交易日(北京) | " + TimeToString(ToBeijing(statFrom), TIME_DATE) + " |");
    FileWrite(h, "| 导出时间(北京) | " + TimeToString(BeijingNow(), TIME_DATE|TIME_MINUTES) + " |");
    FileWrite(h, "| 账户 | " + (string)acct + " |");
    FileWrite(h, "| 品种 | " + _Symbol + " |");
    FileWrite(h, "| 今日初始金额 | $" + DoubleToString(g_InitBalance, 2) + " |");
    FileWrite(h, "| 当前余额 | $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " |");
    FileWrite(h, "| 当前净值 | $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + " |");
    FileWrite(h, "");

    FileWrite(h, "## 盈亏概览");
    FileWrite(h, "");
    FileWrite(h, "| 指标 | 数值 |");
    FileWrite(h, "|------|------|");
    FileWrite(h, "| 已实现净盈亏 | " + DoubleToString(all.net, 2) + " |");
    FileWrite(h, "| 毛盈利 | " + DoubleToString(all.grossProfit, 2) + " |");
    FileWrite(h, "| 毛亏损 | " + DoubleToString(all.grossLoss, 2) + " |");
    FileWrite(h, "| 当前浮动盈亏 | " + DoubleToString(AllFloatingPL(), 2) + " |");
    FileWrite(h, "| 今日最高盈利 | " + DoubleToString(peakProfit, 2) + " |");
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

    ExportDealTable(h, statFrom);   // 全部订单明细

    FileClose(h);
    Print("已导出当日报告: ", fname);
}

void CheckDayRollover()
{
    datetime ds = TodayStart();
    if(g_DayStart != ds)
    {
        // 重置前先导出即将结束的交易日数据(首次初始化 g_DayStart=0 时跳过)
        if(g_DayStart != 0) ExportDailyReport();

        g_DayStart        = ds;
        g_ScalpBlocked    = false;
        g_TrendBlocked    = false;
        g_TotalBlocked    = false;
        g_MoatLiquidated  = false;   // 新的一天解除护城河清盘锁定
        g_MoatDrawHit     = false;
        g_TodayHighProfit = 0.0;
        g_HighInit        = false;
        g_ScalpHighProfit = 0.0;
        g_TrendHighProfit = 0.0;
        g_ScalpHiInit     = false;
        g_TrendHiInit     = false;
        g_GlobalRealHigh  = 0.0;
        g_GlobalHiInit    = false;
        g_ScalpReason     = "";
        g_TrendReason     = "";
        g_TotalReason     = "";
        g_ConsecLoss      = 0;
        g_CooldownUntil   = 0;
        g_LastDealTime    = ds;   // 新的一天从当日起点开始计连亏
        // 余额峰值基准归位到当前余额
        g_InitBalance     = AccountInfoDouble(ACCOUNT_BALANCE);
        g_PeakBalance     = g_InitBalance;
        // 新的一天:基线回到当日0点(除非用户当天又手动重置)
        if(g_ResetTime < ds) g_ResetTime = ds;
    }
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
    if(!HistorySelect(from, TimeCurrent() + 3600)) return;

    int deals = HistoryDealsTotal();
    datetime newestSeen = g_LastDealTime;

    for(int i = 0; i < deals; i++)
    {
        ulong dt = HistoryDealGetTicket(i);
        if(dt == 0) continue;
        if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) continue;
        if(HistoryDealGetInteger(dt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

        datetime dtime = (datetime)HistoryDealGetInteger(dt, DEAL_TIME);
        if(dtime <= g_LastDealTime) continue; // 只处理新成交

        double profit = HistoryDealGetDouble(dt, DEAL_PROFIT)
                      + HistoryDealGetDouble(dt, DEAL_SWAP)
                      + HistoryDealGetDouble(dt, DEAL_COMMISSION);
        if(profit < 0.0) g_ConsecLoss++;   // 亏损累加
        else             g_ConsecLoss = 0; // 盈利/保本清零

        if(dtime > newestSeen) newestSeen = dtime;
    }
    g_LastDealTime = newestSeen;

    // 达连续亏损阈值 → 启动时间熔断
    if(Inp_ConsecLossLimit > 0 && g_ConsecLoss >= Inp_ConsecLossLimit && g_CooldownUntil <= TimeCurrent())
    {
        g_CooldownUntil = TimeCurrent() + Inp_CooldownMinutes * 60;
        g_ConsecLoss = 0; // 重置计数,冷却期结束后重新累计
        if(Inp_AlertOnBreaker)
            Alert(Lang("【连亏熔断】连续亏损达上限,冷却 ", "[STREAK BREAKER] Consecutive losses — cooldown ")
                  + (string)Inp_CooldownMinutes + Lang(" 分钟", " min"));
    }
}

// 是否处于连亏冷却中
bool InCooldown() { return (g_CooldownUntil > TimeCurrent()); }

void CheckAllRiskControl()
{
    CheckDayRollover();
    UpdateConsecutiveLoss();

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
    if(-globalNet >= TotalDrawdownLimit()) { g_TotalBlocked = true; g_TotalReason = Lang("日回撤阈值熔断", "Daily drawdown breaker"); }

    // 护城河(用全局净盈亏含浮动 + 手动单)
    CheckProfitProtection(globalNet);
    EnforceMoatLiquidation();   // 动态回撤阈值触及0 → 强平本品种全部持仓并锁定当日

    if(Inp_AlertOnBreaker)
    {
        if(!prevScalp && g_ScalpBlocked) Alert(Lang("【熔断】", "[BREAKER] ") + g_ScalpReason);
        if(!prevTrend && g_TrendBlocked) Alert(Lang("【熔断】", "[BREAKER] ") + g_TrendReason);
        if(!prevTotal && g_TotalBlocked) Alert(Lang("【全局熔断】", "[GLOBAL] ") + g_TotalReason);
    }

    SaveState();   // 持续保存关键风控状态,切周期/重载后可恢复
}

// 连亏冷却期间,所有开仓一律禁止
bool IsScalpAllowed() { return !g_ScalpBlocked && !g_TotalBlocked && !InCooldown(); }
bool IsTrendAllowed() { return !g_TrendBlocked && !g_TotalBlocked && !InCooldown(); }

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
    datetime weekStart = WeekStart();
    if(!HistorySelect(weekStart, TimeCurrent() + 3600)) return 0.0;
    double net = 0.0;
    int deals = HistoryDealsTotal();
    for(int i = 0; i < deals; i++)
    {
        ulong dt = HistoryDealGetTicket(i);
        if(dt == 0) continue;
        if(HistoryDealGetString(dt, DEAL_SYMBOL) != _Symbol) continue;
        if(HistoryDealGetInteger(dt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
        net += HistoryDealGetDouble(dt, DEAL_PROFIT)
             + HistoryDealGetDouble(dt, DEAL_SWAP)
             + HistoryDealGetDouble(dt, DEAL_COMMISSION);
    }
    return net;
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
        if(CountScalpPositions() >= Inp_ScalpMaxPositions)
        {
            Alert(Lang("【拒绝】剥头皮已满仓", "[REJECT] Scalping max positions"));
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
        if(CountTrendPositions() >= Inp_TrendMaxPositions)
        {
            Alert(Lang("【拒绝】趋势已满仓", "[REJECT] Trend max positions"));
            return false;
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| 一键平仓:平掉本品种所有持仓 + 删除本品种所有挂单                   |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
    // 平所有持仓
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        g_trade.PositionClose(tk);
    }
    // 删所有挂单
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong tk = OrderGetTicket(i);
        if(tk == 0) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        g_trade.OrderDelete(tk);
    }
}

//+------------------------------------------------------------------+
//| 利润护城河回撤保护:动态回撤阈值触及0 → 强平本品种全部持仓+挂单     |
//| 当日只执行一次,之后保持全局锁定(不再开仓),跨日重置时自愈           |
//+------------------------------------------------------------------+
void EnforceMoatLiquidation()
{
    // 已锁定:保持禁开,不重复平仓
    if(g_MoatLiquidated)
    {
        g_TotalBlocked = true;
        g_TotalReason  = Lang("利润护城河-已清盘锁定", "Profit moat — locked");
        return;
    }
    if(!g_MoatDrawHit) return;   // 本tick未触发回撤保护条件

    // 首次触发:强平本品种全部持仓 + 删除全部挂单(含手动单,与护城河全局口径一致)
    CloseAllOrders();
    g_MoatLiquidated = true;
    g_TotalBlocked   = true;
    g_TotalReason    = Lang("利润护城河-已清盘锁定", "Profit moat — locked");
    if(Inp_AlertOnBreaker)
        Alert(Lang("【护城河强平】动态回撤阈值触及0,已平仓并锁定当日",
                   "[MOAT] Drawdown floor hit — liquidated & locked for the day"));
}

// 平掉指定策略的所有持仓(剥头皮/趋势)
void CloseByKind(ENUM_SOP_ORDER kind)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PosType() != kind) continue;
        g_trade.PositionClose(tk);
    }
}

// 只平当前浮盈>0 的持仓(锁定利润单)
void CloseProfitable()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(tk == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        if(pl > 0.0) g_trade.PositionClose(tk);
    }
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

    double sl = 0.0, tp = 0.0;
    if(slPts > 0.0)
        sl = isBuy ? price - PointsToPrice(slPts) : price + PointsToPrice(slPts);
    if(tpPts > 0.0)
        tp = isBuy ? price + PointsToPrice(tpPts) : price - PointsToPrice(tpPts);

    g_trade.SetDeviationInPoints((ulong)Inp_Slippage);
    g_trade.SetExpertMagicNumber((kind == SOP_SCALP) ? Inp_MagicScalp : Inp_MagicTrend);
    string cmt = (kind == SOP_SCALP) ? Inp_CommentScalp : Inp_CommentTrend;

    bool ok = isBuy
            ? g_trade.Buy(lots, _Symbol, 0.0, NormalizePrice(sl), NormalizePrice(tp), cmt)
            : g_trade.Sell(lots, _Symbol, 0.0, NormalizePrice(sl), NormalizePrice(tp), cmt);

    if(!ok)
        Alert(Lang("下单失败: ", "Order failed: ") + (string)g_trade.ResultRetcode());
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
        sl = isBuy ? limitPrice - PointsToPrice(slPts) : limitPrice + PointsToPrice(slPts);
    if(tpPts > 0.0)
        tp = isBuy ? limitPrice + PointsToPrice(tpPts) : limitPrice - PointsToPrice(tpPts);

    g_trade.SetExpertMagicNumber((kind == SOP_SCALP) ? Inp_MagicScalp : Inp_MagicTrend);
    string cmt = (kind == SOP_SCALP) ? Inp_CommentScalp : Inp_CommentTrend;

    bool ok = isBuy
            ? g_trade.BuyLimit(lots, limitPrice, _Symbol, NormalizePrice(sl), NormalizePrice(tp), ORDER_TIME_GTC, 0, cmt)
            : g_trade.SellLimit(lots, limitPrice, _Symbol, NormalizePrice(sl), NormalizePrice(tp), ORDER_TIME_GTC, 0, cmt);

    PrintFormat("[挂单结果] %s 价格=%.5f SL=%.5f TP=%.5f 成功=%s Retcode=%d(%s)",
                dir, limitPrice, sl, tp, (ok ? "是" : "否"),
                g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());

    if(!ok)
        Alert(Lang("挂单失败: ", "Limit order failed: ") + (string)g_trade.ResultRetcode()
              + " " + g_trade.ResultRetcodeDescription());
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
    ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
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
    ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
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

    ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, COLOR_CARD_BG);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, COLOR_CARD_BORDER);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);

    ObjectCreate(0, barName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
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
    ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetString(0, objName, OBJPROP_FONT, isBold ? PANEL_FONT " Bold" : PANEL_FONT);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, (int)fontSize);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

// 垂直居中的左对齐标签(y 为文字中线)
void CreateLabelMid(string name, int x, int y, string text, color clr, double fontSize = 9, bool isBold = false)
{
    string objName = Prefix + name;
    ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetString(0, objName, OBJPROP_FONT, isBold ? PANEL_FONT " Bold" : PANEL_FONT);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, (int)fontSize);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT); // 左对齐+垂直居中
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

// 通用锚点标签(x,y 为锚点像素;anchor 决定对齐方式)
void CreateLabelAnchor(string name, int x, int y, string text, color clr, double fontSize, bool isBold, int anchor)
{
    string objName = Prefix + name;
    ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetString(0, objName, OBJPROP_FONT, isBold ? PANEL_FONT " Bold" : PANEL_FONT);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, (int)fontSize);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

// 右对齐标签:rightX 为右边界像素X
void CreateLabelRightAt(string name, int rightX, int y, string text, color clr, double fontSize = 9, bool isBold = false)
{
    string objName = Prefix + name;
    ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, rightX);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetString(0, objName, OBJPROP_FONT, isBold ? PANEL_FONT " Bold" : PANEL_FONT);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, (int)fontSize);
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
    string objName = Prefix + name;
    ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, h);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetString(0, objName, OBJPROP_FONT, isBold ? PANEL_FONT " Bold" : PANEL_FONT);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, (int)fontSize);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bg_color);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, border_color);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, text_clr);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_STATE, false);
}

void CreateEdit(string name, int x, int y, int w, int h, string default_text)
{
    string objName = Prefix + name;
    string bgName = Prefix + name + "_Bg";  // 底层白色边框矩形

    // 关键修复：如果输入框已存在，不重建，只更新内容（保持焦点状态）
    if(ObjectFind(0, objName) >= 0)
    {
        // 输入框已存在，只更新文本内容（不影响焦点）
        ObjectSetString(0, objName, OBJPROP_TEXT, default_text);
        return;
    }

    // 1. 先创建底层白色边框矩形（提供视觉边框）
    ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, w);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, h);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, COLOR_APP_BG);           // 深色底
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, COLOR_TEXT_HEADER); // 白色边框
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, bgName, OBJPROP_ZORDER, 99);  // 在输入框下层

    // 2. 再创建无边框输入框（浮在矩形上层）
    ObjectCreate(0, objName, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x + 2);  // 向右2px避开边框
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y + 2);  // 向下2px避开边框
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, w - 4);      // 宽度减4px（左右各2px）
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, h - 4);      // 高度减4px（上下各2px）
    ObjectSetString(0, objName, OBJPROP_TEXT, default_text);
    ObjectSetString(0, objName, OBJPROP_FONT, PANEL_FONT " Bold");
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 11);
    ObjectSetInteger(0, objName, OBJPROP_ALIGN, ALIGN_CENTER);
    // 关键：无边框，透明背景，浮在白色矩形边框上
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, COLOR_APP_BG);           // 深色底
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, COLOR_APP_BG);      // 无边框（同底色）
    ObjectSetInteger(0, objName, OBJPROP_COLOR, COLOR_TEXT_HEADER);        // 白色文字
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 100);  // 在矩形上层
    ObjectSetInteger(0, objName, OBJPROP_READONLY, false);  // 确保可编辑
}

// 删除本EA所有对象,但保留两个限价输入框及其背景矩形(它们不随刷新重建)
void DeleteUIKeepEdits()
{
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, Prefix) != 0) continue;
        // 保留剥头皮输入框及其背景
        if(nm == Prefix + "Edt_Sc_Price") continue;
        if(nm == Prefix + "Edt_Sc_Price_Bg") continue;
        // 保留趋势输入框及其背景
        if(nm == Prefix + "Edt_Tr_Price") continue;
        if(nm == Prefix + "Edt_Tr_Price_Bg") continue;
        ObjectDelete(0, nm);
    }
}

//+------------------------------------------------------------------+
//| 报价条:卖价靠左 / 买价靠右 / 点差居中,整数小、小数大,底部对齐    |
//+------------------------------------------------------------------+
// 画一个价格:整数常规 + 末两位放大,垂直居中(midY 为中线)。
// align: -1=靠右(leftX+blockW 为右边界), +1=靠左(leftX 为左边界)
void DrawSplitPrice(string name, int leftX, int blockW, int midY, double price, color txtColor, int align)
{
    string s = DoubleToString(price, _Digits);
    int dot = StringFind(s, ".");
    string intPart = s, decPart = "";
    if(dot >= 0) { intPart = StringSubstr(s, 0, dot); decPart = StringSubstr(s, dot + 1); }

    int intPx  = (int)(StringLen(intPart) * 12);  // 16号
    int gap    = 4;
    int decPx  = (int)(StringLen(decPart) * 18);  // 26号
    int priceW = intPx + gap + decPx;

    int startX;
    if(align < 0) startX = leftX + blockW - 18 - priceW; // 靠右(留18边距)
    else          startX = leftX + 18;                   // 靠左

    // 整数字号略小,与放大的小数用不同中线微调使基线大致齐平
    CreateLabelAnchor(name + "_Int", startX,               midY + 5, intPart, txtColor, 16, true, ANCHOR_LEFT);
    CreateLabelAnchor(name + "_Dec", startX + intPx + gap, midY,     decPart, txtColor, 26, true, ANCHOR_LEFT);
}

void RenderQuoteBar(int x, int y, int h, double bid, double ask)
{
    int fullW  = Col2X + CardW - x;   // 横跨两列
    int gapMid = 30;                  // 中间点差区(收窄)
    int halfW  = (fullW - gapMid) / 2;
    int rightX = x + halfW + gapMid;

    // 静态深色背景(彭博风格:稳定不闪烁)
    CreatePanel("PxSell_Bg", x,      y, halfW, h, COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BG);
    CreatePanel("PxBuy_Bg",  rightX, y, halfW, h, COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BG);

    int cy = y + h/2 + 0;             // 垂直中线(略下移,视觉居中)

    // 左块价格靠右、右块价格靠左 —— 两价向中间点差靠拢,整体垂直居中
    DrawSplitPrice("PxSell", x,      halfW, cy, bid, C'255,255,255', -1);
    DrawSplitPrice("PxBuy",  rightX, halfW, cy, ask, C'255,255,255', +1);

    // 中间点差:标签稍大 + 数值
    double spread = (ask - bid) / _Point;
    int cx = x + halfW + gapMid/2;
    CreateLabelAnchor("PxSpread_Lbl", cx, cy - 11, Lang("点差", "SPRD"), COLOR_TEXT_MUTED, 7.5, true, ANCHOR_CENTER);
    CreateLabelAnchor("PxSpread",     cx, cy + 9,  DoubleToString(spread, 0), COLOR_TEXT_HEADER, 13, true, ANCHOR_CENTER);
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
    // 获取最新价格
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // 解析价格为整数+小数部分
    string bidStr = DoubleToString(bid, _Digits);
    string askStr = DoubleToString(ask, _Digits);
    int bidDot = StringFind(bidStr, "."), askDot = StringFind(askStr, ".");
    string bidInt = bidStr, bidDec = "", askInt = askStr, askDec = "";
    if(bidDot >= 0) { bidInt = StringSubstr(bidStr, 0, bidDot); bidDec = StringSubstr(bidStr, bidDot + 1); }
    if(askDot >= 0) { askInt = StringSubstr(askStr, 0, askDot); askDec = StringSubstr(askStr, askDot + 1); }

    // 无删除更新:直接改文本内容(对象在主渲染时已创建)
    ObjectSetString(0, Prefix + "PxSell_Int", OBJPROP_TEXT, bidInt);
    ObjectSetString(0, Prefix + "PxSell_Dec", OBJPROP_TEXT, bidDec);
    ObjectSetString(0, Prefix + "PxBuy_Int",  OBJPROP_TEXT, askInt);
    ObjectSetString(0, Prefix + "PxBuy_Dec",  OBJPROP_TEXT, askDec);

    // 更新点差文本
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
    ObjectCreate(0, barName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
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
    ObjectCreate(0, sepName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
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
        if(HistoryDealGetInteger(dt, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
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
        g_Rows[n].pnl         = HistoryDealGetDouble(dt, DEAL_PROFIT)
                              + HistoryDealGetDouble(dt, DEAL_SWAP)
                              + HistoryDealGetDouble(dt, DEAL_COMMISSION);
        g_Rows[n].time        = TimeToString(ToBeijing(closeT), TIME_MINUTES | TIME_SECONDS); // 北京时间

        // 尝试用 position id 找入场价与持时
        long posId = HistoryDealGetInteger(dt, DEAL_POSITION_ID);
        datetime openT = closeT;
        for(int j = 0; j < deals; j++)
        {
            ulong dj = HistoryDealGetTicket(j);
            if(dj == 0) continue;
            if(HistoryDealGetInteger(dj, DEAL_POSITION_ID) != posId) continue;
            if(HistoryDealGetInteger(dj, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
            g_Rows[n].open_price = HistoryDealGetDouble(dj, DEAL_PRICE);
            openT = (datetime)HistoryDealGetInteger(dj, DEAL_TIME);
            break;
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
    if(kind == SOP_SCALP)
    {
        // 剥头皮:做空(左) / 做多(右) / 改趋势单 / 撤止盈(四按钮均分)
        int bw = (CardW - LeftPad - RightPad - 3 * 4) / 4;
        CreateButton("Btn_" + tag + "_Sell", leftX,             contentY, bw, 30, Lang("做空", "SELL"), sellBg, sellBd, sellTx, 9, true);
        CreateButton("Btn_" + tag + "_Buy",  leftX + bw + 4,    contentY, bw, 30, Lang("做多", "BUY"),  buyBg,  buyBd,  buyTx,  9, true);
        color qbBg = allowed ? COLOR_BTN_SYS_BG      : COLOR_BTN_DISABLED_BG;
        color qbTx = allowed ? COLOR_SIGNAL_WARNING   : COLOR_BTN_DISABLED_TXT;
        color qbBd = allowed ? COLOR_SIGNAL_WARNING   : COLOR_BTN_DISABLED_BG;
        CreateButton("Btn_Sc_QuickBE",       leftX + 2*(bw+4),  contentY, bw, 30, Lang("改趋势", "TREND"), qbBg, qbBd, qbTx, 9, true);
        // 撤止盈按钮(仅在有剥头皮持仓进入峰值追踪时激活)
        bool hasTracking = false;
        for(int i = 0; i < ArraySize(g_ScalpTrackTicket); i++)
        {
            if(PositionSelectByTicket(g_ScalpTrackTicket[i]))
            {
                hasTracking = true;
                break;
            }
        }
        color tpBg = (allowed && hasTracking) ? COLOR_BTN_SYS_BG      : COLOR_BTN_DISABLED_BG;
        color tpTx = (allowed && hasTracking) ? COLOR_TEXT_HEADER      : COLOR_BTN_DISABLED_TXT;  // 白色字体
        color tpBd = (allowed && hasTracking) ? COLOR_BTN_SYS_BORDER   : COLOR_BTN_DISABLED_BG;   // 淡灰色边框
        CreateButton("Btn_Sc_ClearTP",       leftX + 3*(bw+4),  contentY, bw, 30, Lang("撤止盈", "RM TP"), tpBg, tpBd, tpTx, 9, true);
    }
    else
    {
        // 趋势:做空(左) / 做多(右,两按钮均分)
        int bw = (CardW - LeftPad - RightPad - 12) / 2;
        int rightX = cardX + CardW - RightPad - bw;
        CreateButton("Btn_" + tag + "_Sell", leftX,  contentY, bw, 30, Lang(title + " 做空", "TREND SELL"), sellBg, sellBd, sellTx, 9, true);
        CreateButton("Btn_" + tag + "_Buy",  rightX, contentY, bw, 30, Lang(title + " 做多", "TREND BUY"),  buyBg,  buyBd,  buyTx,  9, true);
    }
    contentY += 38;

    // 限价挂单行:标签 + 输入框(与按钮同高)+ 间距 + 两个限价按钮
    int rowH = 30;
    CreateLabel(tag + "_Limit_Lbl", cardX + LeftPad, contentY + 9, Lang("挂单价", "PX"), COLOR_TEXT_MUTED, 8);
    int editX = cardX + LeftPad + 46;
    int editW = 76;

    // 关键修复：先读取输入框当前实时内容（含正在输入未提交的），优先级最高
    string editName = Prefix + "Edt_" + tag + "_Price";
    string liveText = "";
    if(ObjectFind(0, editName) >= 0)
        liveText = ObjectGetString(0, editName, OBJPROP_TEXT);

    // 决定显示内容：实时输入 > 已提交缓存 > 空白（不自动填充现价，让用户主动输入）
    string editVal = "";
    if(liveText != "")
        editVal = liveText;  // 用户正在输入或已输入未提交 → 保留
    else if((kind == SOP_SCALP && g_ScPriceTxt != "") || (kind == SOP_TREND && g_TrPriceTxt != ""))
        editVal = (kind == SOP_SCALP) ? g_ScPriceTxt : g_TrPriceTxt;  // 已提交缓存
    // else 不填充默认值，保持空白，让用户主动输入

    CreateEdit("Edt_" + tag + "_Price", editX, contentY, editW, rowH, editVal);

    int lbtnW  = 78;
    int lbuyX  = cardX + CardW - RightPad - lbtnW;   // 限价多在右
    int lsellX = lbuyX - lbtnW - 8;                   // 限价空在左
    CreateButton("Btn_" + tag + "_LSell", lsellX, contentY, lbtnW, rowH, Lang("限价空", "LIMIT SELL"), sellBg, sellBd, sellTx, 9, true);
    CreateButton("Btn_" + tag + "_LBuy",  lbuyX,  contentY, lbtnW, rowH, Lang("限价多", "LIMIT BUY"),  buyBg,  buyBd,  buyTx,  9, true);
    contentY += 38;   // 与上两排按钮等距

    // 现价偏移快捷挂单:+2空 +3空 +5空 -2多 -3多 -5多(6 小按钮,整组右对齐卡片右侧)
    int obH  = 22;
    int obGap = 4;
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
    int contentY = currentY + 12;

    double lots   = (kind == SOP_SCALP) ? Inp_ScalpLots : Inp_TrendLots;
    int maxPos    = (kind == SOP_SCALP) ? Inp_ScalpMaxPositions : Inp_TrendMaxPositions;
    int posCnt    = CountPositions(kind);
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
    contentY += 28;

    // 状态
    string stTxt; color stClr;
    // 熔断原因(优先级:连亏冷却 > 全局 > 本策略)
    string blkReason = "";
    if(InCooldown())       blkReason = Lang("连亏熔断", "Streak breaker");
    else if(g_TotalBlocked) blkReason = g_TotalReason;
    else if(kind == SOP_SCALP && g_ScalpBlocked) blkReason = g_ScalpReason;
    else if(kind == SOP_TREND && g_TrendBlocked) blkReason = g_TrendReason;

    if(!allowed)               { stTxt = (blkReason != "" ? blkReason : Lang("熔断 (禁开)", "BLOCKED")); stClr = COLOR_SIGNAL_LOSS; }
    else if(IsMarketClosed())  { stTxt = Lang("休市 (禁开)", "MARKET CLOSED"); stClr = COLOR_SIGNAL_LOSS; }
    else if(posCnt >= maxPos)  { stTxt = Lang("满仓", "MAX POSITION"); stClr = COLOR_SIGNAL_WARNING; }
    else if(Inp_UseSession && !InSession()) { stTxt = Lang("休息 (非时段)", "OFF-SESSION"); stClr = COLOR_TEXT_MUTED; }
    else                       { stTxt = Lang("就绪 (可开仓)", "READY"); stClr = COLOR_SIGNAL_PROFIT; }
    CreateRowLR(tag + "_Status", cardX, contentY, Lang("策略运行状态", "Strategy Status"), stTxt, COLOR_TEXT_MUTED, stClr, true);
    contentY += 22;

    CreateRowLR(tag + "_Pos", cardX, contentY, Lang("策略当前持仓", "Active Position"),
                (string)posCnt + " / " + (string)maxPos + Lang(" 仓位", " Pos"),
                COLOR_TEXT_MUTED, COLOR_TEXT_BODY);
    contentY += 22;

    string perf = Lang("盈 ", "W ") + (string)winCnt + Lang(" | 亏 ", " | L ") + (string)lossCnt + Lang(" [点击]", " [Click]");
    CreateRowLR(tag + "_Orders", cardX, contentY, Lang("今日胜负平统计 🔍", "Daily Performance 🔍"), perf, COLOR_TEXT_MUTED, COLOR_SIGNAL_PROFIT, true);
    contentY += 22;

    CreateRowLR(tag + "_Profit", cardX, contentY, Lang("今日已实现盈亏", "Realized PNL"), FmtMoney(realized), COLOR_TEXT_MUTED, PLColor(realized), true);
    contentY += 22;

    CreateRowLR(tag + "_Float", cardX, contentY, Lang("策略浮动盈亏", "Unrealized PNL"), FmtMoney(floatPL), COLOR_TEXT_MUTED, PLColor(floatPL), true);
    contentY += 22;

    CreateRowLR(tag + "_Hi", cardX, contentY, Lang("今日最高盈利", "Peak Profit"), FmtMoney(hiProfit), COLOR_TEXT_MUTED, PLColor(hiProfit), true);
    contentY += 22;

    CreateRowLR(tag + "_Melt", cardX, contentY, Lang("风控熔断间距", "Drawdown Gap"),
                FmtMoneyPlain(usedLoss) + " / " + FmtMoneyPlain(limit),
                COLOR_TEXT_MUTED, GapColor(usedLoss, limit));
    contentY += 28;
    RenderStrategyCardButtons(tag, cardX, contentY, title, kind, allowed);
}

//+------------------------------------------------------------------+
//| 更新日志舱（左右分栏：左侧版本列表，右侧版本详情）                 |
//+------------------------------------------------------------------+
void RenderChangelogPanel()
{
    int cw = 580;
    int cx = StartX + PanelWidth + 12;
    int cy = StartY;
    int ch = 620;

    CreatePanel("CL_Bg", cx, cy, cw, ch, COLOR_CARD_BG, COLOR_CARD_BORDER);
    DrawGoldBorderNamed("CL", cx, cy, cw, ch, 2, COLOR_GOLD);

    // 标题栏
    CreateLabel("CL_Title", cx + 20, cy + 14, Lang("TradeEZ-SOP 系统更新日志", "TradeEZ-SOP CHANGELOG"), COLOR_TEXT_HEADER, 11, true);
    CreateButton("Btn_CL_Close", cx + cw - 36, cy + 12, 26, 22, "X", COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BORDER, COLOR_SIGNAL_LOSS, 9, true);

    int y = cy + 48;

    // === 系统核心功能介绍（顶部，字体统一，手动折行） ===
    CreateLabel("CL_Intro_Title", cx + 20, y, Lang("核心功能概述", "CORE FEATURES"), COLOR_GOLD, 8.5, true);
    y += 20;

    // 中文：手动分两行
    CreateLabel("CL_I1_CN_1", cx + 24, y, "TradeEZ-SOP 是一套机构级黄金日内交易风控系统，集成双策略引擎、", COLOR_TEXT_BODY, 8);
    y += 16;
    CreateLabel("CL_I1_CN_2", cx + 24, y, "多维熔断机制与利润护城河技术，为专业交易者提供彭博终端级交易体验。", COLOR_TEXT_BODY, 8);
    y += 16;
    // 英文：手动分两行
    CreateLabel("CL_I1_EN_1", cx + 24, y, "TradeEZ-SOP: Institutional-grade intraday gold risk engine with dual-strategy", COLOR_TEXT_BODY, 8);
    y += 16;
    CreateLabel("CL_I1_EN_2", cx + 24, y, "architecture, multi-tier circuit breaker & profit moat for professional traders.", COLOR_TEXT_BODY, 8);
    y += 18;

    // 分隔线
    ColorBar("CL_Sep1", cx + 20, y, cw - 40, 1, COLOR_CARD_BORDER, 96);
    y += 20;

    // === 左右分栏区域 ===
    int leftW = 120;   // 左侧版本列表宽度
    int leftX = cx + 20;
    int rightW = cw - leftW - 60;  // 右侧详情区宽度（增加间距，避免溢出）
    int rightX = leftX + leftW + 20;
    int contentY = y;

    // --- 左侧：版本列表标题 ---
    CreateLabel("CL_Ver_Title", leftX, contentY, Lang("版本历史", "VERSIONS"), COLOR_GOLD, 8.5, true);
    contentY += 24;

    // 版本按钮列表（可点击切换）
    string verList[] = {"v1.03", "v1.02", "v1.01", "v1.00"};
    string dateList[] = {"2025-01-20", "2025-01-20", "2025-01-15", "2025-01-10"};
    for(int i = 0; i < ArraySize(verList); i++)
    {
        color verClr = (verList[i] == g_ChangelogVer) ? COLOR_SIGNAL_PROFIT : COLOR_TEXT_BODY;
        color verBg  = (verList[i] == g_ChangelogVer) ? COLOR_BTN_SYS_BG : C'0,0,0,0';  // 选中高亮背景

        // 版本号按钮（可点击）
        if(verList[i] == g_ChangelogVer)
            CreatePanel("CL_Ver_Sel_" + (string)i, leftX, contentY - 2, leftW, 36, COLOR_BTN_SYS_BG, COLOR_SIGNAL_PROFIT);
        CreateButton("Btn_CL_Ver_" + verList[i], leftX + 4, contentY, leftW - 8, 16, verList[i], C'0,0,0,0', C'0,0,0,0', verClr, 9, true);
        CreateLabel("CL_Ver_Date_" + (string)i, leftX + 4, contentY + 18, dateList[i], COLOR_TEXT_MUTED, 7.5);
        contentY += 42;
    }

    // --- 右侧：选中版本的详细内容 ---
    int detailY = y + 24;
    CreateLabel("CL_Detail_Title", rightX, y, Lang("更新内容", "RELEASE NOTES"), COLOR_GOLD, 8.5, true);

    // 根据选中版本显示对应内容
    if(g_ChangelogVer == "v1.03")
    {
        CreateLabel("CL_D1", rightX, detailY, Lang("• 剥头皮止损推进BUG修复", "• Scalp SL trail bug fix"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D1_1", rightX + 8, detailY, Lang("空单峰值追踪止损正确下推", "Short position SL trails down correctly"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D2", rightX, detailY, Lang("• 修复止损卡死问题", "• Fixed SL stuck issue"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D2_1", rightX + 8, detailY, Lang("盈利增加时止损跟进推进", "SL advances as profit grows"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D3", rightX, detailY, Lang("• 完善空单止损逻辑", "• Enhanced short SL logic"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D3_1", rightX + 8, detailY, Lang("多空止损分离判断更清晰", "Separated long/short logic"), COLOR_TEXT_MUTED, 8);
    }
    else if(g_ChangelogVer == "v1.02")
    {
        CreateLabel("CL_D1", rightX, detailY, Lang("• 系统品牌更名", "• Rebranding"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D1_1", rightX + 8, detailY, Lang("Gold SOP → TradeEZ-SOP", "Gold SOP → TradeEZ-SOP"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D2", rightX, detailY, Lang("• 订单备注前缀更新", "• Order prefix update"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D2_1", rightX + 8, detailY, Lang("TradeEZ-SC / TradeEZ-TR", "TradeEZ-SC / TradeEZ-TR"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D3", rightX, detailY, Lang("• 导出报告文件名更新", "• Export filename update"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D3_1", rightX + 8, detailY, Lang("TradeEZ_账户_日期.md", "TradeEZ_Acct_Date.md"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D4", rightX, detailY, Lang("• 版本号显示优化", "• Version display refined"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D4_1", rightX + 8, detailY, Lang("移除按钮框改为纯文字", "Removed button frame"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D5", rightX, detailY, Lang("• 更新日志舱布局重构", "• Changelog layout redesign"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D5_1", rightX + 8, detailY, Lang("左右分栏可切换版本", "Left-right split design"), COLOR_TEXT_MUTED, 8);
    }
    else if(g_ChangelogVer == "v1.01")
    {
        CreateLabel("CL_D1", rightX, detailY, Lang("• 剥头皮峰值追踪重构", "• Scalp peak trail refactor"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D1_1", rightX + 8, detailY, Lang("有向计算修复亏损单误触发", "Fixed loss trigger bug"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D2", rightX, detailY, Lang("• 达80点启动峰值回撤", "• Peak trail @80pt"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D2_1", rightX + 8, detailY, Lang("保留止盈回撤300点平仓", "Keep TP, exit on 300pt pullback"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D3", rightX, detailY, Lang("• 改趋势单功能优化", "• To-Trend optimization"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D3_1", rightX + 8, detailY, Lang("必须盈利≥300点(第一目标)", "Require profit ≥300pt"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D4", rightX, detailY, Lang("• 删除废弃参数", "• Removed deprecated param"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D4_1", rightX + 8, detailY, Lang("保本锁定点数参数说明更新", "BE lock & param descriptions"), COLOR_TEXT_MUTED, 8);
    }
    else if(g_ChangelogVer == "v1.00")
    {
        CreateLabel("CL_D1", rightX, detailY, Lang("• 系统架构初始发布", "• Initial release"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D1_1", rightX + 8, detailY, Lang("双策略引擎+多维熔断", "Dual-strategy + Breaker"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D2", rightX, detailY, Lang("• 彭博终端级UI", "• Bloomberg-grade UI"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D2_1", rightX + 8, detailY, Lang("暗黑配色+实时看板+双语", "Dark theme + Dashboard"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D3", rightX, detailY, Lang("• 风控熔断机制", "• Risk control"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D3_1", rightX + 8, detailY, Lang("连亏+分策略+全局回撤", "Consec loss + DD control"), COLOR_TEXT_MUTED, 8);
        detailY += 22;
        CreateLabel("CL_D4", rightX, detailY, Lang("• 数据可视化", "• Data visualization"), COLOR_TEXT_BODY, 8);
        detailY += 22;
        CreateLabel("CL_D4_1", rightX + 8, detailY, Lang("明细舱+日统计+Markdown", "Cabin + Stats + Export"), COLOR_TEXT_MUTED, 8);
    }

    y += (ch - 100);
    CreateLabel("CL_Footer", cx + 20, cy + ch - 26, Lang("* 所有版本均已通过严格回测验证 | 技术支持: TradeEZ Team", "* All versions validated via rigorous backtest | Support: TradeEZ Team"), COLOR_TEXT_MUTED, 7);
}

//+------------------------------------------------------------------+
//| 主渲染                                                            |
//+------------------------------------------------------------------+
void RenderPerfectUI()
{
    // 重绘前:抓取输入框当前内容存入缓存(含正在输入未提交的),再删除所有UI对象(但保留输入框)
    if(ObjectFind(0, Prefix + "Edt_Sc_Price") >= 0)
        g_ScPriceTxt = ObjectGetString(0, Prefix + "Edt_Sc_Price", OBJPROP_TEXT);
    if(ObjectFind(0, Prefix + "Edt_Tr_Price") >= 0)
        g_TrPriceTxt = ObjectGetString(0, Prefix + "Edt_Tr_Price", OBJPROP_TEXT);
    DeleteUIKeepEdits();  // 关键修复：保留输入框，避免用户输入丢失

    // 底层背景
    CreatePanel("AppBg", StartX, StartY, PanelWidth, PanelHeight, COLOR_APP_BG, COLOR_GOLD);
    DrawGoldBorder(StartX, StartY, PanelWidth, PanelHeight, 3); // 模拟金色粗边框

    int currentY = StartY + 16;

    // LOGO + 折叠 + K线倒计时 + 语言切换
    CreateLabel("Title", StartX + 18, currentY, "TradeEZ-SOP", COLOR_TEXT_HEADER, 13, true);
    // 版本号可点击：普通蓝色文字（移除按钮框和图标）
    CreateLabel("Version", StartX + 142, currentY + 3, "v1.03", COLOR_SIGNAL_PROFIT, 9, true);

    // 重置按钮(标题栏,V1.02 右侧;可参数隐藏)
    int syncX = StartX + 198; // 同步状态显示位置
    if(Inp_ShowResetBtn)
    {
        CreateButton("Btn_Reset_All", StartX + 198, currentY - 2, 70, 22, Lang("重置", "RESET"), COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BORDER, COLOR_SIGNAL_WARNING, 8, true);
        syncX = StartX + 274; // 重置按钮右侧
    }

    // 数据同步状态指示器（在重置按钮和时钟之间）
    if(Inp_EnableSync)
    {
        string syncText = "";
        color syncColor = COLOR_TEXT_MUTED;

        if(g_SyncInProgress)
        {
            // 同步进行中
            syncText = Lang("同步中", "SYNC");
            syncColor = COLOR_SIGNAL_WARNING;
        }
        else
        {
            // 检查最后同步时间，超过10分钟未同步显示异常
            int elapsedMin = (TimeCurrent() > g_LastSyncTime) ? (int)((TimeCurrent() - g_LastSyncTime) / 60) : 0;
            if(g_LastSyncTime == 0)
            {
                syncText = Lang("未同步", "NO SYNC");
                syncColor = COLOR_TEXT_MUTED;
            }
            else if(elapsedMin > 10)
            {
                syncText = Lang("同步异常", "SYNC ERR");
                syncColor = COLOR_SIGNAL_LOSS;
            }
            else
            {
                syncText = Lang("已同步", "SYNCED");
                syncColor = COLOR_SIGNAL_PROFIT;
            }
        }

        CreateLabel("SyncStatus", syncX, currentY + 3, syncText, syncColor, 8, true);
    }

    // 标题栏中间:北京时间(精确到秒,与收线时间同字号/高度)
    int clockCx = StartX + PanelWidth / 2;
    CreateLabelAnchor("Clock", clockCx, currentY + 10, TimeToString(BeijingNow(), TIME_MINUTES | TIME_SECONDS), COLOR_TEXT_HEADER, 16, true, ANCHOR_CENTER);
    // 北京时间右侧小字:休市标识(仅券商休市时显示,与休息区分)
    if(IsMarketClosed())
        CreateLabelAnchor("ClockClosed", clockCx + 48, currentY + 13, Lang("休市", "CLOSED"), COLOR_SIGNAL_LOSS, 9, true, ANCHOR_LEFT);
    else
        ObjectDelete(0, Prefix + "ClockClosed");
    // 右侧按钮簇:折叠(最右,右边界与卡片右侧对齐) + 语言(在其左)
    int foldX = Col2X + CardW - 24;             // 折叠按钮:右边界对齐卡片右侧
    int langX = foldX - 6 - 92;                  // 语言按钮:折叠左侧
    CreateButton("Btn_Fold", foldX, currentY - 2, 24, 24, g_Collapsed ? "+" : "-", COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BORDER, COLOR_TEXT_HEADER, 11, true);
    CreateButton("Btn_Lang_Toggle", langX, currentY - 2, 92, 24, g_Language_ZH ? "LANG: 中文" : "LANG: EN", COLOR_BTN_SYS_BG, COLOR_BTN_SYS_BORDER, COLOR_TEXT_HEADER, 8, true);
    // 收线倒计时:与按钮垂直居中对齐;"收线"小字与时间同一中线
    int cdMidY = currentY + 10;                 // 按钮垂直中线(略下移)
    int cdRight = langX - 12;                    // 时间右边界(距语言按钮12px)
    CreateLabelAnchor("BarCD",     cdRight,      cdMidY, BarCountdown(), COLOR_SIGNAL_WARNING, 16, true, ANCHOR_RIGHT);
    CreateLabelAnchor("BarCD_Lbl", cdRight - 66, cdMidY+3, Lang("收线", "BAR"), COLOR_TEXT_MUTED, 9, true, ANCHOR_RIGHT);
    currentY += 36;

    // 折叠状态:仅保留顶栏,背景收窄,移除输入框
    if(g_Collapsed)
    {
        ObjectDelete(0, Prefix + "Edt_Sc_Price");
        ObjectDelete(0, Prefix + "Edt_Tr_Price");
        ObjectSetInteger(0, Prefix + "AppBg", OBJPROP_YSIZE, 46);
        ChartRedraw();
        return;
    }

    // ===== 买卖价格条(卖左/买右/点差居中,底部对齐) =====
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    int priceH = 52;
    RenderQuoteBar(Col1X, currentY, priceH, bid, ask);
    currentY += priceH + 14;

    // ===== 行1:账户核心(左) + 全局风控(右) =====
    int rowA_Y = currentY;
    int rowA_H = 236;

    // --- 账户核心数据(7项)---
    CreateCard("Card1", Col1X, rowA_Y, CardW, rowA_H, COLOR_SIGNAL_PROFIT);
    int cY = rowA_Y + 12;
    CreateLabel("C1_Title", Col1X + LeftPad, cY, Lang("账户核心数据", "ACCOUNT METRICS"), COLOR_TEXT_HEADER, 9.5, true);
    cY += 28;
    double bal = AccountInfoDouble(ACCOUNT_BALANCE);
    double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
    double floatTotal = AllFloatingPL();
    double realTotal  = AllRealizedPL();
    // 1 今日初始金额
    CreateRowLR("C1_Init", Col1X, cY, Lang("今日初始金额", "Day Start Balance"), "$ " + DoubleToString(g_InitBalance, 2), COLOR_TEXT_MUTED, COLOR_TEXT_BODY);
    cY += 26;
    // 2 当前账户余额
    CreateRowLR("C1_Bal", Col1X, cY, Lang("当前账户余额", "Account Balance"), "$ " + DoubleToString(bal, 2), COLOR_TEXT_MUTED, COLOR_TEXT_BODY);
    cY += 26;
    // 3 今日实现盈亏(可点击,展开今日全部平仓明细)
    CreateRowLR("C1_Real", Col1X, cY, Lang("今日实现盈亏 🔍", "Realized PNL 🔍"), FmtMoney(realTotal), COLOR_TEXT_MUTED, PLColor(realTotal), true);
    cY += 26;
    // 4 实时账户净值
    CreateRowLR("C1_Eq", Col1X, cY, Lang("实时账户净值", "Real-time Equity"), "$ " + DoubleToString(eq, 2), COLOR_TEXT_MUTED, (eq >= bal ? COLOR_SIGNAL_PROFIT : COLOR_SIGNAL_LOSS), true);
    cY += 26;
    // 5 账户浮动盈亏
    CreateRowLR("C1_Float", Col1X, cY, Lang("账户浮动盈亏", "Floating PNL"), FmtMoney(floatTotal), COLOR_TEXT_MUTED, PLColor(floatTotal), true);
    cY += 26;
    // 6 系统激活时段
    string sess = StringFormat("%02d:00 ~ %02d:00 ", Inp_SessionStartHour, Inp_SessionEndHour)
                + (InSession() ? Lang("[已激活]", "[ACTIVE]") : Lang("[休息]", "[OFF]"));
    CreateRowLR("C1_Time", Col1X, cY, Lang("系统激活时段", "Active Session"), sess, COLOR_TEXT_MUTED, (InSession() ? COLOR_SIGNAL_PROFIT : COLOR_TEXT_MUTED));
    cY += 26;
    // 7 重置倒计时
    datetime nextDay = NextResetTime();
    int remain = (int)(nextDay - TimeCurrent());
    if(remain < 0) remain = 0;
    string cd = (string)(remain / 3600) + Lang(" 小时 ", " Hrs ") + (string)((remain % 3600) / 60) + Lang(" 分钟", " Mins");
    CreateRowLR("C1_Reset", Col1X, cY, Lang("重置倒计时", "Reset Countdown"), cd, COLOR_TEXT_MUTED, COLOR_SIGNAL_WARNING, true);

    // --- 全局风控数据(6项 + 4平仓按钮)---
    CreateCard("Card4", Col2X, rowA_Y, CardW, rowA_H, COLOR_SIGNAL_WARNING);
    cY = rowA_Y + 12;
    CreateLabel("C4_Title", Col2X + LeftPad, cY, Lang("全局风控数据面板", "GLOBAL RISK MONITOR"), COLOR_TEXT_HEADER, 9.5, true);
    // 日统计入口按钮(标题右侧)
    CreateButton("Btn_Stat_Open", Col2X + CardW - RightPad - 70, cY - 3, 70, 20, Lang("日统计 »", "STATS »"), COLOR_BTN_SYS_BG, COLOR_SIGNAL_PROFIT, COLOR_SIGNAL_PROFIT, 8, true);
    cY += 28;

    // 1 今日最高盈利(已平仓口径,可为负)
    double peakProfit = g_GlobalRealHigh;
    CreateRowLR("C4_Hi", Col2X, cY, Lang("今日最高盈利", "Peak Profit"), FmtMoney(peakProfit), COLOR_TEXT_MUTED, PLColor(peakProfit), true);
    cY += 24;
    // 2 动态回撤基准(具体金额:未达档=初始-日回撤;达档=初始+保底利润)
    double ddBase = DrawdownBase();
    CreateRowLR("C4_Base", Col2X, cY, Lang("动态回撤基准", "Drawdown Base"), "$ " + DoubleToString(ddBase, 0), COLOR_TEXT_MUTED, COLOR_TEXT_BODY, true);
    cY += 24;
    // 3 动态回撤阈值 = 当前净值 - 基准(距离触发的剩余金额,随持仓浮动)
    double eqNow = AccountInfoDouble(ACCOUNT_EQUITY);
    double ddRemain = eqNow - ddBase;
    // 口径与真实触发一致:阈值 > 0 = 尚有缓冲(蓝);≤ 0 = 已触及/跌破基准(红)
    color  thClr = (ddRemain > 0.0) ? COLOR_SIGNAL_PROFIT : COLOR_SIGNAL_LOSS;
    CreateRowLR("C4_Thr", Col2X, cY, Lang("动态回撤阈值", "Drawdown Room"), FmtMoney(ddRemain), COLOR_TEXT_MUTED, thClr, true);
    cY += 24;
    // 4 周目标进度
    CreateRowLR("C4_WeekP", Col2X, cY, Lang("周目标进度", "Weekly Progress"), WeeklyProgress(), COLOR_TEXT_MUTED, PLColor(WeekRealized()), true);
    cY += 24;
    // 5 周目标提示
    string wkHint = (WeekRealized() >= Inp_WeeklyProfitTarget) ? Lang("已完成", "DONE") : Lang("进行中", "In progress");
    CreateRowLR("C4_Week", Col2X, cY, Lang("周目标提示", "Weekly Hint"), wkHint, COLOR_TEXT_MUTED, (WeekRealized() >= Inp_WeeklyProfitTarget ? COLOR_SIGNAL_PROFIT : COLOR_TEXT_BODY), true);
    cY += 24;
    // 6 系统安全状态(显示熔断原因)
    string secTxt; color secClr;
    if(InCooldown())        { secTxt = Lang("连亏熔断-冷却中", "STREAK BREAKER"); secClr = COLOR_SIGNAL_LOSS; }
    else if(g_TotalBlocked) { secTxt = g_TotalReason;  secClr = COLOR_SIGNAL_LOSS; }
    else if(g_ScalpBlocked && g_TrendBlocked) { secTxt = Lang("双策略熔断", "Both blocked"); secClr = COLOR_SIGNAL_LOSS; }
    else if(g_ScalpBlocked) { secTxt = g_ScalpReason;  secClr = COLOR_SIGNAL_WARNING; }
    else if(g_TrendBlocked) { secTxt = g_TrendReason;  secClr = COLOR_SIGNAL_WARNING; }
    else                    { secTxt = Lang("运行正常 (STABLE)", "SECURED (STABLE)"); secClr = COLOR_SIGNAL_PROFIT; }
    CreateRowLR("C4_Status", Col2X, cY, Lang("系统安全状态", "Global Security"), secTxt, COLOR_TEXT_MUTED, secClr, true);
    cY += 28;
    // 4 平仓按钮:一键全平 / 平剥头皮 / 平趋势 / 平盈利
    int cbW = (CardW - LeftPad - RightPad - 3 * 6) / 4;
    int cbX0 = Col2X + LeftPad;
    CreateButton("Btn_Close_All",    cbX0,                 cY, cbW, 24, Lang("一键全平", "ALL"),    COLOR_BTN_SELL_BG, COLOR_BTN_SELL_BORDER, COLOR_SIGNAL_LOSS,   8, true);
    CreateButton("Btn_Close_Scalp",  cbX0 + (cbW+6),       cY, cbW, 24, Lang("平剥头皮", "SCALP"),  COLOR_BTN_SYS_BG,  COLOR_BTN_SYS_BORDER,  COLOR_TEXT_HEADER,   8, true);
    CreateButton("Btn_Close_Trend",  cbX0 + 2*(cbW+6),     cY, cbW, 24, Lang("平趋势单", "TREND"),  COLOR_BTN_SYS_BG,  COLOR_BTN_SYS_BORDER,  COLOR_TEXT_HEADER,   8, true);
    CreateButton("Btn_Close_Profit", cbX0 + 3*(cbW+6),     cY, cbW, 24, Lang("平盈利单", "PROFIT"), COLOR_BTN_BUY_BG,  COLOR_BTN_BUY_BORDER,  COLOR_SIGNAL_PROFIT, 8, true);

    currentY += rowA_H + 14;

    // ===== 行2:剥头皮(左) + 趋势(右) =====
    int rowB_H = 310;
    RenderStrategyCard("Sc", Col1X, currentY, rowB_H, COLOR_SIGNAL_PROFIT, Lang("极速剥头皮策略", "SCALPING STRATEGY"), SOP_SCALP);
    RenderStrategyCard("Tr", Col2X, currentY, rowB_H, COLOR_SIGNAL_LOSS,   Lang("波段趋势策略", "TREND STRATEGY"), SOP_TREND);
    currentY += rowB_H + 12;

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
    // 分隔线
    string sep = Prefix + "Foot_Sep";
    ObjectCreate(0, sep, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, sep, OBJPROP_XDISTANCE, fx);
    ObjectSetInteger(0, sep, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, sep, OBJPROP_XSIZE, fw);
    ObjectSetInteger(0, sep, OBJPROP_YSIZE, 1);
    ObjectSetInteger(0, sep, OBJPROP_BGCOLOR, COLOR_GOLD);
    ObjectSetInteger(0, sep, OBJPROP_BORDER_COLOR, COLOR_GOLD);
    ObjectSetInteger(0, sep, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, sep, OBJPROP_SELECTABLE, false);

    int ly = y + 11;
    CreateLabel("Foot_Title", fx, ly, Lang("策略参数说明", "STRATEGY PARAMETERS"), COLOR_GOLD, 8, true);
    ly += 21;

    // 剥头皮:入场止损/止盈 + 峰值追踪 + 超时
    string sc = Lang("剥头皮 · ", "Scalp · ")
              + Lang("止损 ", "SL ") + (string)Inp_ScalpSL_Points + Lang("点 / 止盈 ", "pt / TP ") + (string)Inp_ScalpTP_Points + Lang("点", "pt")
              + Lang(";浮盈≥", "; trail @+") + (string)Inp_ScalpBETrigger + Lang("点启动峰值追踪,回撤 ", "pt peak trail, exit on ") + (string)Inp_ScalpTrailStep + Lang("点离场", "pt pullback")
              + (Inp_ScalpTimeLimitOn ? (Lang(";持仓超 ", "; time-stop ") + (string)Inp_ScalpMaxHoldSecs + Lang("秒强平", "s")) : "");
    CreateLabel("Foot_Sc", fx, ly, sc, COLOR_TEXT_BODY, 8);
    ly += 21;

    // 趋势:初始止损 + 阶梯保本 + 减仓 + 峰值追踪
    string tr = Lang("趋势 · ", "Trend · ")
              + Lang("初始止损 ", "init SL ") + (string)Inp_TrendSL_Points + Lang("点", "pt")
              + Lang(";阶梯保本 +", "; step BE +") + (string)Inp_TrendBE1_Trigger + Lang("→本, +", "→BE, +") + (string)Inp_TrendBE2_Trigger + Lang("→+", "→+") + (string)Inp_TrendBE2_Lock
              + Lang(", +", ", +") + (string)Inp_TrendBE3_Trigger + Lang("→+", "→+") + (string)Inp_TrendBE3_Lock + Lang("点", "pt");
    CreateLabel("Foot_Tr", fx, ly, tr, COLOR_TEXT_BODY, 8);
    ly += 21;

    string tr2 = Lang("趋势 · ", "Trend · ")
               + Lang("+", "+") + (string)Inp_TrendBE3_Trigger + Lang("点减仓 ", "pt reduce ") + DoubleToString(Inp_TrendReducePercent,0) + "%"
               + Lang(";浮盈≥", "; trail @+") + (string)Inp_TrendTrailTrigger + Lang("点启动峰值追踪,回撤 ", "pt, exit on ") + (string)Inp_TrendTrailStep + Lang("点离场", "pt pullback");
    CreateLabel("Foot_Tr2", fx, ly, tr2, COLOR_TEXT_BODY, 8);
}

//+------------------------------------------------------------------+
//| 生命周期                                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 状态持久化(终端全局变量,跨切周期/重载存活)                       |
//+------------------------------------------------------------------+
string PVKey(string k)
{
    return StringFormat("GSOP_%I64d_%s", AccountInfoInteger(ACCOUNT_LOGIN), k);
}
void PVSet(string k, double v) { GlobalVariableSet(PVKey(k), v); }
bool   PVHas(string k)         { return GlobalVariableCheck(PVKey(k)); }
double PVGet(string k)         { return GlobalVariableGet(PVKey(k)); }

// 保存关键风控状态
void SaveState()
{
    PVSet("StatDay",    (double)g_DayStart);       // 统计日戳,用于判断存档是否属于今天
    PVSet("ResetTime",  (double)g_ResetTime);
    PVSet("Cooldown",   (double)g_CooldownUntil);
    PVSet("ConsecLoss", (double)g_ConsecLoss);
    PVSet("LastDeal",   (double)g_LastDealTime);
    // 注:g_InitBalance / g_PeakBalance 不持久化,每次 OnInit 按当前余额-今日已实现重算(自愈)
    PVSet("TodayHi",    g_TodayHighProfit);   PVSet("HiInit",   g_HighInit    ? 1 : 0);
    PVSet("ScalpHi",    g_ScalpHighProfit);   PVSet("ScHiInit", g_ScalpHiInit ? 1 : 0);
    PVSet("TrendHi",    g_TrendHighProfit);   PVSet("TrHiInit", g_TrendHiInit ? 1 : 0);
    PVSet("GlobalHi",   g_GlobalRealHigh);    PVSet("GbHiInit", g_GlobalHiInit? 1 : 0);
    PVSet("MoatLiq",    g_MoatLiquidated ? 1 : 0);  // 护城河清盘锁定(当日,跨日不恢复)
}

// 尝试恢复存档;返回 true 表示存档有效(属于今天)并已载入
bool LoadState()
{
    if(!PVHas("StatDay")) return false;
    // 存档必须属于"当前统计日",否则视为过期(跨日后不恢复)
    if((datetime)(long)PVGet("StatDay") != g_DayStart) return false;

    g_ResetTime       = (datetime)(long)PVGet("ResetTime");
    g_CooldownUntil   = (datetime)(long)PVGet("Cooldown");
    g_ConsecLoss      = (int)PVGet("ConsecLoss");
    g_LastDealTime    = (datetime)(long)PVGet("LastDeal");
    // g_InitBalance / g_PeakBalance 不从存档恢复,OnInit 里统一重算
    g_TodayHighProfit = PVGet("TodayHi");   g_HighInit    = (PVGet("HiInit")   > 0.5);
    g_ScalpHighProfit = PVGet("ScalpHi");   g_ScalpHiInit = (PVGet("ScHiInit") > 0.5);
    g_TrendHighProfit = PVGet("TrendHi");   g_TrendHiInit = (PVGet("TrHiInit") > 0.5);
    g_GlobalRealHigh  = PVGet("GlobalHi");  g_GlobalHiInit= (PVGet("GbHiInit") > 0.5);
    g_MoatLiquidated  = (PVGet("MoatLiq") > 0.5);   // 恢复当日清盘锁定(重载后不误开)
    return true;
}

//+------------------------------------------------------------------+
//| 数组类状态持久化(文件):超时取消名单 / 趋势追踪 / 提升名单        |
//| 文件首行 = 统计日戳,跨日则视为过期不恢复                          |
//+------------------------------------------------------------------+
string StateFileName() { return StringFormat("GSOP_state_%I64d.csv", AccountInfoInteger(ACCOUNT_LOGIN)); }

void SaveArrays()
{
    int h = FileOpen(StateFileName(), FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
    if(h == INVALID_HANDLE) return;
    FileWrite(h, "DAY", (long)g_DayStart);
    // 超时取消名单
    for(int i = 0; i < ArraySize(g_TimeoutCancelled); i++)
        FileWrite(h, "TOC", (long)g_TimeoutCancelled[i]);
    // 快速移损提升名单
    for(int i = 0; i < ArraySize(g_PromotedTickets); i++)
        FileWrite(h, "PRO", (long)g_PromotedTickets[i]);
    // 趋势追踪状态:ticket, 已减仓(0/1), 峰值点
    for(int i = 0; i < ArraySize(g_TrTicket); i++)
        FileWrite(h, "TRK", (long)g_TrTicket[i], g_TrReduced[i] ? 1 : 0, g_TrPeakPoints[i]);
    // 剥头皮追踪状态:ticket, 峰值点
    for(int i = 0; i < ArraySize(g_ScalpTrackTicket); i++)
        FileWrite(h, "SCT", (long)g_ScalpTrackTicket[i], g_ScalpTrackPeak[i]);
    FileClose(h);
}

void LoadArrays()
{
    if(!FileIsExist(StateFileName())) return;
    int h = FileOpen(StateFileName(), FILE_READ | FILE_CSV | FILE_ANSI, ',');
    if(h == INVALID_HANDLE) return;

    // 首行日戳校验
    string tag0 = FileReadString(h);
    long   day0 = (long)FileReadNumber(h);
    if(tag0 != "DAY" || (datetime)day0 != g_DayStart) { FileClose(h); return; } // 过期存档

    ArrayResize(g_TimeoutCancelled, 0);
    ArrayResize(g_PromotedTickets, 0);
    ArrayResize(g_TrTicket, 0);
    ArrayResize(g_TrReduced, 0);
    ArrayResize(g_TrPeakPoints, 0);
    ArrayResize(g_ScalpTrackTicket, 0);
    ArrayResize(g_ScalpTrackPeak, 0);

    while(!FileIsEnding(h))
    {
        string tag = FileReadString(h);
        if(tag == "") break;
        if(tag == "TOC")
        {
            ulong tk = (ulong)FileReadNumber(h);
            if(PositionSelectByTicket(tk)) { int n=ArraySize(g_TimeoutCancelled); ArrayResize(g_TimeoutCancelled,n+1); g_TimeoutCancelled[n]=tk; }
        }
        else if(tag == "PRO")
        {
            ulong tk = (ulong)FileReadNumber(h);
            if(PositionSelectByTicket(tk)) { int n=ArraySize(g_PromotedTickets); ArrayResize(g_PromotedTickets,n+1); g_PromotedTickets[n]=tk; }
        }
        else if(tag == "TRK")
        {
            ulong  tk  = (ulong)FileReadNumber(h);
            long   red = (long)FileReadNumber(h);
            double pk  = FileReadNumber(h);
            if(PositionSelectByTicket(tk))
            {
                int n=ArraySize(g_TrTicket);
                ArrayResize(g_TrTicket,n+1); ArrayResize(g_TrReduced,n+1); ArrayResize(g_TrPeakPoints,n+1);
                g_TrTicket[n]=tk; g_TrReduced[n]=(red!=0); g_TrPeakPoints[n]=pk;
            }
        }
        else if(tag == "SCT")
        {
            ulong  tk = (ulong)FileReadNumber(h);
            double pk = FileReadNumber(h);
            if(PositionSelectByTicket(tk))
            {
                int n=ArraySize(g_ScalpTrackTicket);
                ArrayResize(g_ScalpTrackTicket,n+1); ArrayResize(g_ScalpTrackPeak,n+1);
                g_ScalpTrackTicket[n]=tk; g_ScalpTrackPeak[n]=pk;
            }
        }
    }
    FileClose(h);
}

//+------------------------------------------------------------------+
//| 数据同步模块 (TradeSync-Web) - 增量同步版本                       |
//+------------------------------------------------------------------+
// 全局变量：服务器端最后同步时间（从服务器获取，缓存在本地）
datetime g_ServerLastSyncTime = 0;

// 获取服务器端的最后同步时间
datetime GetServerLastSyncTime()
{
    if(!Inp_EnableSync) return 0;
    if(Inp_SecretKey == "") return 0;

    // 分割Key: prefix.secret
    string parts[];
    int split = StringSplit(Inp_SecretKey, '.', parts);
    if(split != 2) return 0;
    string prefix = parts[0];
    string secret = parts[1];

    long login = AccountInfoInteger(ACCOUNT_LOGIN);
    string body = StringFormat("{\"mt5_login\":%I64d}", login);

    long timestamp = TimeGMT();
    string signature = ComputeHMAC(secret, body);

    string headers =
        "Content-Type: application/json\r\n" +
        "Authorization: Bearer " + Inp_SecretKey + "\r\n" +
        "X-Timestamp: " + IntegerToString(timestamp) + "\r\n" +
        "X-Signature: " + signature + "\r\n";

    char post[], result[];
    StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
    ArrayResize(post, ArraySize(post) - 1);

    string url = Inp_ApiBaseURL + "/api/v1/sync/last_sync_time";
    int res = WebRequest("POST", url, headers, Inp_RequestTimeoutMS, post, result, headers);

    if(res == 200)
    {
        string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
        // 解析JSON响应: {"last_sync_time": 1234567890}
        // 简化版JSON解析
        int pos = StringFind(response, "\"last_sync_time\"");
        if(pos >= 0)
        {
            int colonPos = StringFind(response, ":", pos);
            if(colonPos >= 0)
            {
                string numStr = StringSubstr(response, colonPos + 1);
                // 移除非数字字符
                StringReplace(numStr, "}", "");
                StringReplace(numStr, " ", "");
                StringReplace(numStr, ",", "");
                StringReplace(numStr, "\"", "");
                StringTrimLeft(numStr);
                StringTrimRight(numStr);
                datetime lastTime = (datetime)StringToInteger(numStr);
                if(Inp_DebugSync)
                    Print("[Sync] Server last sync time: ", TimeToString(lastTime, TIME_DATE|TIME_MINUTES));
                return lastTime;
            }
        }
    }
    else
    {
        if(Inp_DebugSync)
            Print("[Sync] Failed to get last sync time: ", res);
    }

    return 0; // 返回0表示从头开始同步
}

// HMAC-SHA256 签名(MQL5没有内置HMAC,用简化方式:SHA256(secret+body))
string ComputeHMAC(string secret, string body)
{
    uchar key[], data[], result[];
    StringToCharArray(secret + body, data, 0, WHOLE_ARRAY, CP_UTF8);
    if(CryptEncode(CRYPT_HASH_SHA256, data, key, result))
    {
        string hex = "";
        for(int i = 0; i < ArraySize(result); i++)
            hex += StringFormat("%02x", result[i]);
        return hex;
    }
    return "";
}

// 收集指定时间范围内的成交记录
int CollectDealsAfterTime(datetime afterTime, string &dealsJson[])
{
    ArrayResize(dealsJson, 0);

    // 选择历史范围：从 afterTime 到现在（加1秒避免边界重复）
    datetime fromTime = afterTime + 1; // 避免重复上传边界时间的订单
    datetime toTime = TimeCurrent();

    if(fromTime >= toTime)
    {
        if(Inp_DebugSync)
            Print("[Sync] No new deals after ", TimeToString(afterTime, TIME_DATE|TIME_MINUTES));
        return 0;
    }

    if(!HistorySelect(fromTime, toTime))
    {
        if(Inp_DebugSync)
            Print("[Sync] HistorySelect failed for range ", TimeToString(fromTime), " to ", TimeToString(toTime));
        return 0;
    }

    int total = HistoryDealsTotal();
    if(Inp_DebugSync)
        Print("[Sync] Found ", total, " deals after ", TimeToString(afterTime, TIME_DATE|TIME_MINUTES));

    for(int i = 0; i < total; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(dealTicket == 0) continue;

        long posId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
        long orderId = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
        string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
        long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        long type = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
        double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
        double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
        double sl = HistoryDealGetDouble(dealTicket, DEAL_SL);
        double tp = HistoryDealGetDouble(dealTicket, DEAL_TP);
        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
        double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
        long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
        string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
        datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);

        // 构造JSON(简化版,生产环境需严格转义)
        string json = StringFormat(
            "{\"ticket\":%I64d,\"position_id\":%I64d,\"order_id\":%I64d,\"symbol\":\"%s\",\"entry\":%d,\"type\":%d," +
            "\"volume\":%.2f,\"price\":%.5f,\"sl_price\":%.5f,\"tp_price\":%.5f," +
            "\"profit\":%.2f,\"swap\":%.2f,\"commission\":%.2f,\"magic\":%I64d,\"comment\":\"%s\",\"deal_time\":%d}",
            dealTicket, posId, orderId, symbol, entry, type,
            volume, price, sl, tp,
            profit, swap, commission, magic, comment, dealTime
        );

        int n = ArraySize(dealsJson);
        ArrayResize(dealsJson, n + 1);
        dealsJson[n] = json;
    }

    return ArraySize(dealsJson);
}

// 获取数组中最后一笔成交的时间
datetime GetLatestDealTime(const string &dealsJson[])
{
    datetime latestTime = 0;

    for(int i = 0; i < ArraySize(dealsJson); i++)
    {
        // 从JSON中提取 deal_time 字段
        string json = dealsJson[i];
        int pos = StringFind(json, "\"deal_time\":");
        if(pos >= 0)
        {
            string timeStr = StringSubstr(json, pos + 12); // 跳过 "deal_time":
            StringReplace(timeStr, "}", "");
            StringTrimLeft(timeStr);
            StringTrimRight(timeStr);
            datetime dealTime = (datetime)StringToInteger(timeStr);
            if(dealTime > latestTime)
                latestTime = dealTime;
        }
    }

    return latestTime;
}

// 上传成交批次到服务器（增量同步版本）
bool SyncDeals()
{
    if(!Inp_EnableSync) return false;
    if(Inp_SecretKey == "") return false;
    if(g_SyncInProgress) return false;

    g_SyncInProgress = true;

    // 1. 获取服务器端最后同步时间
    datetime serverLastTime = GetServerLastSyncTime();

    // 如果获取失败且有缓存值，使用缓存
    if(serverLastTime == 0 && g_ServerLastSyncTime > 0)
        serverLastTime = g_ServerLastSyncTime;

    // 如果还是0，从7天前开始（首次同步）
    if(serverLastTime == 0)
        serverLastTime = TimeCurrent() - 7 * 86400;

    // 更新缓存
    g_ServerLastSyncTime = serverLastTime;

    // 2. 收集 serverLastTime 之后的所有成交
    string deals[];
    int count = CollectDealsAfterTime(serverLastTime, deals);

    if(count == 0)
    {
        g_SyncInProgress = false;
        return true; // 没有新成交，视为成功
    }

    // 3. 获取最后一笔成交的时间（用于更新服务器端同步时间）
    datetime latestDealTime = GetLatestDealTime(deals);

    // 分割Key: prefix.secret
    string parts[];
    int split = StringSplit(Inp_SecretKey, '.', parts);
    if(split != 2)
    {
        if(Inp_DebugSync)
            Print("[Sync] Invalid key format, expected prefix.secret");
        g_SyncInProgress = false;
        return false;
    }
    string prefix = parts[0];
    string secret = parts[1];

    // 4. 构造请求体（包含 last_deal_time）
    long login = AccountInfoInteger(ACCOUNT_LOGIN);
    int gmtOffset = ServerGmtOffset();

    string bodyDeals = "";
    for(int i = 0; i < ArraySize(deals); i++)
    {
        if(i > 0) bodyDeals += ",";
        bodyDeals += deals[i];
    }

    // 关键：添加 last_deal_time 字段，服务器会用它更新最后同步时间
    string body = StringFormat(
        "{\"mt5_login\":%I64d,\"server_gmt_off\":%d,\"last_deal_time\":%d,\"deals\":[%s]}",
        login, gmtOffset, latestDealTime, bodyDeals
    );

    // 计算签名
    long timestamp = TimeGMT();
    string signature = ComputeHMAC(secret, body);

    // 准备请求头
    string headers =
        "Content-Type: application/json\r\n" +
        "Authorization: Bearer " + Inp_SecretKey + "\r\n" +
        "X-Timestamp: " + IntegerToString(timestamp) + "\r\n" +
        "X-Signature: " + signature + "\r\n";

    // 发送请求
    char post[], result[];
    StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
    ArrayResize(post, ArraySize(post) - 1);

    string url = Inp_ApiBaseURL + "/api/v1/ingest/deals";
    int res = WebRequest("POST", url, headers, Inp_RequestTimeoutMS, post, result, headers);

    g_SyncInProgress = false;

    if(res == 200)
    {
        // 成功，更新本地缓存的最后同步时间
        g_ServerLastSyncTime = latestDealTime;
        g_LastSyncTime = TimeCurrent();

        if(Inp_DebugSync)
            Print("[Sync] Successfully synced ", count, " deals. Latest deal time: ",
                  TimeToString(latestDealTime, TIME_DATE|TIME_MINUTES));
        return true;
    }
    else
    {
        string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
        if(Inp_DebugSync)
            Print("[Sync] Failed: ", res, " ", response);
        return false;
    }
}

// 上传品种规格
bool SyncSymbols()
{
    if(!Inp_EnableSync) return false;
    if(Inp_SecretKey == "") return false;

    string parts[];
    int split = StringSplit(Inp_SecretKey, '.', parts);
    if(split != 2) return false;
    string prefix = parts[0];
    string secret = parts[1];

    long login = AccountInfoInteger(ACCOUNT_LOGIN);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    string body = StringFormat(
        "{\"mt5_login\":%I64d,\"symbols\":[{\"name\":\"%s\",\"digits\":%d,\"point\":%.10f," +
        "\"tick_value\":%.5f,\"contract_size\":%.2f}]}",
        login, _Symbol, digits, point, tickValue, contractSize
    );

    long timestamp = TimeGMT();
    string signature = ComputeHMAC(secret, body);

    string headers =
        "Content-Type: application/json\r\n" +
        "Authorization: Bearer " + Inp_SecretKey + "\r\n" +
        "X-Timestamp: " + IntegerToString(timestamp) + "\r\n" +
        "X-Signature: " + signature + "\r\n";

    char post[], result[];
    StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
    ArrayResize(post, ArraySize(post) - 1);

    string url = Inp_ApiBaseURL + "/api/v1/ingest/symbols";
    int res = WebRequest("POST", url, headers, Inp_RequestTimeoutMS, post, result, headers);

    if(res == 200)
    {
        if(Inp_DebugSync)
            Print("[Sync] Symbol specs synced");
        return true;
    }
    return false;
}

// 上传账户快照
bool SyncSnapshot()
{
    if(!Inp_EnableSync) return false;
    if(Inp_SecretKey == "") return false;

    string parts[];
    int split = StringSplit(Inp_SecretKey, '.', parts);
    if(split != 2) return false;
    string prefix = parts[0];
    string secret = parts[1];

    long login = AccountInfoInteger(ACCOUNT_LOGIN);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double margin = AccountInfoDouble(ACCOUNT_MARGIN);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    datetime timestamp = TimeCurrent();

    string body = StringFormat(
        "{\"mt5_login\":%I64d,\"snapshots\":[{\"balance\":%.2f,\"equity\":%.2f," +
        "\"margin\":%.2f,\"free_margin\":%.2f,\"snapshot_time\":%d}]}",
        login, balance, equity, margin, freeMargin, timestamp
    );

    long ts = TimeGMT();
    string signature = ComputeHMAC(secret, body);

    string headers =
        "Content-Type: application/json\r\n" +
        "Authorization: Bearer " + Inp_SecretKey + "\r\n" +
        "X-Timestamp: " + IntegerToString(ts) + "\r\n" +
        "X-Signature: " + signature + "\r\n";

    char post[], result[];
    StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
    ArrayResize(post, ArraySize(post) - 1);

    string url = Inp_ApiBaseURL + "/api/v1/ingest/snapshots";
    int res = WebRequest("POST", url, headers, Inp_RequestTimeoutMS, post, result, headers);

    return (res == 200);
}

// 发送心跳
bool SyncHeartbeat()
{
    if(!Inp_EnableSync) return false;
    if(Inp_SecretKey == "") return false;

    string parts[];
    int split = StringSplit(Inp_SecretKey, '.', parts);
    if(split != 2) return false;
    string prefix = parts[0];
    string secret = parts[1];

    long login = AccountInfoInteger(ACCOUNT_LOGIN);
    string body = StringFormat("{\"mt5_login\":%I64d}", login);

    long timestamp = TimeGMT();
    string signature = ComputeHMAC(secret, body);

    string headers =
        "Content-Type: application/json\r\n" +
        "Authorization: Bearer " + Inp_SecretKey + "\r\n" +
        "X-Timestamp: " + IntegerToString(timestamp) + "\r\n" +
        "X-Signature: " + signature + "\r\n";

    char post[], result[];
    StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
    ArrayResize(post, ArraySize(post) - 1);

    string url = Inp_ApiBaseURL + "/api/v1/ingest/heartbeat";
    int res = WebRequest("POST", url, headers, Inp_RequestTimeoutMS, post, result, headers);

    return (res == 200);
}

//+------------------------------------------------------------------+
//| 入口函数                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    g_Language_ZH = Inp_DefaultChinese;
    g_DayStart    = TodayStart();

    // 先尝试恢复今日存档(切周期/重载后保留连亏冷却等纪律状态)
    if(!LoadState())
    {
        // 无有效存档 → 纪律状态全新初始化
        g_ResetTime    = TodayStart();
        g_HighInit     = false;
        g_ScalpHiInit  = false;
        g_TrendHiInit  = false;
        g_GlobalHiInit = false;
        g_LastDealTime = TodayStart();
        g_ConsecLoss   = 0;
        g_CooldownUntil = 0;
    }

    // 今日初始金额/峰值:每次都重新推算,不用存档的旧值(自愈,过了重置点后正确)
    // 今日起点余额 = 当前余额 - 今日已实现盈亏
    g_InitBalance = AccountInfoDouble(ACCOUNT_BALANCE) - AllRealizedPL();
    g_PeakBalance = MathMax(g_InitBalance, AccountInfoDouble(ACCOUNT_BALANCE));

    LoadArrays();   // 恢复数组类状态(超时取消名单/趋势追踪/提升名单)

    if(MathAbs(Inp_ScalpDrawdownRatio + Inp_TrendDrawdownRatio - 100.0) > 0.01)
        Print("提示:剥头皮+趋势回撤占比之和不等于100%,请确认参数。");

    g_trade.SetExpertMagicNumber(Inp_Magic);
    g_trade.SetDeviationInPoints((ulong)Inp_Slippage);
    g_trade.SetTypeFillingBySymbol(_Symbol);

    ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);

    CheckAllRiskControl();
    RenderPerfectUI();

    EventSetTimer(MathMax(1, Inp_RefreshSeconds));

    // 数据同步初始化
    if(Inp_EnableSync && Inp_SecretKey != "")
    {
        // 首次启动时上传品种规格
        SyncSymbols();

        // 获取服务器端最后同步时间并缓存
        g_ServerLastSyncTime = GetServerLastSyncTime();

        if(Inp_DebugSync)
            Print("[Sync] Module initialized. Server last sync time: ",
                  TimeToString(g_ServerLastSyncTime, TIME_DATE|TIME_MINUTES));
    }

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    EventKillTimer();
    ObjectsDeleteAll(0, Prefix);
    ChartRedraw();
}

void OnTick()
{
    CheckDayRollover();
    ManageAllTrailingStops();
    CheckAllRiskControl();

    // 每tick更新报价条(不重建整个面板,避免打字被打断)
    if(!g_Collapsed) UpdateQuoteBar();
}

void OnTimer()
{
    CheckAllRiskControl();
    RenderPerfectUI();

    // 数据同步定时器(每秒递增计数器)
    if(Inp_EnableSync)
    {
        g_SyncTimerCounter++;
        g_AlignTimerCounter++;

        // 每N分钟常规同步成交
        int syncInterval = Inp_SyncIntervalMin * 60; // 转换为秒
        if(g_SyncTimerCounter >= syncInterval)
        {
            g_SyncTimerCounter = 0;
            SyncDeals();
        }

        // 每30秒上传一次快照(净值曲线)
        static int snapshotCounter = 0;
        snapshotCounter++;
        if(snapshotCounter >= 30)
        {
            snapshotCounter = 0;
            SyncSnapshot();
        }

        // 每5分钟发送一次心跳
        static int heartbeatCounter = 0;
        heartbeatCounter++;
        if(heartbeatCounter >= 300)
        {
            heartbeatCounter = 0;
            SyncHeartbeat();
        }
    }
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        // 增量同步版本：不需要在这里入队，由定时器统一同步
        // OnTimer 会定期调用 SyncDeals()，自动获取服务器最后同步时间后的所有成交

        CheckAllRiskControl();
        RenderPerfectUI();
    }
}

//+------------------------------------------------------------------+
//| 图表事件:按钮点击                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // 输入框编辑结束(回车/失焦):把值实时存入全局
    if(id == CHARTEVENT_OBJECT_ENDEDIT)
    {
        if(sparam == Prefix + "Edt_Sc_Price")
        {
            g_ScPriceTxt = ObjectGetString(0, Prefix + "Edt_Sc_Price", OBJPROP_TEXT);
            PrintFormat("[输入框提交] 剥头皮挂单价=\"%s\"", g_ScPriceTxt);
        }
        else if(sparam == Prefix + "Edt_Tr_Price")
        {
            g_TrPriceTxt = ObjectGetString(0, Prefix + "Edt_Tr_Price", OBJPROP_TEXT);
            PrintFormat("[输入框提交] 趋势挂单价=\"%s\"", g_TrPriceTxt);
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
        g_Collapsed = !g_Collapsed;
        if(g_Collapsed) g_ShowDetails = false;
        RenderPerfectUI();
        return;
    }

    // 日统计舱开/关
    if(sparam == Prefix + "Btn_Stat_Open")  { g_ShowStats = !g_ShowStats; ResetBtn(sparam); RenderPerfectUI(); return; }
    if(sparam == Prefix + "Btn_Stat_Close") { g_ShowStats = false; ResetBtn(sparam); RenderPerfectUI(); return; }

    // 更新日志舱开/关（点击版本号）
    if(sparam == Prefix + "Version")
    {
        g_ShowChangelog = !g_ShowChangelog;
        RenderPerfectUI();
        return;
    }
    if(sparam == Prefix + "Btn_CL_Close") { g_ShowChangelog = false; ResetBtn(sparam); RenderPerfectUI(); return; }

    // 更新日志：版本切换按钮
    if(StringFind(sparam, Prefix + "Btn_CL_Ver_") == 0)
    {
        string ver = StringSubstr(sparam, StringLen(Prefix + "Btn_CL_Ver_"));
        g_ChangelogVer = ver;
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

    // 市价单(先复位按钮状态,去抖防重复)
    if(sparam == Prefix + "Btn_Sc_Buy")  { ResetBtn(sparam); if(OrderDebounceOK()) { OpenMarket(SOP_SCALP, true);  RenderPerfectUI(); } return; }
    if(sparam == Prefix + "Btn_Sc_Sell") { ResetBtn(sparam); if(OrderDebounceOK()) { OpenMarket(SOP_SCALP, false); RenderPerfectUI(); } return; }
    if(sparam == Prefix + "Btn_Tr_Buy")  { ResetBtn(sparam); if(OrderDebounceOK()) { OpenMarket(SOP_TREND, true);  RenderPerfectUI(); } return; }
    if(sparam == Prefix + "Btn_Tr_Sell") { ResetBtn(sparam); if(OrderDebounceOK()) { OpenMarket(SOP_TREND, false); RenderPerfectUI(); } return; }

    // 剥头皮快速移损:取消止盈+移保本+转趋势逻辑
    if(sparam == Prefix + "Btn_Sc_QuickBE") { ResetBtn(sparam); if(IsScalpAllowed()) ConvertScalpToTrend(); RenderPerfectUI(); return; }

    // 剥头皮撤止盈:清除已进入峰值追踪的持仓的止盈
    if(sparam == Prefix + "Btn_Sc_ClearTP") { ResetBtn(sparam); if(IsScalpAllowed()) ClearScalpTP(); RenderPerfectUI(); return; }

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
    if(sparam == Prefix + "Btn_Close_All")    { CloseAllOrders();       ResetBtn(sparam); RenderPerfectUI(); return; }
    if(sparam == Prefix + "Btn_Close_Scalp")  { CloseByKind(SOP_SCALP);  ResetBtn(sparam); RenderPerfectUI(); return; }
    if(sparam == Prefix + "Btn_Close_Trend")  { CloseByKind(SOP_TREND);  ResetBtn(sparam); RenderPerfectUI(); return; }
    if(sparam == Prefix + "Btn_Close_Profit") { CloseProfitable();       ResetBtn(sparam); RenderPerfectUI(); return; }

    // 重置统计基线
    if(sparam == Prefix + "Btn_Reset_All")
    {
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
        g_MoatDrawHit     = false;
        g_ScalpReason     = "";
        g_TrendReason     = "";
        g_TotalReason     = "";
        g_ConsecLoss      = 0;
        g_CooldownUntil   = 0;
        g_LastDealTime    = TimeCurrent();
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
