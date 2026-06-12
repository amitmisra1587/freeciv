#!/usr/bin/env python3
"""Phase 40 sub-phase A: per-actor failure diagnostic.

For each of the structural failures from Phase 39 Wave 3 100x200
(rome, castile, ming, india), produce a per-seed breakdown of:
  - spawn pattern (turn, mode, placement)
  - peak pattern (peak cities, peak turn)
  - final pattern (final cities, alive)
  - distribution of peak/final cities across all 100 seeds
  - cross-actor blocker analysis from log scans

Usage:
  python3 tools/organic_history/phase40_failure_diagnostic.py \
      --sweep-dir runs/organic_history_phase39_wave3_100x200 \
      --output runs/organic_history_phase40_diagnostic/failure_report.json
"""
from __future__ import annotations

import argparse
import json
import re
import statistics
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

TARGET_ACTORS = ["rome", "castile", "ming", "india"]

CONQUEST_RE = re.compile(
    r"organic_history_event type=city_transferred turn=(?P<turn>\d+) "
    r"city=\"(?P<city>[^\"]+)\" loser=(?P<loser>\d+) "
    r"winner=(?P<winner>\d+) reason=\"(?P<reason>[^\"]+)\""
)
CLAIM_CONV_RE = re.compile(
    r"organic_history_claim_conversion turn=(?P<turn>\d+) actor=\"(?P<actor>[^\"]+)\".*"
    r"applied=true.*claim_class=\"(?P<claim_class>[^\"]+)\" region=\"(?P<region>[^\"]+)\""
)


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def percentile(values: list[float], q: float) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    idx = int(q * (len(s) - 1))
    return s[idx]


def actor_distribution(evidence: dict) -> dict[str, Any]:
    peaks = evidence.get("samplePeakRecords") or []
    finals = evidence.get("sampleFinalRecords") or []
    peak_cities = [r.get("cities", 0) for r in peaks]
    final_cities = [r.get("cities", 0) for r in finals]
    final_alive = [bool(r.get("alive")) for r in finals]

    return {
        "n_seeds": len(finals),
        "peak_distribution": {
            "min": min(peak_cities) if peak_cities else 0,
            "max": max(peak_cities) if peak_cities else 0,
            "median": statistics.median(peak_cities) if peak_cities else 0,
            "p10": percentile(peak_cities, 0.10),
            "p25": percentile(peak_cities, 0.25),
            "p75": percentile(peak_cities, 0.75),
            "p90": percentile(peak_cities, 0.90),
            "histogram": dict(sorted(Counter(peak_cities).items())),
        },
        "final_distribution": {
            "min": min(final_cities) if final_cities else 0,
            "max": max(final_cities) if final_cities else 0,
            "median": statistics.median(final_cities) if final_cities else 0,
            "histogram": dict(sorted(Counter(final_cities).items())),
        },
        "alive_count": sum(final_alive),
        "dead_count": sum(1 for a in final_alive if not a),
        "peak_to_final_drop_per_seed": [
            r_p.get("cities", 0) - r_f.get("cities", 0)
            for r_p, r_f in zip(peaks, finals)
            if r_p.get("seed") == r_f.get("seed")
        ],
    }


def spawn_pattern(evidence: dict) -> dict[str, Any]:
    spawns = evidence.get("sampleSpawnRecords") or []
    if not spawns:
        return {"n_spawns": 0}
    spawn_turns = [r.get("turn", 0) for r in spawns]
    modes = Counter(r.get("mode", "unknown") for r in spawns)
    placements = Counter(r.get("placement", "unknown") for r in spawns)
    cities = Counter(r.get("city", "unknown") for r in spawns)
    return {
        "n_spawns": len(spawns),
        "spawn_turn_median": statistics.median(spawn_turns),
        "spawn_turn_min": min(spawn_turns),
        "spawn_turn_max": max(spawn_turns),
        "modes": dict(modes),
        "placements": dict(placements),
        "spawn_cities": dict(cities),
    }


def per_seed_records(evidence: dict) -> list[dict[str, Any]]:
    spawns = {r.get("seed"): r for r in evidence.get("sampleSpawnRecords") or []}
    peaks = {r.get("seed"): r for r in evidence.get("samplePeakRecords") or []}
    finals = {r.get("seed"): r for r in evidence.get("sampleFinalRecords") or []}
    rows = []
    all_seeds = sorted(
        set(spawns.keys()) | set(peaks.keys()) | set(finals.keys())
    )
    for seed in all_seeds:
        rows.append({
            "seed": seed,
            "spawn_turn": (spawns.get(seed) or {}).get("turn"),
            "spawn_mode": (spawns.get(seed) or {}).get("mode"),
            "spawn_placement": (spawns.get(seed) or {}).get("placement"),
            "peak_turn": (peaks.get(seed) or {}).get("turn"),
            "peak_cities": (peaks.get(seed) or {}).get("cities"),
            "final_cities": (finals.get(seed) or {}).get("cities"),
            "final_alive": (finals.get(seed) or {}).get("alive"),
            "final_culture": (finals.get(seed) or {}).get("culture"),
            "final_units": (finals.get(seed) or {}).get("units"),
        })
    return rows


