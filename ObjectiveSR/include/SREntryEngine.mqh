//+------------------------------------------------------------------+
//| SREntryEngine.mqh - ObjectiveSR M6b                               |
//| Pin (wick>=2x body) + Engulfing strict. M15 shift 1, closed-bar.  |
//| Equality: body>0 wajib; engulf strict > (sama = bukan engulf).    |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_ENTRY_ENGINE_MQH__
#define __OBJECTIVE_SR_ENTRY_ENGINE_MQH__
#include "include/SRTypes.mqh"
#include "include/SRConfig.mqh"
#include "include/SRTouchEngine.mqh"
//--- Wick/body M15 shift s
void CandleParts(string sym, int s, double &o, double &h, double &l,
                 double &c)
  { o=iOpen(sym,PERIOD_M15,s); h=iHigh(sym,PERIOD_M15,s);
    l=iLow(sym,PERIOD_M15,s); c=iClose(sym,PERIOD_M15,s); }
//--- Bullish pin: lower wick >= 2*body, body>0
bool IsBullishPin(string sym, int s=1)
  {
   double o,h,l,c; CandleParts(sym,s,o,h,l,c);
   if(h<=0||l<=0) return(false);
   double body=MathAbs(c-o); if(body<=0) return(false);
   double lw=MathMin(o,c)-l;
   return(lw>=2.0*body);
  }
//--- Bearish pin: upper wick >= 2*body, body>0
bool IsBearishPin(string sym, int s=1)
  {
   double o,h,l,c; CandleParts(sym,s,o,h,l,c);
   if(h<=0||l<=0) return(false);
   double body=MathAbs(c-o); if(body<=0) return(false);
   double uw=h-MathMax(o,c);
   return(uw>=2.0*body);
  }
//--- Bullish engulfing strict: prev bearish (c<o), curr bullish (c>o),
//--- body curr menelan body prev secara STRICT (>, bukan >=)
bool IsBullishEngulfing(string sym, int s=1)
  {
   double o0,h0,l0,c0; CandleParts(sym,s,o0,h0,l0,c0);
   double o1,h1,l1,c1; CandleParts(sym,s+1,o1,h1,l1,c1);
   if(o0<=0||c0<=0||o1<=0||c1<=0) return(false);
   if(!(c1<o1)) return(false); // prev harus bearish strict
   if(!(c0>o0)) return(false); // curr harus bullish strict
   double prevTop=o1, prevBot=c1, curTop=c0, curBot=o0;
   return(curTop>prevTop && curBot<prevBot);
  }
//--- Bearish engulfing strict (kebalikan)
bool IsBearishEngulfing(string sym, int s=1)
  {
   double o0,h0,l0,c0; CandleParts(sym,s,o0,h0,l0,c0);
   double o1,h1,l1,c1; CandleParts(sym,s+1,o1,h1,l1,c1);
   if(o0<=0||c0<=0||o1<=0||c1<=0) return(false);
   if(!(c1>o1)) return(false); // prev harus bullish strict
   if(!(c0<o0)) return(false); // curr harus bearish strict
   double prevTop=c1, prevBot=o1, curTop=o0, curBot=c0;
   return(curTop>prevTop && curBot<prevBot);
  }
//--- Deteksi pola satu bar: prioritas Pin dulu, lalu Engulfing
ENUM_SR_PATTERN DetectPattern(string sym, bool wantLong, int s=1)
  {
   if(wantLong)
     { if(IsBullishPin(sym,s)) return(SR_PATTERN_BULLISH_PIN);
       if(IsBullishEngulfing(sym,s)) return(SR_PATTERN_BULLISH_ENGULFING);
       return(SR_PATTERN_NONE); }
   if(IsBearishPin(sym,s)) return(SR_PATTERN_BEARISH_PIN);
   if(IsBearishEngulfing(sym,s)) return(SR_PATTERN_BEARISH_ENGULFING);
   return(SR_PATTERN_NONE);
  }
//--- Scan sinyal di cluster: M15 shift1 masuk zone + close sisi benar
//--- + pola + trend + MinTouches + Fresh + state. Tanpa SL/TP/RR (M7).
//--- Return: index cluster sinyal, -1 jika tidak ada. Isi setup dasar.
int ScanEntry(string sym, SRSymbolConfig &sc, SRStrategyConfig &st,
              SRCluster &cl[], SRTrendState &tr, SRTradeSetup &setup)
  {
   ZeroMemory(setup); setup.Valid=false;
   double bh=iHigh(sym,PERIOD_M15,1), bl=iLow(sym,PERIOD_M15,1);
   double cc=iClose(sym,PERIOD_M15,1);
   datetime bt=iTime(sym,PERIOD_M15,1);
   if(bh<=0||bl<=0||cc<=0||bt==0) return(-1);
   int best=-1;
   for(int i=0;i<ArraySize(cl);i++)
     {
      if(cl[i].State!=SR_STATE_ACTIVE) continue;
      if(!PassesFresh(cl[i],st)) continue;
      if(cl[i].TouchCount<sc.MinTouches) continue;
      double zu=cl[i].Upper, zl=cl[i].Lower;
      if(!(bh>=zl && bl<=zu)) continue; // shift1 harus masuk zone
      bool sup=(cc>=((zu+zl)/2.0));
      if(sup) // kandidat LONG
        {
         if(!tr.LongAllowed) continue;
         if(!(cc>cl[i].Center)) continue; // close > level cluster
         ENUM_SR_PATTERN p=DetectPattern(sym,true,1);
         if(p==SR_PATTERN_NONE) continue;
         best=i; setup.Valid=true; setup.Direction=SR_DIRECTION_LONG;
         setup.Pattern=p; setup.ClusterIndex=i; setup.SignalTime=bt;
         setup.TouchCount=cl[i].TouchCount; setup.ClusterScore=cl[i].SourceCount;
         break; // cluster pertama (termurah/terbawah) yg lolos
        }
      else // kandidat SHORT
        {
         if(!tr.ShortAllowed) continue;
         if(!(cc<cl[i].Center)) continue; // close < level cluster
         ENUM_SR_PATTERN p=DetectPattern(sym,false,1);
         if(p==SR_PATTERN_NONE) continue;
         best=i; setup.Valid=true; setup.Direction=SR_DIRECTION_SHORT;
         setup.Pattern=p; setup.ClusterIndex=i; setup.SignalTime=bt;
         setup.TouchCount=cl[i].TouchCount; setup.ClusterScore=cl[i].SourceCount;
         break;
        }
     }
   return(best);
  }
#endif
