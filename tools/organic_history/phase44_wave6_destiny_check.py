#!/usr/bin/env python3
"""Phase 44 Wave 6 destiny + no-regression check.

Compares a Wave 6 (scaling-stress) campaign arm against the same-seed Wave 3
baseline arm and enforces the gravity-not-destiny + no-regression bar:

  1. SURVIVAL FLOOR - each scaling-stress actor (default india, nubia) must keep
     survivalRate >= SURVIVAL_FLOOR and must not drop more than SURVIVAL_DROP_MAX
     below baseline. Violations => death-destiny (decline pressure is killing the
     actor instead of trimming it).
  2. VARIANCE PRESERVED - each scaling-stress actor's finalCities P90-P10 spread
     must stay >= MIN_SPREAD. A collapsed spread => deterministic decline (every
     seed ends at the same trimmed size = destiny, not gravity).
  3. NO REGRESSION - no actor may move from pass -> warn/fail vs baseline. This
     protects the 19 passing actors (which carry no ceiling and should be inert).

It also reports the intended effect: whether each scaling-stress actor's median
final-cities moved DOWN vs baseline (effectiveness, not a destiny criterion).

Usage:
  python3 tools/organic_history/phase44_wave6_destiny_check.py \
      --candidate runs/.../p44_wave6_phase44_wave6_scaling_stress \
      --baseline  runs/.../baseline \
      --scaling-actors india,nubia \
      --output runs/.../phase44_destiny_report.json
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

SURVIVAL_FLOOR = 0.85
SURVIVAL_DROP_MAX = 0.15
MIN_SPREAD = 4.0

VERDICT_RANK = {"pass": 0, "warn": 1, "fail": 2, "missing": 3, None: 3}


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def ensure_fit_report(sweep_dir: Path) -> dict:
    evidence = sweep_dir / "civilization_evidence" / "all_civilization_evidence.json"
    if not evidence.exists():
        subprocess.check_output([
            sys.executable,
            str(ROOT / "tools/organic_history/generate_civilization_evidence.py"),
            "--sweep-dir", str(sweep_dir),
        ], text=True, stderr=subprocess.STDOUT)
    fit_path = sweep_dir / "fit_report.json"
    if not fit_path.exists():
        subprocess.check_output([
            sys.executable,
            str(ROOT / "tools/organic_history/global_historical_fit_report.py"),
            "--sweep-dir", str(sweep_dir),
            "--output", str(fit_path),
        ], text=True, stderr=subprocess.STDOUT)
    return load_json(fit_path)


def evidence_map(sweep_dir: Path) -> dict:
    return load_json(sweep_dir / "civilization_evidence"
                     / "all_civilization_evidence.json")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True,
                        help="Wave 6 (scaling-stress) campaign dir.")
    parser.add_argument("--baseline", type=Path, required=True,
                        help="Wave 3 baseline campaign dir (same seeds).")
    parser.add_argument("--scaling-actors", default="india,nubia")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--strict", action="store_true",
                        help="Exit non-zero on any destiny/regression violation.")
    args = parser.parse_args()

    scaling_actors = [a.strip() for a in args.scaling_actors.split(",") if a.strip()]
    cand_fit = ensure_fit_report(args.candidate)
    base_fit = ensure_fit_report(args.baseline)
    cand_ev = evidence_map(args.candidate)
    base_ev = evidence_map(args.baseline)

    cand_actors = cand_fit.get("actors", {}) or {}
    base_actors = base_fit.get("actors", {}) or {}
    all_actors = sorted(set(cand_actors) | set(base_actors))

    death_destiny: list[str] = []
    deterministic_decline: list[str] = []
    regressed: list[str] = []
    scaling_rows = []
    regression_rows = []

    for actor in all_actors:
        cand_v = (cand_actors.get(actor) or {}).get("verdict")
        base_v = (base_actors.get(actor) or {}).get("verdict")
        if VERDICT_RANK.get(cand_v, 3) > VERDICT_RANK.get(base_v, 3):
            regressed.append(actor)
            regression_rows.append({"actor": actor, "baseline": base_v,
                                    "candidate": cand_v})

    for actor in scaling_actors:
        c = cand_ev.get(actor, {}) or {}
        b = base_ev.get(actor, {}) or {}
        c_surv = c.get("survivalRate")
        b_surv = b.get("survivalRate")
        c_p10, c_p90 = c.get("finalCitiesP10"), c.get("finalCitiesP90")
        spread = (c_p90 - c_p10) if (c_p10 is not None and c_p90 is not None) else None
        c_med, b_med = c.get("finalCitiesMedian"), b.get("finalCitiesMedian")

        is_death = (c_surv is not None and (
            c_surv < SURVIVAL_FLOOR
            or (b_surv is not None and (b_surv - c_surv) > SURVIVAL_DROP_MAX)))
        is_deterministic = (spread is not None and spread < MIN_SPREAD)
        if is_death:
            death_destiny.append(actor)
        if is_deterministic:
            deterministic_decline.append(actor)

        scaling_rows.append({
            "actor": actor,
            "candidateSurvival": c_surv,
            "baselineSurvival": b_surv,
            "candidateFinalP10": c_p10,
            "candidateFinalP90": c_p90,
            "candidateSpread": spread,
            "candidateFinalMedian": c_med,
            "baselineFinalMedian": b_med,
            "medianMovedDown": (c_med is not None and b_med is not None
                                and c_med < b_med),
            "candidateVerdict": (cand_actors.get(actor) or {}).get("verdict"),
            "baselineVerdict": (base_actors.get(actor) or {}).get("verdict"),
            "deathDestiny": is_death,
            "deterministicDecline": is_deterministic,
        })

    clean = not death_destiny and not deterministic_decline and not regressed
    verdict = "clean"
    if regressed:
        verdict = "passes_regressed"
    elif death_destiny:
        verdict = "death_destiny"
    elif deterministic_decline:
        verdict = "deterministic_decline"

    report = {
        "candidateDir": str(args.candidate),
        "baselineDir": str(args.baseline),
        "scalingActors": scaling_actors,
        "verdict": verdict,
        "clean": clean,
        "deathDestiny": death_destiny,
        "deterministicDecline": deterministic_decline,
        "regressedActors": regressed,
        "regressions": regression_rows,
        "scalingActorDetail": scaling_rows,
        "thresholds": {"survivalFloor": SURVIVAL_FLOOR,
                       "survivalDropMax": SURVIVAL_DROP_MAX,
                       "minSpread": MIN_SPREAD},
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(json.dumps({
        "verdict": verdict,
        "clean": clean,
        "deathDestiny": death_destiny,
        "deterministicDecline": deterministic_decline,
        "regressedActors": regressed,
        "scalingActorMedians": {r["actor"]: {
            "baseline": r["baselineFinalMedian"],
            "candidate": r["candidateFinalMedian"],
            "movedDown": r["medianMovedDown"]} for r in scaling_rows},
    }, sort_keys=True))

    if args.strict and not clean:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
