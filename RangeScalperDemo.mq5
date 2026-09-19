//+------------------------------------------------------------------+
//|                                           RangeScalperDemo.mq5   |
//|                 人工区间：中枢动量 + 边缘回归快速演示版          |
//|                 最后修改时间：2026-09-19 04:21（北京时间）       |
//+------------------------------------------------------------------+
#property copyright "TradeEZ"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input double Inp_CenterPrice  = 4320.50; // 中心点位
input double Inp_HalfRange    = 2.00;    // 上下距离（价格）
input double Inp_BaseSpread   = 0.15;    // 用户基准点差（价格）
input double Inp_Lots         = 0.40;    // 每笔手数
input double Inp_MaxRangeLoss = 100.0;   // 区间最大总亏损（账户货币）

const ulong  DEMO_MAGIC          = 26091901;
const int    DEMO_DEVIATION_PTS  = 30;
#define TICK_BUFFER_SIZE 128
const long   MOMENTUM_WINDOW_MSC = 500;
const double MOMENTUM_SCORE_MIN  = 0.30;

enum ENUM_DEMO_PHASE
  {
   DEMO_ACTIVE=0,
   DEMO_PAUSED,
   DEMO_EXITING,
   DEMO_LOCKED
  };

struct TickSample
  {
   long   time_msc;
   double mid;
  };

CTrade          g_trade;
ENUM_DEMO_PHASE g_phase=DEMO_ACTIVE;
TickSample      g_ticks[TICK_BUFFER_SIZE];
int             g_tick_count=0;

double g_lower=0.0;
double g_upper=0.0;
double g_width=0.0;
double g_core_low=0.0;
double g_core_high=0.0;
double g_buy_trigger=0.0;
double g_sell_trigger=0.0;
double g_lower_no_entry=0.0;
double g_upper_no_entry=0.0;
double g_max_entry_spread=0.0;
double g_tp_distance=0.0;
double g_logic_sl_distance=0.0;
double g_server_sl_distance=0.0;
double g_be_trigger=0.0;
double g_be_lock=0.0;
double g_edge_confirm=0.0;
double g_edge_long_low=0.0;
double g_edge_long_high=0.0;
double g_edge_short_low=0.0;
double g_edge_short_high=0.0;
int    g_max_hold_seconds=90;
bool   g_edge_valid=false;

bool   g_core_visited=false;
bool   g_edge_long_tracking=false;
bool   g_edge_short_tracking=false;
bool   g_edge_long_used=false;
bool   g_edge_short_used=false;
double g_edge_lowest_bid=DBL_MAX;
double g_edge_highest_ask=-DBL_MAX;
bool   g_entry_pending=false;
bool   g_exit_pending=false;
ulong  g_last_exit_request_msc=0;
double g_realized_pnl=0.0;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   CalculateModel();
   if(g_tp_distance<=0.0 || g_logic_sl_distance<=0.0)
     {
      Print("RangeScalperDemo: 区间或点差没有留下有效交易空间");
      return INIT_PARAMETERS_INCORRECT;
     }

   g_trade.SetExpertMagicNumber(DEMO_MAGIC);
   g_trade.SetDeviationInPoints(DEMO_DEVIATION_PTS);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   PrintFormat("RangeScalperDemo 启动: L=%.2f M=%.2f U=%.2f TP=%.2f SL=%.2f MaxLoss=%.2f",
               g_lower,Inp_CenterPrice,g_upper,g_tp_distance,g_logic_sl_distance,Inp_MaxRangeLoss);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Tick handler                                                     |
