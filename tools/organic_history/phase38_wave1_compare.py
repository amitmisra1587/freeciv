#!/usr/bin/env python3
"""Phase 38 Wave 1 vs no-change-control summary.

Reads two campaign output dirs (Wave 1 candidate + same-seed control), and
emits a focused promotion-decision report:
  - per-seed success and Freeciv assertion counts
  - aggregate pass/warn/fail counts via global_historical_fit_report
  - per-actor median final / max final delta (candidate - control)
  - tech_floor activity summary (applied actors, granted tech counts)
  - new failures introduced by the candidate

Usage:
  python3 tools/organic_history/phase38_wave1_compare.py \
      --candidate runs/organic_history_phase38_wave1_6x200 \
      --control runs/organic_history_phase38_wave1_control_6x200 \
      --output runs/organic_history_phase38_wave1_compare/report.json
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def per_seed_metadata(campaign_dir: Path) -> list[dict]:
    rows = []
    for seed_dir in sorted(campaign_dir.glob("seed_*")):
        md = load_json(seed_dir / "run_metadata.json")
        rows.append({
            "seed": seed_dir.name,
            "success": md.get("success"),
            "assertions": int(md.get("freecivAssertionLogCount") or 0),
            "finalTurn": md.get("finalTurnSeen"),
            "techFloorLogs": int(md.get("organicTechFloorLogCount") or 0),
        })
    return rows


def fit_report(campaign_dir: Path) -> dict:
    evidence_dir = campaign_dir / "civilization_evidence"
    if not (evidence_dir / "all_civilization_evidence.json").exists():
        subprocess.check_output([
            sys.executable,
            str(ROOT / "tools" / "organic_history" / "generate_civilization_evidence.py"),
            "--sweep-dir", str(campaign_dir),
        ], text=True)
    out_path = campaign_dir / "fit_report.json"
    cmd = [
        sys.executable,
        str(ROOT / "tools" / "organic_history" / "global_historical_fit_report.py"),
        "--sweep-dir", str(campaign_dir),
        "--output", str(out_path),
    ]
    subprocess.check_output(cmd, text=True)
    return load_json(out_path)


def actor_counts(fit: dict) -> dict[str, str]:
    """Map actor -> verdict (pass/warn/fail) for a single fit report."""
    out = {}
    actors = fit.get("actors", {})
    if isinstance(actors, dict):
        for actor, data in actors.items():
            out[actor] = data.get("verdict")
    return out


def actor_metrics(fit: dict) -> dict[str, dict]:
    """Map actor -> observed metrics."""
    out = {}
    actors = fit.get("actors", {})
    if isinstance(actors, dict):
        for actor, data in actors.items():
            obs = data.get("observed", {}) or {}
            out[actor] = {
                "finalCitiesMedian": obs.get("finalCitiesMedian"),
                "maxCitiesMedian": obs.get("maxCitiesMedian"),
                "spawnRate": obs.get("spawnRate"),
                "survivalRate": obs.get("survivalRate"),
            }
    return out


def tech_floor_summary(campaign_dir: Path) -> dict:
    summary = load_json(campaign_dir / "campaign_summary.json")
    agg = (summary or {}).get("aggregate", {}) or {}
    return {
        "techFloorActorApplied": agg.get("techFloorActorApplied", {}),
        "techFloorActorReasons": agg.get("techFloorActorReasons", {}),
        "techFloorActorSkips": agg.get("techFloorActorSkips", {}),
        "techFloorSkipReasons": agg.get("techFloorSkipReasons", {}),
        "organicTechFloorLogs": agg.get("organicTechFloorLogs", 0),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--control", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    cand_meta = per_seed_metadata(args.candidate)
    ctrl_meta = per_seed_metadata(args.control)
    cand_fit = fit_report(args.candidate)
    ctrl_fit = fit_report(args.control)

    cand_status = actor_counts(cand_fit)
    ctrl_status = actor_counts(ctrl_fit)
    cand_metrics = actor_metrics(cand_fit)
    ctrl_metrics = actor_metrics(ctrl_fit)
    all_actors = sorted(set(cand_status) | set(ctrl_status))

    actor_changes = []
    new_failures = []
    new_passes = []
    for actor in all_actors:
        c = cand_status.get(actor, "missing")
        b = ctrl_status.get(actor, "missing")
        cm = cand_metrics.get(actor, {})
        bm = ctrl_metrics.get(actor, {})

        def delta(field):
            cv = cm.get(field)
            bv = bm.get(field)
            if cv is None or bv is None:
                return None
            return round(cv - bv, 3)

        actor_changes.append({
            "actor": actor,
            "candidateStatus": c,
            "controlStatus": b,
            "deltaMedianFinalCities": delta("finalCitiesMedian"),
            "deltaMedianMaxCities": delta("maxCitiesMedian"),
            "candidateMedianFinalCities": cm.get("finalCitiesMedian"),
            "controlMedianFinalCities": bm.get("finalCitiesMedian"),
            "candidateMedianMaxCities": cm.get("maxCitiesMedian"),
            "controlMedianMaxCities": bm.get("maxCitiesMedian"),
        })
        if c == "fail" and b in ("pass", "warn"):
            new_failures.append(actor)
        if b == "fail" and c in ("pass", "warn"):
            new_passes.append(actor)

    def status_counts(actors_dict):
        out = {"pass": 0, "warn": 0, "fail": 0}
        if isinstance(actors_dict, dict):
            for _, data in actors_dict.items():
                v = data.get("verdict")
                if v in out:
                    out[v] += 1
        return out

    report = {
        "candidateDir": str(args.candidate),
        "controlDir": str(args.control),
        "perSeed": {
            "candidate": cand_meta,
            "control": ctrl_meta,
        },
        "candidateStatusCounts": status_counts(cand_fit.get("actors", {})),
        "controlStatusCounts": status_counts(ctrl_fit.get("actors", {})),
        "newFailures": new_failures,
        "newPasses": new_passes,
        "actorChanges": actor_changes,
        "techFloorCandidate": tech_floor_summary(args.candidate),
        "techFloorControl": tech_floor_summary(args.control),
        "verdict": {
            "noNewFailures": not new_failures,
            "newPassesCount": len(new_passes),
            "newFailuresCount": len(new_failures),
            "candidateAllSeedsClean": all(
                r.get("success") and r.get("assertions") == 0 for r in cand_meta
            ),
            "controlAllSeedsClean": all(
                r.get("success") and r.get("assertions") == 0 for r in ctrl_meta
            ),
        },
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")

    print(json.dumps({
        "verdict": report["verdict"],
        "newFailures": new_failures,
        "newPasses": new_passes,
        "candidateStatusCounts": report["candidateStatusCounts"],
        "controlStatusCounts": report["controlStatusCounts"],
    }, sort_keys=True))
    return 0 if report["verdict"]["noNewFailures"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
