#!/usr/bin/env python3
"""Generate per-civilization evidence from an organic-history campaign."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_HISTORY = ROOT / "data" / "organic_history" / "history" / "earth_global_4000.json"

LINE_FIELD_RE = re.compile(r'\b([A-Za-z_][A-Za-z0-9_]*)=("(?:[^"\\]|\\.)*"|\S+)')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign-dir", "--sweep-dir", dest="campaign_dir",
                        type=Path, required=True)
    parser.add_argument("--history-model", type=Path, default=DEFAULT_HISTORY)
    parser.add_argument("--output-dir", type=Path, default=None)
    args = parser.parse_args()

    campaign_dir = resolve(args.campaign_dir)
    history_model = resolve(args.history_model)
    output_dir = resolve(args.output_dir) if args.output_dir else campaign_dir / "civilization_evidence"

    history = read_json(history_model)
    evidence = build_evidence(campaign_dir, history)
    output_dir.mkdir(parents=True, exist_ok=True)
    for actor_id, actor_evidence in evidence.items():
        (output_dir / f"{actor_id}.json").write_text(
            json.dumps(actor_evidence, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        (output_dir / f"{actor_id}.txt").write_text(
            actor_text(actor_evidence), encoding="utf-8"
        )
    (output_dir / "all_civilization_evidence.json").write_text(
        json.dumps(evidence, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({
        "actors": len(evidence),
        "campaignDir": str(campaign_dir),
        "output": str(output_dir / "all_civilization_evidence.json"),
    }, sort_keys=True))
    return 0


def resolve(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def build_evidence(
    campaign_dir: Path,
    history: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    actors = {
        actor["id"]: actor
        for actor in history.get("actors", [])
    }
    actor_ids = list(actors)
    seeds = sorted(campaign_dir.glob("seed_*/run_summary.json"))
    if not seeds:
        raise SystemExit(f"ERROR: no seed_*/run_summary.json files under {campaign_dir}")

    state = {
        actor_id: {
            "actor": actor_id,
            "actions": {},
            "dynasticTransferActions": {},
            "dynasticTransferReasons": {},
            "outcomes_by_seed": {},
            "spawn_records": [],
            "final_records": [],
            "peak_records": [],
            "max_cities": [],
            "latest_claims": [],
            "collapse_risks": [],
            "release_candidates": {},
        }
        for actor_id in actor_ids
    }

    for summary_path in seeds:
        seed = seed_from_path(summary_path)
        summary = read_json(summary_path)
        process_summary(seed, summary, actors, state)
        process_logs(seed, summary_path.parent, actor_ids, state)

    total_seeds = len(seeds)
    return {
        actor_id: finish_actor_evidence(actor_id, actor_state, total_seeds)
        for actor_id, actor_state in state.items()
    }


def process_summary(
    seed: int,
    summary: dict[str, Any],
    actors: dict[str, dict[str, Any]],
    state: dict[str, dict[str, Any]],
) -> None:
    final_players = summary.get("finalPlayers", {})
    per_turn = summary.get("perTurn", [])
    final_turn = summary.get("finalTurn")

    for actor_id, actor in actors.items():
        leader = actor.get("leader")
        nation = actor.get("nation")
        final_record = final_record_for(seed, final_turn, leader, nation,
                                        final_players)
        state[actor_id]["final_records"].append(final_record)
        peak_record = peak_record_for(seed, leader, per_turn)
        state[actor_id]["peak_records"].append(peak_record)
        state[actor_id]["max_cities"].append(peak_record["cities"])


def final_record_for(
    seed: int,
    final_turn: int | None,
    leader: str,
    nation: str,
    final_players: dict[str, Any],
) -> dict[str, Any]:
    for player_id, record in final_players.items():
        if record.get("name") == leader:
            cities = int(num(record.get("cities")))
            return {
                "seed": seed,
                "turn": final_turn,
                "player": int(player_id),
                "name": record.get("name"),
                "nation": nation,
                "alive": cities > 0,
                "cities": cities,
                "units": int(num(record.get("munits"))),
                "gold": int(num(record.get("gold"))),
                "culture": int(num(record.get("culture"))),
                "government": record.get("gov"),
            }

    return {
        "seed": seed,
        "turn": final_turn,
        "player": None,
        "name": leader,
        "nation": nation,
        "alive": False,
        "cities": 0,
        "units": 0,
        "gold": 0,
        "culture": 0,
        "government": 0,
    }


def max_cities_for(leader: str, per_turn: list[dict[str, Any]]) -> int:
    values = [
        int(num(row.get("cities")))
        for row in per_turn
        if row.get("playerName") == leader
    ]
    return max(values) if values else 0


def peak_record_for(
    seed: int,
    leader: str,
    per_turn: list[dict[str, Any]],
) -> dict[str, Any]:
    best = {
        "seed": seed,
        "turn": None,
        "year": None,
        "cities": 0,
    }

    for row in per_turn:
        if row.get("playerName") != leader:
            continue
        cities = int(num(row.get("cities")))
        if cities > best["cities"]:
            best = {
                "seed": seed,
                "turn": maybe_int(row.get("turn")),
                "year": maybe_int(row.get("year")),
                "cities": cities,
            }

    return best


def process_logs(
    seed: int,
    run_dir: Path,
    actor_ids: list[str],
    state: dict[str, dict[str, Any]],
) -> None:
    for log_path in sorted(run_dir.glob("server_*.log")):
        for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
            if "organic_history_emergence " in line:
                fields = parse_fields(line)
                actor_id = fields.get("actor")
                if actor_id in state:
                    action = str(fields.get("action", "unknown"))
                    increment(state[actor_id]["actions"], action)
                    record_emergence_outcome(seed, state[actor_id], action, fields)
                    if action in ("spawned", "inherited_spawn"):
                        state[actor_id]["spawn_records"].append(spawn_record(seed, fields))
            elif "organic_history_dynastic_transfer" in line:
                fields = parse_fields(line)
                actor_id = fields.get("actor")
                if actor_id in state:
                    action = str(fields.get("action", "unknown"))
                    reason = str(fields.get("reason", "unknown"))
                    increment(state[actor_id]["dynasticTransferActions"], action)
                    increment(state[actor_id]["dynasticTransferReasons"], reason)
                    record_dynastic_outcome(seed, state[actor_id], action, reason)
            elif "organic_history_claim_pressure" in line:
                fields = parse_fields(line)
                actor_id = fields.get("actor")
                if actor_id in state:
                    state[actor_id]["latest_claim_by_seed"] = state[actor_id].get("latest_claim_by_seed", {})
                    state[actor_id]["latest_claim_by_seed"][seed] = {
                        "coreShare": maybe_num(fields.get("core_city_share")),
                        "claimedShare": maybe_num(fields.get("claimed_city_share")),
                        "overextension": maybe_num(fields.get("overextension")),
                        "rivalPressure": maybe_num(fields.get("rival_pressure")),
                    }
            elif "organic_history_collapse " in line:
                fields = parse_fields(line)
                actor_id = fields.get("actor")
                if actor_id in state:
                    risk = maybe_num(fields.get("collapse_risk"))
                    if risk is not None:
                        state[actor_id]["collapse_risks"].append(risk)
            elif "organic_history_collapse_candidate" in line:
                fields = parse_fields(line)
                actor_id = fields.get("actor")
                if actor_id in state:
                    key = (
                        str(fields.get("city", "unknown")),
                        str(fields.get("region", "unknown")),
                        str(fields.get("claim_type", "unknown")),
                    )
                    candidates = state[actor_id]["release_candidates"]
                    candidates[key] = candidates.get(key, 0) + 1

    for actor_id in actor_ids:
        latest_claim = state[actor_id].get("latest_claim_by_seed", {}).get(seed)
        if latest_claim is not None:
            state[actor_id]["latest_claims"].append(latest_claim)


def record_outcome(seed: int, actor_state: dict[str, Any], outcome: str) -> None:
    outcomes = actor_state["outcomes_by_seed"].setdefault(seed, set())
    outcomes.add(outcome)


def record_emergence_outcome(
    seed: int,
    actor_state: dict[str, Any],
    action: str,
    fields: dict[str, Any],
) -> None:
    if action in ("spawned", "inherited_spawn"):
        record_outcome(seed, actor_state, "spawned")
    if action == "inherited_spawn":
        record_outcome(seed, actor_state, "inherited")
    elif action == "dynastic_continuity":
        record_outcome(seed, actor_state, "healthy_continuity_escape")
    elif action in ("delayed_no_site", "delayed_city_site"):
        record_outcome(seed, actor_state, "delayed_no_site")
    elif action == "probability":
        record_outcome(seed, actor_state, "probability_skip")

    mode = fields.get("mode")
    if action in ("spawned", "inherited_spawn"):
        if mode in ("foreign_core_claimant", "weak_holder"):
            record_outcome(seed, actor_state, "claimant_spawn")
        elif mode == "lineage_successor":
            record_outcome(seed, actor_state, "lineage_spawn")
        elif mode == "empty_core":
            record_outcome(seed, actor_state, "empty_core_spawn")


def record_dynastic_outcome(
    seed: int,
    actor_state: dict[str, Any],
    action: str,
    reason: str,
) -> None:
    if reason == "escape_route":
        record_outcome(seed, actor_state, "healthy_continuity_escape")
    elif reason in ("missing_transfer_city", "successor_activation_failed",
                    "transfer_failed", "transfer_cap_zero"):
        record_outcome(seed, actor_state, "failed_activation")
    elif reason in ("bounded_cluster_inheritance", "single_city_inheritance"):
        record_outcome(seed, actor_state, "inherited")
    elif reason == "delayed":
        record_outcome(seed, actor_state, "delayed")
    elif reason == "successor_exists":
        record_outcome(seed, actor_state, "successor_exists")
    elif action == "candidate":
        record_outcome(seed, actor_state, "eligible_transfer")


def spawn_record(seed: int, fields: dict[str, Any]) -> dict[str, Any]:
    return {
        "seed": seed,
        "turn": maybe_int(fields.get("turn")),
        "mode": fields.get("mode"),
        "placement": fields.get("placement"),
        "player": maybe_int(fields.get("player")),
        "leader": fields.get("leader"),
        "nation": fields.get("nation"),
        "city": fields.get("city"),
        "x": maybe_int(fields.get("x")),
        "y": maybe_int(fields.get("y")),
        "core_region": fields.get("core_region"),
    }


def finish_actor_evidence(
    actor_id: str,
    actor_state: dict[str, Any],
    total_seeds: int,
) -> dict[str, Any]:
    final_records = sorted(actor_state["final_records"], key=lambda record: record["seed"])
    peak_records = sorted(actor_state["peak_records"], key=lambda record: record["seed"])
    final_cities = [record["cities"] for record in final_records]
    max_cities = actor_state["max_cities"]
    spawn_records = sorted(actor_state["spawn_records"], key=lambda record: (record["seed"], record.get("turn") or 0))
    spawned_seeds = {record["seed"] for record in spawn_records}
    spawn_turns = [
        record["turn"]
        for record in spawn_records
        if isinstance(record.get("turn"), int)
    ]
    latest_claims = actor_state["latest_claims"]
    collapse_risks = actor_state["collapse_risks"]
    outcomes_by_seed = actor_state["outcomes_by_seed"]
    alive_records = [record for record in final_records if record["alive"]]
    spawned_final_records = [
        record for record in final_records if record["seed"] in spawned_seeds
    ]
    spawned_final_cities = [record["cities"] for record in spawned_final_records]
    spawned_max_cities = [
        max_city for record, max_city in zip(final_records, max_cities)
        if record["seed"] in spawned_seeds
    ]
    peak_turns = [
        record["turn"] for record in peak_records
        if isinstance(record.get("turn"), int) and record["cities"] > 0
    ]
    peak_to_final_drops = [
        max(0, peak_record["cities"] - final_record["cities"])
        for peak_record, final_record in zip(peak_records, final_records)
    ]
    spawned_peak_to_final_drops = [
        drop for final_record, drop in zip(final_records, peak_to_final_drops)
        if final_record["seed"] in spawned_seeds
    ]
    spawned_alive = [
        record for record in spawned_final_records if record["alive"]
    ]

    evidence = {
        "actor": actor_id,
        "totalSeeds": total_seeds,
        "actions": dict(sorted(actor_state["actions"].items())),
        "dynasticTransferActions": dict(sorted(actor_state["dynasticTransferActions"].items())),
        "dynasticTransferReasons": dict(sorted(actor_state["dynasticTransferReasons"].items())),
        "successorOutcomeCounts": outcome_counts(outcomes_by_seed, spawned_seeds,
                                                 total_seeds),
        "spawnedSeedCount": len(spawned_seeds),
        "spawnRate": round(len(spawned_seeds) / total_seeds, 3),
        "spawnRateWilsonLower95": round(
            wilson_lower_bound(len(spawned_seeds), total_seeds), 3
        ),
        "spawnTurnMedian": median(spawn_turns),
        "survivalRate": round(
            len(alive_records) / total_seeds,
            3,
        ),
        "survivalRateWilsonLower95": round(
            wilson_lower_bound(len(alive_records), total_seeds), 3
        ),
        "survivalGivenSpawnRate": (
            round(len(spawned_alive) / len(spawned_seeds), 3)
            if spawned_seeds else None
        ),
        "survivalGivenSpawnWilsonLower95": (
            round(wilson_lower_bound(len(spawned_alive), len(spawned_seeds)), 3)
            if spawned_seeds else None
        ),
        "finalCitiesMean": round(mean(final_cities), 3),
        "finalCitiesMedian": median(final_cities),
        "finalCitiesP10": percentile(final_cities, 10),
        "finalCitiesP90": percentile(final_cities, 90),
        "maxCitiesMean": round(mean(max_cities), 3),
        "maxCitiesMedian": median(max_cities),
        "peakTurnMedian": median(peak_turns),
        "peakToFinalDropMean": round(mean(peak_to_final_drops), 3),
        "peakToFinalDropMedian": median(peak_to_final_drops),
        "finalCitiesGivenSpawnMean": (
            round(mean(spawned_final_cities), 3)
            if spawned_final_cities else None
        ),
        "finalCitiesGivenSpawnMedian": median(spawned_final_cities),
        "maxCitiesGivenSpawnMean": (
            round(mean(spawned_max_cities), 3)
            if spawned_max_cities else None
        ),
        "maxCitiesGivenSpawnMedian": median(spawned_max_cities),
        "peakToFinalDropGivenSpawnMean": (
            round(mean(spawned_peak_to_final_drops), 3)
            if spawned_peak_to_final_drops else None
        ),
        "peakToFinalDropGivenSpawnMedian": median(spawned_peak_to_final_drops),
        "collapseRiskMedian": median(collapse_risks),
        "collapseRiskMax": round(max(collapse_risks), 3) if collapse_risks else 0,
        "latestClaimMedian": median_claim(latest_claims),
        "topReleaseCandidates": top_release_candidates(actor_state["release_candidates"]),
        "sampleFinalRecords": final_records[:20],
        "samplePeakRecords": peak_records[:20],
        "sampleSpawnRecords": spawn_records[:20],
    }
    return evidence


def outcome_counts(
    outcomes_by_seed: dict[int, set[str]],
    spawned_seeds: set[int],
    total_seeds: int,
) -> dict[str, int]:
    counts: dict[str, int] = {}
    for outcomes in outcomes_by_seed.values():
        for outcome in outcomes:
            counts[outcome] = counts.get(outcome, 0) + 1
    counts["no_spawn"] = total_seeds - len(spawned_seeds)
    return dict(sorted(counts.items()))


def median_claim(claims: list[dict[str, float | None]]) -> dict[str, float]:
    result = {}
    for output_key, input_key in (
        ("coreShare", "coreShare"),
        ("claimedShare", "claimedShare"),
        ("overextension", "overextension"),
        ("rivalPressure", "rivalPressure"),
    ):
        values = [claim[input_key] for claim in claims if claim.get(input_key) is not None]
        result[output_key] = median(values) or 0
    return result


def top_release_candidates(candidates: dict[tuple[str, str, str], int]) -> list[dict[str, Any]]:
    return [
        {
            "city": city,
            "region": region,
            "claimType": claim_type,
            "count": count,
        }
        for (city, region, claim_type), count in sorted(
            candidates.items(),
            key=lambda item: (-item[1], item[0][0], item[0][1], item[0][2]),
        )[:10]
    ]


def actor_text(evidence: dict[str, Any]) -> str:
    return (
        f"{evidence['actor']}\n"
        f"spawnRate: {evidence['spawnRate']}\n"
        f"spawnRateWilsonLower95: {evidence['spawnRateWilsonLower95']}\n"
        f"spawnedSeedCount: {evidence['spawnedSeedCount']}\n"
        f"spawnTurnMedian: {evidence['spawnTurnMedian']}\n"
        f"survivalRate: {evidence['survivalRate']}\n"
        f"survivalGivenSpawnRate: {evidence['survivalGivenSpawnRate']}\n"
        f"finalCitiesMedian: {evidence['finalCitiesMedian']}\n"
        f"maxCitiesMedian: {evidence['maxCitiesMedian']}\n"
        f"maxCitiesGivenSpawnMedian: {evidence['maxCitiesGivenSpawnMedian']}\n"
        f"peakTurnMedian: {evidence['peakTurnMedian']}\n"
        f"peakToFinalDropMedian: {evidence['peakToFinalDropMedian']}\n"
        f"peakToFinalDropGivenSpawnMedian: {evidence['peakToFinalDropGivenSpawnMedian']}\n"
        f"collapseRiskMedian: {evidence['collapseRiskMedian']}\n"
        f"actions: {json.dumps(evidence['actions'], sort_keys=True)}\n"
        f"successorOutcomeCounts: {json.dumps(evidence['successorOutcomeCounts'], sort_keys=True)}\n"
    )


def parse_fields(line: str) -> dict[str, Any]:
    fields = {}
    for key, raw_value in LINE_FIELD_RE.findall(line):
        fields[key] = parse_scalar(raw_value)
    return fields


def parse_scalar(text: str) -> Any:
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        return text[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    if text in ("true", "false"):
        return text == "true"
    value = maybe_int(text)
    if value is not None:
        return value
    value_float = maybe_num(text)
    return value_float if value_float is not None else text


def seed_from_path(path: Path) -> int:
    text = path.parent.name.removeprefix("seed_")
    return int(text)


def increment(counts: dict[str, int], key: str) -> None:
    counts[key] = counts.get(key, 0) + 1


def maybe_int(value: Any) -> int | None:
    try:
        return int(str(value))
    except (TypeError, ValueError):
        return None


def maybe_num(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def num(value: Any) -> float:
    return maybe_num(value) or 0.0


def mean(values: list[int | float]) -> float:
    return sum(values) / len(values) if values else 0.0


def wilson_lower_bound(successes: int, total: int, z: float = 1.96) -> float:
    if total <= 0:
        return 0.0
    phat = successes / total
    denominator = 1 + z * z / total
    center = phat + z * z / (2 * total)
    margin = z * ((phat * (1 - phat) + z * z / (4 * total)) / total) ** 0.5
    return max(0.0, (center - margin) / denominator)


def median(values: list[int | float]) -> float | None:
    if not values:
        return None
    values = sorted(values)
    midpoint = len(values) // 2
    if len(values) % 2:
        return round(float(values[midpoint]), 3)
    return round((values[midpoint - 1] + values[midpoint]) / 2, 3)


def percentile(values: list[int | float], percentile_value: int) -> float | None:
    if not values:
        return None
    values = sorted(values)
    if len(values) == 1:
        return round(float(values[0]), 3)
    rank = (len(values) - 1) * percentile_value / 100
    lower = int(rank)
    upper = min(lower + 1, len(values) - 1)
    weight = rank - lower
    return round(values[lower] * (1 - weight) + values[upper] * weight, 3)


if __name__ == "__main__":
    raise SystemExit(main())
