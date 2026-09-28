//+------------------------------------------------------------------+
//| SRLogger.mqh - ObjectiveSR M8                                     |
//| CSV: trades + signals. MAE/MFE dilacak per-tick saat posisi buka. |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_LOGGER_MQH__
#define __OBJECTIVE_SR_LOGGER_MQH__
#include "include/SRTypes.mqh"
#include "include/SRUtils.mqh"
//--- Nama file per EA+symbol+tanggal GMT (append, header sekali)
string LoggerTradeFile(string sym)
  {
   MqlDateTime g; TimeToStruct(TimeGMT(),g);
   return(StringFormat("ObjectiveSR_%s_%04d%02d%02d_trades.csv",
                       sym,g.year,g.mon,g.day));
  }
string LoggerSignalFile(string sym)
  {
   MqlDateTime g; TimeToStruct(TimeGMT(),g);
   return(StringFormat("ObjectiveSR_%s_%04d%02d%02d_signals.csv",
                       sym,g.year,g.mon,g.day));
  }
void LoggerWriteHeader(string file, string header)
  {
   int h=FileOpen(file,FILE_READ|FILE_TXT|FILE_ANSI);
   bool need=(h==INVALID_HANDLE);
   if(!need) FileClose(h);
   if(!need) return;
   h=FileOpen(file,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return;
   FileWriteString(h,header+"\r\n");
   FileClose(h);
  }
void LoggerAppend(string file, string line)
  {
   int h=FileOpen(file,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return;
   FileSeek(h,0,SEEK_END);
   FileWriteString(h,line+"\r\n");
   FileClose(h);
  }
string LoggerTradeHeader()
  {
   return("Date,TimeGMT,Symbol,Direction,Entry,SL,TP,LevelSource,"
          "ClusterScore,TouchCount,ZoneUpper,ZoneLower,H4Close,EMA50,"
          "Pattern,RR,Spread,SessionHour,MAE,MFE,ExitPrice,ExitReason,"
          "ResultR,ResultMoney");
  }
string LoggerSignalHeader()
  {
   return("Date,TimeGMT,Symbol,Direction,Pattern,ClusterIdx,"
          "ClusterScore,TouchCount,ZoneUpper,ZoneLower,H4Close,EMA50,"
          "Entry,SL,TP,RR,Spread,Note");
  }
//--- Sumber dominan cluster: tipe level terbanyak dlm radius zone
string ClusterSources(string sym, SRLevel &lv[], SRCluster &c)
  {
   int cnt[9]; for(int i=0;i<9;i++) cnt[i]=0;
   for(int i=0;i<ArraySize(lv);i++)
     {
      if(lv[i].Price>=c.Lower && lv[i].Price<=c.Upper)
         cnt[(int)lv[i].Source]++;
     }
   string s="";
   for(int k=0;k<9;k++)
     {
      if(cnt[k]<=0) continue;
      string nm=EnumToString((ENUM_SR_SOURCE)k);
      StringReplace(nm,"SR_SOURCE_","");
      if(StringLen(s)>0) s+="|";
      s+=nm+":"+IntegerToString(cnt[k]);
     }
   if(StringLen(s)==0) s="UNKNOWN";
   return(s);
  }
ENUM_SR_SOURCE ClusterPrimary(string sym, SRLevel &lv[], SRCluster &c)
  {
   int cnt[9]; for(int i=0;i<9;i++) cnt[i]=0;
   for(int i=0;i<ArraySize(lv);i++)
     {
      if(lv[i].Price>=c.Lower && lv[i].Price<=c.Upper)
         cnt[(int)lv[i].Source]++;
     }
   int best=0;
   for(int k=1;k<9;k++) if(cnt[k]>cnt[best]) best=k;
   return((ENUM_SR_SOURCE)best);
  }
string DirName(ENUM_SR_DIRECTION d)
  { return(d==SR_DIRECTION_LONG?"LONG":(d==SR_DIRECTION_SHORT?"SHORT":"NONE")); }
string PatName(ENUM_SR_PATTERN p)
  {
   string s=EnumToString(p); StringReplace(s,"SR_PATTERN_","");
   return(s);
  }
string ExitName(ENUM_SR_EXIT_REASON e)
  {
   string s=EnumToString(e); StringReplace(s,"SR_EXIT_","");
   return(s);
  }
#endif
