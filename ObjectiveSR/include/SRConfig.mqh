//+------------------------------------------------------------------+
//| SRConfig.mqh - ObjectiveSR Phase 1                              |
//| Symbol config + strategy config + defaults EURUSD/GBPUSD        |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_CONFIG_MQH__
#define __OBJECTIVE_SR_CONFIG_MQH__

//+------------------------------------------------------------------+
//| Symbol-specific configuration                                    |
//+------------------------------------------------------------------+
struct SRSymbolConfig
  {
   string            Symbol;
   double            ZoneHalfPips;
   double            SLBufferPips;
   double            MinSLPips;
   double            MaxSLPips;
   double            ClusterDistancePips;
   double            MinRR;
   int               MinTouches;
   double            MaxSpreadPips;
  };

//+------------------------------------------------------------------+
//| Global strategy configuration                                    |
//+------------------------------------------------------------------+
struct SRStrategyConfig
  {
   double            RiskPercent;
   double            DailyMaxLossR;
   double            WeeklyMaxLossR;
   int               ConsecutiveLossTrigger;
   double            ReducedRiskPercent;
   int               EntryStartHourGMT;
   int               EntryStartMinuteGMT;
   int               EntryEndHourGMT;
   int               EntryEndMinuteGMT;
   int               ForceCloseHourGMT;
   int               ForceCloseMinuteGMT;
   int               SwingLookbackDays;
   int               SwingLeftBars;
   int               SwingRightBars;
   int               TouchMinSpacingBars;
   double            TPBufferPips;
   double            MaxRewardR;
   bool              FreshOnly;
   bool              NewsFilterEnabled;
  };

//+------------------------------------------------------------------+
//| EURUSD default (Spec #67)                                        |
//+------------------------------------------------------------------+
SRSymbolConfig DefaultEURUSDConfig()
  {
   SRSymbolConfig cfg;
   cfg.Symbol              = "EURUSD";
   cfg.ZoneHalfPips        = 5.0;
   cfg.SLBufferPips        = 4.0;
   cfg.MinSLPips           = 8.0;
   cfg.MaxSLPips           = 25.0;
   cfg.ClusterDistancePips = 10.0;
   cfg.MinRR               = 1.5;
   cfg.MinTouches          = 2;
   cfg.MaxSpreadPips       = 2.0;
   return(cfg);
  }

//+------------------------------------------------------------------+
//| GBPUSD default (Spec #68)                                        |
//+------------------------------------------------------------------+
SRSymbolConfig DefaultGBPUSDConfig()
  {
   SRSymbolConfig cfg;
   cfg.Symbol              = "GBPUSD";
   cfg.ZoneHalfPips        = 7.0;
   cfg.SLBufferPips        = 6.0;
   cfg.MinSLPips           = 10.0;
   cfg.MaxSLPips           = 35.0;
   cfg.ClusterDistancePips = 10.0;
   cfg.MinRR               = 1.5;
   cfg.MinTouches          = 2;
   cfg.MaxSpreadPips       = 3.0;
   return(cfg);
  }

//+------------------------------------------------------------------+
//| Default strategy configuration                                   |
//+------------------------------------------------------------------+
SRStrategyConfig DefaultStrategyConfig()
  {
   SRStrategyConfig cfg;
   cfg.RiskPercent           = 0.5;
   cfg.DailyMaxLossR         = 2.0;
   cfg.WeeklyMaxLossR        = 4.0;
   cfg.ConsecutiveLossTrigger = 3;
   cfg.ReducedRiskPercent    = 0.25;
   cfg.EntryStartHourGMT     = 7;
   cfg.EntryStartMinuteGMT   = 0;
   cfg.EntryEndHourGMT       = 16;
   cfg.EntryEndMinuteGMT     = 0;
   cfg.ForceCloseHourGMT     = 20;
   cfg.ForceCloseMinuteGMT   = 0;
   cfg.SwingLookbackDays     = 20;
   cfg.SwingLeftBars         = 2;
   cfg.SwingRightBars        = 2;
   cfg.TouchMinSpacingBars   = 6;
   cfg.TPBufferPips          = 2.0;
   cfg.MaxRewardR            = 3.0;
   cfg.FreshOnly             = false;
   cfg.NewsFilterEnabled     = true;
   return(cfg);
  }

#endif // __OBJECTIVE_SR_CONFIG_MQH__
