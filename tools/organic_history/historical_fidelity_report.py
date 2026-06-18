#!/usr/bin/env python3
"""Historical-fidelity scorer for organic-history runs.

The per-actor gates (global_historical_fit_report.py) are loose numeric guardrails: they check
each civ ends within a city-count band. They do NOT measure whether a run looks like *believable
history* -- civs rising AND falling, ancient civs dying/being absorbed, dominance shifting by era.
A run can pass 23/24 gates and still be a frozen tableau where nobody dies and the same three civs
lead for 5000 years.

This scorer measures that missing dimension from data we already produce (the per-turn
`organic_history_metric` lines in server_stdout.log). It reports per-signal scores and an overall
0-100 fidelity score, to be read ALONGSIDE the gates, not instead of them.

TARGETS BELOW ARE PROVISIONAL -- they encode "believable emergent history" and are meant to be
vetted/tuned by a human. Getting them right is the whole point; do not optimise blindly against them.
"""
from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

# --- PROVISIONAL targets for "believable emergent history" (vet these) -------------------------
TARGET_TURNOVER = (0.35, 0.65)      # fraction of seen civs dead/absorbed by the end
TARGET_FALL_FRACTION = 0.35         # of civs that ever got sizable, fraction that later fell hard
FALL_PEAK_MIN = 4                   # "sizable" = peaked at >= this many cities
FALL_DROP = 0.6                     # "fell" = ended <= this fraction of peak
TARGET_CHURN = 0.7                  # 1 - (top-K dominance overlap ancient->end); higher = more shift
TOPK = 5
TARGET_ANCIENT_RETIRED = 0.6        # fraction of ancient civs gone (dead or <=2 cities) by the end
ANCIENT = {"Sumerian", "Assyrian", "Hittite", "Phoenician", "Babylonian", "Akkadian",
           "Egyptian", "Nubian", "Carthaginian", "Minoan", "Elamite"}
# Eras by in-game YEAR (negative = BCE). Checkpoints for dominance churn.
ERAS = [("ancient", -10000, -800), ("classical", -800, 500),
        ("medieval", 500, 1300), ("early_modern", 1300, 9999)]
# Nations that could PLAUSIBLY be a top-tier world power. The dominant powers each
# era should come mostly from this set; an obscure upstart (Tibet, Assam, Khazar)
# topping the leaderboard is the believability blind spot the churn/turnover
# signals miss. Generous on purpose -- only egregious upstarts are penalized.
MAJOR_POWERS = {
    "Egyptian", "Sumerian", "Akkadian", "Babylonian", "Assyrian", "Hittite",
    "Elamite", "Phoenician", "Nubian", "Lydian", "Median",
    "Persian", "Parthian", "Sassanid", "Indian", "Mauryan", "Mughal", "Chola",
    "Gupta", "Chinese", "Han", "Tang", "Song", "Ming", "Manchu", "Mongol",
    "Xiongnu", "Korean", "Japanese", "Vietnamese", "Khmer", "Thai", "Burmese",
    "Greek", "Macedonian", "Roman", "Byzantine", "Carthaginian", "Numidian",
    "Celtic", "Gaulish", "Gothic", "Hunnic", "Vandal", "Frankish", "French",
    "German", "English", "Spanish", "Portuguese", "Italian", "Dutch", "Russian",
    "Polish", "Austrian", "Swedish", "Ottoman", "Turkish", "Seljuk", "Arab",
    "Abbasid", "Umayyad", "Fatimid", "Berber", "Moorish", "Mamluk",
    "Ethiopian", "Abyssinian", "Malian", "Songhai", "Ghanaian", "Kongo", "Zulu",
    "Aztec", "Inca", "Mayan", "Olmec", "Toltec",
}
TARGET_PLAUSIBLE = 0.8              # of the top-K dominant powers, fraction that should be plausible

WEIGHTS = {"turnover": 0.25, "rise_and_fall": 0.25, "churn": 0.15,
           "ancient_retired": 0.15, "plausible_dominance": 0.20}

# Barbarian-like / independent players are not real civilizations and must not
# count toward turnover etc. (the decisive-collapse mechanic parks fragments on a
# "Free Cities" independent under one of these nations).
EXCLUDE_NATIONS = {"Pirate", "Barbarian", "Animals"}
EXCLUDE_NAMES = {"Free Cities"}

