#!/usr/bin/env python3
"""Run and summarize multiple organic-history AI-only games."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import shutil
import subprocess
import sys
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
        "timeout": 1200,
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
        "timeout": 1200,
        "jobs": 1,
    },
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Run an organic-history campaign.")
    parser.add_argument("--ruleset-serv", type=Path, default=Path("data/organic_history.serv"))
    parser.add_argument("--seeds", default="1-3", help="Seed range/list, e.g. 1-12 or 1,3,5.")
    parser.add_argument("--turns", type=int, default=50)
    parser.add_argument("--players", type=int, default=6)
    parser.add_argument("--saveturns", type=int, default=10)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--preset", choices=sorted(PRESETS), default=None)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "runs" / "organic_history_campaign")
    parser.add_argument("--clean", action="store_true")
    parser.add_argument("--rerun-failed", action="store_true")
    parser.add_argument("--extra-command", action="append", default=[], help="Additional command passed through to each run.")
    parser.add_argument("--label", default=None, help="Optional campaign variant label.")
    args = parser.parse_args()

    if args.preset:
        apply_preset(args, PRESETS[args.preset])
    if args.jobs != 1:
        print("ERROR: --jobs > 1 is not enabled yet; keep campaigns sequential until isolation is proven.", file=sys.stderr)
        return 2

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    if args.clean and output_dir.exists():
        if not is_relative_to(output_dir.resolve(), (ROOT / "runs").resolve()):
            print(f"ERROR: refusing to clean output outside runs/: {output_dir}", file=sys.stderr)
            return 2
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    seeds = parse_seeds(args.seeds)
    manifest = {
        "rulesetServ": str(args.ruleset_serv),
        "seeds": seeds,
        "turns": args.turns,
        "players": args.players,
        "saveturns": args.saveturns,
        "timeout": args.timeout,
        "preset": args.preset,
        "label": args.label,
        "extraCommands": args.extra_command,
    }
    write_json(output_dir / "campaign_manifest.json", manifest)

    summaries = []
    failures = []
    for seed in seeds:
        run_dir = output_dir / f"seed_{seed:04d}"
        existing_summary = read_json(run_dir / "run_summary.json")
        if (existing_summary.get("success")
                and not args.clean
                and not args.rerun_failed):
            summaries.append(existing_summary)
            continue

        run_result = run_seed(args, seed, run_dir)
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
        summaries.append(summary)
        if not summary.get("success"):
            failures.append({
                "seed": seed,
                "runDir": str(run_dir),
                "returncode": run_result.returncode,
                "error": summary.get("error"),
            })

    campaign_summary = build_campaign_summary(args, seeds, summaries, failures)
    write_json(output_dir / "campaign_summary.json", campaign_summary)
    write_json(output_dir / "failed_runs.json", failures)
    write_campaign_csv(output_dir / "campaign_metrics.csv", summaries)
    print(json.dumps(campaign_summary, sort_keys=True))
    return 0 if campaign_summary["runsFailed"] == 0 else 1


def apply_preset(args: argparse.Namespace, preset: dict[str, Any]) -> None:
    args.seeds = preset["seeds"]
    args.turns = preset["turns"]
    args.players = preset["players"]
    args.saveturns = preset["saveturns"]
    args.timeout = preset["timeout"]
    args.jobs = preset["jobs"]


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


def run_seed(args: argparse.Namespace, seed: int, run_dir: Path) -> subprocess.CompletedProcess[str]:
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
            "civilWarChecks": int(sum(num(summary.get("mechanics", {}).get("civilWarChecks"))
                                      for summary in succeeded)),
            "civilWarTriggered": int(sum(num(summary.get("mechanics", {}).get("civilWarTriggered"))
                                         for summary in succeeded)),
            "civilWarNoop": int(sum(num(summary.get("mechanics", {}).get("civilWarNoop"))
                                    for summary in succeeded)),
            "civilWarSkips": int(sum(num(summary.get("mechanics", {}).get("civilWarSkips"))
                                     for summary in succeeded)),
        },
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
        "civilWarChecks",
        "civilWarTriggered",
        "civilWarNoop",
        "civilWarSkips",
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
                "civilWarChecks": mechanics.get("civilWarChecks"),
                "civilWarTriggered": mechanics.get("civilWarTriggered"),
                "civilWarNoop": mechanics.get("civilWarNoop"),
                "civilWarSkips": mechanics.get("civilWarSkips"),
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


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def num(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0


def mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


if __name__ == "__main__":
    raise SystemExit(main())
