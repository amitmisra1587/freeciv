#!/usr/bin/env python3
"""Phase 43 - Wave 3 cross-scenario generalization reporter.

Compares a Wave 3 (claim-conversion) campaign arm against a same-seed,
mechanics-off control arm on a NON-global fixture (e.g. earth_medieval_v1,
earth_1450_v1). Unlike phase38_wave1_compare.py this reporter does NOT lean on
the pass/warn/fail verdicts: DEFAULT_EXPECTATIONS in
global_historical_fit_report.py is calibrated for the global_4000 EMERGENCE
scenario, so those thresholds are miscalibrated for a fixed medieval/1450
start. Verdicts, if computed, are reported as directional-only.

The generalization question is answered with three criteria:

  1. ACTIVE        - does the claim-conversion mechanic actually fire on this
                     fixture's map? (candidate organicClaimConversionLogs > 0
                     and >> control)
  2. NON-REGRESSIVE- no new Freeciv assertions vs control, comparable run
                     completion, no degenerate collapse (minFinalCities > 0,
                     meanFinalCities not far below control).
  3. SENSIBLE      - the stickiness effect manifests: candidate shows more
                     conquest-conversion / core-consolidation activity than
                     control, and net per-actor city retention is not negative.

Outcome taxonomy:
  generalizes        - active + non-regressive + sensible
  active_inconclusive- active + non-regressive but no clear behavioral effect
  regresses          - active but introduces new assertions / collapse
  inert              - mechanic does not fire (global_4000-specific)

Usage:
  python3 tools/organic_history/phase43_scenario_generalization.py \
      --candidate runs/.../p43_medieval_wave3 \
      --control   runs/.../baseline \
      --fixture   earth_medieval_v1 \
      --output    runs/.../phase43_medieval_report.json
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]

# Actors that carry region claims in the default (80x50) claim table and so
# could plausibly receive claim conversions on the medieval/1450 fixtures.
# Used only to annotate coverage, never to gate the verdict.
FIXTURE_ACTORS = {
    "earth_medieval_v1": ["franks", "byzantium", "abbasid", "chola", "song",
                          "steppe", "africa"],
    "earth_1450_v1": ["castile", "portugal", "ottoman", "venice", "ming",
                      "japan", "aztec", "inca"],
    "earth_ancient_v1": ["egypt", "sumer", "assyria", "hittite", "persia",
                         "greece", "rome", "carthage", "india", "china"],
}


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def per_seed_metadata(campaign_dir: Path) -> list[dict]:
    rows = []
    for seed_dir in sorted(campaign_dir.glob("seed_*")):
        md = load_json(seed_dir / "run_metadata.json")
        summary = load_json(seed_dir / "run_summary.json")
        rows.append({
            "seed": seed_dir.name,
            "success": md.get("success"),
            "assertions": int(md.get("freecivAssertionLogCount") or 0),
            "finalTurn": md.get("finalTurnSeen"),
            "claimConversionLogs": int(
                md.get("organicClaimConversionLogCount") or 0),
            "conquestConversionLogs": int(
                md.get("organicConquestConversionLogCount") or 0),
            "finalTotalCities": summary.get("finalTotalCities"),
            "alivePlayers": summary.get("alivePlayers"),
        })
    return rows


def arm_metrics(campaign_dir: Path) -> dict:
    summary = load_json(campaign_dir / "campaign_summary.json")
    agg = (summary or {}).get("aggregate", {}) or {}
    seeds = per_seed_metadata(campaign_dir)
    n = len(seeds) or 1
    succeeded = sum(1 for s in seeds if s["success"])
    total_assertions = sum(s["assertions"] for s in seeds)
    seeds_with_assertions = sum(1 for s in seeds if s["assertions"] > 0)
    alive = [s["alivePlayers"] for s in seeds if s["alivePlayers"] is not None]
    final_cities = [s["finalTotalCities"] for s in seeds
                    if s["finalTotalCities"] is not None]
    return {
        "campaignDir": str(campaign_dir),
        "runsRequested": summary.get("runsRequested", len(seeds)),
        "runsSucceeded": summary.get("runsSucceeded", succeeded),
        "seedCount": len(seeds),
        # Activity
        "claimConversionLogs": int(agg.get("organicClaimConversionLogs") or 0),
        "claimConversionActorApplied": agg.get(
            "claimConversionActorApplied", {}) or {},
        "conquestConversionLogs": int(
            agg.get("organicConquestConversionLogs") or 0),
        "conquestConversionActorActions": agg.get(
            "conquestConversionActorActions", {}) or {},
        "coreConsolidationLogs": int(
            agg.get("organicCoreConsolidationLogs") or 0),
        # Stability / behavior
        "meanFinalCities": agg.get("meanFinalCities"),
        "minFinalCities": agg.get("minFinalCities"),
        "maxFinalCities": agg.get("maxFinalCities"),
        "secessionEvents": agg.get("secessionEvents"),
        "totalAssertions": total_assertions,
        "seedsWithAssertions": seeds_with_assertions,
        "meanAlivePlayers": round(sum(alive) / len(alive), 2) if alive else None,
        "meanFinalCitiesObserved": (
            round(sum(final_cities) / len(final_cities), 2)
            if final_cities else None),
        "perSeed": seeds,
    }


def actor_evidence(campaign_dir: Path) -> dict[str, dict]:
    """Per-actor observed city outcomes (raw, threshold-independent)."""
    evidence_path = (campaign_dir / "civilization_evidence"
                     / "all_civilization_evidence.json")
    if not evidence_path.exists():
        try:
            subprocess.check_output([
                sys.executable,
                str(ROOT / "tools" / "organic_history"
                    / "generate_civilization_evidence.py"),
                "--sweep-dir", str(campaign_dir),
            ], text=True, stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as exc:
            print(f"WARN: civ evidence generation failed for {campaign_dir}: "
                  f"{exc.output}", file=sys.stderr)
            return {}
    data = load_json(evidence_path)
    out: dict[str, dict] = {}
    if isinstance(data, dict):
        for actor, rec in data.items():
            if not isinstance(rec, dict):
                continue
            out[actor] = {
                "finalCitiesMedian": rec.get("finalCitiesMedian"),
                "maxCitiesMedian": rec.get("maxCitiesMedian"),
                "survivalRate": rec.get("survivalRate"),
                "spawnRate": rec.get("spawnRate"),
            }
    return out


def build_report(candidate: Path, control: Path, fixture: str) -> dict:
    cand = arm_metrics(candidate)
    ctrl = arm_metrics(control)
    cand_ev = actor_evidence(candidate)
    ctrl_ev = actor_evidence(control)

    # Per-actor city deltas (candidate - control), shared actors only.
    actor_deltas = []
    pos_max = 0.0
    neg_max = 0.0
    for actor in sorted(set(cand_ev) | set(ctrl_ev)):
        cm = cand_ev.get(actor, {})
        bm = ctrl_ev.get(actor, {})

        def delta(field: str):
            cv = cm.get(field)
            bv = bm.get(field)
            if cv is None or bv is None:
                return None
            return round(cv - bv, 3)

        d_max = delta("maxCitiesMedian")
        d_final = delta("finalCitiesMedian")
        if d_max is not None:
            if d_max > 0:
                pos_max += d_max
            elif d_max < 0:
                neg_max += d_max
        actor_deltas.append({
            "actor": actor,
            "deltaMaxCitiesMedian": d_max,
            "deltaFinalCitiesMedian": d_final,
            "candidateMaxCitiesMedian": cm.get("maxCitiesMedian"),
            "controlMaxCitiesMedian": bm.get("maxCitiesMedian"),
            "candidateFinalCitiesMedian": cm.get("finalCitiesMedian"),
            "controlFinalCitiesMedian": bm.get("finalCitiesMedian"),
        })

    # ---- Criteria ----
    cand_cc = cand["claimConversionLogs"]
    ctrl_cc = ctrl["claimConversionLogs"]
    active = cand_cc > 0 and (ctrl_cc == 0 or cand_cc >= 3 * ctrl_cc)

    new_assertions = (cand["totalAssertions"] > ctrl["totalAssertions"]
                      and cand["seedsWithAssertions"]
                      > ctrl["seedsWithAssertions"])
    completion_ok = (cand["runsSucceeded"] >= max(0, ctrl["runsSucceeded"] - 1))
    min_cities = cand["minFinalCities"]
    no_collapse = (min_cities is None or min_cities > 0)
    cand_mean = cand["meanFinalCitiesObserved"]
    ctrl_mean = ctrl["meanFinalCitiesObserved"]
    cities_ok = (cand_mean is None or ctrl_mean is None or ctrl_mean == 0
                 or cand_mean >= 0.7 * ctrl_mean)
    non_regressive = (not new_assertions and completion_ok and no_collapse
                      and cities_ok)

    stickier = (cand["conquestConversionLogs"] >= ctrl["conquestConversionLogs"]
                or cand["coreConsolidationLogs"]
                >= ctrl["coreConsolidationLogs"])
    retention_ok = (pos_max + neg_max) >= 0  # net per-actor max-city delta
    sensible = stickier and retention_ok

    if not active:
        verdict = "inert"
    elif not non_regressive:
        verdict = "regresses"
    elif sensible:
        verdict = "generalizes"
    else:
        verdict = "active_inconclusive"

    fixture_actors = FIXTURE_ACTORS.get(fixture, [])
    covered = [a for a in fixture_actors if a in cand_ev]
    uncovered = [a for a in fixture_actors if a not in cand_ev]

    return {
        "fixture": fixture,
        "candidateDir": str(candidate),
        "controlDir": str(control),
        "verdict": verdict,
        "criteria": {
            "active": active,
            "nonRegressive": non_regressive,
            "sensible": sensible,
            "newAssertions": new_assertions,
            "completionOk": completion_ok,
            "noCollapse": no_collapse,
            "citiesOk": cities_ok,
            "stickier": stickier,
            "netMaxCityDelta": round(pos_max + neg_max, 3),
        },
        "candidate": cand,
        "control": ctrl,
        "actorDeltas": actor_deltas,
        "fixtureActorCoverage": {
            "withEvidence": covered,
            "withoutEvidence": uncovered,
        },
    }


def compact(report: dict) -> dict:
    cand = report["candidate"]
    ctrl = report["control"]
    return {
        "fixture": report["fixture"],
        "verdict": report["verdict"],
        "criteria": report["criteria"],
        "candidateClaimConversionLogs": cand["claimConversionLogs"],
        "controlClaimConversionLogs": ctrl["claimConversionLogs"],
        "candidateRunsSucceeded": f"{cand['runsSucceeded']}/{cand['runsRequested']}",
        "controlRunsSucceeded": f"{ctrl['runsSucceeded']}/{ctrl['runsRequested']}",
        "candidateMeanFinalCities": cand["meanFinalCitiesObserved"],
        "controlMeanFinalCities": ctrl["meanFinalCitiesObserved"],
        "fixtureActorsWithoutEvidence": report["fixtureActorCoverage"][
            "withoutEvidence"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True,
                        help="Wave 3 (claim-conversion) campaign dir.")
    parser.add_argument("--control", type=Path, required=True,
                        help="Mechanics-off control campaign dir.")
    parser.add_argument("--fixture", required=True,
                        help="Fixture name, e.g. earth_medieval_v1.")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--strict", action="store_true",
                        help="Exit non-zero when the verdict is 'regresses'.")
    args = parser.parse_args()

    report = build_report(args.candidate, args.control, args.fixture)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(json.dumps(compact(report), sort_keys=True))

    if args.strict and report["verdict"] == "regresses":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
