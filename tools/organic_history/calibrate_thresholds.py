#!/usr/bin/env python3
"""Calibrate organic-history diagnostic thresholds from campaign output."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
from typing import Any


STRESS_RE = re.compile(r"\borganic_history_stability\b.*\bstress=(?P<stress>-?\d+)")


def main() -> int:
    parser = argparse.ArgumentParser(description="Calibrate thresholds from an organic-history campaign.")
    parser.add_argument("campaign_dir", type=Path)
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    thresholds = calibrate(args.campaign_dir)
    output = args.output or args.campaign_dir / "thresholds.json"
    output.write_text(json.dumps(thresholds, indent=2, sort_keys=True) + "\n",
                      encoding="utf-8")
    print(json.dumps(thresholds, sort_keys=True))
    return 0


def calibrate(campaign_dir: Path) -> dict[str, Any]:
    run_summaries = list(load_run_summaries(campaign_dir))
    stress_values = load_stress_values(campaign_dir)
    city_shares = [number(summary.get("maxCityShare")) for summary in run_summaries]
    city_deltas = [number(summary.get("cityCountDelta")) for summary in run_summaries]
    final_cities = [number(summary.get("finalTotalCities")) for summary in run_summaries]

    stress_p90 = percentile(stress_values, 90)
    stress_p95 = percentile(stress_values, 95)
    city_share_p90 = percentile(city_shares, 90)
    return {
        "campaignDir": str(campaign_dir),
        "runs": len(run_summaries),
        "stress": {
            "count": len(stress_values),
            "p50": percentile(stress_values, 50),
            "p75": percentile(stress_values, 75),
            "p90": stress_p90,
            "p95": stress_p95,
            "max": max(stress_values) if stress_values else 0,
        },
        "cityShare": {
            "p75": percentile(city_shares, 75),
            "p90": city_share_p90,
            "max": max(city_shares) if city_shares else 0,
        },
        "cityDelta": {
            "min": min(city_deltas) if city_deltas else 0,
            "p50": percentile(city_deltas, 50),
        },
        "finalCities": {
            "min": min(final_cities) if final_cities else 0,
            "p50": percentile(final_cities, 50),
            "max": max(final_cities) if final_cities else 0,
        },
        "recommended": {
            "civilWarStressThreshold": max(25, int(round(stress_p95 or stress_p90 or 45))),
            "civilWarMinCities": max(6, int(round(percentile(final_cities, 50) / 3)) if final_cities else 8),
            "civilWarProbability": 8,
            "civilWarCooldown": 40,
            "dominationCityShare": round(max(0.65, city_share_p90), 3),
            "stagnationCityDelta": min(0, int(min(city_deltas))) if city_deltas else 0,
        },
    }


def load_run_summaries(campaign_dir: Path):
    for summary_path in sorted(campaign_dir.glob("seed_*/run_summary.json")):
        yield json.loads(summary_path.read_text(encoding="utf-8"))


def load_stress_values(campaign_dir: Path) -> list[int]:
    values = []
    for log_path in sorted(campaign_dir.glob("seed_*/server_*.log")):
        for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
            match = STRESS_RE.search(line)
            if match:
                values.append(int(match.group("stress")))
    return values


def percentile(values: list[float | int], pct: int) -> float:
    if not values:
        return 0
    sorted_values = sorted(float(value) for value in values)
    if len(sorted_values) == 1:
        return round(sorted_values[0], 3)
    rank = (len(sorted_values) - 1) * (pct / 100)
    lower = int(rank)
    upper = min(lower + 1, len(sorted_values) - 1)
    weight = rank - lower
    value = sorted_values[lower] * (1 - weight) + sorted_values[upper] * weight
    return round(value, 3)


def number(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0


if __name__ == "__main__":
    raise SystemExit(main())
