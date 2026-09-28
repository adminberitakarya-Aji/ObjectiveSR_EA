//+------------------------------------------------------------------+
//| SRTouchEngine.mqh - ObjectiveSR M5                                |
//| Touch M15 + spacing 6 + invalidation + FreshOnly. Closed-bar.     |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_TOUCH_ENGINE_MQH__
#define __OBJECTIVE_SR_TOUCH_ENGINE_MQH__
#include "SRTypes.mqh"
#include "SRConfig.mqh"
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
//--- Spacing: scan BARU->lama (shift 1..maxScan, waktu mundur).
//--- Gap waktu = curShift - prevShift (keduanya shift M15).
//--- Touch berikutnya valid jika (curShift - prevShift) >= minGap.
bool CheckTouchSpacing(int prevShift, int curShift, int minGap)
  { return((curShift-prevShift)>=minGap); }
//--- Invalidation: close tembus >1 ZW di luar zone (sisa hari)
bool IsInvalidatedClose(bool isSupport, double close, double zu,
                        double zl, double zw)
  {
   if(isSupport) return(close<zl-zw);
   return(close>zu+zw);
  }
//--- Update touches+invalidation semua cluster dari M15 closed.
//--- Scan BARU->lama (shift 1..maxScan) agar break invalidation benar:
//--- bar terbaru dicek dulu; jika close tembus jauh -> INVALIDATED.
//--- LastTouchTime = touch terbaru (paling dekat dgn harga kini).
//--- Return: jumlah touch valid total semua cluster.
int UpdateTouches(string sym, SRStrategyConfig &st, SRCluster &cl[])
  {
   int n=ArraySize(cl); int tot=0;
   int maxScan=120;
   int av=Bars(sym,PERIOD_M15); if(av>0 && av<maxScan+2) maxScan=av-2;
   if(maxScan<1) return(0);
   for(int c=0;c<n;c++)
     {
      double zu=cl[c].Upper, zl=cl[c].Lower, zw=cl[c].ZoneWidth;
      double mid=(zu+zl)/2.0;
      cl[c].TouchCount=0; cl[c].LastTouchTime=0;
      cl[c].State=SR_STATE_ACTIVE; cl[c].FreshState=SR_FRESH;
      int prevShift=-1; bool sup=true; // -1 = belum ada touch
      for(int sh=1;sh<=maxScan;sh++)
        {
         double bh=iHigh(sym,PERIOD_M15,sh);
         double bl=iLow(sym,PERIOD_M15,sh);
         double cc=iClose(sym,PERIOD_M15,sh);
         datetime bt=iTime(sym,PERIOD_M15,sh);
         if(bh<=0||bl<=0||cc<=0||bt==0) continue;
         //--- Orientasi: support jika close di atas mid, resist jika di bawah
         //--- Tepat di mid (cc==mid): default support agar deterministik
         sup=(cc>=mid);
         if(IsInvalidatedClose(sup,cc,zu,zl,zw))
           { cl[c].State=SR_STATE_INVALIDATED; break; }
         if(!IsValidTouch(sup,bh,bl,cc,zu,zl,zw)) continue;
         if(cl[c].TouchCount>0 &&
            !CheckTouchSpacing(prevShift,sh,st.TouchMinSpacingBars))
            continue;
         cl[c].TouchCount++; tot++;
         if(cl[c].LastTouchTime==0) cl[c].LastTouchTime=bt; // sentuh terbaru
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
