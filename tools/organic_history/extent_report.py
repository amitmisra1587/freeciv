#!/usr/bin/env python3
"""Territorial-extent realism report for an organic-history run.

For each major civilization, report the regions it actually held at its PEAK (max
cities) and compare to its historical claim footprint -- i.e. did Rome reach the
Mediterranean (Iberia/Gaul/N.Africa/Anatolia), or only Italy? Measures the "rise"
side that the count-based fidelity signals miss.

Reads runs/<run>/server_stdout.log (organic_history_metric for player->nation and
peak turn; organic_history_city_pressure for which regions a player holds).
"""
from __future__ import annotations

import argparse
import re
from collections import defaultdict
from pathlib import Path

# core + historical claim regions per major actor (from script.lua claims tables).
CLAIMS = {
    "rome": {"italy", "iberia", "gaul", "balkans_aegean", "maghreb_punic_west",
             "levant", "anatolia"},
    "persia": {"iran", "mesopotamia", "levant", "anatolia", "north_india"},
    "egypt": {"nile", "levant", "mesopotamia"},
    "carthage": {"maghreb_punic_west", "iberia", "italy"},
    "china": {"north_china", "south_china", "japan_korea", "steppe_mongolia"},
    "india": {"north_india", "deccan_south_india"},
    "greece": {"balkans_aegean", "anatolia"},
    "assyria": {"mesopotamia", "levant"},
    "nubia": {"nile", "africa"},
}
# nation (as logged) -> actor key
NATION_ACTOR = {
    "Roman": "rome", "Persian": "persia", "Egyptian": "egypt",
    "Carthaginian": "carthage", "Chinese": "china", "Indian": "india",
    "Greek": "greece", "Assyrian": "assyria", "Nubian": "nubia",
}

METRIC_RE = re.compile(
    r'organic_history_metric turn=(\d+) year=-?\d+ player=(\d+) name="[^"]*" '
    r'nation="([^"]+)" alive=\w+ cities=(\d+)')
CITY_RE = re.compile(
    r'organic_history_city_pressure turn=(\d+) city="[^"]*" city_id=[\d.]+ '
    r'player=(\d+) region="([^"]+)"')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-dir", type=Path, required=True)
    args = ap.parse_args()
    log = args.run_dir / "server_stdout.log"
    if not log.exists():
        print(f"no server_stdout.log in {args.run_dir}")
        return 1

    # player -> {turn: cities}, player -> nation
    pcities: dict[int, dict[int, int]] = defaultdict(dict)
    pnation: dict[int, str] = {}
    # player -> {turn: set(regions)}
    pregions: dict[int, dict[int, set]] = defaultdict(lambda: defaultdict(set))
    with open(log, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = METRIC_RE.search(line)
            if m:
                t, pid, nation, c = int(m.group(1)), int(m.group(2)), m.group(3), int(m.group(4))
                pcities[pid][t] = c
                pnation[pid] = nation
                continue
            m = CITY_RE.search(line)
            if m:
                t, pid, region = int(m.group(1)), int(m.group(2)), m.group(3)
                pregions[pid][t].add(region)

    # for each major actor, pick the player with the highest peak cities of that nation
    print(f"{'actor':9s} {'peak':>4s} {'@turn':>6s}  coverage  held / missing claimed regions")
    print("-" * 92)
    rows = []
    for actor, claimed in CLAIMS.items():
        # candidate players whose nation maps to this actor
        cands = [pid for pid, nat in pnation.items()
                 if NATION_ACTOR.get(nat) == actor]
        if not cands:
            continue
        # pick the player with the largest peak
        best_pid, best_peak, best_turn = None, -1, None
        for pid in cands:
            if not pcities[pid]:
                continue
            pk_turn = max(pcities[pid], key=lambda t: pcities[pid][t])
            pk = pcities[pid][pk_turn]
            if pk > best_peak:
                best_pid, best_peak, best_turn = pid, pk, pk_turn
        if best_pid is None:
            continue
        held = pregions[best_pid].get(best_turn, set())
        held_claimed = held & claimed
        missing = claimed - held
        cov = len(held_claimed) / len(claimed) if claimed else 0.0
        rows.append((actor, cov))
        print(f"{actor:9s} {best_peak:>4d} {best_turn:>6d}  {cov*100:6.0f}%  "
              f"{sorted(held_claimed)} / missing {sorted(missing)}")
    if rows:
        avg = sum(c for _, c in rows) / len(rows)
        print("-" * 92)
        print(f"mean claim coverage at peak: {avg*100:.0f}%  "
              f"(higher = civs reach their realistic historical extent)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
