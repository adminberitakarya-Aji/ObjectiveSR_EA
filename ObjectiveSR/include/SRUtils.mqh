//+------------------------------------------------------------------+
//| SRUtils.mqh - ObjectiveSR Phase 1                                |
//| Pip conversion, GMT window, source identity (kontrak)            |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_UTILS_MQH__
#define __OBJECTIVE_SR_UTILS_MQH__

#include "SRConfig.mqh"
#include "SRConstants.mqh"

//+------------------------------------------------------------------+
//| Pip size (aman untuk broker 3/5 digit)                           |
//+------------------------------------------------------------------+
double PipSize(const string symbol)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return(point * 10.0);
   return(point);
  }

//+------------------------------------------------------------------+
//| Pips -> price distance                                           |
//+------------------------------------------------------------------+
double PipsToPrice(const string symbol, const double pips)
  {
   return(pips * PipSize(symbol));
  }

//+------------------------------------------------------------------+
//| Price distance -> pips                                           |
//+------------------------------------------------------------------+
double PriceToPips(const string symbol, const double priceDistance)
  {
   double pip = PipSize(symbol);
   if(pip <= 0.0)
      return(0.0);
   return(priceDistance / pip);
  }

//+------------------------------------------------------------------+
//| Entry window check (GMT)                                         |
//+------------------------------------------------------------------+
bool IsEntryWindow(const datetime gmtTime, SRStrategyConfig &cfg)
  {
   MqlDateTime t;
   TimeToStruct(gmtTime, t);
   int currentMinutes = t.hour * 60 + t.min;
   int startMinutes = cfg.EntryStartHourGMT * 60 + cfg.EntryStartMinuteGMT;
   int endMinutes = cfg.EntryEndHourGMT * 60 + cfg.EntryEndMinuteGMT;
   return(currentMinutes >= startMinutes && currentMinutes < endMinutes);
  }

//+------------------------------------------------------------------+
//| Force-close check (GMT): tutup jika >= 20:00 GMT                 |
//+------------------------------------------------------------------+
bool IsForceCloseTime(const datetime gmtTime, SRStrategyConfig &cfg)
  {
   MqlDateTime t;
   TimeToStruct(gmtTime, t);
   int currentMinutes = t.hour * 60 + t.min;
   int forceMinutes = cfg.ForceCloseHourGMT * 60 + cfg.ForceCloseMinuteGMT;
   return(currentMinutes >= forceMinutes);
  }

//+------------------------------------------------------------------+
//| Source identity (untuk Cluster Score)                            |
//+------------------------------------------------------------------+
bool IsSameSource(const ENUM_SR_SOURCE a, const ENUM_SR_SOURCE b)
  {
   return(a == b);
  }

#endif // __OBJECTIVE_SR_UTILS_MQH__
