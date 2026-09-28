//+------------------------------------------------------------------+
//| SRTrendEngine.mqh - ObjectiveSR M6a                               |
//| H4 EMA50: Long = Close[1]>EMA[1] & EMA[1]>EMA[4]. Closed-bar.     |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_TREND_ENGINE_MQH__
#define __OBJECTIVE_SR_TREND_ENGINE_MQH__
#include "include/SRTypes.mqh"
//--- Handle EMA50 H4 (dibuat sekali, static di UpdateTrend)
int TrendEMAHandle(string sym)
  {
   static string lastSym=""; static int h=INVALID_HANDLE;
   if(sym!=lastSym && h!=INVALID_HANDLE){IndicatorRelease(h); h=INVALID_HANDLE;}
   if(h==INVALID_HANDLE){h=iMA(sym,PERIOD_H4,50,0,MODE_EMA,PRICE_CLOSE); lastSym=sym;}
   return(h);
  }
void UpdateTrend(string sym, SRTrendState &t)
  {
   ZeroMemory(t);
   double close1=iClose(sym,PERIOD_H4,1);
   int h=TrendEMAHandle(sym); if(h==INVALID_HANDLE) return;
   double ema[]; ArraySetAsSeries(ema,true);
   if(CopyBuffer(h,0,0,5,ema)<5) return;
   double e1=ema[1], e4=ema[4];
   if(e1<=0||e4<=0||close1<=0) return;
   t.H4Close=close1; t.EMA50Current=e1; t.EMA50Previous=e1;
   t.EMA50SlopeReference=e4;
   t.LongAllowed=(close1>e1 && e1>e4);
   t.ShortAllowed=(close1<e1 && e1<e4);
  }
bool IsLongTrend(SRTrendState &t){return(t.LongAllowed);}
bool IsShortTrend(SRTrendState &t){return(t.ShortAllowed);}
#endif
