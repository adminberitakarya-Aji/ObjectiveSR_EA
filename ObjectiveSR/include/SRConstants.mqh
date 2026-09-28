//+------------------------------------------------------------------+
//| SRConstants.mqh - ObjectiveSR Phase 1                            |
//| Level source, state, direction, pattern, exit reason enums       |
//+------------------------------------------------------------------+
#ifndef __OBJECTIVE_SR_CONSTANTS_MQH__
#define __OBJECTIVE_SR_CONSTANTS_MQH__

//+------------------------------------------------------------------+
//| Level source types                                               |
//+------------------------------------------------------------------+
enum ENUM_SR_SOURCE
  {
   SR_SOURCE_PDH = 0,
   SR_SOURCE_PDL,
   SR_SOURCE_PWH,
   SR_SOURCE_PWL,
   SR_SOURCE_ASIA_HIGH,
   SR_SOURCE_ASIA_LOW,
   SR_SOURCE_ROUND_NUMBER,
   SR_SOURCE_H4_SWING_HIGH,
   SR_SOURCE_H4_SWING_LOW
  };

//+------------------------------------------------------------------+
//| Cluster / level state                                            |
//+------------------------------------------------------------------+
enum ENUM_SR_STATE
  {
   SR_STATE_ACTIVE = 0,
   SR_STATE_INVALIDATED
  };

//+------------------------------------------------------------------+
//| Freshness state                                                  |
//+------------------------------------------------------------------+
enum ENUM_SR_FRESH_STATE
  {
   SR_FRESH = 0,
   SR_TOUCHED
  };

//+------------------------------------------------------------------+
//| Trade direction                                                  |
//+------------------------------------------------------------------+
enum ENUM_SR_DIRECTION
  {
   SR_DIRECTION_NONE = 0,
   SR_DIRECTION_LONG,
   SR_DIRECTION_SHORT
  };

//+------------------------------------------------------------------+
//| Rejection pattern                                                |
//+------------------------------------------------------------------+
enum ENUM_SR_PATTERN
  {
   SR_PATTERN_NONE = 0,
   SR_PATTERN_BULLISH_PIN,
   SR_PATTERN_BULLISH_ENGULFING,
   SR_PATTERN_BEARISH_PIN,
   SR_PATTERN_BEARISH_ENGULFING
  };

//+------------------------------------------------------------------+
//| Exit reason                                                      |
//+------------------------------------------------------------------+
enum ENUM_SR_EXIT_REASON
  {
   SR_EXIT_NONE = 0,
   SR_EXIT_TP,
   SR_EXIT_SL,
   SR_EXIT_TIME,
   SR_EXIT_MANUAL,
   SR_EXIT_OTHER
  };

#endif // __OBJECTIVE_SR_CONSTANTS_MQH__
