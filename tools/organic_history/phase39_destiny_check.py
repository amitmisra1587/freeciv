#!/usr/bin/env python3
"""Phase 39 destiny-risk diagnostic for a Wave 1 100x200 sweep.

Compares per-actor survival/spawn rates and final-cities metrics between
the Wave 1 100x200 campaign and the Phase 33 baseline. Flags any actor
whose tech-floor application correlates with deterministic success
(survival >= 0.95 under Wave 1 while < 0.70 under Phase 33).

If destiny is detected, the operator should consider:
  - widening organic_history_tech_floor_delta (currently 2),
  - per-archetype overrides via lifecycleArchetype.techFloor.delta,
  - a per-actor cap via actor.techFloor.maxGrant.

Usage:
  python3 tools/organic_history/phase39_destiny_check.py \
      --wave1-sweep runs/organic_history_phase39_wave1_100x200 \
      --baseline-sweep runs/organic_history_phase33_current_candidate_20x200 \
      --output runs/organic_history_phase39_wave1_100x200/destiny_report.json
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]

DESTINY_SURVIVAL_THRESHOLD = 0.95
GRAVITY_BASELINE_SURVIVAL_MAX = 0.70


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def ensure_fit_report(sweep_dir: Path) -> dict:
    evidence_dir = sweep_dir / "civilization_evidence"
    if not (evidence_dir / "all_civilization_evidence.json").exists():
        subprocess.check_output([
            sys.executable,
            str(ROOT / "tools" / "organic_history" / "generate_civilization_evidence.py"),
            "--sweep-dir", str(sweep_dir),
        ], text=True)
    fit_path = sweep_dir / "fit_report.json"
    if not fit_path.exists():
        subprocess.check_output([
            sys.executable,
            str(ROOT / "tools" / "organic_history" / "global_historical_fit_report.py"),
            "--sweep-dir", str(sweep_dir),
            "--output", str(fit_path),
        ], text=True)
    return load_json(fit_path)


def actor_observed(fit: dict, actor_id: str) -> dict:
    actors = fit.get("actors", {})
    if not isinstance(actors, dict):
        return {}
    return actors.get(actor_id, {}).get("observed", {}) or {}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wave1-sweep", type=Path, required=True)
    parser.add_argument("--baseline-sweep", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    wave1_fit = ensure_fit_report(args.wave1_sweep)
    baseline_fit = ensure_fit_report(args.baseline_sweep)
    wave1_summary = load_json(args.wave1_sweep / "campaign_summary.json")
    wave1_agg = (wave1_summary or {}).get("aggregate", {}) or {}
    tech_floor_applied = wave1_agg.get("techFloorActorApplied", {}) or {}

    all_actors = sorted(
        set((wave1_fit.get("actors") or {}).keys())
        | set((baseline_fit.get("actors") or {}).keys())
    )

    rows = []
    destiny_flags: list[str] = []
    gravity_actors: list[str] = []
    inert_actors: list[str] = []

    for actor in all_actors:
        wave1_obs = actor_observed(wave1_fit, actor)
        base_obs = actor_observed(baseline_fit, actor)
        tf_apps = int(tech_floor_applied.get(actor, 0))
        wave1_survival = wave1_obs.get("survivalRate")
        base_survival = base_obs.get("survivalRate")
        wave1_spawn = wave1_obs.get("spawnRate")
        base_spawn = base_obs.get("spawnRate")
        wave1_final = wave1_obs.get("finalCitiesMedian")
        base_final = base_obs.get("finalCitiesMedian")

        is_destiny = (
            tf_apps > 0
            and wave1_survival is not None
            and base_survival is not None
            and wave1_survival >= DESTINY_SURVIVAL_THRESHOLD
            and base_survival < GRAVITY_BASELINE_SURVIVAL_MAX
        )
        is_inert = (
            tf_apps == 0
            and wave1_survival is not None
            and base_survival is not None
            and abs(wave1_survival - base_survival) < 0.05
        )

        if is_destiny:
            destiny_flags.append(actor)
        elif tf_apps > 0:
            gravity_actors.append(actor)
        if is_inert:
            inert_actors.append(actor)

        rows.append({
            "actor": actor,
            "techFloorApplications": tf_apps,
            "wave1Survival": wave1_survival,
            "baselineSurvival": base_survival,
            "wave1Spawn": wave1_spawn,
            "baselineSpawn": base_spawn,
            "wave1FinalCitiesMedian": wave1_final,
            "baselineFinalCitiesMedian": base_final,
            "verdictDestiny": is_destiny,
            "verdictInert": is_inert,
        })

    report = {
        "destinyActors": destiny_flags,
        "gravityActors": gravity_actors,
        "inertActors": inert_actors,
        "destinyCount": len(destiny_flags),
        "gravityCount": len(gravity_actors),
        "inertCount": len(inert_actors),
        "thresholds": {
            "destinySurvivalMin": DESTINY_SURVIVAL_THRESHOLD,
            "gravityBaselineSurvivalMax": GRAVITY_BASELINE_SURVIVAL_MAX,
        },
        "actors": rows,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(json.dumps({
        "destinyActors": destiny_flags,
        "gravityActors": gravity_actors,
        "inertActors": inert_actors,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
