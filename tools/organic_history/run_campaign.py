#!/usr/bin/env python3
"""Run and summarize multiple organic-history AI-only games."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
from typing import Any

from analyze_campaign import analyze_run


ROOT = Path(__file__).resolve().parents[2]


PRESETS = {
    "overnight": {
        "seeds": "1-12",
        "turns": 120,
        "players": 8,
        "saveturns": 20,
        "timeout": 600,
        "jobs": 1,
    },
    "calibration_long": {
        "seeds": "1-24",
        "turns": 300,
        "players": 10,
        "saveturns": 25,
        "timeout": 1800,
        "jobs": 1,
    },
    "mechanics_probe": {
        "seeds": "1-6",
        "turns": 120,
        "players": 8,
        "saveturns": 20,
        "timeout": 600,
        "jobs": 1,
    },
    "mechanics_ab_long": {
        "seeds": "1-24",
        "turns": 300,
        "players": 10,
        "saveturns": 25,
        "timeout": 1800,
        "jobs": 1,
    },
    "scenario_ancient": {
        "seeds": "1-3",
        "turns": 80,
        "players": 8,
        "saveturns": 10,
        "timeout": 600,
        "jobs": 1,
        "scenario": "data/organic_history/scenarios/earth_ancient_v0.sav",
    },
    "scenario_medieval": {
        "seeds": "1-3",
        "turns": 80,
        "players": 10,
        "saveturns": 10,
        "timeout": 600,
        "jobs": 1,
        "scenario": "data/organic_history/scenarios/earth_medieval_v0.sav",
    },
    "scenario_1450": {
        "seeds": "1-3",
        "turns": 80,
        "players": 10,
        "saveturns": 10,
        "timeout": 600,
        "jobs": 1,
        "scenario": "data/organic_history/scenarios/earth_1450_v0.sav",
    },
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Run an organic-history campaign.")
    parser.add_argument("--ruleset-serv", type=Path, default=Path("data/organic_history.serv"))
    parser.add_argument("--seeds", default="1-3", help="Seed range/list, e.g. 1-12 or 1,3,5.")
    parser.add_argument("--turns", type=int, default=50)
    parser.add_argument("--players", type=int, default=6)
    parser.add_argument("--scenario", type=Path, default=None,
                        help="Optional scenario savegame to load for each run.")
    parser.add_argument("--saveturns", type=int, default=10)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--max-load-average", type=float, default=0.0,
                        help="Pause before launching a seed while 1-minute load average is above this value. 0 disables the guard.")
    parser.add_argument("--load-check-interval", type=float, default=30.0,
                        help="Seconds between load guard checks.")
    parser.add_argument("--load-guard-timeout", type=float, default=0.0,
                        help="Maximum seconds to wait in the load guard before failing a seed. 0 waits indefinitely.")
    parser.add_argument("--preset", choices=sorted(PRESETS), default=None)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "runs" / "organic_history_campaign")
    parser.add_argument("--clean", action="store_true")
    parser.add_argument("--rerun-failed", action="store_true")
    parser.add_argument("--profile", type=Path, default=None,
                        help="Optional mechanics profile JSON passed through to each run.")
    parser.add_argument("--extra-command", action="append", default=[], help="Additional command passed through to each run.")
    parser.add_argument("--label", default=None, help="Optional campaign variant label.")
    args = parser.parse_args()

    if args.preset:
        apply_preset(args, PRESETS[args.preset])
    if args.jobs < 1:
        print("ERROR: --jobs must be at least 1.", file=sys.stderr)
        return 2

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    if args.clean and output_dir.exists():
        if not is_relative_to(output_dir.resolve(), (ROOT / "runs").resolve()):
            print(f"ERROR: refusing to clean output outside runs/: {output_dir}", file=sys.stderr)
            return 2
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    seeds = parse_seeds(args.seeds)
    seed_ports = {seed: campaign_port(output_dir, index)
                  for index, seed in enumerate(seeds)}
    manifest = {
        "rulesetServ": str(args.ruleset_serv),
        "seeds": seeds,
        "turns": args.turns,
        "players": args.players,
        "scenario": str(args.scenario) if args.scenario else None,
        "saveturns": args.saveturns,
        "timeout": args.timeout,
        "jobs": args.jobs,
        "maxLoadAverage": args.max_load_average,
        "loadCheckInterval": args.load_check_interval,
        "loadGuardTimeout": args.load_guard_timeout,
        "preset": args.preset,
        "label": args.label,
        "profile": str(args.profile) if args.profile else None,
        "extraCommands": args.extra_command,
        "ports": seed_ports,
    }
    write_json(output_dir / "campaign_manifest.json", manifest)

    summaries_by_seed: dict[int, dict[str, Any]] = {}
    failures = []
    pending = []
    for seed in seeds:
        run_dir = output_dir / f"seed_{seed:04d}"
        existing_summary = read_json(run_dir / "run_summary.json")
        if existing_summary.get("success") and not args.clean:
            summaries_by_seed[seed] = existing_summary
            write_progress(output_dir, {
                "event": "seed_skipped_success",
                "seed": seed,
                "runDir": str(run_dir),
            })
            continue
        pending.append((seed, run_dir))

    write_progress(output_dir, {
        "event": "campaign_start",
        "jobs": args.jobs,
        "seedsRequested": len(seeds),
        "seedsPending": len(pending),
        "seedsSkipped": len(seeds) - len(pending),
    })
    if args.jobs == 1:
        for seed, run_dir in pending:
            result = execute_seed(args, seed, run_dir, seed_ports[seed],
                                  output_dir)
            summaries_by_seed[seed] = result["summary"]
            if result.get("failure"):
                failures.append(result["failure"])
    else:
        with ThreadPoolExecutor(max_workers=args.jobs) as executor:
            futures = {}
            for seed, run_dir in pending:
                write_progress(output_dir, {
                    "event": "seed_submitted",
                    "seed": seed,
                    "runDir": str(run_dir),
                    "port": seed_ports[seed],
                })
                future = executor.submit(execute_seed, args, seed, run_dir,
                                         seed_ports[seed], output_dir)
                futures[future] = seed
            for future in as_completed(futures):
                seed = futures[future]
                try:
                    result = future.result()
                except Exception as exc:  # noqa: BLE001 - explicit seed failure.
                    run_dir = output_dir / f"seed_{seed:04d}"
                    summary = {
                        "runDir": str(run_dir),
                        "success": False,
                        "seed": seed,
                        "error": f"worker failed: {exc}",
                    }
                    write_json(run_dir / "run_summary.json", summary)
                    result = {
                        "summary": summary,
                        "failure": {
                            "seed": seed,
                            "runDir": str(run_dir),
                            "returncode": None,
                            "error": summary["error"],
                        },
                    }
                    write_progress(output_dir, {
                        "event": "seed_worker_failed",
                        "seed": seed,
                        "runDir": str(run_dir),
                        "error": summary["error"],
                    })
                summaries_by_seed[seed] = result["summary"]
                if result.get("failure"):
                    failures.append(result["failure"])

    summaries = [summaries_by_seed[seed] for seed in seeds
                 if seed in summaries_by_seed]
    campaign_summary = build_campaign_summary(args, seeds, summaries, failures)
    write_json(output_dir / "campaign_summary.json", campaign_summary)
    write_json(output_dir / "failed_runs.json", failures)
    write_campaign_csv(output_dir / "campaign_metrics.csv", summaries)
    write_progress(output_dir, {
        "event": "campaign_complete",
        "runsSucceeded": campaign_summary["runsSucceeded"],
        "runsFailed": campaign_summary["runsFailed"],
    })
    print(json.dumps(campaign_summary, sort_keys=True))
    return 0 if campaign_summary["runsFailed"] == 0 else 1


def apply_preset(args: argparse.Namespace, preset: dict[str, Any]) -> None:
    args.seeds = preset["seeds"]
    args.turns = preset["turns"]
    args.players = preset["players"]
    args.saveturns = preset["saveturns"]
    args.timeout = preset["timeout"]
    args.jobs = preset["jobs"]
    args.scenario = Path(preset["scenario"]) if preset.get("scenario") else args.scenario


def parse_seeds(seed_text: str) -> list[int]:
    seeds = []
    for part in seed_text.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            start_text, end_text = part.split("-", 1)
            start = int(start_text)
            end = int(end_text)
            step = 1 if end >= start else -1
            seeds.extend(range(start, end + step, step))
        else:
            seeds.append(int(part))
    return seeds


def execute_seed(
    args: argparse.Namespace,
    seed: int,
    run_dir: Path,
    port: int,
    campaign_dir: Path,
) -> dict[str, Any]:
    wait_for_load_guard(args, campaign_dir, seed)
    write_progress(campaign_dir, {
        "event": "seed_start",
        "seed": seed,
        "runDir": str(run_dir),
        "port": port,
    })
    run_result = run_seed(args, seed, run_dir, port)
    try:
        summary = analyze_run(run_dir)
        write_json(run_dir / "run_summary.json", summary)
        write_run_metrics_csv(summary, run_dir / "run_metrics.csv")
    except Exception as exc:  # noqa: BLE001 - keep campaign failure explicit.
        summary = {
            "runDir": str(run_dir),
            "success": False,
            "seed": seed,
            "error": f"analysis failed: {exc}",
        }
        write_json(run_dir / "run_summary.json", summary)

    if run_result.returncode != 0:
        summary["success"] = False
        summary["runReturncode"] = run_result.returncode
        write_json(run_dir / "run_summary.json", summary)

    failure = None
    if not summary.get("success"):
        failure = {
            "seed": seed,
            "runDir": str(run_dir),
            "returncode": run_result.returncode,
            "error": summary.get("error"),
        }
    write_progress(campaign_dir, {
        "event": "seed_complete" if summary.get("success") else "seed_failed",
        "seed": seed,
        "runDir": str(run_dir),
        "returncode": run_result.returncode,
        "success": bool(summary.get("success")),
        "finalTurn": summary.get("finalTurn"),
        "elapsedSeconds": summary.get("elapsedSeconds"),
        "error": summary.get("error"),
    })
    return {"summary": summary, "failure": failure}


def wait_for_load_guard(
    args: argparse.Namespace,
    campaign_dir: Path,
    seed: int,
) -> None:
    max_load = float(args.max_load_average or 0)
    if max_load <= 0:
        return

    interval = max(1.0, float(args.load_check_interval or 30))
    timeout = float(args.load_guard_timeout or 0)
    started = time.monotonic()
    wait_count = 0

    while True:
        load1, load5, load15 = os.getloadavg()
        if load1 <= max_load:
            if wait_count > 0:
                write_progress(campaign_dir, {
                    "event": "seed_load_guard_released",
                    "seed": seed,
                    "load1": round(load1, 3),
                    "load5": round(load5, 3),
                    "load15": round(load15, 3),
                    "maxLoadAverage": max_load,
                    "waitSeconds": round(time.monotonic() - started, 3),
                })
            return

        waited = time.monotonic() - started
        if timeout > 0 and waited >= timeout:
            raise RuntimeError(
                "load guard timeout: "
                f"load1={load1:.3f} max={max_load:.3f} waited={waited:.1f}s"
            )

        write_progress(campaign_dir, {
            "event": "seed_load_guard_wait",
            "seed": seed,
            "load1": round(load1, 3),
            "load5": round(load5, 3),
            "load15": round(load15, 3),
            "maxLoadAverage": max_load,
            "waitSeconds": round(waited, 3),
        })
        wait_count += 1
        time.sleep(interval)


def run_seed(
    args: argparse.Namespace,
    seed: int,
    run_dir: Path,
    port: int | None = None,
) -> subprocess.CompletedProcess[str]:
    command = [
        sys.executable,
        "tools/organic_history/run_ai_game.py",
        "--ruleset-serv", str(args.ruleset_serv),
        "--turns", str(args.turns),
        "--players", str(args.players),
        "--seed", str(seed),
        "--saveturns", str(args.saveturns),
        "--output-dir", str(run_dir),
        "--timeout", str(args.timeout),
        "--clean-output-dir",
    ]
    if port is not None:
        command.extend(["--port", str(port)])
    if args.scenario:
        command.extend(["--load-scenario", str(args.scenario)])
    if args.profile:
        command.extend(["--profile", str(args.profile)])
    for extra_command in args.extra_command:
        command.extend(["--extra-command", extra_command])
    return subprocess.run(command, cwd=ROOT, text=True)


def build_campaign_summary(
    args: argparse.Namespace,
    seeds: list[int],
    summaries: list[dict[str, Any]],
    failures: list[dict[str, Any]],
) -> dict[str, Any]:
    succeeded = [summary for summary in summaries if summary.get("success")]
    final_cities = [num(summary.get("finalTotalCities")) for summary in succeeded]
    max_city_shares = [num(summary.get("maxCityShare")) for summary in succeeded]
    stress_means = [num(summary.get("organicStress", {}).get("mean"))
                    for summary in succeeded]
    high_risk_turns = [num(summary.get("organicStress", {}).get("highRiskTurns"))
                       for summary in succeeded]
    return {
        "runsRequested": len(seeds),
        "runsSucceeded": len(succeeded),
        "runsFailed": len(failures),
        "turns": args.turns,
        "players": args.players,
        "scenario": str(args.scenario) if args.scenario else None,
        "label": args.label,
        "seeds": seeds,
        "failures": failures,
        "aggregate": {
            "meanFinalCities": round(mean(final_cities), 3),
            "minFinalCities": min(final_cities) if final_cities else 0,
            "maxFinalCities": max(final_cities) if final_cities else 0,
            "meanMaxCityShare": round(mean(max_city_shares), 3),
            "dominationWarnings": sum(1 for summary in succeeded
                                      if summary.get("warnings", {}).get("domination")),
            "stagnationWarnings": sum(1 for summary in succeeded
                                      if summary.get("warnings", {}).get("stagnation")),
            "meanOrganicStress": round(mean(stress_means), 3),
            "highRiskStressTurns": int(sum(high_risk_turns)),
            "organicMetricLogs": int(sum(num(summary.get("logCounts", {}).get("metric"))
                                         for summary in succeeded)),
            "organicStabilityLogs": int(sum(num(summary.get("logCounts", {}).get("stability"))
                                            for summary in succeeded)),
            "organicEventLogs": int(sum(num(summary.get("logCounts", {}).get("event"))
                                        for summary in succeeded)),
            "organicMechanicLogs": int(sum(num(summary.get("logCounts", {}).get("mechanic"))
                                           for summary in succeeded)),
            "organicRegionLogs": int(sum(num(summary.get("logCounts", {}).get("region"))
                                         for summary in succeeded)),
            "organicPrestigeLogs": int(sum(num(summary.get("logCounts", {}).get("prestige"))
                                           for summary in succeeded)),
            "organicCityPressureLogs": int(sum(num(summary.get("logCounts", {}).get("cityPressure"))
                                               for summary in succeeded)),
            "organicInstitutionLogs": int(sum(num(summary.get("logCounts", {}).get("institution"))
                                             for summary in succeeded)),
            "organicEventRiskLogs": int(sum(num(summary.get("logCounts", {}).get("eventRisk"))
                                           for summary in succeeded)),
            "organicStateCapacityLogs": int(sum(num(summary.get("logCounts", {}).get("stateCapacity"))
                                               for summary in succeeded)),
            "organicDynasticProbeLogs": int(sum(num(summary.get("logCounts", {}).get("dynasticProbe"))
                                                for summary in succeeded)),
            "organicDynasticTransferLogs": int(sum(num(summary.get("logCounts", {}).get("dynasticTransfer"))
                                                  for summary in succeeded)),
            "organicLineageHandoffLogs": int(sum(num(summary.get("logCounts", {}).get("lineageHandoff"))
                                                 for summary in succeeded)),
            "organicExpansionPressureLogs": int(sum(num(summary.get("logCounts", {}).get("expansionPressure"))
                                                   for summary in succeeded)),
            "organicPartialContractionLogs": int(sum(num(summary.get("logCounts", {}).get("partialContraction"))
                                                    for summary in succeeded)),
            "organicUrbanizationLogs": int(sum(num(summary.get("logCounts", {}).get("urbanization"))
                                              for summary in succeeded)),
            "organicBurstLogs": int(sum(num(summary.get("logCounts", {}).get("burst"))
                                        for summary in succeeded)),
            "organicNearEastHandoffLogs": int(sum(num(summary.get("logCounts", {}).get("nearEastHandoff"))
                                                  for summary in succeeded)),
            "organicConquestTargetLogs": int(sum(num(summary.get("logCounts", {}).get("conquestTarget"))
                                                 for summary in succeeded)),
            "organicConquestConversionLogs": int(sum(num(summary.get("logCounts", {}).get("conquestConversion"))
                                                     for summary in succeeded)),
            "organicSettlerConversionLogs": int(sum(num(summary.get("logCounts", {}).get("settlerConversion"))
                                                    for summary in succeeded)),
            "organicObjectiveLogs": int(sum(num(summary.get("logCounts", {}).get("objective"))
                                           for summary in succeeded)),
            "organicIberianSiteLogs": int(sum(num(summary.get("logCounts", {}).get("iberianSite"))
                                             for summary in succeeded)),
            "organicIberianSitePoolLogs": int(sum(num(summary.get("logCounts", {}).get("iberianSitePool"))
                                                for summary in succeeded)),
            "organicIberianActivationLogs": int(sum(num(summary.get("logCounts", {}).get("iberianActivation"))
                                                  for summary in succeeded)),
            "organicCoreConsolidationLogs": int(sum(num(summary.get("logCounts", {}).get("coreConsolidation"))
                                                    for summary in succeeded)),
            "organicContractionRecipientLogs": int(sum(num(summary.get("logCounts", {}).get("contractionRecipient"))
                                                     for summary in succeeded)),
            "organicTargetOverlapLogs": int(sum(num(summary.get("logCounts", {}).get("targetOverlap"))
                                              for summary in succeeded)),
            "organicTechFloorLogs": int(sum(num(summary.get("logCounts", {}).get("techFloor"))
                                            for summary in succeeded)),
            "organicClaimConversionLogs": int(sum(num(summary.get("logCounts", {}).get("claimConversion"))
                                                  for summary in succeeded)),
            "organicFallbackSuccessorLogs": int(sum(num(summary.get("logCounts", {}).get("fallbackSuccessor"))
                                                    for summary in succeeded)),
            "organicHomelandDefenseLogs": int(sum(num(summary.get("logCounts", {}).get("homelandDefense"))
                                                  for summary in succeeded)),
            "organicMandateLogs": int(sum(num(summary.get("logCounts", {}).get("mandate"))
                                          for summary in succeeded)),
            "organicSecessionLogs": int(sum(num(summary.get("logCounts", {}).get("secession"))
                                            for summary in succeeded)),
            "organicArrivalLogs": int(sum(num(summary.get("logCounts", {}).get("arrival"))
                                          for summary in succeeded)),
            "organicOceanCrossingLogs": int(sum(num(summary.get("logCounts", {}).get("oceanCrossing"))
                                               for summary in succeeded)),
            "organicContactLogs": int(sum(num(summary.get("logCounts", {}).get("contact"))
                                          for summary in succeeded)),
            "meanCityUnrest": round(mean_metric(succeeded, "cityPressure", "unrest"), 3),
            "meanCityAutonomy": round(mean_metric(succeeded, "cityPressure", "autonomy"), 3),
            "meanMigrationPressure": round(mean_metric(succeeded, "cityPressure", "migration_pressure"), 3),
            "meanInstitutionCohesion": round(mean_metric(succeeded, "institutions", "cohesion"), 3),
            "meanReformPressure": round(mean_metric(succeeded, "institutions", "reform_pressure"), 3),
            "meanSuccessionRisk": round(mean_metric(succeeded, "eventRisks", "succession"), 3),
            "meanFiscalRisk": round(mean_metric(succeeded, "eventRisks", "fiscal"), 3),
            "meanStateCapacityCrisis": round(mean_metric(succeeded, "stateCapacity", "crisis"), 3),
            "meanStateCapacityModifier": round(mean_metric(succeeded, "stateCapacity", "stress_modifier"), 3),
            "meanDynasticBonus": round(mean_nested_metric(succeeded, "dynasticProbe", "fields", "bonus"), 3),
            "meanInstitutionStressModifier": round(mean_nested_metric(succeeded, "dynasticProbe", "fields", "institution_modifier"), 3),
            "meanPressureStressModifier": round(mean_nested_metric(succeeded, "dynasticProbe", "fields", "pressure_modifier"), 3),
            "meanDynasticStateCapacityModifier": round(mean_nested_metric(succeeded, "dynasticProbe", "fields", "state_capacity_modifier"), 3),
            "meanMandateStressReduction": round(mean_nested_metric(succeeded, "dynasticProbe", "fields", "mandate_reduction"), 3),
            "meanDynasticEffectiveStress": round(mean_nested_metric(succeeded, "dynasticProbe", "fields", "effective_stress"), 3),
            "meanMandate": round(mean_metric(succeeded, "mandate", "mandate"), 3),
            "dynasticProbeActions": merge_count_maps(
                summary.get("dynasticProbe", {}).get("actions", {})
                for summary in succeeded
            ),
            "dynasticTransferActions": merge_count_maps(
                summary.get("dynasticTransfer", {}).get("actions", {})
                for summary in succeeded
            ),
            "dynasticTransferReasons": merge_count_maps(
                summary.get("dynasticTransfer", {}).get("reasons", {})
                for summary in succeeded
            ),
            "dynasticTransferActorActions": merge_count_maps(
                summary.get("dynasticTransfer", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "dynasticTransferActorReasons": merge_count_maps(
                summary.get("dynasticTransfer", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "lineageHandoffActions": merge_count_maps(
                summary.get("lineageHandoff", {}).get("actions", {})
                for summary in succeeded
            ),
            "lineageHandoffReasons": merge_count_maps(
                summary.get("lineageHandoff", {}).get("reasons", {})
                for summary in succeeded
            ),
            "lineageHandoffActorActions": merge_count_maps(
                summary.get("lineageHandoff", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "lineageHandoffActorReasons": merge_count_maps(
                summary.get("lineageHandoff", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "expansionPressureActions": merge_count_maps(
                summary.get("expansionPressure", {}).get("actions", {})
                for summary in succeeded
            ),
            "partialContractionActions": merge_count_maps(
                summary.get("partialContraction", {}).get("actions", {})
                for summary in succeeded
            ),
            "partialContractionReasons": merge_count_maps(
                summary.get("partialContraction", {}).get("reasons", {})
                for summary in succeeded
            ),
            "partialContractionActorActions": merge_count_maps(
                summary.get("partialContraction", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "partialContractionActorReasons": merge_count_maps(
                summary.get("partialContraction", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "urbanizationActions": merge_count_maps(
                summary.get("urbanization", {}).get("actions", {})
                for summary in succeeded
            ),
            "urbanizationReasons": merge_count_maps(
                summary.get("urbanization", {}).get("reasons", {})
                for summary in succeeded
            ),
            "burstActions": merge_count_maps(
                summary.get("burst", {}).get("actions", {})
                for summary in succeeded
            ),
            "burstReasons": merge_count_maps(
                summary.get("burst", {}).get("reasons", {})
                for summary in succeeded
            ),
            "burstActorActions": merge_count_maps(
                summary.get("burst", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "burstActorReasons": merge_count_maps(
                summary.get("burst", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "nearEastHandoffActions": merge_count_maps(
                summary.get("nearEastHandoff", {}).get("actions", {})
                for summary in succeeded
            ),
            "nearEastHandoffReasons": merge_count_maps(
                summary.get("nearEastHandoff", {}).get("reasons", {})
                for summary in succeeded
            ),
            "nearEastHandoffActorActions": merge_count_maps(
                summary.get("nearEastHandoff", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "nearEastHandoffActorReasons": merge_count_maps(
                summary.get("nearEastHandoff", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "conquestTargetActions": merge_count_maps(
                summary.get("conquestTarget", {}).get("actions", {})
                for summary in succeeded
            ),
            "conquestTargetReasons": merge_count_maps(
                summary.get("conquestTarget", {}).get("reasons", {})
                for summary in succeeded
            ),
            "conquestTargetActorActions": merge_count_maps(
                summary.get("conquestTarget", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "conquestTargetActorReasons": merge_count_maps(
                summary.get("conquestTarget", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "conquestConversionActions": merge_count_maps(
                summary.get("conquestConversion", {}).get("actions", {})
                for summary in succeeded
            ),
            "conquestConversionReasons": merge_count_maps(
                summary.get("conquestConversion", {}).get("reasons", {})
                for summary in succeeded
            ),
            "conquestConversionActorActions": merge_count_maps(
                summary.get("conquestConversion", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "conquestConversionActorReasons": merge_count_maps(
                summary.get("conquestConversion", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "settlerConversionActions": merge_count_maps(
                summary.get("settlerConversion", {}).get("actions", {})
                for summary in succeeded
            ),
            "settlerConversionReasons": merge_count_maps(
                summary.get("settlerConversion", {}).get("reasons", {})
                for summary in succeeded
            ),
            "settlerConversionActorActions": merge_count_maps(
                summary.get("settlerConversion", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "settlerConversionActorReasons": merge_count_maps(
                summary.get("settlerConversion", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "objectiveActions": merge_count_maps(
                summary.get("objective", {}).get("actions", {})
                for summary in succeeded
            ),
            "objectiveReasons": merge_count_maps(
                summary.get("objective", {}).get("reasons", {})
                for summary in succeeded
            ),
            "objectiveActorActions": merge_count_maps(
                summary.get("objective", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "objectiveActorReasons": merge_count_maps(
                summary.get("objective", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "objectiveActorObjectives": merge_count_maps(
                summary.get("objective", {}).get("actorObjectives", {})
                for summary in succeeded
            ),
            "iberianSiteActorPlacements": merge_count_maps(
                summary.get("iberianSite", {}).get("actorPlacements", {})
                for summary in succeeded
            ),
            "iberianSiteActorTargetHolders": merge_count_maps(
                summary.get("iberianSite", {}).get("actorTargetHolders", {})
                for summary in succeeded
            ),
            "iberianSitePoolActorRegions": merge_count_maps(
                summary.get("iberianSitePool", {}).get("actorRegions", {})
                for summary in succeeded
            ),
            "iberianSitePoolActorScopes": merge_count_maps(
                summary.get("iberianSitePool", {}).get("actorScopes", {})
                for summary in succeeded
            ),
            "iberianActivationActorActions": merge_count_maps(
                summary.get("iberianActivation", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "contractionRecipientActorCounts": merge_count_maps(
                summary.get("contractionRecipient", {}).get("actorCounts", {})
                for summary in succeeded
            ),
            "targetOverlapActorRegions": merge_count_maps(
                summary.get("targetOverlap", {}).get("actorRegions", {})
                for summary in succeeded
            ),
            "targetOverlapActorSources": merge_count_maps(
                summary.get("targetOverlap", {}).get("actorSources", {})
                for summary in succeeded
            ),
            "targetOverlapSelectedRegions": merge_count_maps(
                summary.get("targetOverlap", {}).get("selectedRegions", {})
                for summary in succeeded
            ),
            "targetOverlapTopRivals": merge_count_maps(
                summary.get("targetOverlap", {}).get("topRivals", {})
                for summary in succeeded
            ),
            "techFloorActorReasons": merge_count_maps(
                summary.get("techFloor", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "techFloorActorApplied": merge_count_maps(
                summary.get("techFloor", {}).get("actorApplied", {})
                for summary in succeeded
            ),
            "techFloorActorSkips": merge_count_maps(
                summary.get("techFloor", {}).get("actorSkips", {})
                for summary in succeeded
            ),
            "techFloorSkipReasons": merge_count_maps(
                summary.get("techFloor", {}).get("skipReasons", {})
                for summary in succeeded
            ),
            "claimConversionActorApplied": merge_count_maps(
                summary.get("claimConversion", {}).get("actorApplied", {})
                for summary in succeeded
            ),
            "claimConversionActorSkips": merge_count_maps(
                summary.get("claimConversion", {}).get("actorSkips", {})
                for summary in succeeded
            ),
            "claimConversionActorClaimClasses": merge_count_maps(
                summary.get("claimConversion", {}).get("actorClaimClasses", {})
                for summary in succeeded
            ),
            "claimConversionActorRegions": merge_count_maps(
                summary.get("claimConversion", {}).get("actorRegions", {})
                for summary in succeeded
            ),
            "claimConversionSkipReasons": merge_count_maps(
                summary.get("claimConversion", {}).get("skipReasons", {})
                for summary in succeeded
            ),
            "fallbackSuccessorOutcomes": merge_count_maps(
                summary.get("fallbackSuccessor", {}).get("outcomes", {})
                for summary in succeeded
            ),
            "fallbackSuccessorParentRegions": merge_count_maps(
                summary.get("fallbackSuccessor", {}).get("parentRegions", {})
                for summary in succeeded
            ),
            "fallbackSuccessorDormantActors": merge_count_maps(
                summary.get("fallbackSuccessor", {}).get("dormantActors", {})
                for summary in succeeded
            ),
            "homelandDefenseActorApplied": merge_count_maps(
                summary.get("homelandDefense", {}).get("actorApplied", {})
                for summary in succeeded
            ),
            "homelandDefenseActorSkips": merge_count_maps(
                summary.get("homelandDefense", {}).get("actorSkips", {})
                for summary in succeeded
            ),
            "homelandDefenseActorCities": merge_count_maps(
                summary.get("homelandDefense", {}).get("actorCities", {})
                for summary in succeeded
            ),
            "homelandDefenseSkipReasons": merge_count_maps(
                summary.get("homelandDefense", {}).get("skipReasons", {})
                for summary in succeeded
            ),
            "coreConsolidationActions": merge_count_maps(
                summary.get("coreConsolidation", {}).get("actions", {})
                for summary in succeeded
            ),
            "coreConsolidationReasons": merge_count_maps(
                summary.get("coreConsolidation", {}).get("reasons", {})
                for summary in succeeded
            ),
            "coreConsolidationActorActions": merge_count_maps(
                summary.get("coreConsolidation", {}).get("actorActions", {})
                for summary in succeeded
            ),
            "coreConsolidationActorReasons": merge_count_maps(
                summary.get("coreConsolidation", {}).get("actorReasons", {})
                for summary in succeeded
            ),
            "secessionEvents": merge_count_maps(
                summary.get("secession", {})
                for summary in succeeded
            ),
            "arrivalGroups": merge_count_maps(
                summary.get("contactDiagnostics", {}).get("arrivalGroups", {})
                for summary in succeeded
            ),
            "arrivalActors": merge_count_maps(
                summary.get("contactDiagnostics", {}).get("arrivalActors", {})
                for summary in succeeded
            ),
            "oceanCrossingRoutes": merge_count_maps(
                summary.get("contactDiagnostics", {}).get("oceanCrossingRoutes", {})
                for summary in succeeded
            ),
            "oceanCrossingActors": merge_count_maps(
                summary.get("contactDiagnostics", {}).get("oceanCrossingActors", {})
                for summary in succeeded
            ),
            "contactRegions": merge_count_maps(
                summary.get("contactDiagnostics", {}).get("contactRegions", {})
                for summary in succeeded
            ),
            "civilWarChecks": int(sum(num(summary.get("mechanics", {}).get("civilWarChecks"))
                                      for summary in succeeded)),
            "civilWarEligibleChecks": int(sum(num(summary.get("mechanics", {}).get("civilWarEligibleChecks"))
                                             for summary in succeeded)),
            "civilWarTriggered": int(sum(num(summary.get("mechanics", {}).get("civilWarTriggered"))
                                         for summary in succeeded)),
            "civilWarNoop": int(sum(num(summary.get("mechanics", {}).get("civilWarNoop"))
                                    for summary in succeeded)),
            "civilWarSkips": int(sum(num(summary.get("mechanics", {}).get("civilWarSkips"))
                                     for summary in succeeded)),
            "civilWarSkipReasons": merge_count_maps(
                summary.get("mechanics", {}).get("civilWarSkipReasons", {})
                for summary in succeeded
            ),
            "civilWarInertRuns": int(sum(1 for summary in succeeded
                                        if summary.get("mechanics", {}).get("civilWarInert"))),
        },
        "secessionDetails": [
            detail
            for summary in succeeded
            for detail in summary.get("secessionDetails", [])
            if isinstance(detail, dict)
        ],
        "firstNewWorldArrivals": [
            {
                "seed": summary.get("seed"),
                **summary.get("contactDiagnostics", {}).get("firstNewWorldArrival", {}),
            }
            for summary in succeeded
            if isinstance(summary.get("contactDiagnostics", {}).get("firstNewWorldArrival"), dict)
        ],
        "firstOceanCrossings": [
            {
                "seed": summary.get("seed"),
                **summary.get("contactDiagnostics", {}).get("firstOceanCrossing", {}),
            }
            for summary in succeeded
            if isinstance(summary.get("contactDiagnostics", {}).get("firstOceanCrossing"), dict)
        ],
    }


def write_campaign_csv(path: Path, summaries: list[dict[str, Any]]) -> None:
    fields = [
        "seed",
        "success",
        "finalTurn",
        "finalTotalCities",
        "maxCityShare",
        "maxScoreShare",
        "cityCountDelta",
        "scoreSpread",
        "techSpread",
        "metricLogs",
        "stabilityLogs",
        "eventLogs",
        "mechanicLogs",
        "regionLogs",
        "prestigeLogs",
        "cityPressureLogs",
        "institutionLogs",
        "eventRiskLogs",
        "stateCapacityLogs",
        "dynasticProbeLogs",
        "dynasticTransferLogs",
        "expansionPressureLogs",
        "partialContractionLogs",
        "mandateLogs",
        "secessionLogs",
        "arrivalLogs",
        "oceanCrossingLogs",
        "contactLogs",
        "meanCityUnrest",
        "meanCityAutonomy",
        "meanMigrationPressure",
        "meanInstitutionCohesion",
        "meanReformPressure",
        "meanSuccessionRisk",
        "meanFiscalRisk",
        "meanStateCapacityCrisis",
        "meanStateCapacityModifier",
        "meanDynasticBonus",
        "meanInstitutionStressModifier",
        "meanPressureStressModifier",
        "meanDynasticStateCapacityModifier",
        "meanMandateStressReduction",
        "meanDynasticEffectiveStress",
        "meanMandate",
        "civilWarChecks",
        "civilWarEligibleChecks",
        "civilWarTriggered",
        "civilWarNoop",
        "civilWarSkips",
        "civilWarTopSkipReason",
        "civilWarInert",
        "meanStress",
        "maxStress",
        "highRiskTurns",
    ]
    with path.open("w", encoding="utf-8", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fields)
        writer.writeheader()
        for summary in summaries:
            log_counts = summary.get("logCounts", {})
            stress = summary.get("organicStress", {})
            mechanics = summary.get("mechanics", {})
            city_pressure = summary.get("cityPressure", {})
            institutions = summary.get("institutions", {})
            event_risks = summary.get("eventRisks", {})
            state_capacity = summary.get("stateCapacity", {})
            dynastic = summary.get("dynasticProbe", {})
            dynastic_fields = dynastic.get("fields", {}) if isinstance(dynastic, dict) else {}
            writer.writerow({
                "seed": summary.get("seed"),
                "success": summary.get("success"),
                "finalTurn": summary.get("finalTurn"),
                "finalTotalCities": summary.get("finalTotalCities"),
                "maxCityShare": summary.get("maxCityShare"),
                "maxScoreShare": summary.get("maxScoreShare"),
                "cityCountDelta": summary.get("cityCountDelta"),
                "scoreSpread": summary.get("scoreSpread"),
                "techSpread": summary.get("techSpread"),
                "metricLogs": log_counts.get("metric"),
                "stabilityLogs": log_counts.get("stability"),
                "eventLogs": log_counts.get("event"),
                "mechanicLogs": log_counts.get("mechanic"),
                "regionLogs": log_counts.get("region"),
                "prestigeLogs": log_counts.get("prestige"),
                "cityPressureLogs": log_counts.get("cityPressure"),
                "institutionLogs": log_counts.get("institution"),
                "eventRiskLogs": log_counts.get("eventRisk"),
                "stateCapacityLogs": log_counts.get("stateCapacity"),
                "dynasticProbeLogs": log_counts.get("dynasticProbe"),
                "dynasticTransferLogs": log_counts.get("dynasticTransfer"),
                "expansionPressureLogs": log_counts.get("expansionPressure"),
                "partialContractionLogs": log_counts.get("partialContraction"),
                "mandateLogs": log_counts.get("mandate"),
                "secessionLogs": log_counts.get("secession"),
                "arrivalLogs": log_counts.get("arrival"),
                "oceanCrossingLogs": log_counts.get("oceanCrossing"),
                "contactLogs": log_counts.get("contact"),
                "meanCityUnrest": metric_mean(city_pressure, "unrest"),
                "meanCityAutonomy": metric_mean(city_pressure, "autonomy"),
                "meanMigrationPressure": metric_mean(city_pressure, "migration_pressure"),
                "meanInstitutionCohesion": metric_mean(institutions, "cohesion"),
                "meanReformPressure": metric_mean(institutions, "reform_pressure"),
                "meanSuccessionRisk": metric_mean(event_risks, "succession"),
                "meanFiscalRisk": metric_mean(event_risks, "fiscal"),
                "meanStateCapacityCrisis": metric_mean(state_capacity, "crisis"),
                "meanStateCapacityModifier": metric_mean(state_capacity, "stress_modifier"),
                "meanDynasticBonus": metric_mean(dynastic_fields, "bonus"),
                "meanInstitutionStressModifier": metric_mean(dynastic_fields, "institution_modifier"),
                "meanPressureStressModifier": metric_mean(dynastic_fields, "pressure_modifier"),
                "meanDynasticStateCapacityModifier": metric_mean(dynastic_fields, "state_capacity_modifier"),
                "meanMandateStressReduction": metric_mean(dynastic_fields, "mandate_reduction"),
                "meanDynasticEffectiveStress": metric_mean(dynastic_fields, "effective_stress"),
                "meanMandate": metric_mean(summary.get("mandate", {}), "mandate"),
                "civilWarChecks": mechanics.get("civilWarChecks"),
                "civilWarEligibleChecks": mechanics.get("civilWarEligibleChecks"),
                "civilWarTriggered": mechanics.get("civilWarTriggered"),
                "civilWarNoop": mechanics.get("civilWarNoop"),
                "civilWarSkips": mechanics.get("civilWarSkips"),
                "civilWarTopSkipReason": top_count_key(mechanics.get("civilWarSkipReasons", {})),
                "civilWarInert": mechanics.get("civilWarInert"),
                "meanStress": stress.get("mean"),
                "maxStress": stress.get("max"),
                "highRiskTurns": stress.get("highRiskTurns"),
            })


def write_run_metrics_csv(summary: dict[str, Any], path: Path) -> None:
    rows = summary.get("perTurn", [])
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields = sorted({key for row in rows for key in row})
    with path.open("w", encoding="utf-8", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")


def write_progress(output_dir: Path, event: dict[str, Any]) -> None:
    event = dict(event)
    event["timestamp"] = datetime.now(timezone.utc).isoformat()
    with (output_dir / "campaign_progress.jsonl").open("a",
                                                       encoding="utf-8") as progress_file:
        progress_file.write(json.dumps(event, sort_keys=True) + "\n")


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def campaign_port(output_dir: Path, index: int) -> int:
    import hashlib
    digest = hashlib.md5(str(output_dir.resolve()).encode("utf-8")).hexdigest()
    return 6200 + (int(digest[:6], 16) % 5000) + index


def num(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0


def metric_mean(summary: dict[str, Any], key: str) -> float:
    value = summary.get(key, {})
    if not isinstance(value, dict):
        return 0.0
    return num(value.get("mean"))


def mean_metric(summaries: list[dict[str, Any]], section: str, key: str) -> float:
    values = [metric_mean(summary.get(section, {}), key) for summary in summaries]
    return mean(values)


def mean_nested_metric(
    summaries: list[dict[str, Any]],
    section: str,
    nested: str,
    key: str,
) -> float:
    values = []
    for summary in summaries:
        section_data = summary.get(section, {})
        if not isinstance(section_data, dict):
            values.append(0.0)
            continue
        nested_data = section_data.get(nested, {})
        values.append(metric_mean(nested_data if isinstance(nested_data, dict) else {}, key))
    return mean(values)


def merge_count_maps(count_maps: Any) -> dict[str, int]:
    merged: dict[str, int] = {}
    for count_map in count_maps:
        if not isinstance(count_map, dict):
            continue
        for key, value in count_map.items():
            if isinstance(key, str):
                merged[key] = merged.get(key, 0) + int(num(value))
    return dict(sorted(merged.items()))


def top_count_key(count_map: Any) -> str | None:
    if not isinstance(count_map, dict) or not count_map:
        return None
    key, _ = max(count_map.items(), key=lambda item: num(item[1]))
    return key if isinstance(key, str) else None


def mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


if __name__ == "__main__":
    raise SystemExit(main())
