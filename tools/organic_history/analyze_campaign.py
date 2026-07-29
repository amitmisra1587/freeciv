#!/usr/bin/env python3
"""Combine organic-history run artifacts into per-run summaries."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import re
from typing import Any

from parse_savegame import parse_savegame
from parse_scorelog import parse_scorelog


STRESS_RE = re.compile(r"\borganic_history_stability\b.*\bstress=(?P<stress>-?\d+)")
RISK_RE = re.compile(r'\borganic_history_stability\b.*\brisk="?(?P<risk>[A-Za-z_]+)"?')
MECHANIC_RE = re.compile(r"\borganic_history_mechanic\b.*\btype=(?P<type>[A-Za-z0-9_]+)")
REASON_RE = re.compile(r'\breason="?(?P<reason>[A-Za-z0-9_]+)"?')
FLOAT_FIELD_RE = r'\b{field}=(-?\d+(?:\.\d+)?)'
CITY_PRESSURE_FIELDS = [
    "population_pressure",
    "food_pressure",
    "economic_pressure",
    "garrison_pressure",
    "development",
    "unrest",
    "autonomy",
    "climate_stress",
    "migration_pressure",
]
INSTITUTION_FIELDS = ["cohesion", "reform_pressure"]
EVENT_RISK_FIELDS = ["succession", "fiscal", "plague", "trade_disruption", "climate", "frontier"]
STATE_CAPACITY_FIELDS = [
    "mandate",
    "mandate_deficit",
    "overextension",
    "cohesion",
    "cohesion_deficit",
    "reform_pressure",
    "unrest",
    "autonomy",
    "frontier_risk",
    "crisis",
    "recovery",
    "stress_modifier",
]
DYNASTIC_PROBE_FIELDS = [
    "base_stress",
    "succession_risk",
    "fiscal_risk",
    "frontier_risk",
    "cohesion",
    "reform_pressure",
    "mandate",
    "bonus",
    "institution_modifier",
    "pressure_modifier",
    "state_capacity_modifier",
    "state_capacity_crisis",
    "mandate_reduction",
    "effective_stress",
]
DYNASTIC_TRANSFER_FIELDS = [
    "predecessor_cities",
    "mandate",
    "crisis",
    "overextension",
    "region_total",
    "region_leader_share",
    "transfer_city_count",
    "transfer_cap",
    "min_remaining_cities",
    "transfer_city_available",
]
EXPANSION_PRESSURE_FIELDS = [
    "age",
    "cities",
    "target_min",
    "target_max",
    "core_cities",
    "historical_cities",
    "claimed_cities",
    "peripheral_cities",
    "claim_gap",
    "gold",
    "crisis",
]
PARTIAL_CONTRACTION_FIELDS = [
    "total_cities",
    "min_cities",
    "collapse_risk",
    "threshold",
    "effective_threshold",
    "crisis",
    "mandate",
    "overextension",
    "peripheral_share",
    "overextension_debt",
    "debt_required",
    "debt_overextension_threshold",
    "debt_peripheral_threshold",
    "release_candidates",
    "live_release_candidates",
    "peripheral_release_candidates",
    "regional_successor_candidates",
    "protected_center_candidates",
    "safe_release_candidates",
    "max_release_cities",
    "cluster_threshold",
    "cluster_peripheral_share",
    "transfer_limit",
    "transferred",
    "streak",
    "sustained_required",
]
URBANIZATION_FIELDS = [
    "cities",
    "target_cities",
    "created_so_far",
    "max_created",
    "cooldown",
    "created",
]
BURST_FIELDS = [
    "age",
    "start_age",
    "duration",
    "cities",
    "target_min",
    "target_max",
    "applications",
    "max_applications",
    "cooldown",
    "gold",
    "requested_units",
    "created_units",
    "skipped_units",
]
NEAR_EAST_HANDOFF_FIELDS = [
    "cities",
    "corridor_cities",
    "mesopotamia",
    "levant",
    "iran",
    "anatolia",
    "age",
    "target_min",
    "target_max",
    "applications",
    "max_applications",
    "gold",
    "offensive_units",
    "skipped_offensive",
    "settlers",
    "skipped_settlers",
]
CONQUEST_TARGET_FIELDS = [
    "cities",
    "age",
    "target_min",
    "target_max",
    "actor_region_cities",
    "rival_region_cities",
    "region_total",
    "target_score",
    "applications",
    "max_applications",
    "gold",
    "requested_units",
    "created_units",
    "skipped_units",
]
CONQUEST_CONVERSION_FIELDS = [
    "id",
    "start_turn",
    "age",
    "initial_actor_region_cities",
    "current_actor_region_cities",
    "max_actor_region_cities",
    "initial_rival_region_cities",
    "current_rival_region_cities",
    "min_rival_region_cities",
    "initial_region_total",
    "current_region_total",
    "city_gain",
    "peak_city_gain",
    "rival_loss",
    "target_score",
    "created_units",
    "skipped_units",
]
SETTLER_CONVERSION_FIELDS = [
    "id",
    "start_turn",
    "age",
    "initial_cities",
    "current_cities",
    "max_cities",
    "city_gain",
    "peak_city_gain",
    "created_settlers",
    "skipped_settlers",
]
OBJECTIVE_FIELDS = [
    "age",
    "start_age",
    "duration",
    "cities",
    "min_cities",
    "target_cities",
    "applications",
    "max_applications",
    "cooldown",
    "actor_region_cities",
    "rival_region_cities",
    "region_total",
    "target_score",
    "gold",
    "staging_x",
    "staging_y",
    "offensive_units",
    "defender_units",
    "site_x",
    "site_y",
    "settlers",
    "defenders",
    "skipped_units",
]
IBERIAN_SITE_FIELDS = [
    "candidate_count",
    "core_sites",
    "legal_core_sites",
    "iberian_sites",
    "legal_iberian_sites",
    "fallback_sites",
    "legal_fallback_sites",
    "target_units",
    "total_core_cities",
    "leader_share",
]
IBERIAN_SITE_POOL_FIELDS = [
    "checked",
    "city_occupied",
    "unit_occupied",
    "terrain_blocked",
    "empty_sites",
    "legal_sites",
    "illegal_sites",
]
IBERIAN_ACTIVATION_FIELDS = [
    "order",
    "castile_cities",
    "portugal_cities",
]
CONTRACTION_RECIPIENT_FIELDS = [
    "release_candidates",
    "live_candidates",
    "peripheral_candidates",
    "protected_center_candidates",
    "regional_successor_candidates",
    "safe_candidates",
    "missing_recipient_candidates",
    "recipient_core",
    "recipient_historical",
    "recipient_contested",
    "recipient_colonial",
    "recipient_cultural",
    "recipient_respawn",
    "recipient_peripheral",
    "recipient_unknown",
]
TARGET_OVERLAP_FIELDS = [
    "actor_region_cities",
    "rival_region_cities",
    "region_total",
    "target_score",
    "top_rival_cities",
]
TECH_FLOOR_FIELDS = [
    "median",
    "delta",
    "target",
    "actor_known",
    "actor_known_before",
    "granted",
    "attempted",
    "candidates",
    "max_grant",
    "peers",
]
CLAIM_CONVERSION_FIELDS = [
    "city_size",
    "gold",
    "history_added",
    "unlock_turn",
    "actor_applied_count",
]
FALLBACK_SUCCESSOR_FIELDS = [
    "spawns_this_turn",
    "cooldown",
]
HOMELAND_DEFENSE_FIELDS = [
    "required",
    "current",
    "birth_turn",
    "era_window",
    "total",
    "max_total",
]
CORE_CONSOLIDATION_FIELDS = [
    "cities",
    "target_cities",
    "applications",
    "max_applications",
    "cooldown",
    "created",
]
MANDATE_FIELDS = ["leader_share", "cohesion", "reform_pressure", "unrest", "mandate", "stress_reduction"]
CLAIM_PRESSURE_FIELDS = [
    "core_city_share",
    "claimed_city_share",
    "overextension",
    "core_region_leader_share",
    "rival_pressure",
]
COLLAPSE_FIELDS = [
    "core_share",
    "peripheral_share",
    "mandate",
    "crisis",
    "overextension",
    "scaling_stress",
    "collapse_risk",
    "release_candidates",
]
ACTION_RE = re.compile(r'\baction="?(?P<action>[A-Za-z0-9_]+)"?')
SECESSION_RE = re.compile(r"\borganic_history_secession\b.*\btype=(?P<type>[A-Za-z0-9_]+)")
SECESSION_DETAIL_FIELDS = [
    "turn",
    "player",
    "successor",
    "successor_name",
    "successor_nation",
    "parent_actor",
    "core_region",
    "city",
    "city_region",
    "city_core",
    "peripheral",
    "transferred",
]
ARRIVAL_FIELDS = [
    "turn",
    "player",
    "actor",
    "region",
    "region_group",
    "city",
    "city_count",
    "claim_type",
    "core_region",
    "origin_group",
    "x",
    "y",
]
OCEAN_CROSSING_FIELDS = [
    "turn",
    "player",
    "actor",
    "route",
    "origin_group",
    "target_region",
    "target_group",
    "city",
    "x",
    "y",
]
CONTACT_FIELDS = [
    "turn",
    "actor_a",
    "player_a",
    "actor_b",
    "player_b",
    "region",
    "kind",
    "actor_a_cities",
    "actor_b_cities",
]
OWNERSHIP_CHANGE_FIELDS = [
    "turn",
    "city",
    "city_id",
    "loser",
    "winner",
    "source",
    "category",
    "reason",
    "success",
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze one organic-history run directory.")
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--csv-output", type=Path, default=None)
    args = parser.parse_args()

    run_dir = args.run_dir
    summary = analyze_run(run_dir)
    output = args.output or run_dir / "run_summary.json"
    csv_output = args.csv_output or run_dir / "run_metrics.csv"
    output.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n",
                      encoding="utf-8")
    write_run_metrics_csv(summary, csv_output)
    print(json.dumps(compact_summary(summary), sort_keys=True))
    return 0 if summary.get("success") else 1


def analyze_run(run_dir: Path) -> dict[str, Any]:
    metadata = read_json(run_dir / "run_metadata.json")
    scorelog_path = Path(metadata.get("scorelogPath") or run_dir / "score.log")
    score_metrics_path = run_dir / "score_metrics.json"
    if scorelog_path.exists():
        score_metrics = parse_scorelog(scorelog_path)
        score_metrics_path.write_text(json.dumps(score_metrics, indent=2, sort_keys=True) + "\n",
                                      encoding="utf-8")
    else:
        score_metrics = {"summary": {"parseWarning": True}, "perTurn": []}

    final_save = metadata.get("finalSave")
    final_save_path = Path(final_save) if final_save else find_final_save(run_dir)
    save_metrics_path = run_dir / "save_metrics.json"
    if final_save_path and final_save_path.exists():
        save_metrics = parse_savegame(final_save_path)
        save_metrics_path.write_text(json.dumps(save_metrics, indent=2, sort_keys=True) + "\n",
                                     encoding="utf-8")
    else:
        save_metrics = {"summary": {"parseWarning": True}}

    log_metrics = parse_log_metrics(run_dir)
    score_summary = score_metrics.get("summary", {})
    save_summary = save_metrics.get("summary", {})
    final_players = score_metrics.get("finalPlayers", {})
    success = bool(metadata.get("success")) and scorelog_path.exists()

    return {
        "runDir": str(run_dir),
        "success": success,
        "seed": metadata.get("seed"),
        "turnsRequested": metadata.get("turns"),
        "playersRequested": metadata.get("players"),
        "finalTurn": score_metrics.get("finalTurn") or metadata.get("finalTurnSeen"),
        "elapsedSeconds": metadata.get("elapsedSeconds"),
        "saveCount": metadata.get("saveCount"),
        "scorelogPath": str(scorelog_path),
        "scoreMetricsPath": str(score_metrics_path),
        "saveMetricsPath": str(save_metrics_path),
        "rulesetdir": save_metrics.get("rulesetdir"),
        "alivePlayers": score_summary.get("aliveScorelogPlayers"),
        "saveAlivePlayers": save_summary.get("alivePlayers"),
        "finalTotalCities": score_summary.get("finalTotalCities"),
        "saveTotalCities": save_summary.get("totalCities"),
        "maxCityShare": score_summary.get("maxCityShare"),
        "maxScoreShare": score_summary.get("maxScoreShare"),
        "cityCountDelta": score_summary.get("cityCountDelta"),
        "scoreSpread": score_summary.get("scoreSpread"),
        "techSpread": score_summary.get("techSpread"),
        "warnings": {
            "domination": score_summary.get("dominationWarning", False),
            "stagnation": score_summary.get("stagnationWarning", False),
            "extinction": score_summary.get("extinctionWarning", False),
            "parse": score_summary.get("parseWarning", False),
        },
        "logCounts": log_metrics["counts"],
        "organicStress": log_metrics["stress"],
        "cityPressure": log_metrics["cityPressure"],
        "institutions": log_metrics["institutions"],
        "eventRisks": log_metrics["eventRisks"],
        "stateCapacity": log_metrics["stateCapacity"],
        "claimPressure": log_metrics["claimPressure"],
        "collapse": log_metrics["collapse"],
        "containment": log_metrics["containment"],
        "dynasticProbe": log_metrics["dynasticProbe"],
        "dynasticTransfer": log_metrics["dynasticTransfer"],
        "lineageHandoff": log_metrics["lineageHandoff"],
        "expansionPressure": log_metrics["expansionPressure"],
        "partialContraction": log_metrics["partialContraction"],
        "urbanization": log_metrics["urbanization"],
        "burst": log_metrics["burst"],
        "nearEastHandoff": log_metrics["nearEastHandoff"],
        "conquestTarget": log_metrics["conquestTarget"],
        "conquestConversion": log_metrics["conquestConversion"],
        "settlerConversion": log_metrics["settlerConversion"],
        "objective": log_metrics["objective"],
        "iberianSite": log_metrics["iberianSite"],
        "iberianSitePool": log_metrics["iberianSitePool"],
        "iberianActivation": log_metrics["iberianActivation"],
        "contractionRecipient": log_metrics["contractionRecipient"],
        "targetOverlap": log_metrics["targetOverlap"],
        "techFloor": log_metrics["techFloor"],
        "claimConversion": log_metrics["claimConversion"],
        "fallbackSuccessor": log_metrics["fallbackSuccessor"],
        "homelandDefense": log_metrics["homelandDefense"],
        "coreConsolidation": log_metrics["coreConsolidation"],
        "mandate": log_metrics["mandate"],
        "secession": log_metrics["secession"],
        "secessionDetails": log_metrics["secessionDetails"],
        "ownershipChanges": log_metrics["ownershipChanges"],
        "contactDiagnostics": log_metrics["contactDiagnostics"],
        "mechanics": log_metrics["mechanics"],
        "finalPlayers": final_players,
        "perTurn": score_metrics.get("perTurn", []),
    }


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def find_final_save(run_dir: Path) -> Path | None:
    saves = sorted(run_dir.glob("*final.sav*"))
    return saves[-1] if saves else None


def parse_log_metrics(run_dir: Path) -> dict[str, Any]:
    counts = {
        "turnBegin": 0,
        "metric": 0,
        "stability": 0,
        "event": 0,
        "ownershipChange": 0,
        "mechanic": 0,
        "region": 0,
        "prestige": 0,
        "cityPressure": 0,
        "institution": 0,
        "eventRisk": 0,
        "stateCapacity": 0,
        "claimPressure": 0,
        "collapse": 0,
        "collapseCandidate": 0,
        "containment": 0,
        "bootstrap": 0,
        "urbanization": 0,
        "burst": 0,
        "nearEastHandoff": 0,
        "conquestTarget": 0,
        "conquestConversion": 0,
        "settlerConversion": 0,
        "objective": 0,
        "iberianSite": 0,
        "iberianSitePool": 0,
        "iberianActivation": 0,
        "coreConsolidation": 0,
        "flavor": 0,
        "dynasticProbe": 0,
        "dynasticTransfer": 0,
        "lineageHandoff": 0,
        "expansionPressure": 0,
        "partialContraction": 0,
        "contractionRecipient": 0,
        "targetOverlap": 0,
        "techFloor": 0,
        "claimConversion": 0,
        "fallbackSuccessor": 0,
        "homelandDefense": 0,
        "mandate": 0,
        "secession": 0,
        "arrival": 0,
        "oceanCrossing": 0,
        "contact": 0,
    }
    mechanics = {
        "civilWarChecks": 0,
        "civilWarEligibleChecks": 0,
        "civilWarTriggered": 0,
        "civilWarNoop": 0,
        "civilWarSkips": 0,
        "civilWarSkipReasons": {},
        "civilWarCooldowns": 0,
        "civilWarInert": False,
    }
    stress_values: list[int] = []
    high_risk = 0
    city_pressure_values: dict[str, list[float]] = {field: [] for field in CITY_PRESSURE_FIELDS}
    institution_values: dict[str, list[float]] = {field: [] for field in INSTITUTION_FIELDS}
    event_risk_values: dict[str, list[float]] = {field: [] for field in EVENT_RISK_FIELDS}
    state_capacity_values: dict[str, list[float]] = {field: [] for field in STATE_CAPACITY_FIELDS}
    claim_pressure_values: dict[str, list[float]] = {field: [] for field in CLAIM_PRESSURE_FIELDS}
    collapse_values: dict[str, list[float]] = {field: [] for field in COLLAPSE_FIELDS}
    dynastic_probe_values: dict[str, list[float]] = {field: [] for field in DYNASTIC_PROBE_FIELDS}
    dynastic_transfer_values: dict[str, list[float]] = {field: [] for field in DYNASTIC_TRANSFER_FIELDS}
    expansion_pressure_values: dict[str, list[float]] = {field: [] for field in EXPANSION_PRESSURE_FIELDS}
    partial_contraction_values: dict[str, list[float]] = {field: [] for field in PARTIAL_CONTRACTION_FIELDS}
    mandate_values: dict[str, list[float]] = {field: [] for field in MANDATE_FIELDS}
    dynastic_actions: dict[str, int] = {}
    dynastic_transfer_actions: dict[str, int] = {}
    dynastic_transfer_reasons: dict[str, int] = {}
    dynastic_transfer_actor_actions: dict[str, int] = {}
    dynastic_transfer_actor_reasons: dict[str, int] = {}
    lineage_handoff_actions: dict[str, int] = {}
    lineage_handoff_reasons: dict[str, int] = {}
    lineage_handoff_actor_actions: dict[str, int] = {}
    lineage_handoff_actor_reasons: dict[str, int] = {}
    expansion_pressure_actions: dict[str, int] = {}
    partial_contraction_actions: dict[str, int] = {}
    partial_contraction_reasons: dict[str, int] = {}
    partial_contraction_actor_actions: dict[str, int] = {}
    partial_contraction_actor_reasons: dict[str, int] = {}
    urbanization_values: dict[str, list[float]] = {field: [] for field in URBANIZATION_FIELDS}
    urbanization_actions: dict[str, int] = {}
    urbanization_reasons: dict[str, int] = {}
    burst_values: dict[str, list[float]] = {field: [] for field in BURST_FIELDS}
    burst_actions: dict[str, int] = {}
    burst_reasons: dict[str, int] = {}
    burst_actor_actions: dict[str, int] = {}
    burst_actor_reasons: dict[str, int] = {}
    containment_actor_actions: dict[str, int] = {}
    near_east_handoff_values: dict[str, list[float]] = {
        field: [] for field in NEAR_EAST_HANDOFF_FIELDS
    }
    near_east_handoff_actions: dict[str, int] = {}
    near_east_handoff_reasons: dict[str, int] = {}
    near_east_handoff_actor_actions: dict[str, int] = {}
    near_east_handoff_actor_reasons: dict[str, int] = {}
    conquest_target_values: dict[str, list[float]] = {
        field: [] for field in CONQUEST_TARGET_FIELDS
    }
    conquest_target_actions: dict[str, int] = {}
    conquest_target_reasons: dict[str, int] = {}
    conquest_target_actor_actions: dict[str, int] = {}
    conquest_target_actor_reasons: dict[str, int] = {}
    conquest_conversion_values: dict[str, list[float]] = {
        field: [] for field in CONQUEST_CONVERSION_FIELDS
    }
    conquest_conversion_actions: dict[str, int] = {}
    conquest_conversion_reasons: dict[str, int] = {}
    conquest_conversion_actor_actions: dict[str, int] = {}
    conquest_conversion_actor_reasons: dict[str, int] = {}
    settler_conversion_values: dict[str, list[float]] = {
        field: [] for field in SETTLER_CONVERSION_FIELDS
    }
    settler_conversion_actions: dict[str, int] = {}
    settler_conversion_reasons: dict[str, int] = {}
    settler_conversion_actor_actions: dict[str, int] = {}
    settler_conversion_actor_reasons: dict[str, int] = {}
    objective_values: dict[str, list[float]] = {
        field: [] for field in OBJECTIVE_FIELDS
    }
    objective_actions: dict[str, int] = {}
    objective_reasons: dict[str, int] = {}
    objective_actor_actions: dict[str, int] = {}
    objective_actor_reasons: dict[str, int] = {}
    objective_actor_objectives: dict[str, int] = {}
    iberian_site_values: dict[str, list[float]] = {
        field: [] for field in IBERIAN_SITE_FIELDS
    }
    iberian_site_actor_placements: dict[str, int] = {}
    iberian_site_actor_holders: dict[str, int] = {}
    iberian_site_pool_values: dict[str, list[float]] = {
        field: [] for field in IBERIAN_SITE_POOL_FIELDS
    }
    iberian_site_pool_actor_regions: dict[str, int] = {}
    iberian_site_pool_actor_scopes: dict[str, int] = {}
    iberian_activation_values: dict[str, list[float]] = {
        field: [] for field in IBERIAN_ACTIVATION_FIELDS
    }
    iberian_activation_actor_actions: dict[str, int] = {}
    contraction_recipient_values: dict[str, list[float]] = {
        field: [] for field in CONTRACTION_RECIPIENT_FIELDS
    }
    contraction_recipient_actor_counts: dict[str, int] = {}
    target_overlap_values: dict[str, list[float]] = {
        field: [] for field in TARGET_OVERLAP_FIELDS
    }
    target_overlap_actor_regions: dict[str, int] = {}
    target_overlap_actor_sources: dict[str, int] = {}
    target_overlap_selected_regions: dict[str, int] = {}
    target_overlap_top_rivals: dict[str, int] = {}
    tech_floor_values: dict[str, list[float]] = {
        field: [] for field in TECH_FLOOR_FIELDS
    }
    tech_floor_actor_reasons: dict[str, int] = {}
    tech_floor_actor_applied: dict[str, int] = {}
    tech_floor_actor_skips: dict[str, int] = {}
    tech_floor_skip_reasons: dict[str, int] = {}
    claim_conversion_values: dict[str, list[float]] = {
        field: [] for field in CLAIM_CONVERSION_FIELDS
    }
    claim_conversion_actor_applied: dict[str, int] = {}
    claim_conversion_actor_skips: dict[str, int] = {}
    claim_conversion_actor_claim_classes: dict[str, int] = {}
    claim_conversion_skip_reasons: dict[str, int] = {}
    claim_conversion_actor_regions: dict[str, int] = {}
    fallback_successor_values: dict[str, list[float]] = {
        field: [] for field in FALLBACK_SUCCESSOR_FIELDS
    }
    fallback_successor_outcomes: dict[str, int] = {}
    fallback_successor_parent_regions: dict[str, int] = {}
    fallback_successor_dormant_actors: dict[str, int] = {}
    homeland_defense_values: dict[str, list[float]] = {
        field: [] for field in HOMELAND_DEFENSE_FIELDS
    }
    homeland_defense_actor_applied: dict[str, int] = {}
    homeland_defense_actor_skips: dict[str, int] = {}
    homeland_defense_actor_cities: dict[str, int] = {}
    homeland_defense_skip_reasons: dict[str, int] = {}
    core_consolidation_values: dict[str, list[float]] = {
        field: [] for field in CORE_CONSOLIDATION_FIELDS
    }
    core_consolidation_actions: dict[str, int] = {}
    core_consolidation_reasons: dict[str, int] = {}
    core_consolidation_actor_actions: dict[str, int] = {}
    core_consolidation_actor_reasons: dict[str, int] = {}
    secession_types: dict[str, int] = {}
    secession_details: list[dict[str, Any]] = []
    arrival_regions: dict[str, int] = {}
    arrival_groups: dict[str, int] = {}
    arrival_actors: dict[str, int] = {}
    ocean_crossing_routes: dict[str, int] = {}
    ocean_crossing_actors: dict[str, int] = {}
    contact_regions: dict[str, int] = {}
    first_new_world_arrival: dict[str, Any] | None = None
    first_ocean_crossing: dict[str, Any] | None = None
    ownership_sources: dict[str, int] = {}
    ownership_categories: dict[str, int] = {}
    ownership_reasons: dict[str, int] = {}
    ownership_changes: list[dict[str, Any]] = []
    for log_path in sorted(run_dir.glob("server_*.log")):
        for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
            if "organic_history turn_begin" in line:
                counts["turnBegin"] += 1
            if "organic_history_metric" in line:
                counts["metric"] += 1
            if "organic_history_event" in line:
                counts["event"] += 1
            if "organic_history_ownership_change" in line:
                counts["ownershipChange"] += 1
                fields = parse_line_fields(line, OWNERSHIP_CHANGE_FIELDS)
                increment_count(ownership_sources, fields.get("source"))
                increment_count(ownership_categories, fields.get("category"))
                increment_count(ownership_reasons, fields.get("reason"))
                ownership_changes.append(fields)
            if "organic_history_region" in line:
                counts["region"] += 1
            if "organic_history_prestige" in line:
                counts["prestige"] += 1
            if "organic_history_city_pressure" in line:
                counts["cityPressure"] += 1
                collect_float_fields(line, CITY_PRESSURE_FIELDS, city_pressure_values)
            if "organic_history_institution" in line:
                counts["institution"] += 1
                collect_float_fields(line, INSTITUTION_FIELDS, institution_values)
            if "organic_history_event_risk" in line:
                counts["eventRisk"] += 1
                collect_float_fields(line, EVENT_RISK_FIELDS, event_risk_values)
            if "organic_history_state_capacity" in line:
                counts["stateCapacity"] += 1
                collect_float_fields(line, STATE_CAPACITY_FIELDS, state_capacity_values)
            if "organic_history_claim_pressure" in line:
                counts["claimPressure"] += 1
                collect_float_fields(line, CLAIM_PRESSURE_FIELDS, claim_pressure_values)
            if "organic_history_collapse " in line:
                counts["collapse"] += 1
                collect_float_fields(line, COLLAPSE_FIELDS, collapse_values)
            if "organic_history_collapse_candidate" in line:
                counts["collapseCandidate"] += 1
            if "organic_history_containment " in line:
                counts["containment"] += 1
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor"])
                actor = str(fields.get("actor", "unknown"))
                increment_count(containment_actor_actions, f"{actor}:{action}")
            if "organic_history_bootstrap" in line:
                counts["bootstrap"] += 1
            if "organic_history_urbanization" in line:
                counts["urbanization"] += 1
                collect_float_fields(line, URBANIZATION_FIELDS, urbanization_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["reason"])
                reason = str(fields.get("reason", "unknown"))
                increment_count(urbanization_actions, action)
                increment_count(urbanization_reasons, reason)
            if "organic_history_burst" in line:
                counts["burst"] += 1
                collect_float_fields(line, BURST_FIELDS, burst_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor", "reason"])
                actor = str(fields.get("actor", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                increment_count(burst_actions, action)
                increment_count(burst_reasons, reason)
                increment_count(burst_actor_actions, f"{actor}:{action}")
                increment_count(burst_actor_reasons, f"{actor}:{reason}")
            if "organic_history_near_east_handoff" in line:
                counts["nearEastHandoff"] += 1
                collect_float_fields(line, NEAR_EAST_HANDOFF_FIELDS,
                                     near_east_handoff_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor", "reason"])
                actor = str(fields.get("actor", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                increment_count(near_east_handoff_actions, action)
                increment_count(near_east_handoff_reasons, reason)
                increment_count(near_east_handoff_actor_actions,
                                f"{actor}:{action}")
                increment_count(near_east_handoff_actor_reasons,
                                f"{actor}:{reason}")
            if "organic_history_conquest_target" in line:
                counts["conquestTarget"] += 1
                collect_float_fields(line, CONQUEST_TARGET_FIELDS,
                                     conquest_target_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor", "reason"])
                actor = str(fields.get("actor", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                increment_count(conquest_target_actions, action)
                increment_count(conquest_target_reasons, reason)
                increment_count(conquest_target_actor_actions, f"{actor}:{action}")
                increment_count(conquest_target_actor_reasons, f"{actor}:{reason}")
            if "organic_history_conquest_conversion" in line:
                counts["conquestConversion"] += 1
                collect_float_fields(line, CONQUEST_CONVERSION_FIELDS,
                                     conquest_conversion_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor", "reason"])
                actor = str(fields.get("actor", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                increment_count(conquest_conversion_actions, action)
                increment_count(conquest_conversion_reasons, reason)
                increment_count(conquest_conversion_actor_actions,
                                f"{actor}:{action}")
                increment_count(conquest_conversion_actor_reasons,
                                f"{actor}:{reason}")
            if "organic_history_settler_conversion" in line:
                counts["settlerConversion"] += 1
                collect_float_fields(line, SETTLER_CONVERSION_FIELDS,
                                     settler_conversion_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor", "reason"])
                actor = str(fields.get("actor", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                increment_count(settler_conversion_actions, action)
                increment_count(settler_conversion_reasons, reason)
                increment_count(settler_conversion_actor_actions,
                                f"{actor}:{action}")
                increment_count(settler_conversion_actor_reasons,
                                f"{actor}:{reason}")
            if "organic_history_objective" in line:
                counts["objective"] += 1
                collect_float_fields(line, OBJECTIVE_FIELDS, objective_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor", "objective",
                                                  "reason"])
                actor = str(fields.get("actor", "unknown"))
                objective = str(fields.get("objective", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                increment_count(objective_actions, action)
                increment_count(objective_reasons, reason)
                increment_count(objective_actor_actions, f"{actor}:{action}")
                increment_count(objective_actor_reasons, f"{actor}:{reason}")
                increment_count(objective_actor_objectives,
                                f"{actor}:{objective}:{action}")
            if "organic_history_iberian_site " in line:
                counts["iberianSite"] += 1
                collect_float_fields(line, IBERIAN_SITE_FIELDS,
                                     iberian_site_values)
                fields = parse_line_fields(line, ["actor", "placement",
                                                  "target_holder"])
                actor = str(fields.get("actor", "unknown"))
                placement = str(fields.get("placement", "unknown"))
                target_holder = str(fields.get("target_holder", "unknown"))
                increment_count(iberian_site_actor_placements,
                                f"{actor}:{placement}")
                increment_count(iberian_site_actor_holders,
                                f"{actor}:{target_holder}")
            if "organic_history_iberian_site_pool" in line:
                counts["iberianSitePool"] += 1
                collect_float_fields(line, IBERIAN_SITE_POOL_FIELDS,
                                    iberian_site_pool_values)
                fields = parse_line_fields(line, ["actor", "region", "scope"])
                actor = str(fields.get("actor", "unknown"))
                region = str(fields.get("region", "unknown"))
                scope = str(fields.get("scope", "unknown"))
                increment_count(iberian_site_pool_actor_regions,
                                f"{actor}:{region}")
                increment_count(iberian_site_pool_actor_scopes,
                                f"{actor}:{scope}")
            if "organic_history_iberian_activation_order" in line:
                counts["iberianActivation"] += 1
                collect_float_fields(line, IBERIAN_ACTIVATION_FIELDS,
                                    iberian_activation_values)
                fields = parse_line_fields(line, ["actor", "action"])
                actor = str(fields.get("actor", "unknown"))
                action = str(fields.get("action", "unknown"))
                increment_count(iberian_activation_actor_actions,
                                f"{actor}:{action}")
            if "organic_history_core_consolidation" in line:
                counts["coreConsolidation"] += 1
                collect_float_fields(line, CORE_CONSOLIDATION_FIELDS,
                                     core_consolidation_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor", "reason"])
                actor = str(fields.get("actor", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                increment_count(core_consolidation_actions, action)
                increment_count(core_consolidation_reasons, reason)
                increment_count(core_consolidation_actor_actions,
                                f"{actor}:{action}")
                increment_count(core_consolidation_actor_reasons,
                                f"{actor}:{reason}")
            if "organic_history_flavor" in line:
                counts["flavor"] += 1
            if "organic_history_dynastic_probe" in line:
                counts["dynasticProbe"] += 1
                collect_float_fields(line, DYNASTIC_PROBE_FIELDS, dynastic_probe_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                dynastic_actions[action] = dynastic_actions.get(action, 0) + 1
            if "organic_history_dynastic_transfer" in line:
                counts["dynasticTransfer"] += 1
                collect_float_fields(line, DYNASTIC_TRANSFER_FIELDS, dynastic_transfer_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor", "reason"])
                actor = str(fields.get("actor", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                dynastic_transfer_actions[action] = dynastic_transfer_actions.get(action, 0) + 1
                increment_count(dynastic_transfer_reasons, reason)
                increment_count(dynastic_transfer_actor_actions, f"{actor}:{action}")
                increment_count(dynastic_transfer_actor_reasons, f"{actor}:{reason}")
            if "organic_history_lineage_handoff" in line:
                counts["lineageHandoff"] += 1
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor", "reason"])
                actor = str(fields.get("actor", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                increment_count(lineage_handoff_actions, action)
                increment_count(lineage_handoff_reasons, reason)
                increment_count(lineage_handoff_actor_actions, f"{actor}:{action}")
                increment_count(lineage_handoff_actor_reasons, f"{actor}:{reason}")
            if "organic_history_expansion_pressure" in line:
                counts["expansionPressure"] += 1
                collect_float_fields(line, EXPANSION_PRESSURE_FIELDS, expansion_pressure_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                expansion_pressure_actions[action] = expansion_pressure_actions.get(action, 0) + 1
            if "organic_history_partial_contraction" in line:
                counts["partialContraction"] += 1
                collect_float_fields(line, PARTIAL_CONTRACTION_FIELDS, partial_contraction_values)
                action_match = ACTION_RE.search(line)
                action = action_match.group("action") if action_match else "unknown"
                fields = parse_line_fields(line, ["actor", "reason"])
                actor = str(fields.get("actor", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                partial_contraction_actions[action] = partial_contraction_actions.get(action, 0) + 1
                increment_count(partial_contraction_reasons, reason)
                increment_count(partial_contraction_actor_actions, f"{actor}:{action}")
                increment_count(partial_contraction_actor_reasons, f"{actor}:{reason}")
            if "organic_history_contraction_recipient" in line:
                counts["contractionRecipient"] += 1
                collect_float_fields(line, CONTRACTION_RECIPIENT_FIELDS,
                                     contraction_recipient_values)
                fields = parse_line_fields(line, ["actor"])
                actor = str(fields.get("actor", "unknown"))
                increment_count(contraction_recipient_actor_counts, actor)
            if "organic_history_target_overlap" in line:
                counts["targetOverlap"] += 1
                collect_float_fields(line, TARGET_OVERLAP_FIELDS,
                                     target_overlap_values)
                fields = parse_line_fields(line, ["actor", "source", "region",
                                                  "selected",
                                                  "top_rival_actor"])
                actor = str(fields.get("actor", "unknown"))
                source = str(fields.get("source", "unknown"))
                region = str(fields.get("region", "unknown"))
                selected = fields.get("selected", False)
                top_rival = str(fields.get("top_rival_actor", "none"))
                increment_count(target_overlap_actor_regions,
                                f"{actor}:{source}:{region}")
                increment_count(target_overlap_actor_sources,
                                f"{actor}:{source}")
                if selected:
                    increment_count(target_overlap_selected_regions,
                                    f"{actor}:{source}:{region}")
                if top_rival != "none":
                    increment_count(target_overlap_top_rivals,
                                    f"{actor}:{source}:{top_rival}")
            if "organic_history_tech_floor " in line:
                counts["techFloor"] += 1
                collect_float_fields(line, TECH_FLOOR_FIELDS,
                                     tech_floor_values)
                fields = parse_line_fields(line, ["actor", "reason", "applied",
                                                  "skip_reason"])
                actor = str(fields.get("actor", "unknown"))
                reason = str(fields.get("reason", "unknown"))
                applied = fields.get("applied", False)
                skip_reason = str(fields.get("skip_reason", "none"))
                increment_count(tech_floor_actor_reasons, f"{actor}:{reason}")
                if applied:
                    increment_count(tech_floor_actor_applied, actor)
                else:
                    increment_count(tech_floor_actor_skips,
                                    f"{actor}:{skip_reason}")
                    if skip_reason != "none":
                        increment_count(tech_floor_skip_reasons, skip_reason)
            if "organic_history_claim_conversion " in line:
                counts["claimConversion"] += 1
                collect_float_fields(line, CLAIM_CONVERSION_FIELDS,
                                     claim_conversion_values)
                fields = parse_line_fields(line, ["actor", "applied",
                                                  "skip_reason", "claim_class",
                                                  "region"])
                actor = str(fields.get("actor", "unknown"))
                applied = fields.get("applied", False)
                skip_reason = str(fields.get("skip_reason", "none"))
                claim_class = str(fields.get("claim_class", "unknown"))
                region = str(fields.get("region", "unknown"))
                if applied:
                    increment_count(claim_conversion_actor_applied, actor)
                    increment_count(claim_conversion_actor_claim_classes,
                                    f"{actor}:{claim_class}")
                    increment_count(claim_conversion_actor_regions,
                                    f"{actor}:{region}")
                else:
                    increment_count(claim_conversion_actor_skips,
                                    f"{actor}:{skip_reason}")
                    if skip_reason != "none":
                        increment_count(claim_conversion_skip_reasons,
                                        skip_reason)
            if "organic_history_fallback_successor " in line:
                counts["fallbackSuccessor"] += 1
                collect_float_fields(line, FALLBACK_SUCCESSOR_FIELDS,
                                     fallback_successor_values)
                fields = parse_line_fields(line, ["parent_actor", "region",
                                                  "dormant_actor", "outcome",
                                                  "spawned"])
                parent_actor = str(fields.get("parent_actor", "unknown"))
                region = str(fields.get("region", "unknown"))
                dormant_actor = str(fields.get("dormant_actor", "unknown"))
                outcome = str(fields.get("outcome", "unknown"))
                increment_count(fallback_successor_outcomes,
                                f"{outcome}:{dormant_actor}")
                increment_count(fallback_successor_parent_regions,
                                f"{parent_actor}:{region}")
                increment_count(fallback_successor_dormant_actors,
                                dormant_actor)
            if "organic_history_homeland_defense " in line:
                counts["homelandDefense"] += 1
                collect_float_fields(line, HOMELAND_DEFENSE_FIELDS,
                                     homeland_defense_values)
                fields = parse_line_fields(line, ["actor", "applied",
                                                  "skip_reason", "city"])
                actor = str(fields.get("actor", "unknown"))
                applied = fields.get("applied", False)
                skip_reason = str(fields.get("skip_reason", "none"))
                city = str(fields.get("city", "unknown"))
                if applied:
                    increment_count(homeland_defense_actor_applied, actor)
                    increment_count(homeland_defense_actor_cities,
                                    f"{actor}:{city}")
                else:
                    increment_count(homeland_defense_actor_skips,
                                    f"{actor}:{skip_reason}")
                    if skip_reason != "none":
                        increment_count(homeland_defense_skip_reasons,
                                        skip_reason)
            if "organic_history_mandate" in line:
                counts["mandate"] += 1
                collect_float_fields(line, MANDATE_FIELDS, mandate_values)
            if "organic_history_arrival" in line:
                counts["arrival"] += 1
                fields = parse_line_fields(line, ARRIVAL_FIELDS)
                increment_count(arrival_regions, fields.get("region"))
                increment_count(arrival_groups, fields.get("region_group"))
                increment_count(arrival_actors, fields.get("actor"))
                if (first_new_world_arrival is None
                    and fields.get("region_group") == "new_world"):
                    first_new_world_arrival = fields
            if "organic_history_ocean_crossing" in line:
                counts["oceanCrossing"] += 1
                fields = parse_line_fields(line, OCEAN_CROSSING_FIELDS)
                increment_count(ocean_crossing_routes, fields.get("route"))
                increment_count(ocean_crossing_actors, fields.get("actor"))
                if first_ocean_crossing is None:
                    first_ocean_crossing = fields
            if "organic_history_contact" in line:
                counts["contact"] += 1
                fields = parse_line_fields(line, CONTACT_FIELDS)
                increment_count(contact_regions, fields.get("region"))
            secession_match = SECESSION_RE.search(line)
            if secession_match:
                counts["secession"] += 1
                secession_type = secession_match.group("type")
                secession_types[secession_type] = secession_types.get(secession_type, 0) + 1
                if secession_type == "secession_triggered":
                    secession_details.append(parse_line_fields(line, SECESSION_DETAIL_FIELDS))
            if "organic_history_stability" in line:
                counts["stability"] += 1
                stress_match = STRESS_RE.search(line)
                if stress_match:
                    stress_values.append(int(stress_match.group("stress")))
                risk_match = RISK_RE.search(line)
                if risk_match and risk_match.group("risk").lower() == "high":
                    high_risk += 1
            if "organic_history_mechanic type=" in line:
                counts["mechanic"] += 1
                mechanic_match = MECHANIC_RE.search(line)
                if mechanic_match:
                    mechanic_type = mechanic_match.group("type")
                    if mechanic_type == "civil_war_check":
                        mechanics["civilWarChecks"] += 1
                        mechanics["civilWarEligibleChecks"] += 1
                    elif mechanic_type == "civil_war_triggered":
                        mechanics["civilWarTriggered"] += 1
                    elif mechanic_type == "civil_war_noop":
                        mechanics["civilWarNoop"] += 1
                    elif mechanic_type == "civil_war_skip":
                        mechanics["civilWarSkips"] += 1
                        reason_match = REASON_RE.search(line)
                        reason = reason_match.group("reason") if reason_match else "unknown"
                        skip_reasons = mechanics["civilWarSkipReasons"]
                        skip_reasons[reason] = skip_reasons.get(reason, 0) + 1
                    elif mechanic_type == "civil_war_cooldown":
                        mechanics["civilWarCooldowns"] += 1
    mechanics["civilWarInert"] = (counts["mechanic"] > 0
                                  and mechanics["civilWarChecks"] == 0
                                  and mechanics["civilWarTriggered"] == 0)
    mean_stress = (sum(stress_values) / len(stress_values)
                   if stress_values else 0.0)
    return {
        "counts": counts,
        "stress": {
            "count": len(stress_values),
            "mean": round(mean_stress, 3),
            "max": max(stress_values) if stress_values else 0,
            "highRiskTurns": high_risk,
        },
        "mechanics": mechanics,
        "cityPressure": summarize_float_fields(city_pressure_values),
        "institutions": summarize_float_fields(institution_values),
        "eventRisks": summarize_float_fields(event_risk_values),
        "stateCapacity": summarize_float_fields(state_capacity_values),
        "claimPressure": summarize_float_fields(claim_pressure_values),
        "collapse": summarize_float_fields(collapse_values),
        "containment": {
            "actorActions": dict(sorted(containment_actor_actions.items())),
        },
        "dynasticProbe": {
            "fields": summarize_float_fields(dynastic_probe_values),
            "actions": dict(sorted(dynastic_actions.items())),
        },
        "dynasticTransfer": {
            "fields": summarize_float_fields(dynastic_transfer_values),
            "actions": dict(sorted(dynastic_transfer_actions.items())),
            "reasons": dict(sorted(dynastic_transfer_reasons.items())),
            "actorActions": dict(sorted(dynastic_transfer_actor_actions.items())),
            "actorReasons": dict(sorted(dynastic_transfer_actor_reasons.items())),
        },
        "lineageHandoff": {
            "actions": dict(sorted(lineage_handoff_actions.items())),
            "reasons": dict(sorted(lineage_handoff_reasons.items())),
            "actorActions": dict(sorted(lineage_handoff_actor_actions.items())),
            "actorReasons": dict(sorted(lineage_handoff_actor_reasons.items())),
        },
        "expansionPressure": {
            "fields": summarize_float_fields(expansion_pressure_values),
            "actions": dict(sorted(expansion_pressure_actions.items())),
        },
        "partialContraction": {
            "fields": summarize_float_fields(partial_contraction_values),
            "actions": dict(sorted(partial_contraction_actions.items())),
            "reasons": dict(sorted(partial_contraction_reasons.items())),
            "actorActions": dict(sorted(partial_contraction_actor_actions.items())),
            "actorReasons": dict(sorted(partial_contraction_actor_reasons.items())),
        },
        "urbanization": {
            "fields": summarize_float_fields(urbanization_values),
            "actions": dict(sorted(urbanization_actions.items())),
            "reasons": dict(sorted(urbanization_reasons.items())),
        },
        "burst": {
            "fields": summarize_float_fields(burst_values),
            "actions": dict(sorted(burst_actions.items())),
            "reasons": dict(sorted(burst_reasons.items())),
            "actorActions": dict(sorted(burst_actor_actions.items())),
            "actorReasons": dict(sorted(burst_actor_reasons.items())),
        },
        "nearEastHandoff": {
            "fields": summarize_float_fields(near_east_handoff_values),
            "actions": dict(sorted(near_east_handoff_actions.items())),
            "reasons": dict(sorted(near_east_handoff_reasons.items())),
            "actorActions": dict(sorted(near_east_handoff_actor_actions.items())),
            "actorReasons": dict(sorted(near_east_handoff_actor_reasons.items())),
        },
        "conquestTarget": {
            "fields": summarize_float_fields(conquest_target_values),
            "actions": dict(sorted(conquest_target_actions.items())),
            "reasons": dict(sorted(conquest_target_reasons.items())),
            "actorActions": dict(sorted(conquest_target_actor_actions.items())),
            "actorReasons": dict(sorted(conquest_target_actor_reasons.items())),
        },
        "conquestConversion": {
            "fields": summarize_float_fields(conquest_conversion_values),
            "actions": dict(sorted(conquest_conversion_actions.items())),
            "reasons": dict(sorted(conquest_conversion_reasons.items())),
            "actorActions": dict(sorted(conquest_conversion_actor_actions.items())),
            "actorReasons": dict(sorted(conquest_conversion_actor_reasons.items())),
        },
        "settlerConversion": {
            "fields": summarize_float_fields(settler_conversion_values),
            "actions": dict(sorted(settler_conversion_actions.items())),
            "reasons": dict(sorted(settler_conversion_reasons.items())),
            "actorActions": dict(sorted(settler_conversion_actor_actions.items())),
            "actorReasons": dict(sorted(settler_conversion_actor_reasons.items())),
        },
        "objective": {
            "fields": summarize_float_fields(objective_values),
            "actions": dict(sorted(objective_actions.items())),
            "reasons": dict(sorted(objective_reasons.items())),
            "actorActions": dict(sorted(objective_actor_actions.items())),
            "actorReasons": dict(sorted(objective_actor_reasons.items())),
            "actorObjectives": dict(sorted(objective_actor_objectives.items())),
        },
        "iberianSite": {
            "fields": summarize_float_fields(iberian_site_values),
            "actorPlacements": dict(sorted(iberian_site_actor_placements.items())),
            "actorTargetHolders": dict(sorted(iberian_site_actor_holders.items())),
        },
        "iberianSitePool": {
            "fields": summarize_float_fields(iberian_site_pool_values),
            "actorRegions": dict(sorted(iberian_site_pool_actor_regions.items())),
            "actorScopes": dict(sorted(iberian_site_pool_actor_scopes.items())),
        },
        "iberianActivation": {
            "fields": summarize_float_fields(iberian_activation_values),
            "actorActions": dict(sorted(iberian_activation_actor_actions.items())),
        },
        "contractionRecipient": {
            "fields": summarize_float_fields(contraction_recipient_values),
            "actorCounts": dict(sorted(contraction_recipient_actor_counts.items())),
        },
        "targetOverlap": {
            "fields": summarize_float_fields(target_overlap_values),
            "actorRegions": dict(sorted(target_overlap_actor_regions.items())),
            "actorSources": dict(sorted(target_overlap_actor_sources.items())),
            "selectedRegions": dict(sorted(target_overlap_selected_regions.items())),
            "topRivals": dict(sorted(target_overlap_top_rivals.items())),
        },
        "techFloor": {
            "fields": summarize_float_fields(tech_floor_values),
            "actorReasons": dict(sorted(tech_floor_actor_reasons.items())),
            "actorApplied": dict(sorted(tech_floor_actor_applied.items())),
            "actorSkips": dict(sorted(tech_floor_actor_skips.items())),
            "skipReasons": dict(sorted(tech_floor_skip_reasons.items())),
        },
        "claimConversion": {
            "fields": summarize_float_fields(claim_conversion_values),
            "actorApplied": dict(sorted(claim_conversion_actor_applied.items())),
            "actorSkips": dict(sorted(claim_conversion_actor_skips.items())),
            "actorClaimClasses": dict(sorted(claim_conversion_actor_claim_classes.items())),
            "actorRegions": dict(sorted(claim_conversion_actor_regions.items())),
            "skipReasons": dict(sorted(claim_conversion_skip_reasons.items())),
        },
        "fallbackSuccessor": {
            "fields": summarize_float_fields(fallback_successor_values),
            "outcomes": dict(sorted(fallback_successor_outcomes.items())),
            "parentRegions": dict(sorted(fallback_successor_parent_regions.items())),
            "dormantActors": dict(sorted(fallback_successor_dormant_actors.items())),
        },
        "homelandDefense": {
            "fields": summarize_float_fields(homeland_defense_values),
            "actorApplied": dict(sorted(homeland_defense_actor_applied.items())),
            "actorSkips": dict(sorted(homeland_defense_actor_skips.items())),
            "actorCities": dict(sorted(homeland_defense_actor_cities.items())),
            "skipReasons": dict(sorted(homeland_defense_skip_reasons.items())),
        },
        "coreConsolidation": {
            "fields": summarize_float_fields(core_consolidation_values),
            "actions": dict(sorted(core_consolidation_actions.items())),
            "reasons": dict(sorted(core_consolidation_reasons.items())),
            "actorActions": dict(sorted(core_consolidation_actor_actions.items())),
            "actorReasons": dict(sorted(core_consolidation_actor_reasons.items())),
        },
        "mandate": summarize_float_fields(mandate_values),
        "secession": dict(sorted(secession_types.items())),
        "secessionDetails": secession_details,
        "contactDiagnostics": {
            "arrivalRegions": dict(sorted(arrival_regions.items())),
            "arrivalGroups": dict(sorted(arrival_groups.items())),
            "arrivalActors": dict(sorted(arrival_actors.items())),
            "oceanCrossingRoutes": dict(sorted(ocean_crossing_routes.items())),
            "oceanCrossingActors": dict(sorted(ocean_crossing_actors.items())),
            "contactRegions": dict(sorted(contact_regions.items())),
            "firstNewWorldArrival": first_new_world_arrival,
            "firstOceanCrossing": first_ocean_crossing,
        },
        "ownershipChanges": {
            "sources": dict(sorted(ownership_sources.items())),
            "categories": dict(sorted(ownership_categories.items())),
            "reasons": dict(sorted(ownership_reasons.items())),
            "events": ownership_changes,
        },
    }


def write_run_metrics_csv(summary: dict[str, Any], csv_output: Path) -> None:
    rows = summary.get("perTurn", [])
    if not rows:
        csv_output.write_text("", encoding="utf-8")
        return
    fieldnames = sorted({key for row in rows for key in row})
    with csv_output.open("w", encoding="utf-8", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def compact_summary(summary: dict[str, Any]) -> dict[str, Any]:
    return {
        "runDir": summary.get("runDir"),
        "success": summary.get("success"),
        "seed": summary.get("seed"),
        "finalTurn": summary.get("finalTurn"),
        "finalTotalCities": summary.get("finalTotalCities"),
        "maxCityShare": summary.get("maxCityShare"),
        "logCounts": summary.get("logCounts"),
        "organicStress": summary.get("organicStress"),
        "cityPressure": summary.get("cityPressure"),
        "institutions": summary.get("institutions"),
        "eventRisks": summary.get("eventRisks"),
        "claimPressure": summary.get("claimPressure"),
        "collapse": summary.get("collapse"),
        "dynasticProbe": summary.get("dynasticProbe"),
        "dynasticTransfer": summary.get("dynasticTransfer"),
        "lineageHandoff": summary.get("lineageHandoff"),
        "expansionPressure": summary.get("expansionPressure"),
        "partialContraction": summary.get("partialContraction"),
        "urbanization": summary.get("urbanization"),
        "burst": summary.get("burst"),
        "mandate": summary.get("mandate"),
        "secession": summary.get("secession"),
        "secessionDetails": summary.get("secessionDetails"),
        "ownershipChanges": summary.get("ownershipChanges"),
        "contactDiagnostics": summary.get("contactDiagnostics"),
        "mechanics": summary.get("mechanics"),
    }


def collect_float_fields(
    line: str,
    fields: list[str],
    values: dict[str, list[float]],
) -> None:
    for field in fields:
        match = re.search(FLOAT_FIELD_RE.format(field=re.escape(field)), line)
        if match:
            values[field].append(float(match.group(1)))


def summarize_float_fields(values: dict[str, list[float]]) -> dict[str, Any]:
    return {
        field: {
            "count": len(field_values),
            "mean": round(mean(field_values), 3),
            "max": round(max(field_values), 3) if field_values else 0,
        }
        for field, field_values in values.items()
    }


def parse_line_fields(line: str, fields: list[str]) -> dict[str, Any]:
    return {
        field: parse_scalar(match.group(1))
        for field in fields
        if (match := re.search(rf'\b{re.escape(field)}=("(?:[^"\\]|\\.)*"|\S+)', line))
    }


def increment_count(counts: dict[str, int], key: Any) -> None:
    if key is None:
        key = "unknown"
    key = str(key)
    counts[key] = counts.get(key, 0) + 1


def parse_scalar(text: str) -> Any:
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        return text[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    if text in ("true", "false"):
        return text == "true"
    try:
        return int(text)
    except ValueError:
        try:
            value = float(text)
        except ValueError:
            return text
        return int(value) if value.is_integer() else value


def mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


if __name__ == "__main__":
    raise SystemExit(main())
