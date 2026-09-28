"""ObjectiveSR M9 analyzer (stdlib only).
Reads ObjectiveSR_*_trades.csv + *_signals.csv, writes summary + equity.
Usage: python analyze_trades.py [folder]  (default: script folder)
"""
import csv, glob, os, sys
from collections import defaultdict

def load(folder):
    rows = []
    for f in sorted(glob.glob(os.path.join(folder, "*_trades.csv"))):
        with open(f, newline="", encoding="utf-8-sig") as fh:
            for r in csv.DictReader(fh):
                r["_file"] = os.path.basename(f)
                rows.append(r)
    return rows
def fnum(x, d=0.0):
    try:
        return float(str(x).strip())
    except (ValueError, AttributeError):
        return d
def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    rows = load(folder)
    sig_n = sum(1 for _ in glob.glob(os.path.join(folder, "*_signals.csv")))
    out = []
    out.append(f"files_trades={len(set(r['_file'] for r in rows))} rows={len(rows)} signals_files={sig_n}")
    if not rows:
        out.append("NO DATA: copy ObjectiveSR_*_trades.csv ke folder analysis dulu.")
        open(os.path.join(folder, "summary.txt"), "w").write("\n".join(out) + "\n")
        print("\n".join(out))
        return
    n = len(rows)
    wins = [r for r in rows if fnum(r.get("ResultR")) > 0]
    gp = sum(fnum(r.get("ResultR")) for r in rows if fnum(r.get("ResultR")) > 0)
    gl = -sum(fnum(r.get("ResultR")) for r in rows if fnum(r.get("ResultR")) < 0)
    pf = (gp / gl) if gl > 0 else 0.0
    out.append(f"N={n} win={len(wins)/n*100:.1f}% PF={pf:.2f} avgR={sum(fnum(r.get('ResultR')) for r in rows)/n:+.3f}")
    # determinism-ish: RR/spread gates
    bad_rr = [r for r in rows if fnum(r.get("RR")) < 1.5 - 1e-9]
    spread_bad = [r for r in rows if ("EURUSD" in str(r.get("Symbol")) and fnum(r.get("Spread")) > 2.0 + 1e-9)
                  or ("GBPUSD" in str(r.get("Symbol")) and fnum(r.get("Spread")) > 3.0 + 1e-9)]
    out.append(f"gate_RR_violations={len(bad_rr)} gate_spread_violations={len(spread_bad)}")
    # per-pattern / per-score / per-source
    for key in ("Pattern", "ClusterScore", "ExitReason", "Direction"):
        g = defaultdict(list)
        for r in rows:
            g[str(r.get(key))].append(fnum(r.get("ResultR")))
        out.append(f"-- by {key} --")
        for k in sorted(g):
            v = g[k]
            w = sum(1 for x in v if x > 0) / len(v) * 100
            out.append(f"  {k}: n={len(v)} win={w:.1f}% avgR={sum(v)/len(v):+.3f}")
    # source contains (LevelSource = PDH:1|ROUND:2)
    src = defaultdict(list)
    for r in rows:
        for tok in str(r.get("LevelSource", "")).split("|"):
            name = tok.split(":")[0].strip()
            if name and name != "UNKNOWN":
                src[name].append(fnum(r.get("ResultR")))
    out.append("-- by source-in-cluster --")
    for k in sorted(src):
        v = src[k]
        w = sum(1 for x in v if x > 0) / len(v) * 100
        out.append(f"  {k}: n={len(v)} win={w:.1f}% avgR={sum(v)/len(v):+.3f}")
    # equity by day + maxDD in R
    eq = defaultdict(float)
    for r in rows:
        eq[str(r.get("Date"))] += fnum(r.get("ResultR"))
    cum, peak, mdd = 0.0, 0.0, 0.0
    with open(os.path.join(folder, "equity_by_day.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["Date", "DayR", "CumR"])
        for d in sorted(eq):
            cum += eq[d]
            peak = max(peak, cum)
            mdd = min(mdd, cum - peak)
            w.writerow([d, f"{eq[d]:.3f}", f"{cum:.3f}"])
    out.append(f"cumR={cum:+.2f} maxDD_R={mdd:.2f}")
    out.append("PASS-DEMO?" + (" checkpoints: N>=100, cek PF OOS>=0.7x baseline manual, maxDD<10R" if n >= 100 else f" N={n}<100 BELUM CUKUP"))
    open(os.path.join(folder, "summary.txt"), "w").write("\n".join(out) + "\n")
    print("\n".join(out))
if __name__ == "__main__":
    main()
