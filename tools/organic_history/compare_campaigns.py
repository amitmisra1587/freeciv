#!/usr/bin/env python3
"""Compare baseline and candidate organic-history campaigns."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare two organic-history campaigns.")
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--csv-output", type=Path, required=True)
    args = parser.parse_args()

    summary = compare_campaigns(args.baseline, args.candidate)
    args.output.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    write_comparison_csv(args.csv_output, summary["seedComparisons"])
    print(json.dumps(summary, sort_keys=True))
    return 0 if not summary["candidateWorseThanBaseline"] else 1


def compare_campaigns(baseline_dir: Path, candidate_dir: Path) -> dict[str, Any]:
    baseline_summary = read_json(baseline_dir / "campaign_summary.json")
    candidate_summary = read_json(candidate_dir / "campaign_summary.json")
    baseline_runs = load_run_summaries(baseline_dir)
    candidate_runs = load_run_summaries(candidate_dir)
    seed_comparisons = []
    for seed in sorted(set(baseline_runs) | set(candidate_runs)):
        base = baseline_runs.get(seed, {})
        cand = candidate_runs.get(seed, {})
        seed_comparisons.append({
            "seed": seed,
            "baselineSuccess": base.get("success", False),
            "candidateSuccess": cand.get("success", False),
            "baselineFinalCities": num(base.get("finalTotalCities")),
            "candidateFinalCities": num(cand.get("finalTotalCities")),
            "baselineMaxCityShare": num(base.get("maxCityShare")),
            "candidateMaxCityShare": num(cand.get("maxCityShare")),
            "candidateCivilWarChecks": num(cand.get("mechanics", {}).get("civilWarChecks")),
            "candidateCivilWarTriggered": num(cand.get("mechanics", {}).get("civilWarTriggered")),
            "candidateMechanicLogs": num(cand.get("logCounts", {}).get("mechanic")),
        })

    baseline_failed = num(baseline_summary.get("runsFailed"))
    candidate_failed = num(candidate_summary.get("runsFailed"))
    candidate_mechanics = candidate_summary.get("aggregate", {})
    civil_war_triggered = num(candidate_mechanics.get("civilWarTriggered"))
    mechanic_logs = num(candidate_mechanics.get("organicMechanicLogs"))
    candidate_final_min = num(candidate_summary.get("aggregate", {}).get("minFinalCities"))
    baseline_domination = num(baseline_summary.get("aggregate", {}).get("dominationWarnings"))
    candidate_domination = num(candidate_summary.get("aggregate", {}).get("dominationWarnings"))
    runaway = civil_war_triggered > max(3, len(seed_comparisons) * 2)
    worse = (candidate_failed > baseline_failed
             or candidate_final_min <= 0
             or candidate_domination > baseline_domination
             or runaway)

    return {
        "baseline": str(baseline_dir),
        "candidate": str(candidate_dir),
        "baselineSummary": baseline_summary,
        "candidateSummary": candidate_summary,
        "seedComparisons": seed_comparisons,
        "runawayCivilWarWarning": runaway,
        "candidateWorseThanBaseline": worse,
        "mechanicLogsPresent": mechanic_logs > 0,
        "civilWarTriggered": civil_war_triggered,
    }


def load_run_summaries(campaign_dir: Path) -> dict[int, dict[str, Any]]:
    runs = {}
    for path in sorted(campaign_dir.glob("seed_*/run_summary.json")):
        summary = read_json(path)
        seed = summary.get("seed")
        if isinstance(seed, int):
            runs[seed] = summary
    return runs


def write_comparison_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields = list(rows[0])
    with path.open("w", encoding="utf-8", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def num(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0


if __name__ == "__main__":
    raise SystemExit(main())