def scan_seed_logs_for_actor(seed_dir: Path, actor_id: str,
                             max_records: int = 50) -> dict[str, Any]:
    """Scan a single seed's server stdout for conquest/conversion events
    involving the actor. Returns aggregate counters and a small sample.
    """
    log = seed_dir / "server_stdout.log"
    if not log.exists():
        return {}
    conquest_won = 0
    conquest_lost = 0
    claim_conv_applied = 0
    conv_regions: Counter = Counter()
    conv_classes: Counter = Counter()
    actor_player_ids: set[int] = set()

    # First pass: identify the actor's player IDs from the emergence_event
    spawn_re = re.compile(
        r"organic_history_emergence turn=\d+ actor=\"" + re.escape(actor_id)
        + r"\".*player=(\d+)"
    )
    for raw in log.read_text(encoding="utf-8", errors="replace").splitlines():
        m = spawn_re.search(raw)
        if m:
            actor_player_ids.add(int(m.group(1)))
    if not actor_player_ids:
        return {"actor_player_ids": []}

    for raw in log.read_text(encoding="utf-8", errors="replace").splitlines():
        m = CONQUEST_RE.search(raw)
        if m:
            winner = int(m.group("winner"))
            loser = int(m.group("loser"))
            if winner in actor_player_ids:
                conquest_won += 1
            if loser in actor_player_ids:
                conquest_lost += 1
        m2 = CLAIM_CONV_RE.search(raw)
        if m2 and m2.group("actor") == actor_id:
            claim_conv_applied += 1
            conv_classes[m2.group("claim_class")] += 1
            conv_regions[m2.group("region")] += 1
    return {
        "actor_player_ids": sorted(actor_player_ids),
        "conquest_won": conquest_won,
        "conquest_lost": conquest_lost,
        "claim_conversions_applied": claim_conv_applied,
        "claim_class_counts": dict(conv_classes),
        "region_counts": dict(conv_regions.most_common(10)),
    }


def aggregate_log_diagnostics(sweep_dir: Path, actor_id: str,
                              max_seeds: int = 20) -> dict[str, Any]:
    """Sample up to max_seeds seeds; aggregate conquest/conversion patterns."""
    seed_dirs = sorted(sweep_dir.glob("seed_*"))[:max_seeds]
    per_seed = {}
    aggregate = {
        "conquest_won_total": 0,
        "conquest_lost_total": 0,
        "claim_conversions_total": 0,
        "claim_class_counts": Counter(),
        "region_counts": Counter(),
    }
    for sd in seed_dirs:
        res = scan_seed_logs_for_actor(sd, actor_id)
        if not res:
            continue
        per_seed[sd.name] = res
        aggregate["conquest_won_total"] += res.get("conquest_won", 0)
        aggregate["conquest_lost_total"] += res.get("conquest_lost", 0)
        aggregate["claim_conversions_total"] += (
            res.get("claim_conversions_applied", 0)
        )
        for k, v in (res.get("claim_class_counts") or {}).items():
            aggregate["claim_class_counts"][k] += v
        for k, v in (res.get("region_counts") or {}).items():
            aggregate["region_counts"][k] += v
    aggregate["claim_class_counts"] = dict(aggregate["claim_class_counts"])
    aggregate["region_counts"] = dict(
        Counter(aggregate["region_counts"]).most_common(10)
    )
    return {
        "n_seeds_scanned": len(per_seed),
        "aggregate": aggregate,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sweep-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--log-sample-seeds", type=int, default=20,
                        help="How many seeds to deeply scan logs for.")
    args = parser.parse_args()

    evidence_dir = args.sweep_dir / "civilization_evidence"
    fit_report_path = args.sweep_dir / "fit_report.json"
    fit_report = load_json(fit_report_path)

    report = {
        "sweepDir": str(args.sweep_dir),
        "actorDiagnostics": {},
    }

    for actor_id in TARGET_ACTORS:
        evidence = load_json(evidence_dir / f"{actor_id}.json")
        if not evidence:
            report["actorDiagnostics"][actor_id] = {"error": "no evidence"}
            continue
        verdict = (fit_report.get("actors", {})
                   .get(actor_id, {})
                   .get("verdict"))
        observed = (fit_report.get("actors", {})
                    .get(actor_id, {})
                    .get("observed", {}))
        report["actorDiagnostics"][actor_id] = {
            "verdict": verdict,
            "observed_summary": {
                "finalCitiesMedian": observed.get("finalCitiesMedian"),
                "maxCitiesMedian": observed.get("maxCitiesMedian"),
                "spawnRate": observed.get("spawnRate"),
                "survivalRate": observed.get("survivalRate"),
                "peakToFinalDropMedian": observed.get("peakToFinalDropMedian"),
            },
            "spawn_pattern": spawn_pattern(evidence),
            "distribution": actor_distribution(evidence),
            "per_seed": per_seed_records(evidence),
            "log_diagnostics": aggregate_log_diagnostics(
                args.sweep_dir, actor_id, args.log_sample_seeds),
        }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")

    # Console summary
    print(json.dumps({
        "actors": {
            a: {
                "verdict": d.get("verdict"),
                "peak_p25": d.get("distribution", {}).get("peak_distribution", {}).get("p25"),
                "peak_p75": d.get("distribution", {}).get("peak_distribution", {}).get("p75"),
                "peak_median": d.get("distribution", {}).get("peak_distribution", {}).get("median"),
                "final_median": d.get("distribution", {}).get("final_distribution", {}).get("median"),
                "alive_rate": (d.get("distribution", {}).get("alive_count", 0)
                              / max(1, d.get("distribution", {}).get("n_seeds", 1))),
            }
            for a, d in report["actorDiagnostics"].items() if "distribution" in d
        }
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
