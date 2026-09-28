//+------------------------------------------------------------------+
//| SRTradeEngine.mqh - ObjectiveSR M7a                               |
//| SL/TP/RR strict Spec #33-40. Entry = open bar berikut (ask/bid).  |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_TRADE_ENGINE_MQH__
#define __OBJECTIVE_SR_TRADE_ENGINE_MQH__
#include "SRTypes.mqh"
#include "SRConfig.mqh"
#include "SRUtils.mqh"
//--- SL long = min(rejLow, zoneLow) - buffer | short = max(rejHigh, zoneUp) + buffer
bool CalcSL(string sym, SRSymbolConfig &sc, bool isLong, double rejEdge,
            double zoneLow, double zoneUp, double &sl)
  {
   double buf=PipsToPrice(sym,sc.SLBufferPips);
   sl=(isLong ? MathMin(rejEdge,zoneLow)-buf : MathMax(rejEdge,zoneUp)+buf);
   return(true);
  }
//--- Jarak SL dalam pips + gate Min/Max
bool SLDistOK(string sym, SRSymbolConfig &sc, double entry, double sl,
              double &distPips)
  {
   distPips=PriceToPips(sym,MathAbs(entry-sl));
   return(distPips>=sc.MinSLPips && distPips<=sc.MaxSLPips);
  }
//--- Cari opposing cluster terdekat yg ACTIVE di arah profit
int NextOpposing(string sym, SRCluster &cl[], bool isLong, double entry,
                 int selfIdx)
  {
   int best=-1; double bestD=0;
   for(int i=0;i<ArraySize(cl);i++)
     {
      if(i==selfIdx) continue;
      if(cl[i].State!=SR_STATE_ACTIVE) continue;
      if(isLong)
        { if(cl[i].Center<=entry) continue;
          double d=cl[i].Center-entry;
          if(best<0||d<bestD){best=i;bestD=d;} }
      else
        { if(cl[i].Center>=entry) continue;
          double d=entry-cl[i].Center;
          if(best<0||d<bestD){best=i;bestD=d;} }
     }
   return(best);
  }
//--- TP = opposing center -/+ buffer, cap 3R. Return false jika tak ada lawan.
bool CalcTP(string sym, SRSymbolConfig &sc, SRStrategyConfig &st,
            bool isLong, double entry, double riskPrice, SRCluster &cl[],
            int selfIdx, double &tp)
  {
   int o=NextOpposing(sym,cl,isLong,entry,selfIdx);
   double buf=PipsToPrice(sym,st.TPBufferPips);
   double raw=0; bool have=(o>=0);
   if(have) raw=(isLong ? cl[o].Center-buf : cl[o].Center+buf);
   double cap=(isLong ? entry+st.MaxRewardR*riskPrice
                      : entry-st.MaxRewardR*riskPrice);
   if(!have){ tp=cap; return(false); }
   //--- Cap 3R: long ambil min(raw,cap), short ambil max(raw,cap)
   tp=(isLong ? MathMin(raw,cap) : MathMax(raw,cap));
   return(true);
  }
bool RROK(SRSymbolConfig &sc, double rr){ return(rr>=sc.MinRR); }
#endif
