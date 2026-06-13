#!/usr/bin/env python3
"""Phase 45 expansion fingerprint diagnostic.

For each target actor, processes a campaign's per-seed server logs and reports
the EXPANSION shape that drives its historical-fit miss:

  - final city split: total / core / claimed / peripheral (median across seeds),
    from the last organic_history_collapse line per actor per seed.
  - peripheral over-grab fingerprint: the region distribution of the actor's
    peripheral (out-of-claim) cities, aggregated from organic_history_collapse_
    candidate lines. This shows WHERE an over-expander sprawls (e.g. india into
    steppe/china, nubia across africa/near_east).
  - over/under classification vs the fit expectation (medianMaxCitiesMin/Max).

No new simulation: reads an existing campaign dir (default the Wave 3 100x200
baseline).

Usage:
  python3 tools/organic_history/phase45_expansion_diagnostic.py \
      --campaign-dir runs/organic_history_phase39_wave3_100x200 \
      --actors india,nubia,rome,castile \
      --output runs/organic_history_phase39_wave3_100x200/phase45_expansion.json
"""
from __future__ import annotations

import argparse
import json
import re
import statistics
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CAMPAIGN = ROOT / "runs" / "organic_history_phase39_wave3_100x200"

COLLAPSE_RE = re.compile(
    r'organic_history_collapse turn=(?P<turn>\d+) player=\d+ actor="(?P<actor>[a-z_]+)"'
    r'.*?cities=(?P<cities>\d+) core_cities=(?P<core>\d+) '
    r'claimed_cities=(?P<claimed>\d+) peripheral_cities=(?P<peripheral>\d+)')
CANDIDATE_RE = re.compile(
    r'organic_history_collapse_candidate turn=(?P<turn>\d+) player=\d+ '
    r'actor="(?P<actor>[a-z_]+)" city="[^"]*" region="(?P<region>[a-z_]+)"')

# Fit expectations (mirror of global_historical_fit_report DEFAULT_EXPECTATIONS,
# only the city-size bounds needed for classification).
EXPECT = {
    "india": {"maxMin": None, "finalMax": 18},
    "nubia": {"maxMin": None, "finalMin": 2, "finalMax": 10},
    "rome": {"maxMin": 10},
    "castile": {"maxMin": 3, "finalMin": 3},
    "egypt": {"finalMax": 20},
    "china": {"finalMax": 25},
}


def median(values: list[float]):
    return round(statistics.median(values), 2) if values else None


def find_log(seed_dir: Path) -> Path | None:
    for name in ("server_stdout.log", "server_stderr.log"):
        p = seed_dir / name
        if p.exists():
            return p
    return None


def process_seed(log_path: Path, actors: set[str]):
    """Return per-actor final split + peripheral-region counter for one seed."""
    last_split: dict[str, dict] = {}
    last_turn: dict[str, int] = {}
    region_counts: dict[str, Counter] = {a: Counter() for a in actors}
    with log_path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if "organic_history_collapse" not in line:
                continue
            m = COLLAPSE_RE.search(line)
            if m and m.group("actor") in actors:
                a = m.group("actor")
                t = int(m.group("turn"))
                if t >= last_turn.get(a, -1):
                    last_turn[a] = t
                    last_split[a] = {
                        "total": int(m.group("cities")),
                        "core": int(m.group("core")),
                        "claimed": int(m.group("claimed")),
                        "peripheral": int(m.group("peripheral")),
                    }
                continue
            mc = CANDIDATE_RE.search(line)
            if mc and mc.group("actor") in actors:
                region_counts[mc.group("actor")][mc.group("region")] += 1
    return last_split, region_counts


def classify(actor: str, total_med, peripheral_med):
    exp = EXPECT.get(actor, {})
    notes = []
    if "finalMax" in exp and total_med is not None and total_med > exp["finalMax"]:
        notes.append(f"OVER final {total_med} > cap {exp['finalMax']}")
    if "finalMin" in exp and total_med is not None and total_med < exp["finalMin"]:
        notes.append(f"UNDER final {total_med} < min {exp['finalMin']}")
    if "maxMin" in exp and exp.get("maxMin") and total_med is not None \
            and total_med < exp["maxMin"]:
        notes.append(f"UNDER total {total_med} < maxCitiesMin {exp['maxMin']}")
    return notes or ["within/near expectation"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign-dir", type=Path, default=DEFAULT_CAMPAIGN)
    parser.add_argument("--actors", default="india,nubia,rome,castile")
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    actors = {a.strip() for a in args.actors.split(",") if a.strip()}
    seed_dirs = sorted(args.campaign_dir.glob("seed_*"))
    if not seed_dirs:
        raise SystemExit(f"ERROR: no seed_* under {args.campaign_dir}")

    totals = {a: [] for a in actors}
    cores = {a: [] for a in actors}
    claimeds = {a: [] for a in actors}
    peripherals = {a: [] for a in actors}
    region_totals = {a: Counter() for a in actors}
    seeds_used = 0

    for seed_dir in seed_dirs:
        log_path = find_log(seed_dir)
        if log_path is None:
            continue
        seeds_used += 1
        last_split, region_counts = process_seed(log_path, actors)
        for a in actors:
            if a in last_split:
                totals[a].append(last_split[a]["total"])
                cores[a].append(last_split[a]["core"])
                claimeds[a].append(last_split[a]["claimed"])
                peripherals[a].append(last_split[a]["peripheral"])
            region_totals[a].update(region_counts[a])

    report = {"campaignDir": str(args.campaign_dir), "seedsUsed": seeds_used,
              "actors": {}}
    for a in sorted(actors):
        total_med = median(totals[a])
        periph_med = median(peripherals[a])
        top_regions = region_totals[a].most_common(8)
        report["actors"][a] = {
            "finalTotalMedian": total_med,
            "finalCoreMedian": median(cores[a]),
            "finalClaimedMedian": median(claimeds[a]),
            "finalPeripheralMedian": periph_med,
            "seedsWithData": len(totals[a]),
            "peripheralRegionTop": [{"region": r, "count": c}
                                    for r, c in top_regions],
            "classification": classify(a, total_med, periph_med),
            "expectation": EXPECT.get(a, {}),
        }

    out = args.output or args.campaign_dir / "phase45_expansion.json"
    out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                   encoding="utf-8")

    # Compact console view.
    print(f"seedsUsed={seeds_used}")
    for a in sorted(actors):
        d = report["actors"][a]
        regions = ", ".join(f"{x['region']}:{x['count']}"
                            for x in d["peripheralRegionTop"][:5])
        print(f"\n{a}: total~{d['finalTotalMedian']} "
              f"(core {d['finalCoreMedian']}, claimed {d['finalClaimedMedian']}, "
              f"peripheral {d['finalPeripheralMedian']})")
        print(f"  {'; '.join(d['classification'])}")
        print(f"  over-grab regions: {regions}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