METRIC_RE = re.compile(
    r'organic_history_metric turn=(\d+) year=(-?\d+) player=\d+ name="([^"]*)" '
    r'nation="([^"]+)" alive=(\w+) cities=(\d+)')


def parse_metrics(log_path: Path):
    """nation -> {turn: (year, cities, alive)} plus sorted turn list."""
    hist: dict[str, dict[int, tuple]] = defaultdict(dict)
    turns = set()
    with open(log_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = METRIC_RE.search(line)
            if not m:
                continue
            turn, year, name, nation, alive, cities = m.groups()
            if nation in EXCLUDE_NATIONS or name in EXCLUDE_NAMES:
                continue
            hist[nation][int(turn)] = (int(year), int(cities), alive == "true")
            turns.add(int(turn))
    return hist, sorted(turns)


def era_of(year: int) -> str:
    for name, lo, hi in ERAS:
        if lo <= year < hi:
            return name
    return ERAS[-1][0]


def band_score(value, lo, hi):
    """1.0 inside [lo,hi]; decays linearly to 0 at twice the band width outside."""
    if lo <= value <= hi:
        return 1.0
    w = max(1e-9, hi - lo)
    d = (lo - value) if value < lo else (value - hi)
    return max(0.0, 1.0 - d / w)


def top_at(hist, turns, year_target, k):
    # nearest turn to the target year
    best_turn, best_d = None, 1e18
    for t in turns:
        years = [v[0] for v in (h.get(t) for h in hist.values()) if v]
        if not years:
            continue
        y = years[0]
        if abs(y - year_target) < best_d:
            best_d, best_turn = abs(y - year_target), t
    if best_turn is None:
        return []
    rows = sorted(((h[best_turn][1], n) for n, h in hist.items() if best_turn in h), reverse=True)
    return [n for c, n in rows[:k] if c > 0]


def score_run(log_path: Path) -> dict:
    hist, turns = parse_metrics(log_path)
    if not turns:
        return {"error": "no organic_history_metric lines found"}
    last = turns[-1]
    seen = list(hist)

    # 1. turnover
    dead = [n for n in seen if not hist[n][last][2] or hist[n][last][1] == 0]
    turnover = len(dead) / len(seen)
    s_turn = band_score(turnover, *TARGET_TURNOVER)

    # 2. rise-and-fall
    sizable, fell = [], []
    for n in seen:
        series = [hist[n][t][1] for t in turns if t in hist[n]]
        if not series:
            continue
        peak, final = max(series), series[-1]
        if peak >= FALL_PEAK_MIN:
            sizable.append(n)
            if final <= FALL_DROP * peak:
                fell.append((n, peak, final))
    fall_frac = (len(fell) / len(sizable)) if sizable else 0.0
    s_fall = min(1.0, fall_frac / TARGET_FALL_FRACTION) if TARGET_FALL_FRACTION else 0.0

    # 3. dominance churn ancient -> end
    anc_year = ERAS[0][2] - 1
    end_year = hist[seen[0]][last][0]
    top_anc = top_at(hist, turns, anc_year, TOPK)
    top_end = top_at(hist, turns, end_year, TOPK)
    overlap = len(set(top_anc) & set(top_end))
    churn = 1.0 - (overlap / TOPK if TOPK else 0)
    s_churn = min(1.0, churn / TARGET_CHURN) if TARGET_CHURN else 0.0

    # 4. ancient-civ retirement
    anc_seen = [n for n in seen if n in ANCIENT]
    anc_retired = [n for n in anc_seen if (not hist[n][last][2]) or hist[n][last][1] <= 2]
    retired_frac = (len(anc_retired) / len(anc_seen)) if anc_seen else 1.0
    s_anc = min(1.0, retired_frac / TARGET_ANCIENT_RETIRED) if TARGET_ANCIENT_RETIRED else 0.0

    # 5. plausible dominance: of the CITIES held by the top-K powers (size-weighted,
    # so a 31-city upstart bites hard), the fraction held by plausible powers. Taken
    # at the WORST of the later-era checkpoints (a Tibet-dominated end is implausible
    # even if earlier eras looked fine). Raw fraction = the score.
    def plaus_at(year_target):
        bt, bd = None, 1e18
        for t in turns:
            y = next((v[0] for v in (h.get(t) for h in hist.values()) if v), None)
            if y is not None and abs(y - year_target) < bd:
                bd, bt = abs(y - year_target), t
        if bt is None:
            return None, None
        rows = sorted(((hist[n][bt][1], n) for n in hist if bt in hist[n]),
                      reverse=True)[:TOPK]
        tot = sum(c for c, n in rows)
        if tot == 0:
            return None, rows
        return sum(c for c, n in rows if n in MAJOR_POWERS) / tot, rows
    checkpoints = [ERAS[1][2] - 1, ERAS[2][2] - 1, end_year]
    fracs, dom_detail = [], []
    for yr_chk in checkpoints:
        fr, rows = plaus_at(yr_chk)
        if fr is not None:
            fracs.append(fr)
            dom_detail.append([f"{n}:{c}" if n in MAJOR_POWERS else f"*{n}*:{c}"
                               for c, n in rows])
    s_plaus = min(fracs) if fracs else 1.0
    plausible = s_plaus

    parts = {"turnover": s_turn, "rise_and_fall": s_fall, "churn": s_churn,
             "ancient_retired": s_anc, "plausible_dominance": s_plaus}
    overall = round(100 * sum(WEIGHTS[k] * parts[k] for k in WEIGHTS), 1)

    return {
        "fidelityScore": overall,
        "signals": {
            "plausible_dominance": {"score": round(s_plaus, 2),
                                    "value": round(plausible, 2),
                                    "target": TARGET_PLAUSIBLE,
                                    "detail": "top-K powers (*=implausible upstart)",
                                    "topByEra": dom_detail},
            "turnover": {"score": round(s_turn, 2), "value": round(turnover, 2),
                         "target": list(TARGET_TURNOVER),
                         "detail": f"{len(dead)}/{len(seen)} civs dead/absorbed", "dead": sorted(dead)},
            "rise_and_fall": {"score": round(s_fall, 2), "value": round(fall_frac, 2),
                              "target": TARGET_FALL_FRACTION,
                              "detail": f"{len(fell)}/{len(sizable)} sizable civs fell",
                              "fell": sorted(fell, key=lambda x: -x[1])[:8]},
            "churn": {"score": round(s_churn, 2), "value": round(churn, 2), "target": TARGET_CHURN,
                      "detail": f"top{TOPK} ancient->end overlap {overlap}/{TOPK}",
                      "topAncient": top_anc, "topEnd": top_end},
            "ancient_retired": {"score": round(s_anc, 2), "value": round(retired_frac, 2),
                                "target": TARGET_ANCIENT_RETIRED,
                                "detail": f"{len(anc_retired)}/{len(anc_seen)} ancient civs retired",
                                "stillBig": [(n, hist[n][last][1]) for n in anc_seen
                                             if n not in anc_retired]},
        },
        "weights": WEIGHTS,
    }


def render(report: dict) -> str:
    if "error" in report:
        return report["error"]
    out = [f"HISTORICAL FIDELITY: {report['fidelityScore']}/100   (higher = more believable)", "-" * 64]
    for key, s in report["signals"].items():
        bar = "#" * int(s["score"] * 20)
        out.append(f"  {key:16s} {s['score']:.2f} [{bar:<20}]  {s['detail']}  (target {s['target']})")
    sig = report["signals"]
    out.append("")
    out.append(f"  still-immortal ancients: {sig['ancient_retired']['stillBig']}")
    out.append(f"  top5 ancient era: {sig['churn']['topAncient']}")
    out.append(f"  top5 at the end:  {sig['churn']['topEnd']}")
    out.append(f"  empires that fell: {sig['rise_and_fall']['fell']}")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser(description="Score a run's historical believability.")
    ap.add_argument("--run-dir", type=Path, required=True)
    ap.add_argument("--json", action="store_true", help="emit JSON instead of text")
    args = ap.parse_args()
    log = args.run_dir / "server_stdout.log"
    if not log.exists():
        print(f"no server_stdout.log in {args.run_dir}")
        return 1
    report = score_run(log)
    print(json.dumps(report, indent=2) if args.json else render(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
