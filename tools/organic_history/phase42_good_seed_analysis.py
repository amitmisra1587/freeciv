#!/usr/bin/env python3
"""Phase 42 Path C: identify what makes Rome reach Roman-Empire scale in some
seeds and not others.

For each seed in the Wave 3 100x200 sweep, extracts:
  - Rome's spawn turn / tile
  - Rome's peak cities + peak turn
  - Rome's first conquest turn + target city
  - Per-rival (Carthage, Greece, Persia) city counts at Rome spawn,
    Rome peak, turn 100, turn 200
  - Number of claim conversions Rome receives across the campaign

Then partitions seeds into "great Rome" (peak >= 12), "median Rome"
(peak 6-11), "bad Rome" (peak <= 5) and reports per-group differentiators.

Usage:
  python3 tools/organic_history/phase42_good_seed_analysis.py \
      --sweep-dir runs/organic_history_phase39_wave3_100x200 \
      --output runs/organic_history_phase42_analysis/rome_pattern.json
"""
from __future__ import annotations

import argparse
import json
import re
import statistics
from collections import defaultdict
from pathlib import Path
from typing import Any

ROME_SPAWN_RE = re.compile(
    r'organic_history_emergence turn=(?P<turn>\d+) actor="rome" '
    r'action="spawned" .*player=(?P<player>\d+) .*x=(?P<x>\d+) y=(?P<y>\d+)'
)
METRIC_RE = re.compile(
    r'organic_history_metric turn=(?P<turn>\d+) year=-?\d+ player=(?P<player>\d+) '
    r'name="(?P<name>[^"]+)" nation="(?P<nation>[^"]+)" '
    r'alive=(?P<alive>true|false) cities=(?P<cities>\d+)'
)
CONQUEST_RE = re.compile(
    r'organic_history_event type=city_transferred turn=(?P<turn>\d+) '
    r'city="(?P<city>[^"]+)" loser=(?P<loser>\d+) winner=(?P<winner>\d+) '
    r'reason="(?P<reason>[^"]+)"'
)
CLAIM_CONV_RE = re.compile(
    r'organic_history_claim_conversion turn=(?P<turn>\d+) '
    r'actor="(?P<actor>[^"]+)".*applied=true'
)

# Rivals we want neighbor-state for
RIVAL_NATIONS = {
    "carthage": "Carthaginian",
    "greece": "Greek",
    "persia": "Persian",
    "egypt": "Egyptian",
}

SNAPSHOT_TURNS = [55, 75, 100, 125, 150, 175, 200]