//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return;

   PushTick(tick);
   const double range_pnl=CalculateRangeNetPnl();
   UpdatePanel(tick,range_pnl);

   if(g_phase==DEMO_LOCKED)
      return;

   if(range_pnl<=-Inp_MaxRangeLoss)
     {
      BeginGlobalExit("MAX_RANGE_LOSS");
      ProcessGlobalExit();
      return;
     }

   if(tick.bid<=g_lower || tick.ask>=g_upper)
     {
      BeginGlobalExit(tick.bid<=g_lower ? "LOWER_BOUNDARY" : "UPPER_BOUNDARY");
      ProcessGlobalExit();
      return;
     }

   if(g_phase==DEMO_EXITING)
     {
      ProcessGlobalExit();
      return;
     }

   if(ManageOpenPosition(tick))
      return;

   if(CountManagedPositions()>0 || g_entry_pending || g_exit_pending)
      return;

   const double spread=tick.ask-tick.bid;
   if(spread>g_max_entry_spread || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      g_phase=DEMO_PAUSED;
      return;
     }
   g_phase=DEMO_ACTIVE;

   const double mid=(tick.bid+tick.ask)/2.0;
   if(mid>=g_core_low && mid<=g_core_high)
      g_core_visited=true;

   UpdateEdgeTracking(tick,mid);

   double net_move=0.0,score=0.0;
   CalculateMomentum(tick.time_msc,net_move,score);

   // 中枢模型优先：访问核心区后，沿短时动量方向只开一边。
   if(g_core_visited)
     {
      if(tick.ask>=g_buy_trigger && tick.ask<g_upper_no_entry &&
         net_move>=g_edge_confirm && score>=MOMENTUM_SCORE_MIN)
        {
         OpenPosition(ORDER_TYPE_BUY,"CENTER");
         return;
        }
      if(tick.bid<=g_sell_trigger && tick.bid>g_lower_no_entry &&
         net_move<=-g_edge_confirm && score<=-MOMENTUM_SCORE_MIN)
        {
         OpenPosition(ORDER_TYPE_SELL,"CENTER");
         return;
        }
     }

   // 边缘模型低优先级：只有形成局部极值并确认反转后才入场。
   if(g_edge_valid && g_edge_long_tracking && !g_edge_long_used &&
      tick.bid-g_edge_lowest_bid>=g_edge_confirm)
     {
      g_edge_long_used=true;
      OpenPosition(ORDER_TYPE_BUY,"EDGE");
      return;
     }
   if(g_edge_valid && g_edge_short_tracking && !g_edge_short_used &&
      g_edge_highest_ask-tick.ask>=g_edge_confirm)
     {
      g_edge_short_used=true;
      OpenPosition(ORDER_TYPE_SELL,"EDGE");
      return;
     }
  }

//+------------------------------------------------------------------+
//| Trade transaction                                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD && trans.deal>0 &&
      HistoryDealGetInteger(trans.deal,DEAL_MAGIC)==(long)DEMO_MAGIC &&
      HistoryDealGetString(trans.deal,DEAL_SYMBOL)==_Symbol)
     {
      g_realized_pnl+=HistoryDealGetDouble(trans.deal,DEAL_PROFIT);
      g_realized_pnl+=HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
      g_realized_pnl+=HistoryDealGetDouble(trans.deal,DEAL_SWAP);
      g_realized_pnl+=HistoryDealGetDouble(trans.deal,DEAL_FEE);
     }

   if(trans.type==TRADE_TRANSACTION_REQUEST && request.magic==DEMO_MAGIC)
     {
      g_entry_pending=false;
      if(result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_PLACED &&
         result.retcode!=TRADE_RETCODE_DONE_PARTIAL)
         PrintFormat("交易请求未完成: retcode=%u %s",result.retcode,result.comment);
     }

   if(CountManagedPositions()==0)
     {
      g_exit_pending=false;
      if(g_phase==DEMO_EXITING && CountManagedOrders()==0)
         g_phase=DEMO_LOCKED;
     }
  }

