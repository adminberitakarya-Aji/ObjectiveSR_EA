//+------------------------------------------------------------------+
//| ObjectiveSR.mq5 - ObjectiveSR EA M2-M7                           |
//| Full pipeline single-position: signal->SL/TP/RR->risk->execution. |
//+------------------------------------------------------------------+
#property copyright "ObjectiveSR"
#property version   "1.00"

#include "include/SRConstants.mqh"
#include "include/SRConfig.mqh"
#include "include/SRTypes.mqh"
#include "include/SRUtils.mqh"
#include "include/SRMarket.mqh"
#include "include/SRLevelEngine.mqh"
#include "include/SRClusterEngine.mqh"
#include "include/SRTouchEngine.mqh"
#include "include/SRTrendEngine.mqh"
#include "include/SREntryEngine.mqh"
#include "include/SRTradeEngine.mqh"
#include "include/SRRiskManager.mqh"
#include "include/SRLogger.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input                                                            |
//+------------------------------------------------------------------+
input bool InpLogLevels = false;
input bool InpTradeEnabled = false; // false = sinyal saja; true = live order
input string InpNewsDates = "";     // "2026.01.15,2026.02.12" -> blokir entry
input bool InpLogCSV = true;        // tulis signals/trades CSV di MQL5/Files

//--- Forward declaration (dipanggil dari OnInit)
void RefreshLevels(const string reason);
bool IsNewsDay();
void ManageOpen();
void CheckForceClose();
void TrackMAEMFE();
void LogSignal(int cIdx, SRTradeSetup &sig, string note);
void LogTrade(ulong ticket, double exitPrice, ENUM_SR_EXIT_REASON reason,
              double profit, double resultR);
void OnPositionClosed(ulong ticket, double profit, double resultR);

//--- Globals (kontrak utama EA, Phase 1)
SRStrategyConfig g_strategy;
SRSymbolConfig   g_symbol;

SRLevel          g_levels[];
SRCluster        g_clusters[];

SRTrendState     g_trend;
SRRiskState      g_risk;

//--- M7 state: single position + daily/weekly trackers
ulong            g_ticket = 0;
double           g_openRiskPips = 0;
double           g_openEntry = 0;
double           g_openSL = 0;
double           g_openTP = 0;
double           g_openMAE = 0;
double           g_openMFE = 0;
double           g_openSpread = 0;
int              g_openDir = 0; // +1 long, -1 short
ENUM_SR_PATTERN  g_openPattern = SR_PATTERN_NONE;
int              g_openClusterIdx = -1;
int              g_openScore = 0;
int              g_openTouches = 0;
double           g_openZoneU = 0;
double           g_openZoneL = 0;
double           g_openH4 = 0;
double           g_openEMA = 0;
double           g_openRR = 0;
datetime         g_openTime = 0;
string           g_dayKey = "";
string           g_weekKey = "";
ulong            g_lastClosedTicket = 0;
CTrade           g_trade;

//--- New-bar trackers (lifecycle hemat: D1/H4/M15)
datetime g_lastD1Bar  = 0;
datetime g_lastH4Bar  = 0;
datetime g_lastM15Bar = 0;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_strategy = DefaultStrategyConfig();

   if(_Symbol == "EURUSD")
      g_symbol = DefaultEURUSDConfig();
   else if(_Symbol == "GBPUSD")
      g_symbol = DefaultGBPUSDConfig();
   else
     {
      Print("ObjectiveSR M1: symbol tidak didukung: ", _Symbol,
            ". Hanya EURUSD/GBPUSD.");
      return(INIT_PARAMETERS_INCORRECT);
     }

//--- Reset state (M1: kosong, engine isi di fase berikutnya)
   ArrayResize(g_levels, 0);
   ArrayResize(g_clusters, 0);
   ZeroMemory(g_trend);
   ZeroMemory(g_risk);
   g_risk.RiskPercent = g_strategy.RiskPercent;

   g_lastD1Bar  = 0;
   g_lastH4Bar  = 0;
   g_lastM15Bar = 0;

   Print("ObjectiveSR M7 init OK: ", g_symbol.Symbol,
         " ZoneHalf=", DoubleToString(g_symbol.ZoneHalfPips, 1),
         " SL=", DoubleToString(g_symbol.MinSLPips, 1),
         "-", DoubleToString(g_symbol.MaxSLPips, 1),
         " trade=", (InpTradeEnabled ? "ON" : "OFF-SIGNAL-ONLY"));
   //--- Build awal agar SRLevel[] langsung tersedia setelah init
   RefreshLevels("INIT");
   //--- Sinkron state posisi (jika reload saat posisi terbuka, kelola)
   ManageOpen();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("ObjectiveSR M7 deinit, reason=", reason);
  }

