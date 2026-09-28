//+------------------------------------------------------------------+
//| SRMarket.mqh - ObjectiveSR M2                                    |
//| GMT, spread, session, new-bar helpers (closed-bar, TimeGMT)      |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_MARKET_MQH__
#define __OBJECTIVE_SR_MARKET_MQH__

#include "include/SRUtils.mqh"

//+------------------------------------------------------------------+
//| Current GMT (acuan tunggal strategi)                             |
//+------------------------------------------------------------------+
datetime MarketGetGMT()
  {
   return(TimeGMT());
  }

//+------------------------------------------------------------------+
//| Server -> GMT offset in seconds                                  |
//+------------------------------------------------------------------+
int MarketGMTOffsetSec()
  {
   datetime gmt = TimeGMT();
   datetime srv = TimeTradeServer();
   if(gmt == 0 || srv == 0)
      return(0);
   return((int)(gmt - srv));
  }

//+------------------------------------------------------------------+
//| Convert server bar time -> GMT                                   |
//+------------------------------------------------------------------+
datetime MarketServerToGMT(const datetime serverTime)
  {
   return(serverTime + MarketGMTOffsetSec());
  }

//+------------------------------------------------------------------+
//| Spread in pips (aman 3/5 digit)                                  |
//+------------------------------------------------------------------+
double MarketSpreadPips(const string symbol)
  {
   long spreadPoints = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_SPREAD, spreadPoints))
      return(0.0);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double pip = point;
   if(digits == 3 || digits == 5)
      pip = point * 10.0;
   if(pip <= 0.0)
      return(0.0);
   return((double)spreadPoints * point / pip);
  }

//+------------------------------------------------------------------+
//| New-bar check: true sekali saat bar 0 berganti                   |
//+------------------------------------------------------------------+
bool MarketIsNewBar(const string symbol, const ENUM_TIMEFRAMES tf,
                    datetime &lastBarTime)
  {
   datetime cur = iTime(symbol, tf, 0);
   if(cur == 0)
      return(false);
   if(cur != lastBarTime)
     {
      lastBarTime = cur;
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Entry session check (bungkus IsEntryWindow dgn TimeGMT)          |
//+------------------------------------------------------------------+
bool MarketIsEntrySession(SRStrategyConfig &cfg)
  {
   return(IsEntryWindow(MarketGetGMT(), cfg));
  }

//+------------------------------------------------------------------+
//| Force-close check (bungkus IsForceCloseTime dgn TimeGMT)         |
//+------------------------------------------------------------------+
bool MarketIsForceClose(SRStrategyConfig &cfg)
  {
   return(IsForceCloseTime(MarketGetGMT(), cfg));
  }

#endif // __OBJECTIVE_SR_MARKET_MQH__
