//+------------------------------------------------------------------+
//| SRRiskManager.mqh - ObjectiveSR M7b                               |
//| Basis BALANCE dikunci (tidak berubah antar trade). R dari SL pips.|
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_RISK_MANAGER_MQH__
#define __OBJECTIVE_SR_RISK_MANAGER_MQH__
#include "SRTypes.mqh"
#include "SRConfig.mqh"
#include "SRUtils.mqh"
#include "SRMarket.mqh"
//--- Risk % aktif (reduced setelah 3 loss beruntun)
double ActiveRisk(SRStrategyConfig &st, SRRiskState &r)
  { return(r.ReducedRiskMode ? st.ReducedRiskPercent : st.RiskPercent); }
//--- Lot dari balance * risk% / (SL pips -> tick value). Floor/ceiling broker.
double CalcLot(string sym, double riskPct, double slPips)
  {
   if(slPips<=0) return(0);
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney=bal*riskPct/100.0;
   double tv=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0) return(0);
   double pip=PipSize(sym);
   double slPrice=slPips*pip;
   double lossPerLot=(slPrice/ts)*tv;
   if(lossPerLot<=0) return(0);
   double lot=riskMoney/lossPerLot;
   double mn=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   double stp=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
   if(stp>0) lot=MathFloor(lot/stp)*stp;
   lot=NormalizeDouble(lot,2);
   if(lot<mn) return(0); // bukan 0.01 paksa: skip jika tak mampu (jujur)
   if(lot>mx) lot=mx;
   return(lot);
  }
//--- Gate spread (Spec #41)
bool SpreadOK(string sym, SRSymbolConfig &sc, double &sp)
  { sp=MarketSpreadPips(sym); return(sp<=sc.MaxSpreadPips); }
//--- Gate daily/weekly/1-trade-per-day (state dipegang EA, M7c)
bool RiskGates(SRRiskState &r, SRStrategyConfig &st)
  {
   if(r.TradesToday>=1) return(false);
   if(r.DailyLimitReached||r.DailyLossR<=-st.DailyMaxLossR) return(false);
   if(r.WeeklyLimitReached||r.WeeklyLossR<=-st.WeeklyMaxLossR) return(false);
   return(true);
  }
#endif