//+------------------------------------------------------------------+
//| Tick: lifecycle hemat                                            |
//+------------------------------------------------------------------+
void OnTick()
  {
   ManageOpen();       // sinkron posisi + deteksi close (tiap tick, murah)
   TrackMAEMFE();      // update MAE/MFE posisi terbuka (untuk CSV M8)
   CheckForceClose();  // tutup >= 20:00 GMT (tiap tick)
   if(g_ticket != 0)
      return; // single position: tidak entry saat posisi terbuka

   bool newD1  = MarketIsNewBar(_Symbol, PERIOD_D1, g_lastD1Bar);
   bool newH4  = MarketIsNewBar(_Symbol, PERIOD_H4, g_lastH4Bar);
   bool newM15 = MarketIsNewBar(_Symbol, PERIOD_M15, g_lastM15Bar);

//--- New D1 -> rebuild PDH/PDL (+PWH/PWL murah, ikut refresh)
   if(newD1)
      RefreshLevels("D1");

//--- New H4 -> rebuild swing (ikut refresh total, murah: ~120 bar)
   if(newH4)
      RefreshLevels("H4");

//--- New M15 -> full pipeline M7 (sinyal -> SL/TP/RR -> risk -> order)
   if(newM15)
     {
      RefreshLevels("M15");
      UpdateTrend(_Symbol, g_trend);
      RollDayWeek();
      if(!MarketIsEntrySession(g_strategy))
         return;
      if(IsNewsDay())
        { Print("ObjectiveSR skip: news day"); return; }
      SRTradeSetup sig; ZeroMemory(sig);
      int idx = ScanEntry(_Symbol, g_symbol, g_strategy,
                          g_clusters, g_trend, sig);
      if(idx < 0 || !sig.Valid)
         return;
      Print("ObjectiveSR signal: ",
            EnumToString(sig.Direction), " ",
            EnumToString(sig.Pattern),
            " cluster#", idx,
            " touch=", sig.TouchCount,
            " score=", sig.ClusterScore);
      LogSignal(idx, sig, "RAW");
      TryEntry(idx, sig);
     }
  }

//+------------------------------------------------------------------+
//| Rebuild SRLevel[] + log ringkas                                  |
//+------------------------------------------------------------------+
void RefreshLevels(const string reason)
  {
   int total = RebuildAllLevels(_Symbol, g_strategy, g_levels);
   int nc = RebuildClusters(_Symbol, g_symbol, g_levels, g_clusters);
   int touches = UpdateTouches(_Symbol, g_strategy, g_clusters);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double spread = MarketSpreadPips(_Symbol);
   bool inSession = MarketIsEntrySession(g_strategy);

   Print("ObjectiveSR levels [", reason, "]: total=", total,
         " clusters=", nc,
         " touches=", touches,
         " spread=", DoubleToString(spread, 1),
         " session=", (inSession ? "IN" : "OUT"));

   if(!InpLogLevels)
      return;

   for(int i = 0; i < ArraySize(g_levels); i++)
     {
      Print("  L#", i, " ", EnumToString(g_levels[i].Source),
            " price=", DoubleToString(g_levels[i].Price, digits));
     }
   for(int i = 0; i < ArraySize(g_clusters); i++)
     {
      Print("  C#", i,
            " center=", DoubleToString(g_clusters[i].Center, digits),
            " U=", DoubleToString(g_clusters[i].Upper, digits),
            " L=", DoubleToString(g_clusters[i].Lower, digits),
            " score=", g_clusters[i].SourceCount,
            " n=", g_clusters[i].LevelCount,
            " touch=", g_clusters[i].TouchCount,
            " state=", EnumToString(g_clusters[i].State),
            " fresh=", EnumToString(g_clusters[i].FreshState));
     }
  }
//+------------------------------------------------------------------+
//| M7a: news-day + day/week roll                                    |
//+------------------------------------------------------------------+
bool IsNewsDay()
  {
   if(StringLen(InpNewsDates)==0) return(false);
   MqlDateTime g; TimeToStruct(MarketGetGMT(),g);
   string today=StringFormat("%04d.%02d.%02d",g.year,g.mon,g.day);
   string p[]; int n=StringSplit(InpNewsDates, StringGetCharacter(",", 0), p);
   for(int i=0;i<n;i++)
     { StringTrimLeft(p[i]); StringTrimRight(p[i]);
       if(p[i]==today) return(true); }
   return(false);
  }