def scan_seed(seed_dir: Path) -> dict[str, Any]:
    log = seed_dir / "server_stdout.log"
    if not log.exists():
        return {}

    rome_spawn_turn = None
    rome_player_id = None
    rome_spawn_x = None
    rome_spawn_y = None
    rome_conquests = []
    rome_lost = []
    rome_claim_convs = 0

    # Per-turn metrics keyed by (turn, player_nation)
    metrics_by_turn: dict[int, dict[str, int]] = defaultdict(dict)

    with open(log, "r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            m = ROME_SPAWN_RE.search(raw)
            if m:
                rome_spawn_turn = int(m.group("turn"))
                rome_player_id = int(m.group("player"))
                rome_spawn_x = int(m.group("x"))
                rome_spawn_y = int(m.group("y"))
                continue

            m = METRIC_RE.search(raw)
            if m:
                turn = int(m.group("turn"))
                nation = m.group("nation")
                if turn in SNAPSHOT_TURNS:
                    metrics_by_turn[turn][nation] = int(m.group("cities"))
                continue

            m = CONQUEST_RE.search(raw)
            if m and rome_player_id is not None:
                winner = int(m.group("winner"))
                loser = int(m.group("loser"))
                turn = int(m.group("turn"))
                if winner == rome_player_id:
                    rome_conquests.append({
                        "turn": turn,
                        "city": m.group("city"),
                        "loser": loser,
                    })
                if loser == rome_player_id:
                    rome_lost.append({
                        "turn": turn,
                        "city": m.group("city"),
                        "winner": winner,
                    })

            m = CLAIM_CONV_RE.search(raw)
            if m and m.group("actor") == "rome":
                rome_claim_convs += 1

    rome_peak = None
    if rome_player_id is not None:
        # Re-scan for Rome's peak cities count across all turns
        peak = 0
        peak_turn = 0
        for turn in SNAPSHOT_TURNS:
            roman_cities = metrics_by_turn.get(turn, {}).get("Roman", 0)
            if roman_cities > peak:
                peak = roman_cities
                peak_turn = turn
        rome_peak = {"cities": peak, "turn": peak_turn}

    first_conquest = rome_conquests[0] if rome_conquests else None
    third_conquest = rome_conquests[2] if len(rome_conquests) >= 3 else None
    return {
        "rome_spawn_turn": rome_spawn_turn,
        "rome_player_id": rome_player_id,
        "rome_spawn_x": rome_spawn_x,
        "rome_spawn_y": rome_spawn_y,
        "rome_peak_from_snapshots": rome_peak,
        "rome_first_conquest": first_conquest,
        "rome_third_conquest": third_conquest,
        "rome_total_conquests": len(rome_conquests),
        "rome_total_lost_cities": len(rome_lost),
        "rome_claim_conversions": rome_claim_convs,
        "snapshots": dict(metrics_by_turn),
    }


def classify_rome(peak_cities: int) -> str:
    if peak_cities >= 12:
        return "great"
    if peak_cities >= 6:
        return "median"
    return "bad"


def summarize_group(rows: list[dict[str, Any]]) -> dict[str, Any]:
    if not rows:
        return {"n": 0}

    def field_stats(field_path: list[str]) -> dict[str, float | None]:
        values = []
        for r in rows:
            cur: Any = r
            for k in field_path:
                if cur is None:
                    cur = None
                    break
                cur = cur.get(k) if isinstance(cur, dict) else None
            if cur is not None and isinstance(cur, (int, float)):
                values.append(float(cur))
        if not values:
            return {"n": 0, "min": None, "max": None, "median": None, "mean": None}
        return {
            "n": len(values),
            "min": min(values),
            "max": max(values),
            "median": statistics.median(values),
            "mean": round(sum(values) / len(values), 2),
        }

    def snapshot_stats(turn: int, nation: str) -> dict[str, Any]:
        values = []
        for r in rows:
            v = (r.get("snapshots") or {}).get(turn, {}).get(nation)
            if v is not None:
                values.append(int(v))
        if not values:
            return {"n": 0}
        return {
            "n": len(values),
            "median": statistics.median(values),
            "mean": round(sum(values) / len(values), 2),
            "min": min(values),
            "max": max(values),
        }

    summary: dict[str, Any] = {
        "n": len(rows),
        "rome_spawn_turn": field_stats(["rome_spawn_turn"]),
        "rome_peak_cities": field_stats(["rome_peak_from_snapshots", "cities"]),
        "rome_peak_turn": field_stats(["rome_peak_from_snapshots", "turn"]),
        "rome_first_conquest_turn": field_stats(["rome_first_conquest", "turn"]),
        "rome_third_conquest_turn": field_stats(["rome_third_conquest", "turn"]),
        "rome_total_conquests": field_stats(["rome_total_conquests"]),
        "rome_total_lost_cities": field_stats(["rome_total_lost_cities"]),
        "rome_claim_conversions": field_stats(["rome_claim_conversions"]),
        "neighbor_states_at_rome_spawn_turn55": {
            nation: snapshot_stats(55, nation) for nation in RIVAL_NATIONS.values()
        },
        "neighbor_states_turn100": {
            nation: snapshot_stats(100, nation) for nation in RIVAL_NATIONS.values()
        },
        "neighbor_states_turn150": {
            nation: snapshot_stats(150, nation) for nation in RIVAL_NATIONS.values()
        },
        "neighbor_states_turn200": {
            nation: snapshot_stats(200, nation) for nation in RIVAL_NATIONS.values()
        },
    }
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sweep-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    seed_dirs = sorted(args.sweep_dir.glob("seed_*"))
    per_seed: list[dict[str, Any]] = []
    for sd in seed_dirs:
        row = scan_seed(sd)
        if not row:
            continue
        row["seed"] = int(sd.name.split("_")[-1])
        peak_cities = (row.get("rome_peak_from_snapshots") or {}).get("cities", 0)
        row["rome_class"] = classify_rome(peak_cities)
        per_seed.append(row)

    groups: dict[str, list[dict[str, Any]]] = {"great": [], "median": [], "bad": []}
    for r in per_seed:
        groups[r["rome_class"]].append(r)

    report = {
        "sweepDir": str(args.sweep_dir),
        "n_seeds_scanned": len(per_seed),
        "class_counts": {k: len(v) for k, v in groups.items()},
        "great_seeds": sorted(r["seed"] for r in groups["great"]),
        "median_seeds": sorted(r["seed"] for r in groups["median"]),
        "bad_seeds": sorted(r["seed"] for r in groups["bad"]),
        "group_summaries": {k: summarize_group(v) for k, v in groups.items()},
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")

    print(json.dumps({
        "class_counts": report["class_counts"],
        "great_seeds": report["great_seeds"][:15],
        "bad_seeds": report["bad_seeds"][:15],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
