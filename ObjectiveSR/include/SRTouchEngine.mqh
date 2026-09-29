//+------------------------------------------------------------------+
//| SRTouchEngine.mqh - ObjectiveSR M5                                |
//| Touch M15 + spacing 6 + invalidation (per-hari GMT) + FreshOnly.  |
//| Closed-bar.                                                       |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_TOUCH_ENGINE_MQH__
#define __OBJECTIVE_SR_TOUCH_ENGINE_MQH__
#include "SRTypes.mqh"
#include "SRConfig.mqh"
#include "SRMarket.mqh"
//--- Overlap: range candle masuk zone?
bool TouchOverlaps(double bh, double bl, double zu, double zl)
  { return(bh>=zl && bl<=zu); }
//--- Close-filter: close tidak >1 zone-width di luar zone
//--- Support: Close>=Lower-ZW | Resist: Close<=Upper+ZW
bool TouchCloseOK(bool isSupport, double close, double zu, double zl,
                  double zw)
  {
   if(isSupport) return(close>=zl-zw);
   return(close<=zu+zw);
  }
//--- Valid touch satu bar (tanpa spacing)
bool IsValidTouch(bool isSupport, double bh, double bl, double close,
                  double zu, double zl, double zw)
  {
   if(!TouchOverlaps(bh,bl,zu,zl)) return(false);
   return(TouchCloseOK(isSupport,close,zu,zl,zw));
  }
//--- Spacing: gap = prevShift - curShift (scan tua->muda, shift mengecil)
//--- Touch berikutnya valid jika (prevShift - curShift) >= minGap
bool CheckTouchSpacing(int prevShift, int curShift, int minGap)
  { return((prevShift-curShift)>=minGap); }
//--- Invalidation: close tembus >1 ZW di luar zone (sisa hari)
bool IsInvalidatedClose(bool isSupport, double close, double zu,
                        double zl, double zw)
  {
   if(isSupport) return(close<zl-zw);
   return(close>zu+zw);
  }
//--- FIX (window 30 jam): histori touch/fresh dulu dibatasi 120 bar M15
//--- (~30 jam) untuk SEMUA cluster, padahal H4 swing punya lookback
//--- sampai SwingLookbackDays (default 20 hari). Akibatnya touch lama
//--- tidak pernah terhitung -> MinTouches/FreshOnly salah baca level
//--- yang sudah lama terbentuk. Sekarang window ikut SwingLookbackDays.
int TouchHistoryBars(string sym, SRStrategyConfig &st)
  {
   int perDay=96; // 24j / 15m
   int want=MathMax(st.SwingLookbackDays,1)*perDay;
   if(want<120) want=120;          // minimal tetap ~30 jam
   if(want>3000) want=3000;        // batas wajar, cukup utk 20 hari + slack
   int av=Bars(sym,PERIOD_M15);
   if(av>0 && av<want+2) want=av-2;
   return(MathMax(want,1));
  }
//--- FIX (window 30 jam): shift bar M15 pertama pada HARI GMT BERJALAN.
//--- Dipakai supaya invalidasi cuma berlaku "sisa hari" sesuai spec --
//--- sebelumnya window scan (30 jam) melewati batas hari, jadi breach
//--- kemarin sore bisa ikut membuat level INVALIDATED sampai besok siang.
int TodayStartShift(string sym)
  {
   datetime gmt=MarketGetGMT();
   MqlDateTime g; TimeToStruct(gmt,g);
   datetime gmtDayStart=gmt-(g.hour*3600+g.min*60+g.sec);
   datetime serverDayStart=gmtDayStart-MarketGMTOffsetSec();
   int shift=iBarShift(sym,PERIOD_M15,serverDayStart,false);
   if(shift<1) shift=1;
   return(shift);
  }
//--- Update touches (histori penuh sesuai SwingLookbackDays) + invalidation
//--- (hari GMT berjalan saja) semua cluster dari M15 closed.
//--- Scan shift=maxScan..1 (tua->muda) agar spacing berurutan waktu.
//--- Return: jumlah touch valid total semua cluster.
int UpdateTouches(string sym, SRStrategyConfig &st, SRCluster &cl[])
  {
   int n=ArraySize(cl); int tot=0;
   int maxScan=TouchHistoryBars(sym,st);
   if(maxScan<1) return(0);
   int todayShift=TodayStartShift(sym);
   if(todayShift>maxScan) todayShift=maxScan; // data pendek/hari pertama jalan
   for(int c=0;c<n;c++)
     {
      double zu=cl[c].Upper, zl=cl[c].Lower, zw=cl[c].ZoneWidth;
      double mid=(zu+zl)/2.0;
      cl[c].TouchCount=0; cl[c].LastTouchTime=0;
      cl[c].State=SR_STATE_ACTIVE; cl[c].FreshState=SR_FRESH;
      int prevShift=-1; bool sup=true; // -1 = belum ada touch
      for(int sh=maxScan;sh>=1;sh--)
        {
         double bh=iHigh(sym,PERIOD_M15,sh);
         double bl=iLow(sym,PERIOD_M15,sh);
         double cc=iClose(sym,PERIOD_M15,sh);
         datetime bt=iTime(sym,PERIOD_M15,sh);
         if(bh<=0||bl<=0||cc<=0||bt==0) continue;
         //--- Orientasi: support jika close di atas mid, resist jika di bawah
         //--- Tepat di mid (cc==mid): default support agar deterministik
         sup=(cc>=mid);
         bool invClose=IsInvalidatedClose(sup,cc,zu,zl,zw);
         if(invClose && sh<=todayShift)
           { cl[c].State=SR_STATE_INVALIDATED; break; } // invalidasi HARI INI
         if(invClose)
            continue; // breach di hari sebelumnya: tidak invalidasi hari ini,
                      // bar itu sendiri bukan touch valid (skip, jangan break)
         if(!IsValidTouch(sup,bh,bl,cc,zu,zl,zw)) continue;
         if(cl[c].TouchCount>0 &&
            !CheckTouchSpacing(prevShift,sh,st.TouchMinSpacingBars))
            continue;
         cl[c].TouchCount++; tot++;
         cl[c].LastTouchTime=bt;
         cl[c].FreshState=SR_TOUCHED;
         prevShift=sh;
        }
     }
   return(tot);
  }
//--- MinTouches gate (untuk entry M6+)
bool PassesMinTouches(SRCluster &c, SRSymbolConfig &sc)
  { return(c.TouchCount>=sc.MinTouches); }
//--- FreshOnly gate: jika FreshOnly, cluster TOUCHED ditolak
bool PassesFresh(SRCluster &c, SRStrategyConfig &st)
  {
   if(!st.FreshOnly) return(true);
   return(c.FreshState==SR_FRESH);
  }
#endif
