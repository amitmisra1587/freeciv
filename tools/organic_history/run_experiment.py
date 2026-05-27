#!/usr/bin/env python3
"""Run baseline-vs-mechanics organic-history experiments."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run an organic-history A/B experiment.")
    parser.add_argument("--ruleset-serv", type=Path, default=Path("data/organic_history.serv"))
    parser.add_argument("--seeds", default="1-6")
    parser.add_argument("--turns", type=int, default=120)
    parser.add_argument("--players", type=int, default=8)
    parser.add_argument("--saveturns", type=int, default=20)
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--preset", choices=["mechanics_probe", "mechanics_ab_long"], default=None)
    parser.add_argument("--thresholds", type=Path, default=None)
    parser.add_argument("--profile", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "runs" / "organic_history_mechanics_ab")
    parser.add_argument("--clean", action="store_true")
    args = parser.parse_args()

    apply_preset(args)
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    if args.clean and output_dir.exists():
        if not is_relative_to(output_dir.resolve(), (ROOT / "runs").resolve()):
            print(f"ERROR: refusing to clean output outside runs/: {output_dir}", file=sys.stderr)
            return 2
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    profile = read_json(args.profile) if args.profile else {}
    mechanic_commands = profile.get("luaCommands")
    if not mechanic_commands:
        thresholds = read_json(args.thresholds) if args.thresholds else {}
        recommended = thresholds.get("recommended", {})
        mechanic_commands = [
            "lua cmd organic_history_mechanics_enabled = true",
            "lua cmd organic_history_civil_war_enabled = true",
            f"lua cmd organic_history_civil_war_stress_threshold = {int(recommended.get('civilWarStressThreshold', 45))}",
            f"lua cmd organic_history_civil_war_min_cities = {int(recommended.get('civilWarMinCities', 8))}",
            f"lua cmd organic_history_civil_war_probability = {int(recommended.get('civilWarProbability', 8))}",
            f"lua cmd organic_history_civil_war_cooldown = {int(recommended.get('civilWarCooldown', 40))}",
        ]
    manifest = {
        "rulesetServ": str(args.ruleset_serv),
        "seeds": args.seeds,
        "turns": args.turns,
        "players": args.players,
        "saveturns": args.saveturns,
        "timeout": args.timeout,
        "thresholds": str(args.thresholds) if args.thresholds else None,
        "profile": str(args.profile) if args.profile else None,
        "mechanicCommands": mechanic_commands,
    }
    write_json(output_dir / "experiment_manifest.json", manifest)

    baseline_dir = output_dir / "baseline"
    candidate_dir = output_dir / "mechanics_v1"
    baseline_result = run_campaign(args, baseline_dir, "baseline", [])
    candidate_result = run_campaign(args, candidate_dir, "mechanics_v1", mechanic_commands)
    compare_result = subprocess.run([
        sys.executable,
        "tools/organic_history/compare_campaigns.py",
        "--baseline", str(baseline_dir),
        "--candidate", str(candidate_dir),
        "--output", str(output_dir / "experiment_summary.json"),
        "--csv-output", str(output_dir / "comparison_metrics.csv"),
    ], cwd=ROOT, text=True)
    summary = read_json(output_dir / "experiment_summary.json")
    summary["baselineReturncode"] = baseline_result.returncode
    summary["candidateReturncode"] = candidate_result.returncode
    summary["compareReturncode"] = compare_result.returncode
    write_json(output_dir / "experiment_summary.json", summary)
    print(json.dumps(summary, sort_keys=True))
    return 0 if (baseline_result.returncode == 0
                 and candidate_result.returncode == 0
                 and compare_result.returncode == 0) else 1


def apply_preset(args: argparse.Namespace) -> None:
    if args.preset == "mechanics_probe":
        args.seeds = "1-6"
        args.turns = 120
        args.players = 8
        args.saveturns = 20
        args.timeout = 600
    elif args.preset == "mechanics_ab_long":
        args.seeds = "1-24"
        args.turns = 300
        args.players = 10
        args.saveturns = 25
        args.timeout = 1800


def run_campaign(
    args: argparse.Namespace,
    output_dir: Path,
    label: str,
    extra_commands: list[str],
) -> subprocess.CompletedProcess[str]:
    command = [
        sys.executable,
        "tools/organic_history/run_campaign.py",
        "--ruleset-serv", str(args.ruleset_serv),
        "--seeds", args.seeds,
        "--turns", str(args.turns),
        "--players", str(args.players),
        "--saveturns", str(args.saveturns),
        "--timeout", str(args.timeout),
        "--output-dir", str(output_dir),
        "--clean",
        "--label", label,
    ]
    for extra_command in extra_commands:
        command.extend(["--extra-command", extra_command])
    return subprocess.run(command, cwd=ROOT, text=True)


def read_json(path: Path | None) -> dict[str, Any]:
    if path is None or not path.exists():
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


if __name__ == "__main__":
    raise SystemExit(main())