void RollDayWeek()
  {
   MqlDateTime g; TimeToStruct(MarketGetGMT(),g);
   string dk=StringFormat("%04d%02d%02d",g.year,g.mon,g.day);
   if(dk!=g_dayKey)
     { g_dayKey=dk; g_risk.TradesToday=0; g_risk.DailyLossR=0;
       g_risk.DailyLimitReached=false; }
   int dow=g.day_of_week; int back=(dow==0?6:dow-1);
   datetime mid=StructToTime(g)-(g.hour*3600+g.min*60+g.sec);
   string wk=TimeToString(mid-back*86400,TIME_DATE);
   if(wk!=g_weekKey)
     { g_weekKey=wk; g_risk.WeeklyLossR=0; g_risk.WeeklyLimitReached=false; }
  }
//+------------------------------------------------------------------+
//| M7b: TryEntry (SL/TP/RR -> spread/risk gates -> market order)    |
//+------------------------------------------------------------------+
void TryEntry(int cIdx, SRTradeSetup &sig)
  {
   if(!InpTradeEnabled)
     { Print("ObjectiveSR dry-run (InpTradeEnabled=false)"); return; }
   if(g_ticket!=0) return;
   if(!RiskGates(g_risk,g_strategy))
     { Print("ObjectiveSR skip: risk gates"); return; }
   double sp=0;
   if(!SpreadOK(_Symbol,g_symbol,sp))
     { Print("ObjectiveSR skip: spread ",DoubleToString(sp,1)); return; }
   bool isLong=(sig.Direction==SR_DIRECTION_LONG);
   double rej=(isLong ? iLow(_Symbol,PERIOD_M15,1)
                      : iHigh(_Symbol,PERIOD_M15,1));
   double sl=0;
   CalcSL(_Symbol,g_symbol,isLong,rej,
          g_clusters[cIdx].Lower,g_clusters[cIdx].Upper,sl);
   double entry=(isLong ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol,SYMBOL_BID));
   double slPips=0;
   if(!SLDistOK(_Symbol,g_symbol,entry,sl,slPips))
     { Print("ObjectiveSR skip: SL ",DoubleToString(slPips,1)); return; }
   double tp=0;
   CalcTP(_Symbol,g_symbol,g_strategy,isLong,entry,
          slPips*PipSize(_Symbol),g_clusters,cIdx,tp);
   double rp=MathAbs(entry-sl), wp=MathAbs(tp-entry);
   double rr=(rp>0?wp/rp:0);
   if(!RROK(g_symbol,rr))
     { Print("ObjectiveSR skip: RR ",DoubleToString(rr,2)); return; }
   double riskPct=ActiveRisk(g_strategy,g_risk);
   double lot=CalcLot(_Symbol,riskPct,slPips);
   if(lot<=0)
     { Print("ObjectiveSR skip: lot 0"); return; }
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   entry=NormalizeDouble(entry,dg);
   sl=NormalizeDouble(sl,dg); tp=NormalizeDouble(tp,dg);
   g_trade.SetExpertMagicNumber(20260928);
   g_trade.SetDeviationInPoints(20);
   bool ok=(isLong ? g_trade.Buy(lot,_Symbol,0,sl,tp,"ObjectiveSR")
                   : g_trade.Sell(lot,_Symbol,0,sl,tp,"ObjectiveSR"));
   if(!ok)
     { Print("ObjectiveSR order fail: ",g_trade.ResultRetcode()," ",
             g_trade.ResultRetcodeDescription()); return; }
   g_ticket=g_trade.ResultOrder();
   g_openEntry=entry; g_openRiskPips=slPips;
   g_openSL=sl; g_openTP=tp; g_openMAE=0; g_openMFE=0;
   g_openSpread=sp;
   g_openDir=(isLong?1:-1); g_risk.TradesToday++;
   g_openPattern=sig.Pattern;
   g_openClusterIdx=cIdx; g_openScore=sig.ClusterScore;
   g_openTouches=sig.TouchCount;
   g_openZoneU=g_clusters[cIdx].Upper; g_openZoneL=g_clusters[cIdx].Lower;
   g_openH4=g_trend.H4Close; g_openEMA=g_trend.EMA50Current;
   g_openRR=rr; g_openTime=TimeGMT();
   sig.EntryPrice=entry; sig.StopLoss=sl; sig.TakeProfit=tp;
   sig.RiskPips=slPips;
   sig.RewardPips=PriceToPips(_Symbol,wp); sig.RR=rr; sig.SpreadPips=sp;
   LogSignal(cIdx, sig, "ENTRY");
   Print("ObjectiveSR entry: ",(isLong?"LONG ":"SHORT "),
         DoubleToString(lot,2)," @",DoubleToString(entry,dg),
         " SL=",DoubleToString(sl,dg)," TP=",DoubleToString(tp,dg),
         " RR=",DoubleToString(rr,2));
  }
