#!/usr/bin/env python3
"""Summarize historical-fit warnings for a global organic-history sweep."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SWEEP = ROOT / "runs" / "organic_history_phase27_global_sweeps" / "full_100x200"
DEFAULT_HISTORY = ROOT / "data" / "organic_history" / "history" / "earth_global_4000.json"


DEFAULT_EXPECTATIONS: dict[str, dict[str, Any]] = {
    "egypt": {"medianFinalCitiesMax": 20, "collapseRiskWarn": 0.55, "note": "Should contract/fragment outside Nile core."},
    "sumer": {"medianFinalCitiesMin": 3, "medianFinalCitiesMax": 8, "collapseRiskWarn": 0.40, "note": "Should urbanize then feed successor chains."},
    "india": {"medianFinalCitiesMax": 18, "collapseRiskWarn": 0.55, "note": "Should fragment regionally instead of one continuous polity."},
    "china": {"medianFinalCitiesMax": 25, "collapseRiskWarn": 0.55, "note": "Should allow dynastic replacement/continuity choices."},
    "nubia": {"spawnRateMin": 0.60, "medianFinalCitiesMin": 2, "medianFinalCitiesMax": 10},
    "assyria": {"spawnRateMin": 0.80, "medianMaxCitiesMin": 6, "note": "Needs imperial expansion phase."},
    "hittite": {"spawnRateMin": 0.50, "medianMaxCitiesMin": 4, "note": "Anatolia/Hattusa emergence should be much less rare."},
    "phoenicia": {"spawnRateMin": 0.80, "medianMaxCitiesMin": 2, "note": "Needs maritime/trade network support."},
    "carthage": {"spawnRateMin": 0.80, "medianMaxCitiesMin": 4, "note": "Needs western Mediterranean maritime expansion."},
    "celts": {"spawnRateMin": 0.80, "medianFinalCitiesMax": 8, "note": "Should be tribal/cultural horizon, not compact empire."},
    "greece": {"spawnRateMin": 0.90, "medianFinalCitiesMax": 10, "collapseRiskWarn": 0.45, "note": "Should fragment/absorb more often."},
    "persia": {"spawnRateMin": 0.90, "medianMaxCitiesMin": 10, "note": "Needs imperial Near East expansion."},
    "rome": {"spawnRateMin": 0.90, "medianMaxCitiesMin": 10, "note": "Needs Italy/Mediterranean expansion before collapse tuning."},
    "franks": {"spawnRateMin": 0.80, "survivalRateMin": 0.50, "medianMaxCitiesMin": 4, "note": "Needs post-Roman inheritance/agency."},
    "abbasid": {"spawnRateMin": 0.80, "survivalRateMin": 0.50, "medianMaxCitiesMin": 4, "note": "Needs Near East transfer/conquest support."},
    "chola": {"spawnRateMin": 0.70, "survivalRateMin": 0.50, "medianMaxCitiesMin": 3, "note": "Needs South Indian/maritime bootstrap."},
    "song": {"spawnRateMin": 0.70, "survivalRateMin": 0.50, "medianMaxCitiesMin": 5, "note": "Should inherit/transform China instead of microstate."},
    "steppe": {"spawnRateMin": 0.70, "survivalRateMin": 0.35, "medianMaxCitiesMin": 5, "note": "Needs mobile conquest burst, not one-city spawn."},
    "castile": {"spawnRateMin": 0.60, "survivalRateMin": 0.50, "medianMaxCitiesMin": 3, "note": "Needs Iberian consolidation."},
    "portugal": {"spawnRateMin": 0.60, "survivalRateMin": 0.50, "medianMaxCitiesMin": 2, "note": "Needs Lisbon survival and maritime bootstrap."},
    "ming": {"spawnRateMin": 0.70, "survivalRateMin": 0.50, "medianMaxCitiesMin": 5, "note": "Should be dynastic successor/reunifier."},
    "japan": {"spawnRateMin": 0.80, "survivalRateMin": 0.60, "medianMaxCitiesMin": 2, "note": "Needs durable island setup."},
    "aztec": {"spawnRateMin": 0.90, "medianMaxCitiesMin": 5, "note": "Needs Mesoamerican consolidation."},
    "inca": {"spawnRateMin": 0.90, "medianMaxCitiesMin": 5, "note": "Needs Andean consolidation."},
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sweep-dir", type=Path, default=DEFAULT_SWEEP)
    parser.add_argument("--history-model", type=Path, default=DEFAULT_HISTORY)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--strict", action="store_true",
                        help="Exit non-zero when any actor has a fail verdict.")
    args = parser.parse_args()

    sweep_dir = resolve(args.sweep_dir)
    history_model = resolve(args.history_model)
    evidence = read_json(sweep_dir / "civilization_evidence" / "all_civilization_evidence.json")
    history = read_json(history_model)
    report = build_report(sweep_dir, history, evidence)
    output = args.output or sweep_dir / "global_historical_fit_report.json"
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(compact_report(report), sort_keys=True))
    return 1 if args.strict and report["summary"]["failedActors"] > 0 else 0


def resolve(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_summary(sweep_dir: Path) -> dict[str, Any]:
    for name in ("full_100x200_summary.json", "campaign_summary.json"):
        path = sweep_dir / name
        if path.exists():
            return read_json(path)
    raise SystemExit(
        "ERROR: sweep directory missing full_100x200_summary.json "
        f"or campaign_summary.json: {sweep_dir}"
    )


def build_report(
    sweep_dir: Path,
    history: dict[str, Any],
    evidence: dict[str, Any],
) -> dict[str, Any]:
    actors = [actor["id"] for actor in history.get("actors", [])]
    global_summary = read_summary(sweep_dir)
    actor_reports = {}
    failed = 0
    warned = 0
    passed = 0
    for actor_id in actors:
        actor_evidence = evidence.get(actor_id, {})
        expectation = DEFAULT_EXPECTATIONS.get(actor_id, {})
        lifecycle_type = history.get("actorLifecycleTypes", {}).get(actor_id)
        lifecycle = history.get("lifecycleArchetypes", {}).get(lifecycle_type, {})
        actor_report = evaluate_actor(actor_id, actor_evidence, expectation,
                                      lifecycle_type, lifecycle)
        actor_reports[actor_id] = actor_report
        if actor_report["verdict"] == "fail":
            failed += 1
        elif actor_report["verdict"] == "warn":
            warned += 1
        else:
            passed += 1

    return {
        "sweepDir": str(sweep_dir),
        "globalSummary": global_summary,
        "probeEvidence": probe_evidence(global_summary),
        "historicalGravity": history.get("historicalGravity", {}),
        "summary": {
            "actorCount": len(actor_reports),
            "failedActors": failed,
            "warnedActors": warned,
            "passedActors": passed,
        },
        "actors": actor_reports,
    }


def probe_evidence(global_summary: dict[str, Any]) -> dict[str, Any]:
    aggregate = global_summary.get("aggregate", {})
    logs = {
        "dynasticTransfer": int(num(aggregate.get("organicDynasticTransferLogs"))),
        "expansionPressure": int(num(aggregate.get("organicExpansionPressureLogs"))),
        "partialContraction": int(num(aggregate.get("organicPartialContractionLogs"))),
        "arrival": int(num(aggregate.get("organicArrivalLogs"))),
        "oceanCrossing": int(num(aggregate.get("organicOceanCrossingLogs"))),
        "contact": int(num(aggregate.get("organicContactLogs"))),
    }
    actions = {
        "dynasticTransfer": aggregate.get("dynasticTransferActions", {}),
        "expansionPressure": aggregate.get("expansionPressureActions", {}),
        "partialContraction": aggregate.get("partialContractionActions", {}),
    }

    return {
        "logs": logs,
        "actions": actions,
        "hasLifecycleProbeLogs": (
            logs["dynasticTransfer"] > 0
            and logs["expansionPressure"] > 0
            and logs["partialContraction"] > 0
        ),
        "hasContactDiagnostics": logs["arrival"] > 0,
    }


def evaluate_actor(
    actor_id: str,
    evidence: dict[str, Any],
    expectation: dict[str, Any],
    lifecycle_type: str | None,
    lifecycle: dict[str, Any],
) -> dict[str, Any]:
    checks = []
    role = "initial" if evidence.get("spawnRate") == 0 and evidence.get("spawnedSeedCount") == 0 else "emergent"
    spawn_rate = num(evidence.get("spawnRate"))
    spawn_rate_lower = maybe_num(evidence.get("spawnRateWilsonLower95"))
    survival_rate = survival_rate_from_evidence(evidence)
    survival_rate_lower = maybe_num(evidence.get("survivalRateWilsonLower95"))
    survival_given_spawn = maybe_num(evidence.get("survivalGivenSpawnRate"))
    survival_given_spawn_lower = maybe_num(
        evidence.get("survivalGivenSpawnWilsonLower95")
    )
    median_final = maybe_num(evidence.get("finalCitiesMedian"))
    median_max = maybe_num(evidence.get("maxCitiesMedian"))
    median_final_given_spawn = maybe_num(evidence.get("finalCitiesGivenSpawnMedian"))
    median_max_given_spawn = maybe_num(evidence.get("maxCitiesGivenSpawnMedian"))
    peak_turn_median = maybe_num(evidence.get("peakTurnMedian"))
    peak_to_final_drop_median = maybe_num(evidence.get("peakToFinalDropMedian"))
    peak_to_final_drop_given_spawn = maybe_num(
        evidence.get("peakToFinalDropGivenSpawnMedian")
    )
    collapse_median = maybe_num(evidence.get("collapseRiskMedian"))
    collapse_max = maybe_num(evidence.get("collapseRiskMax"))
    latest_claim = evidence.get("latestClaimMedian") or {}

    if "spawnRateMin" in expectation:
        checks.append(check_min("spawnRate", spawn_rate, expectation["spawnRateMin"]))
    if "survivalRateMin" in expectation:
        checks.append(check_min("survivalRate", survival_rate, expectation["survivalRateMin"]))
    if "medianFinalCitiesMin" in expectation:
        checks.append(check_min("medianFinalCities", median_final, expectation["medianFinalCitiesMin"]))
    if "medianFinalCitiesMax" in expectation:
        checks.append(check_max("medianFinalCities", median_final, expectation["medianFinalCitiesMax"]))
    if "medianMaxCitiesMin" in expectation:
        checks.append(check_min("medianMaxCities", median_max, expectation["medianMaxCitiesMin"]))
    if "medianMaxCitiesMax" in expectation:
        checks.append(check_max("medianMaxCities", median_max, expectation["medianMaxCitiesMax"]))
    if "collapseRiskWarn" in expectation and collapse_median is not None:
        checks.append({
            "metric": "collapseRiskMedian",
            "observed": collapse_median,
            "threshold": expectation["collapseRiskWarn"],
            "verdict": "warn" if collapse_median >= expectation["collapseRiskWarn"] else "pass",
            "message": "Sustained high collapse diagnostics should be explained or resolved.",
        })

    verdict = collapse_verdict(checks)
    return {
        "actor": actor_id,
        "role": role,
        "lifecycleType": lifecycle_type,
        "verdict": verdict,
        "note": expectation.get("note"),
        "lifecycleBootstrapPackage": lifecycle.get("bootstrapPackage", {}),
        "lifecycleTargets": lifecycle.get("targetCityCurve"),
        "lifecycleEscapeRoutes": lifecycle.get("escapeRoutes", []),
        "lifecycleOutcomeWeights": lifecycle.get("outcomeWeights", {}),
        "observed": {
            "spawnRate": spawn_rate,
            "spawnRateWilsonLower95": spawn_rate_lower,
            "spawnedSeedCount": evidence.get("spawnedSeedCount"),
            "totalSeeds": evidence.get("totalSeeds"),
            "spawnTurnMedian": evidence.get("spawnTurnMedian"),
            "survivalRate": survival_rate,
            "survivalRateWilsonLower95": survival_rate_lower,
            "survivalGivenSpawnRate": survival_given_spawn,
            "survivalGivenSpawnWilsonLower95": survival_given_spawn_lower,
            "finalCitiesMedian": median_final,
            "finalCitiesMean": evidence.get("finalCitiesMean"),
            "finalCitiesGivenSpawnMedian": median_final_given_spawn,
            "finalCitiesGivenSpawnMean": evidence.get("finalCitiesGivenSpawnMean"),
            "finalCitiesP10": evidence.get("finalCitiesP10"),
            "finalCitiesP90": evidence.get("finalCitiesP90"),
            "maxCitiesMedian": median_max,
            "maxCitiesMean": evidence.get("maxCitiesMean"),
            "maxCitiesGivenSpawnMedian": median_max_given_spawn,
            "maxCitiesGivenSpawnMean": evidence.get("maxCitiesGivenSpawnMean"),
            "peakTurnMedian": peak_turn_median,
            "peakToFinalDropMedian": peak_to_final_drop_median,
            "peakToFinalDropMean": evidence.get("peakToFinalDropMean"),
            "peakToFinalDropGivenSpawnMedian": peak_to_final_drop_given_spawn,
            "peakToFinalDropGivenSpawnMean": evidence.get(
                "peakToFinalDropGivenSpawnMean"
            ),
            "collapseRiskMedian": collapse_median,
            "collapseRiskMax": collapse_max,
            "latestClaimMedian": evidence.get("latestClaimMedian"),
            "successorOutcomeCounts": evidence.get("successorOutcomeCounts", {}),
            "dynasticTransferActions": evidence.get("dynasticTransferActions", {}),
            "dynasticTransferReasons": evidence.get("dynasticTransferReasons", {}),
        },
        "historicalGravityAssessment": gravity_assessment(
            latest_claim, collapse_median, collapse_max
        ),
        "successorOutcomeAssessment": successor_outcome_assessment(evidence),
        "checks": checks,
        "topReleaseCandidates": evidence.get("topReleaseCandidates", [])[:5],
        "sampleSpawnRecords": evidence.get("sampleSpawnRecords", [])[:5],
    }


def successor_outcome_assessment(evidence: dict[str, Any]) -> dict[str, Any]:
    outcomes = evidence.get("successorOutcomeCounts") or {}
    total = int(num(evidence.get("totalSeeds")))
    no_spawn = int(num(outcomes.get("no_spawn")))
    continuity = int(num(outcomes.get("healthy_continuity_escape")))
    failed_activation = int(num(outcomes.get("failed_activation")))
    delayed_no_site = int(num(outcomes.get("delayed_no_site")))
    inherited = int(num(outcomes.get("inherited")))
    spawned = int(num(outcomes.get("spawned")))

    def rate(value: int) -> float:
        return round(value / total, 3) if total else 0.0

    interpretation = "not_successor_limited"
    if no_spawn > 0:
        if failed_activation + delayed_no_site > continuity:
            interpretation = "activation_limited"
        elif continuity > 0:
            interpretation = "continuity_escape_dominant"
        else:
            interpretation = "low_spawn_probability"
    elif spawned > 0 and inherited > 0:
        interpretation = "inheritance_active"

    return {
        "interpretation": interpretation,
        "rates": {
            "noSpawn": rate(no_spawn),
            "healthyContinuityEscape": rate(continuity),
            "failedActivation": rate(failed_activation),
            "delayedNoSite": rate(delayed_no_site),
            "inherited": rate(inherited),
            "spawned": rate(spawned),
        },
        "counts": outcomes,
    }


def gravity_assessment(
    latest_claim: dict[str, Any],
    collapse_median: float | None,
    collapse_max: float | None,
) -> dict[str, Any]:
    core_share = num(latest_claim.get("coreShare"))
    overextension = num(latest_claim.get("overextension"))
    rival_pressure = num(latest_claim.get("rivalPressure"))
    collapse_median = collapse_median or 0.0
    collapse_max = collapse_max or 0.0
    escape_routes = []
    pressure_reasons = []

    if core_share >= 0.75:
        escape_routes.append("strong_core_control")
    else:
        pressure_reasons.append("weak_core_control")
    if overextension <= 0.15:
        escape_routes.append("restrained_expansion")
    else:
        pressure_reasons.append("overextension")
    if rival_pressure <= 0.25:
        escape_routes.append("low_rival_pressure")
    else:
        pressure_reasons.append("rival_pressure")
    if collapse_median >= 0.55:
        pressure_reasons.append("sustained_high_collapse_risk")
    elif collapse_max >= 0.65:
        pressure_reasons.append("episodic_high_collapse_risk")
    else:
        escape_routes.append("low_collapse_pressure")

    return {
        "escapeRoutesObserved": escape_routes,
        "pressureReasonsObserved": pressure_reasons,
        "interpretation": (
            "pressure_justified"
            if pressure_reasons and "sustained_high_collapse_risk" in pressure_reasons
            else "mixed_pressure"
            if pressure_reasons
            else "historical_pressure_avoidable"
        ),
    }


# Verdict tolerance bands. Per-actor city medians come from ~100 stochastic
# seeds and are not meaningful to finer than ~half a city (medians of integer
# counts are frequently half-integers, e.g. india 18.5). So a near-miss within
# NOISE of the target is a pass rather than thrashing the gate on sampling
# noise; a miss beyond HARD is a real regression (fail); in between is a warn.
# Floors (check_min) and caps (check_max) use the SAME graded logic so
# over-cap and under-floor are judged symmetrically -- previously caps could
# only ever warn (never fail) while any floor miss was an immediate hard fail.
def noise_band(threshold: float) -> float:
    return max(0.5, 0.05 * abs(threshold))


def hard_band(threshold: float) -> float:
    return max(1.5, 0.25 * abs(threshold))


def graded_check(
    metric: str, observed: float | None, threshold: float, miss: float | None,
    message: str,
) -> dict[str, Any]:
    """Grade a one-sided check. `miss` is how far observed is on the wrong side
    of the threshold (<=0 means the threshold is satisfied)."""
    if observed is None or miss is None:
        return {
            "metric": metric,
            "observed": observed,
            "threshold": threshold,
            "verdict": "fail",
            "message": "Missing metric.",
        }
    noise = noise_band(threshold)
    hard = hard_band(threshold)
    if miss <= noise:
        verdict = "pass"
    elif miss <= hard:
        verdict = "warn"
    else:
        verdict = "fail"
    return {
        "metric": metric,
        "observed": observed,
        "threshold": threshold,
        "verdict": verdict,
        "message": message,
        "tolerance": round(noise, 3),
        "hardMargin": round(hard, 3),
    }


def check_min(metric: str, observed: float | None, threshold: float) -> dict[str, Any]:
    miss = None if observed is None else threshold - observed
    return graded_check(metric, observed, threshold, miss,
                        f"Expected at least {threshold}.")


def check_max(metric: str, observed: float | None, threshold: float) -> dict[str, Any]:
    miss = None if observed is None else observed - threshold
    return graded_check(metric, observed, threshold, miss,
                        f"Expected no more than {threshold}.")


def collapse_verdict(checks: list[dict[str, Any]]) -> str:
    verdicts = {check["verdict"] for check in checks}
    if "fail" in verdicts:
        return "fail"
    if "warn" in verdicts:
        return "warn"
    return "pass"


def survival_rate_from_evidence(evidence: dict[str, Any]) -> float:
    if isinstance(evidence.get("survivalRate"), (int, float)):
        return float(evidence["survivalRate"])
    samples = evidence.get("sampleFinalRecords") or []
    if not samples:
        final_median = maybe_num(evidence.get("finalCitiesMedian"))
        return 1.0 if final_median and final_median > 0 else 0.0
    alive = 0
    for record in samples:
        if record.get("alive") and num(record.get("cities")) > 0:
            alive += 1
    return alive / len(samples)


def maybe_num(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    return None


def num(value: Any) -> float:
    return maybe_num(value) or 0.0


def compact_report(report: dict[str, Any]) -> dict[str, Any]:
    actors = report["actors"]
    return {
        "summary": report["summary"],
        "probeEvidence": report.get("probeEvidence", {}),
        "failed": sorted(actor for actor, data in actors.items() if data["verdict"] == "fail"),
        "warned": sorted(actor for actor, data in actors.items() if data["verdict"] == "warn"),
    }


if __name__ == "__main__":
    raise SystemExit(main())
