//+------------------------------------------------------------------+
//| SRLevelEngine.mqh - ObjectiveSR M3                               |
//| PDH/PDL, PWH/PWL, AsiaHL, RoundNumber, H4Swing -> SRLevel[]      |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_LEVEL_ENGINE_MQH__
#define __OBJECTIVE_SR_LEVEL_ENGINE_MQH__
#include "SRTypes.mqh"
#include "SRConfig.mqh"
#include "SRUtils.mqh"
#include "SRMarket.mqh"
void LevelAppend(SRLevel &levels[], double price, ENUM_SR_SOURCE src,
                 datetime ft, int sh)
  {
   int n=ArraySize(levels); ArrayResize(levels,n+1);
   levels[n].Price=price; levels[n].Source=src; levels[n].FormedTime=ft;
   levels[n].Active=true; levels[n].Fresh=true; levels[n].SourceBarShift=sh;
   levels[n].TouchCount=0; levels[n].LastTouchTime=0;
  }
int CollectPDH_PDL(string symbol, SRLevel &levels[])
  {
   double hi=iHigh(symbol,PERIOD_D1,1);
   double lo=iLow(symbol,PERIOD_D1,1);
   datetime bt=iTime(symbol,PERIOD_D1,1);
   if(hi<=0 || lo<=0 || bt==0) return(0);
   LevelAppend(levels,hi,SR_SOURCE_PDH,bt,1);
   LevelAppend(levels,lo,SR_SOURCE_PDL,bt,1);
   return(2);
  }
int CollectPWH_PWL(string symbol, SRLevel &levels[])
  {
   double hi=iHigh(symbol,PERIOD_W1,1);
   double lo=iLow(symbol,PERIOD_W1,1);
   datetime bt=iTime(symbol,PERIOD_W1,1);
   if(hi<=0 || lo<=0 || bt==0) return(0);
   LevelAppend(levels,hi,SR_SOURCE_PWH,bt,1);
   LevelAppend(levels,lo,SR_SOURCE_PWL,bt,1);
   return(2);
  }
int CollectAsiaHL(string symbol, SRLevel &levels[], int off)
  {
//--- Hari acuan = GMT day dari M15 shift 1 (closed terakhir)
   datetime r1=iTime(symbol,PERIOD_M15,1); if(r1==0) return(0);
   MqlDateTime rd; TimeToStruct(r1+off,rd);
   double hi=0, lo=0; bool f=false; int mx=200;
   int av=Bars(symbol,PERIOD_M15); if(av>0 && av<mx) mx=av;
   for(int sh=1;sh<=mx;sh++)
     {
      datetime st=iTime(symbol,PERIOD_M15,sh); if(st==0) break;
      MqlDateTime d; TimeToStruct(st+off,d);
//--- Hanya hari GMT yang sama dengan bar acuan
      if(d.year!=rd.year||d.mon!=rd.mon||d.day!=rd.day) continue;
      int m=d.hour*60+d.min; if(m<0||m>=420) continue;
      double h=iHigh(symbol,PERIOD_M15,sh);
      double l=iLow(symbol,PERIOD_M15,sh);
      if(h<=0||l<=0) continue;
      if(!f){hi=h;lo=l;f=true;} else {if(h>hi)hi=h; if(l<lo)lo=l;}
     }
   if(!f) return(0);
   MqlDateTime r=rd; r.hour=7; r.min=0; r.sec=0;
   datetime ft=StructToTime(r);
   LevelAppend(levels,hi,SR_SOURCE_ASIA_HIGH,ft,1);
   LevelAppend(levels,lo,SR_SOURCE_ASIA_LOW,ft,1);
   return(2);
  }
int CollectRoundNumbers(string symbol, SRLevel &levels[], int each=2)
  {
   double bid=SymbolInfoDouble(symbol,SYMBOL_BID);
   if(bid<=0) bid=iClose(symbol,PERIOD_M15,1); if(bid<=0) return(0);
   double pip=PipSize(symbol); if(pip<=0) return(0);
   double step=50.0*pip;
   int dg=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double base=MathFloor(bid/step)*step;
   datetime ng=TimeGMT(); int ad=0;
   for(int k=-each;k<=each;k++)
     { double lv=NormalizeDouble(base+k*step,dg);
       if(lv<=0) continue;
       LevelAppend(levels,lv,SR_SOURCE_ROUND_NUMBER,ng,0); ad++; }
   return(ad);
  }
//+------------------------------------------------------------------+
//| H4 Swing fractal 2/2 (mulai shift 3 agar kanan sudah close)      |
//+------------------------------------------------------------------+
int CollectH4Swings(string symbol, SRLevel &levels[], int days,
                    int left, int right)
  {
   int maxB=days*6; int av=Bars(symbol,PERIOD_H4);
   if(av<=0) return(0); if(av<maxB) maxB=av;
   int s0=right+1; int s1=maxB-left; if(s1<s0) return(0); int ad=0;
   for(int s=s0;s<=s1;s++)
     {
      double h0=iHigh(symbol,PERIOD_H4,s);
      double l0=iLow(symbol,PERIOD_H4,s);
      if(h0<=0 || l0<=0) continue;
      bool ih=true, il=true;
      for(int k=1;k<=left;k++)
        { if(iHigh(symbol,PERIOD_H4,s+k)>=h0) ih=false;
          if(iLow(symbol,PERIOD_H4,s+k)<=l0) il=false; }
      for(int k=1;k<=right;k++)
        { if(iHigh(symbol,PERIOD_H4,s-k)>=h0) ih=false;
          if(iLow(symbol,PERIOD_H4,s-k)<=l0) il=false; }
      datetime bt=iTime(symbol,PERIOD_H4,s);
      if(ih) {LevelAppend(levels,h0,SR_SOURCE_H4_SWING_HIGH,bt,s); ad++;}
      if(il) {LevelAppend(levels,l0,SR_SOURCE_H4_SWING_LOW,bt,s); ad++;}
     }
   return(ad);
  }
int RebuildAllLevels(string symbol, SRStrategyConfig &st, SRLevel &lv[])
  {
   ArrayResize(lv,0); int t=0;
   t+=CollectPDH_PDL(symbol,lv); t+=CollectPWH_PWL(symbol,lv);
   t+=CollectAsiaHL(symbol,lv,MarketGMTOffsetSec());
   t+=CollectRoundNumbers(symbol,lv,2);
   t+=CollectH4Swings(symbol,lv,st.SwingLookbackDays,
                      st.SwingLeftBars,st.SwingRightBars);
   return(t);
  }
#endif