//+------------------------------------------------------------------+
//| M7c: ManageOpen + ForceClose + OnPositionClosed                   |
//+------------------------------------------------------------------+
void ManageOpen()
  {
   bool found=false; ulong tick=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong t=PositionGetTicket(i); if(t==0) continue;
      string ps="";
      if(!PositionGetString(POSITION_SYMBOL,ps)) continue;
      long mg=PositionGetInteger(POSITION_MAGIC);
      if(ps==_Symbol && mg==20260928){found=true; tick=t; break;}
     }
   if(found){ g_ticket=tick; return; }
   if(g_ticket!=0)
     {
      ulong closed=g_ticket; g_ticket=0;
      int cdir=g_openDir; g_openDir=0;
      if(closed!=g_lastClosedTicket)
        {
         g_lastClosedTicket=closed;
         double prof=0; double exitPx=0;
         ENUM_SR_EXIT_REASON er=SR_EXIT_OTHER;
         if(HistorySelect(0,TimeCurrent()+86400))
           {
            for(int i=0;i<HistoryDealsTotal();i++)
              {
               ulong dt=HistoryDealGetTicket(i);
               string ds="";
               if(!HistoryDealGetString(dt,DEAL_SYMBOL,ds)) continue;
               long dm=HistoryDealGetInteger(dt,DEAL_MAGIC);
               if(ds==_Symbol && dm==20260928)
                 {
                  prof+=HistoryDealGetDouble(dt,DEAL_PROFIT)
                       +HistoryDealGetDouble(dt,DEAL_SWAP)
                       +HistoryDealGetDouble(dt,DEAL_COMMISSION);
                  exitPx=HistoryDealGetDouble(dt,DEAL_PRICE);
                  long rw=HistoryDealGetInteger(dt,DEAL_REASON);
                  if(rw==DEAL_REASON_SL) er=SR_EXIT_SL;
                  else if(rw==DEAL_REASON_TP) er=SR_EXIT_TP;
                  else if(rw==DEAL_REASON_EXPERT) er=SR_EXIT_TIME;
                 }
              }
           }
         double rr=0;
         double rm=AccountInfoDouble(ACCOUNT_BALANCE)
                   *ActiveRisk(g_strategy,g_risk)/100.0;
         if(rm>0) rr=prof/rm;
         if(exitPx<=0)
            exitPx=(cdir>0?SymbolInfoDouble(_Symbol,SYMBOL_BID)
                          :SymbolInfoDouble(_Symbol,SYMBOL_ASK));
         LogTrade(closed,exitPx,er,prof,rr);
         g_openEntry=0; g_openRiskPips=0; g_openSL=0; g_openTP=0;
         g_openMAE=0; g_openMFE=0;
         OnPositionClosed(closed,prof,rr);
        }
     }
  }
void CheckForceClose()
  {
   if(g_ticket==0) return;
   if(!MarketIsForceClose(g_strategy)) return;
   g_trade.PositionClose(_Symbol);
   Print("ObjectiveSR force-close 20:00 GMT");
  }
void TrackMAEMFE()
  {
   if(g_ticket==0 || g_openDir==0 || g_openEntry<=0) return;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0||ask<=0) return;
   if(g_openDir>0) // long: adverse = entry-bid, fav = bid-entry
     {
      double adv=g_openEntry-bid, fav=bid-g_openEntry;
      double aPips=PriceToPips(_Symbol,adv), fPips=PriceToPips(_Symbol,fav);
      if(aPips>g_openMAE) g_openMAE=aPips;
      if(fPips>g_openMFE) g_openMFE=fPips;
     }
   else // short: adverse = ask-entry, fav = entry-ask
     {
      double adv=ask-g_openEntry, fav=g_openEntry-ask;
      double aPips=PriceToPips(_Symbol,adv), fPips=PriceToPips(_Symbol,fav);
      if(aPips>g_openMAE) g_openMAE=aPips;
      if(fPips>g_openMFE) g_openMFE=fPips;
     }
  }
