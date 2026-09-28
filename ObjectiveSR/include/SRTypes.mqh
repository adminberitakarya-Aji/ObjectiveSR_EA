//+------------------------------------------------------------------+
//| SRTypes.mqh - ObjectiveSR Phase 1                                |
//| SRLevel, SRCluster, SRTouch, SRTrendState, SRTradeSetup,         |
//| SRRiskState, SRTradeRecord                                       |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_TYPES_MQH__
#define __OBJECTIVE_SR_TYPES_MQH__

#include "SRConstants.mqh"

//+------------------------------------------------------------------+
//| Raw S&R level                                                    |
//+------------------------------------------------------------------+
struct SRLevel
  {
   double            Price;
   ENUM_SR_SOURCE    Source;
   datetime          FormedTime;
   bool              Active;
   bool              Fresh;
   int               SourceBarShift;
   int               TouchCount;
   datetime          LastTouchTime;
  };

//+------------------------------------------------------------------+
//| Cluster of S&R levels (tanpa array SRLevel di dalam, Phase 1)    |
//+------------------------------------------------------------------+
struct SRCluster
  {
   double            Center;
   double            Upper;
   double            Lower;
   double            ZoneWidth;
   int               SourceCount;
   int               TouchCount;
   ENUM_SR_STATE     State;
   ENUM_SR_FRESH_STATE FreshState;
   datetime          CreatedTime;
   datetime          LastTouchTime;
   int               LevelCount;
  };

//+------------------------------------------------------------------+
//| Individual touch                                                 |
//+------------------------------------------------------------------+
struct SRTouch
  {
   datetime          Time;
   int               BarShift;
   double            BarHigh;
   double            BarLow;
   double            BarClose;
   bool              Valid;
   bool              SpacingValid;
  };

//+------------------------------------------------------------------+
//| H4 trend state                                                   |
//+------------------------------------------------------------------+
struct SRTrendState
  {
   bool              LongAllowed;
   bool              ShortAllowed;
   double            H4Close;
   double            EMA50Current;
   double            EMA50Previous;
   double            EMA50SlopeReference;
  };

//+------------------------------------------------------------------+
//| Trade setup (output Entry Engine)                                |
//+------------------------------------------------------------------+
struct SRTradeSetup
  {
   bool              Valid;
   ENUM_SR_DIRECTION Direction;
   ENUM_SR_PATTERN   Pattern;
   int               ClusterIndex;
   double            EntryPrice;
   double            StopLoss;
   double            TakeProfit;
   double            RiskPips;
   double            RewardPips;
   double            RR;
   double            SpreadPips;
   int               TouchCount;
   int               ClusterScore;
   datetime          SignalTime;
  };

//+------------------------------------------------------------------+
//| Risk state                                                       |
//+------------------------------------------------------------------+
struct SRRiskState
  {
   double            RiskPercent;
   double            DailyLossR;
   double            WeeklyLossR;
   int               ConsecutiveLosses;
   int               TradesToday;
   bool              DailyLimitReached;
   bool              WeeklyLimitReached;
   bool              ReducedRiskMode;
  };

//+------------------------------------------------------------------+
//| Completed trade record (CSV logger)                              |
//+------------------------------------------------------------------+
struct SRTradeRecord
  {
   datetime          EntryTime;
   datetime          ExitTime;
   string            Symbol;
   ENUM_SR_DIRECTION Direction;
   ENUM_SR_PATTERN   Pattern;
   double            EntryPrice;
   double            StopLoss;
   double            TakeProfit;
   double            ExitPrice;
   double            RiskPips;
   double            RewardPips;
   double            RR;
   double            SpreadPips;
   ENUM_SR_SOURCE    PrimarySource;
   int               ClusterScore;
   int               TouchCount;
   double            ZoneUpper;
   double            ZoneLower;
   double            H4Close;
   double            EMA50;
   double            MAE;
   double            MFE;
   ENUM_SR_EXIT_REASON ExitReason;
   double            ResultR;
   double            ResultMoney;
  };

#endif // __OBJECTIVE_SR_TYPES_MQH__