//+------------------------------------------------------------------+
bool ValidateInputs()
  {
   if(Inp_CenterPrice<=0.0 || Inp_HalfRange<=0.0 || Inp_BaseSpread<=0.0 ||
      Inp_Lots<=0.0 || Inp_MaxRangeLoss<=0.0)
     {
      Print("RangeScalperDemo: 五项输入都必须大于0");
      return false;
     }

   const double min_lot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   const double max_lot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   const double lot_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(Inp_Lots<min_lot || Inp_Lots>max_lot || lot_step<=0.0 ||
      MathAbs(Inp_Lots/lot_step-MathRound(Inp_Lots/lot_step))>1e-7)
     {
      PrintFormat("RangeScalperDemo: 手数 %.2f 不符合范围 %.2f..%.2f 或步长 %.2f",
                  Inp_Lots,min_lot,max_lot,lot_step);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
void CalculateModel()
  {
   g_lower=Inp_CenterPrice-Inp_HalfRange;
   g_upper=Inp_CenterPrice+Inp_HalfRange;
   g_width=2.0*Inp_HalfRange;

   const double trigger_distance=MathMax(0.125*g_width,1.5*Inp_BaseSpread);
   const double available_room=MathMax(0.0,0.5*g_width-trigger_distance-Inp_BaseSpread);

   g_core_low=Inp_CenterPrice-0.05*g_width;
   g_core_high=Inp_CenterPrice+0.05*g_width;
   g_buy_trigger=Inp_CenterPrice+trigger_distance;
   g_sell_trigger=Inp_CenterPrice-trigger_distance;
   g_lower_no_entry=g_lower+0.20*g_width;
   g_upper_no_entry=g_upper-0.20*g_width;
   g_max_entry_spread=MathMax(1.35*Inp_BaseSpread,Inp_BaseSpread+0.05);
   g_tp_distance=MathMin(MathMax(4.0*Inp_BaseSpread,0.225*g_width),available_room);
   g_logic_sl_distance=MathMin(MathMax(2.0*Inp_BaseSpread,0.1625*g_width),0.20*g_width);
   g_server_sl_distance=g_logic_sl_distance+MathMax(Inp_BaseSpread,0.075*g_width);
   g_be_trigger=0.67*g_tp_distance;
   g_be_lock=MathMin(0.10,MathMax(0.05,0.11*g_tp_distance));
   g_max_hold_seconds=(int)MathRound(60.0+7.5*g_width);
   g_edge_confirm=MathMax(Inp_BaseSpread,0.0375*g_width);

   const double edge_buffer=MathMax(2.0*Inp_BaseSpread,0.10*g_width);
   const double edge_max=MathMin(0.20*g_width,0.75*g_tp_distance);
   g_edge_valid=(edge_buffer<edge_max);
   g_edge_long_low=g_lower+edge_buffer;
   g_edge_long_high=g_lower+edge_max;
   g_edge_short_low=g_upper-edge_max;
   g_edge_short_high=g_upper-edge_buffer;
  }

//+------------------------------------------------------------------+
void PushTick(const MqlTick &tick)
  {
   const double mid=(tick.bid+tick.ask)/2.0;
   if(g_tick_count<TICK_BUFFER_SIZE)
     {
      g_ticks[g_tick_count].time_msc=tick.time_msc;
      g_ticks[g_tick_count].mid=mid;
      g_tick_count++;
      return;
     }
   for(int i=1;i<TICK_BUFFER_SIZE;i++)
      g_ticks[i-1]=g_ticks[i];
   g_ticks[TICK_BUFFER_SIZE-1].time_msc=tick.time_msc;
   g_ticks[TICK_BUFFER_SIZE-1].mid=mid;
  }

//+------------------------------------------------------------------+
void CalculateMomentum(const long now_msc,double &net_move,double &score)
  {
   net_move=0.0;
   score=0.0;
   if(g_tick_count<2)
      return;

   int first=g_tick_count-1;
   while(first>0 && now_msc-g_ticks[first-1].time_msc<=MOMENTUM_WINDOW_MSC)
      first--;

   net_move=g_ticks[g_tick_count-1].mid-g_ticks[first].mid;
   int up=0,down=0,changes=0;
   const int score_first=MathMax(first,g_tick_count-21);
   for(int i=score_first+1;i<g_tick_count;i++)
     {
      const double delta=g_ticks[i].mid-g_ticks[i-1].mid;
      if(delta>0.0) { up++; changes++; }
      else if(delta<0.0) { down++; changes++; }
     }
   if(changes>0)
      score=(double)(up-down)/(double)changes;
  }

//+------------------------------------------------------------------+
void UpdateEdgeTracking(const MqlTick &tick,const double mid)
  {
   if(!g_edge_valid)
      return;

   if(mid>=g_edge_long_low && mid<=g_edge_long_high && !g_edge_long_used)
     {
      g_edge_long_tracking=true;
      g_edge_lowest_bid=MathMin(g_edge_lowest_bid,tick.bid);
     }
   if(mid>g_lower+0.30*g_width)
     {
      g_edge_long_tracking=false;
      g_edge_long_used=false;
      g_edge_lowest_bid=DBL_MAX;
     }

   if(mid>=g_edge_short_low && mid<=g_edge_short_high && !g_edge_short_used)
     {
      g_edge_short_tracking=true;
      g_edge_highest_ask=MathMax(g_edge_highest_ask,tick.ask);
     }
   if(mid<g_upper-0.30*g_width)
     {
      g_edge_short_tracking=false;
      g_edge_short_used=false;
      g_edge_highest_ask=-DBL_MAX;
     }
  }

//+------------------------------------------------------------------+
bool OpenPosition(const ENUM_ORDER_TYPE type,const string model)
  {
   if(g_entry_pending || CountManagedPositions()>0 || g_phase!=DEMO_ACTIVE)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return false;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const double entry=(type==ORDER_TYPE_BUY ? tick.ask : tick.bid);
   const double sl=NormalizeDouble(type==ORDER_TYPE_BUY ? entry-g_server_sl_distance : entry+g_server_sl_distance,digits);
   const string comment="RS-DEMO-"+model;

   g_entry_pending=true;
   bool sent=false;
   if(type==ORDER_TYPE_BUY)
      sent=g_trade.Buy(Inp_Lots,_Symbol,0.0,sl,0.0,comment);
   else
      sent=g_trade.Sell(Inp_Lots,_Symbol,0.0,sl,0.0,comment);

   if(!sent || !TradeRetcodeAccepted())
     {
      PrintFormat("开仓失败 %s: retcode=%u %s",model,g_trade.ResultRetcode(),g_trade.ResultRetcodeDescription());
      g_entry_pending=false;
      return false;
     }

   g_core_visited=false;
   PrintFormat("开仓请求已发送: model=%s direction=%s entry=%.2f serverSL=%.2f",
               model,(type==ORDER_TYPE_BUY ? "BUY" : "SELL"),entry,sl);
   return true;
  }

//+------------------------------------------------------------------+
bool ManageOpenPosition(const MqlTick &tick)
  {
   ulong ticket=0;
   if(!SelectManagedPosition(ticket))
      return false;

   const ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price=PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl=PositionGetDouble(POSITION_SL);
   const datetime open_time=(datetime)PositionGetInteger(POSITION_TIME);
   const double executable=(type==POSITION_TYPE_BUY ? tick.bid : tick.ask);
   const double favorable=(type==POSITION_TYPE_BUY ? executable-open_price : open_price-executable);
   const bool protected_phase=(type==POSITION_TYPE_BUY ? current_sl>=open_price : (current_sl>0.0 && current_sl<=open_price));

   string reason="";
   if(favorable>=g_tp_distance)
      reason="TAKE_PROFIT";
   else if(favorable<=-g_logic_sl_distance)
      reason="LOGIC_STOP";
   else if(!protected_phase && TimeCurrent()-open_time>=g_max_hold_seconds)
      reason="TIMEOUT";

   if(reason!="")
     {
      RequestClose(ticket,reason);
      return true;
     }

   if(favorable>=g_be_trigger)
     {
      const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      const double target_sl=NormalizeDouble(type==POSITION_TYPE_BUY ? open_price+g_be_lock : open_price-g_be_lock,digits);
      const bool improves=(type==POSITION_TYPE_BUY ? (current_sl==0.0 || target_sl>current_sl) :
                                             (current_sl==0.0 || target_sl<current_sl));
      if(improves)
        {
         if(!g_trade.PositionModify(ticket,target_sl,0.0) || !TradeRetcodeAccepted())
            PrintFormat("保本SL修改失败 ticket=%I64u retcode=%u %s",
                        ticket,g_trade.ResultRetcode(),g_trade.ResultRetcodeDescription());
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
void RequestClose(const ulong ticket,const string reason)
  {
   const ulong now=GetTickCount64();
   if(g_exit_pending && now-g_last_exit_request_msc<1000)
      return;

   g_exit_pending=true;
   g_last_exit_request_msc=now;
   if(!g_trade.PositionClose(ticket) || !TradeRetcodeAccepted())
      PrintFormat("平仓请求失败 ticket=%I64u reason=%s retcode=%u %s",
                  ticket,reason,g_trade.ResultRetcode(),g_trade.ResultRetcodeDescription());
   else
      PrintFormat("平仓请求已发送 ticket=%I64u reason=%s",ticket,reason);
  }

//+------------------------------------------------------------------+
void BeginGlobalExit(const string reason)
  {
   if(g_phase==DEMO_LOCKED || g_phase==DEMO_EXITING)
      return;
   g_phase=DEMO_EXITING;
   g_entry_pending=false;
   PrintFormat("区间熔断开始: reason=%s rangePnL=%.2f",reason,CalculateRangeNetPnl());
  }

//+------------------------------------------------------------------+
void ProcessGlobalExit()
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      const ulong ticket=OrderGetTicket(i);
      if(ticket==0 || OrderGetInteger(ORDER_MAGIC)!=(long)DEMO_MAGIC ||
         OrderGetString(ORDER_SYMBOL)!=_Symbol)
         continue;
      if(!g_trade.OrderDelete(ticket) || !TradeRetcodeAccepted())
         PrintFormat("撤单失败 #%I64u retcode=%u",ticket,g_trade.ResultRetcode());
     }

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetInteger(POSITION_MAGIC)!=(long)DEMO_MAGIC ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      RequestClose(ticket,"RANGE_EXIT");
     }

   if(CountManagedPositions()==0 && CountManagedOrders()==0)
     {
      g_phase=DEMO_LOCKED;
      g_exit_pending=false;
      Print("区间已锁死；修改输入或重新加载EA才能开始新区间");
     }
  }

//+------------------------------------------------------------------+
double CalculateRangeNetPnl()
  {
   double pnl=g_realized_pnl;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetInteger(POSITION_MAGIC)!=(long)DEMO_MAGIC ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      pnl+=PositionGetDouble(POSITION_PROFIT);
      pnl+=PositionGetDouble(POSITION_SWAP);
     }
   return pnl;
  }

//+------------------------------------------------------------------+
bool SelectManagedPosition(ulong &ticket)
  {
   ticket=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      const ulong current=PositionGetTicket(i);
      if(current==0 || PositionGetInteger(POSITION_MAGIC)!=(long)DEMO_MAGIC ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      ticket=current;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
int CountManagedPositions()
  {
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket>0 && PositionGetInteger(POSITION_MAGIC)==(long)DEMO_MAGIC &&
         PositionGetString(POSITION_SYMBOL)==_Symbol)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
int CountManagedOrders()
  {
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      const ulong ticket=OrderGetTicket(i);
      if(ticket>0 && OrderGetInteger(ORDER_MAGIC)==(long)DEMO_MAGIC &&
         OrderGetString(ORDER_SYMBOL)==_Symbol)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
bool TradeRetcodeAccepted()
  {
   const uint code=g_trade.ResultRetcode();
   return(code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_PLACED || code==TRADE_RETCODE_DONE_PARTIAL);
  }

//+------------------------------------------------------------------+
void UpdatePanel(const MqlTick &tick,const double range_pnl)
  {
   const string phase=(g_phase==DEMO_ACTIVE ? "ACTIVE" :
                      (g_phase==DEMO_PAUSED ? "PAUSED" :
                      (g_phase==DEMO_EXITING ? "EXITING" : "LOCKED")));
   Comment(StringFormat(
      "RangeScalperDemo\n"
      "状态: %s  RangePnL: %.2f / -%.2f\n"
      "区间: %.2f < %.2f < %.2f\n"
      "报价: Bid %.2f / Ask %.2f / Spread %.2f\n"
      "中枢触发: Sell %.2f / Buy %.2f\n"
      "自动退出: TP %.2f / SL %.2f / BE %.2f→%.2f / %ds\n"
      "边缘模型: %s",
      phase,range_pnl,Inp_MaxRangeLoss,
      g_lower,Inp_CenterPrice,g_upper,
      tick.bid,tick.ask,tick.ask-tick.bid,
      g_sell_trigger,g_buy_trigger,
      g_tp_distance,g_logic_sl_distance,g_be_trigger,g_be_lock,g_max_hold_seconds,
      (g_edge_valid ? "ON" : "OFF")));
  }

//+------------------------------------------------------------------+