void LogSignal(int cIdx, SRTradeSetup &sig, string note)
  {
   if(!InpLogCSV) return;
   string f=LoggerSignalFile(_Symbol);
   LoggerWriteHeader(f,LoggerSignalHeader());
   MqlDateTime g; TimeToStruct(sig.SignalTime!=0?sig.SignalTime:TimeGMT(),g);
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   string line=StringFormat("%04d.%02d.%02d,%04d.%02d.%02d %02d:%02d,%s,%s,%s,"
      "%d,%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s",
      g.year,g.mon,g.day,g.year,g.mon,g.day,g.hour,g.min,
      _Symbol,DirName(sig.Direction),PatName(sig.Pattern),
      cIdx,sig.ClusterScore,sig.TouchCount,
      DoubleToString(g_clusters[cIdx].Upper,dg),
      DoubleToString(g_clusters[cIdx].Lower,dg),
      DoubleToString(g_trend.H4Close,dg),
      DoubleToString(g_trend.EMA50Current,dg),
      DoubleToString(sig.EntryPrice,dg),DoubleToString(sig.StopLoss,dg),
      DoubleToString(sig.TakeProfit,dg),DoubleToString(sig.RR,2),
      DoubleToString(sig.SpreadPips,1),note);
   LoggerAppend(f,line);
  }
void LogTrade(ulong ticket, double exitPrice, ENUM_SR_EXIT_REASON reason,
              double profit, double resultR)
  {
   if(!InpLogCSV) return;
   string f=LoggerTradeFile(_Symbol);
   LoggerWriteHeader(f,LoggerTradeHeader());
   MqlDateTime ge; TimeToStruct(g_openTime,ge);
   MqlDateTime gx; TimeToStruct(TimeGMT(),gx);
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   MqlDateTime gs; TimeToStruct(TimeGMT(),gs);
   string srcs=ClusterSources(_Symbol,g_levels,
      (g_openClusterIdx>=0&&g_openClusterIdx<ArraySize(g_clusters)?
       g_clusters[g_openClusterIdx]:g_clusters[0]));
   string line=StringFormat("%04d.%02d.%02d,"
      "%04d.%02d.%02d %02d:%02d,%s,%s,%s,%s,%s,%s,%d,%d,%s,%s,%s,%s,%s,%s,"
      "%02d,%s,%s,%s,%s,%s,%s",
      ge.year,ge.mon,ge.day,
      gx.year,gx.mon,gx.day,gx.hour,gx.min,
      _Symbol,DirName(g_openDir>0?SR_DIRECTION_LONG:SR_DIRECTION_SHORT),
      DoubleToString(g_openEntry,dg),DoubleToString(g_openSL,dg),
      DoubleToString(g_openTP,dg),srcs,
      g_openScore,g_openTouches,
      DoubleToString(g_openZoneU,dg),DoubleToString(g_openZoneL,dg),
      DoubleToString(g_openH4,dg),DoubleToString(g_openEMA,dg),
      PatName(g_openPattern),DoubleToString(g_openRR,2),
      DoubleToString(g_openSpread,1),
      (int)gs.hour,
      DoubleToString(g_openMAE,1),DoubleToString(g_openMFE,1),
      DoubleToString(exitPrice,dg),ExitName(reason),
      DoubleToString(resultR,2),DoubleToString(profit,2));
   LoggerAppend(f,line);
  }
void OnPositionClosed(ulong ticket, double profit, double resultR)
  {
   g_risk.DailyLossR+=resultR; g_risk.WeeklyLossR+=resultR;
   if(g_risk.DailyLossR<=-g_strategy.DailyMaxLossR)
      g_risk.DailyLimitReached=true;
   if(g_risk.WeeklyLossR<=-g_strategy.WeeklyMaxLossR)
      g_risk.WeeklyLimitReached=true;
   if(profit<0) g_risk.ConsecutiveLosses++;
   else if(profit>0) g_risk.ConsecutiveLosses=0;
   g_risk.ReducedRiskMode=
      (g_risk.ConsecutiveLosses>=g_strategy.ConsecutiveLossTrigger);
   Print("ObjectiveSR closed #",ticket," profit=",
         DoubleToString(profit,2)," R=",DoubleToString(resultR,2),
         " dayR=",DoubleToString(g_risk.DailyLossR,2),
         " weekR=",DoubleToString(g_risk.WeeklyLossR,2),
         (g_risk.ReducedRiskMode?" REDUCED":""));
  }



//+------------------------------------------------------------------+
