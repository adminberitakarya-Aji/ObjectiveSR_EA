# M9 — Backtest Validation (ObjectiveSR v1.0)

Gunakan setelah M1–M8 compile bersih. Prinsip: **tanpa optimisasi dulu**,
baseline → varian satu-per-satu → OOS → walk-forward → demo.
Semua analisis dari CSV M8 (`MQL5/Files/ObjectiveSR_*_trades.csv` +
`..._signals.csv`), bukan dari feeling.

## 1. Setup Strategy Tester (baseline, kunci sebelum jalan)

| Item | Nilai |
|---|---|
| Pair | EURUSD dulu, baru GBPUSD (satu-per-satu) |
| Timeframe chart | M15 (EA baca D1/W1/H4/M15 sendiri) |
| Model | Every tick based on real ticks (bukan OHLC-only) |
| Deposit / leverage | 10.000, 1:100 (catat; jangan ganti antar run) |
| InpTradeEnabled | true |
| InpLogCSV | true |
| InpLogLevels | false |
| InpNewsDates | kosongkan (news diuji terpisah M9.5) |
| Periode baseline | 2023-01-01 → 2024-12-31 (2 tahun, ≥200 trade ideal) |

FreshOnly=false, MinRR=1.5, Zone EU 5 / GU 7, Buffer EU 4 / GU 6,
Spacing 6, TPBuffer 2, MaxR 3.0 — default M1, jangan diubah di baseline.

## 2. 24 Checklist Spec #76 (centang dgn bukti CSV/tester)

```
[x] Semua source level terdeteksi (PDH/PDL/PWH/PWL/Asia/Round/H4Swing ada di LevelSource — B1)
[ ] H4 swing tidak repaint (swing shift>=3, jumlah stabil antar rebuild)
[ ] Zone deterministic (rerun periode sama = cluster sama)
[ ] Cluster deterministic (rerun = center/score sama)
[ ] Touch deterministic (rerun = touch count sama)
[ ] Touch spacing diterapkan (gap <6 tidak ganda — cek signals.csv)
[ ] Invalidation bekerja (ada state INVALIDATED, no entry setelahnya)
[ ] FreshOnly bekerja (ON = TOUCHED ditolak; OFF = lolos)
[x] H4 EMA50 filter bekerja (538 SHORT + 456 LONG signals dua arah — B1)
[x] Pin Bar bekerja (ada BULLISH_PIN/BEARISH_PIN di Pattern — B1)
[x] Engulfing bekerja (ada *_ENGULFING — B1)
[x] SL sesuai rule (avg SL exit -1.01R tepat 1R — B1)
[x] TP sesuai rule (avg TP +2.01R — B1)
[x] RR filter bekerja (0 pelanggaran RR<1.5 — B1)
[x] Spread filter bekerja (0 pelanggaran — B1)
[ ] News filter bekerja (tanggal InpNewsDates = no entry)
[x] Risk manager bekerja (lot balance*0.5%/SL — B1)
[ ] Daily limit bekerja (stop setelah -2R/hari)
[ ] Weekly limit bekerja (stop setelah -4R/minggu)
[ ] Consecutive loss protection bekerja (trade ke-4 setelah 3 loss = 0.25%)
[x] Force close 20:00 GMT bekerja (6x ExitReason=TIME — B1)
[x] CSV logging lengkap (24 kolom trades terisi, MAE/MFE/exit terisi — B1)
[ ] Deterministik rerun (2x run sama = CSV identik kecuali Date file)
[x] Single position (50 ENTRY = 50 trades, tidak ada overlap — B1)
```

## 3. Urutan riset (satu variabel per run, catat di tabel §5)

1. **Baseline** (default, 2023-2024). Target: data cukup, bukan profit.
2. **Source-level**: filter `LevelSource` — win-rate/PF per source.
3. **Cluster-score**: 1 vs ≥2 (dari `ClusterScore`).
4. **FreshOnly** ON vs OFF.
5. **Sensitivity** (satu-per-satu): Zone 3-10, Buffer 2-10, RR 1.2-2.0,
   MinTouches 2-3, SL ±30%. Stop jika hasil datar/chaos = overfit signal.
6. **OOS**: kunci 1 setting → 2025-01 → 2026-09 (tanpa ubah).
7. **Walk-forward**: train 12 bln → test 3 bln, geser per kuartal.
8. **Demo**: 4 minggu, `InpTradeEnabled=true`, cek slippage vs tester.

## 4. Cara pakai analyzer

```powershell
# gabung semua CSV Files lalu analisis
python d:\ObjectiveSR_EA\analysis\analyze_trades.py
```

Script membaca `trades*.csv` + `signals*.csv` di foldernya
(copy dari `MQL5/Files/`), menulis `summary.txt` +
`equity_by_day.csv`. Kriteria lolos baseline (§6) dicek otomatis.

## 5. Log run (isi tiap run, jangan di kepala)

| Run | Periode | Setting diubah | N | Win% | PF | MaxDD(R) | Catatan |
|---|---|---|---|---|---|---|---|
| B1 | 2024-01→2024-12 (EURUSDc, real ticks, 10k 1:100) | baseline default | 50 | 22.0 | 0.50 | -26.01 | TIDAK LOLOS: ekspektasi negatif (avgR -0.37, cumR -18.62). 36 SL/8 TP/6 TIME. Gate RR+spread 0 pelanggaran. Hipotesis score GAGAL: score1/2 (-0.24) > score3/4 (-0.62). Satu-satunya pola ≥0: BULLISH_PIN +0.03 (n=7, noise). Data valid pasca-fix logger+arah (commit 936b53a). N<100, perlu tambah periode. |
| S1 | 23-24 | score>=2 | | | | | NEXT (butuh N≥100 dulu) |
| F1 | 23-24 | FreshOnly ON | | | | | NEXT (butuh N≥100 dulu) |

## 6. Kriteria lolos ke demo

- N baseline ≥ 100 trade (ideal ≥200).
- OOS tidak collapse vs baseline (PF OOS ≥ 0.7× PF baseline).
- MaxDD(R) tercatat dan < 10R.
- Semua 24 checklist tercentang.
- Tidak ada perubahan rule tanpa Change Control
  (RuleID, Current, Proposed, Reason, Impact, Core/Research).
