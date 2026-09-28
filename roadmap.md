# Roadmap ObjectiveSR EA

**Acuan:** `ObjectiveSR_EA.txt` (Spec v1.0) + `Data Structures + Contracts MQL5.txt` (Phase 1)
**Prinsip:** OBJECTIVE > REPEATABLE > TESTABLE > MEASURABLE > RESEARCHABLE
**Keras:** closed-bar `shift>=1`, no-repaint, `TimeGMT()`, pips, deterministik.

## 0. Status (28 Sep 2026)

- [x] Spec v1.0 + desain Phase 1 = DEFINED (masih .txt)
- [x] M1 fondasi = DONE (ObjectiveSR.mq5 + 4x .mqh)
- [x] M2+M3 Market+Level = DONE (SRMarket.mqh + SRLevelEngine.mqh, SRLevel[] pertama)
- [ ] M4 Cluster = NEXT, Backtest = NOT STARTED

## 1. Urutan Fase (wajib, Spec #77)

```
P1 Data Structures
 > P2 Market/GMT > P3 Level Engine > P4 Cluster
 > P5 Touch > P6 Invalidation/Fresh > P7 Trend (H4 EMA50)
 > P8 Entry (Pin+Engulf) > P9 SL/TP/RR > P10 Risk
 > P11 Execution > P12 Logger > P13 Backtest
```

Tanpa RSI/MACD/Stoch/FVG/ATR sebelum baseline (Spec #72).
## 2. Milestone dan DoD

### M1 - P1 Fondasi (sekarang)
Out: `ObjectiveSR/include/SRConstants.mqh`, `SRConfig.mqh`, `SRTypes.mqh`, skeleton `ObjectiveSR.mq5`.
DoD: struct sesuai kontrak; helper PipSize/PipsToPrice/PriceToPips, IsEntryWindow, lifecycle New D1/H4/M15; compile bersih; OnInit hanya EURUSD/GBPUSD.

### M2 - P2 Market
Out: Market.mqh (GMT, spread, session, new-bar D1/H4/M15).
DoD: entry 07:00-16:00 GMT, force-close 20:00 GMT, recalc hanya saat bar baru.

### M3 - P3 Level Engine
Fungsi: CollectPDH_PDL, CollectPWH_PWL, CollectAsiaHL, CollectRoundNumbers, CollectH4Swings.
DoD: PDH/PDL=D1 shift1; PWH/PWL=W1 completed; Asia 00:00-07:00 freeze 07:00; Round 50-pip; H4 fractal 2-2 lookback 20 hari (~120 bar), MinTouches=2.

### M4 - P4 Cluster
Fungsi: ClusterLevels, BuildCluster, CalculateClusterScore, BuildZone.
DoD: merge 10-pip deterministik; Center dikunci 1 metode; Score=jumlah tipe source beda; Zone EU 5 / GU 7 half-pip.

### M5 - P5+P6 Touch dan State
Fungsi: CountTouches, IsValidTouch, CheckTouchSpacing + invalidasi + FreshOnly.
DoD: touch High>=Lower dan Low<=Upper (M15), filter close 1x ZoneWidth, spacing >=6 bar; invalid jika close tembus >Upper+ZW atau <Lower-ZW (sisa hari); FreshOnly=true maka swing TOUCHED dilarang entry.

### M6 - P7+P8 Trend dan Entry
DoD: Long jika H4Close[1]>EMA50[1] dan EMA50[1]>EMA50[4] (Short kebalikan, countertrend dilarang); Pin wick>=2x body; Engulfing prev berlawanan + body menelan (kunci equality); M15 shift1 masuk zone + close sisi benar + semua filter.

### M7 - P9+P10+P11 SL/TP/Risk/Eksekusi
DoD: SL long=min(RejLow,ZoneLower)-Buffer, short=max(RejHigh,ZoneUpper)+Buffer; cek EU 8-25 / GU 10-35 else skip; TP=next opposing cluster -/+2 pip, cap 3R, MinRR 1.5 else skip; risk 0.5%/trade, daily -2R, weekly -4R, 3 loss -> 0.25%, 1 trade/hari, tanpa martingale/grid; market order bar berikut; force-close 20:00 GMT.

### M8 - P12 Logger
DoD: CSV Date,TimeGMT,Symbol,Direction,Entry,SL,TP,LevelSource,ClusterScore,Sources,TouchCount,ZoneU/L,H4Close,EMA50,Trend,Pattern,RR,Spread,SessionHour,MAE,MFE,ExitPrice,ExitReason,ResultR,ResultMoney. Siap analisis per-source dan per-score.

### M9 - P13 Validasi (Spec #76, 24 checklist)
Urutan: Baseline > Source-level > Cluster-score 1vs2 > FreshOnly ON/OFF > Sensitivity (Zone 3-10, Buffer 2-10, RR 1.2-2.0, Touches 2-3, SL +-30%) > OOS > Walk-forward > Demo.
DoD: 24 kotak Spec #76 tercentang.

## 3. Cara Kerja

1. Sekarang: M1 skeleton + 3 include > compile.
2. Lalu M2+M3 > print SRLevel[] pertama.
3. Lalu M4 > cluster objektif pertama.
4. Lalu M5-M7 bertahap, uji Strategy Tester visual + log.
5. M8 jangan ditunda. M9 tanpa optimisasi dulu.

## 4. Aturan Main

- Jangan ubah struct P1 diam-diam, via Change Control (RuleID, Current, Proposed, Reason, Impact, Core/Research).
- Dilarang campur tugas: LevelEngine tanpa OrderSend, Risk tanpa tentukan support, Logger tanpa ubah keputusan.
- Semua GMT, closed-bar, pips via PipSize() (waspada 5-digit).

## 5. Next Action

- [x] Buat folder ObjectiveSR/include + 3 file M1 dari .txt Phase 1 -> DONE (plus SRUtils.mqh + skeleton ObjectiveSR.mq5)
- [x] M4 Cluster = DONE (SRClusterEngine.mqh, center=MEDIAN, merge 10-pip)
- [x] M5 Touch+State = DONE (SRTouchEngine.mqh: overlap+close-filter+spacing6+invalidasi+FreshOnly)
- [x] M6 Trend+Entry = DONE (SRTrendEngine H4 EMA50 + SREntryEngine pin/engulf strict, sinyal tanpa order, gate sesi 07-16 GMT)
- [x] M7 SL/TP/RR+Risk+Exec = DONE (SRTradeEngine+SRRiskManager, balance-locked, single-position, force-close 20:00 GMT, InpTradeEnabled default OFF)
- [x] M8 Logger = DONE (SRLogger.mqh + signals/trades CSV, MAE/MFE per-tick, exit reason SL/TP/TIME)
- [x] M9 Validation = DONE (analysis/M9_validation.md + analyze_trades.py stdlib, checklist 24, run log, kriteria demo)

