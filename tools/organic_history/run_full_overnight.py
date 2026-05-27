#!/usr/bin/env python3
"""Run the full organic-history overnight workflow with resumable stages."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the full organic-history overnight workflow.")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "runs" / "organic_history_full_overnight")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--clean", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    if args.clean and output_dir.exists():
        if not is_relative_to(output_dir.resolve(), (ROOT / "runs").resolve()):
            print(f"ERROR: refusing to clean output outside runs/: {output_dir}", file=sys.stderr)
            return 2
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    stages = build_stages(output_dir)
    manifest = {
        "outputDir": str(output_dir),
        "stages": [stage["name"] for stage in stages],
        "dryRun": args.dry_run,
    }
    if not args.dry_run:
        write_json(output_dir / "manifest.json", manifest)

    for stage in stages:
        stage_dir = output_dir / stage["name"]
        stage_dir.mkdir(parents=True, exist_ok=True)
        status_path = stage_dir / "status.json"
        existing = read_json(status_path)
        if args.resume and existing.get("success"):
            print(f"Skipping completed stage {stage['name']}")
            continue
        if args.dry_run:
            status = stage_status(stage, "dry-run", None)
            print(json.dumps(status, sort_keys=True))
            continue

        status = stage_status(stage, "running", None)
        write_json(status_path, status)
        result = subprocess.run(stage["command"], cwd=ROOT, text=True)
        status = stage_status(stage, "completed", result.returncode)
        write_json(status_path, status)
        print(json.dumps(status, sort_keys=True))
        if result.returncode != 0:
            return result.returncode

    return 0


def build_stages(output_dir: Path) -> list[dict[str, Any]]:
    calibration_dir = output_dir / "03_calibration" / "campaign"
    thresholds_path = output_dir / "04_thresholds" / "thresholds.json"
    mechanics_profile = output_dir / "04_thresholds" / "mechanics_v1_profile.json"
    return [
        {
            "name": "01_gate",
            "command": [
                sys.executable, "tools/organic_history/run_ai_game.py",
                "--ruleset-serv", "data/organic_history.serv",
                "--turns", "20",
                "--players", "4",
                "--output-dir", str(output_dir / "01_gate" / "run"),
                "--clean-output-dir",
                "--timeout", "120",
            ],
            "outputPath": str(output_dir / "01_gate" / "run"),
        },
        {
            "name": "02_campaign_gate",
            "command": [
                sys.executable, "tools/organic_history/run_campaign.py",
                "--ruleset-serv", "data/organic_history.serv",
                "--seeds", "1-3",
                "--turns", "50",
                "--players", "6",
                "--saveturns", "10",
                "--output-dir", str(output_dir / "02_campaign_gate" / "campaign"),
                "--clean",
                "--timeout", "240",
            ],
            "outputPath": str(output_dir / "02_campaign_gate" / "campaign"),
        },
        {
            "name": "03_calibration",
            "command": [
                sys.executable, "tools/organic_history/run_campaign.py",
                "--ruleset-serv", "data/organic_history.serv",
                "--preset", "calibration_long",
                "--output-dir", str(calibration_dir),
                "--rerun-failed",
            ],
            "outputPath": str(calibration_dir),
        },
        {
            "name": "04_thresholds",
            "command": [
                sys.executable, "tools/organic_history/mechanics_profile.py",
                "--campaign-dir", str(calibration_dir),
                "--thresholds-output", str(thresholds_path),
                "--profile-output", str(mechanics_profile),
            ],
            "outputPath": str(output_dir / "04_thresholds"),
        },
        {
            "name": "05_continuation",
            "command": [
                sys.executable, "tools/organic_history/continuation_check.py",
                "--ruleset-serv", "data/organic_history.serv",
                "--seed", "1",
                "--players", "6",
                "--first-turns", "80",
                "--final-turns", "160",
                "--output-dir", str(output_dir / "05_continuation" / "check"),
                "--clean",
                "--timeout", "300",
            ],
            "outputPath": str(output_dir / "05_continuation" / "check"),
        },
        {
            "name": "06_mechanics_gate",
            "command": [
                sys.executable, "tools/organic_history/run_experiment.py",
                "--ruleset-serv", "data/organic_history.serv",
                "--preset", "mechanics_probe",
                "--profile", str(mechanics_profile),
                "--output-dir", str(output_dir / "06_mechanics_gate" / "experiment"),
                "--clean",
            ],
            "outputPath": str(output_dir / "06_mechanics_gate" / "experiment"),
        },
        {
            "name": "07_mechanics_ab_long",
            "command": [
                sys.executable, "tools/organic_history/run_experiment.py",
                "--ruleset-serv", "data/organic_history.serv",
                "--preset", "mechanics_ab_long",
                "--profile", str(mechanics_profile),
                "--output-dir", str(output_dir / "07_mechanics_ab_long" / "experiment"),
                "--clean",
            ],
            "outputPath": str(output_dir / "07_mechanics_ab_long" / "experiment"),
        },
    ]


def stage_status(stage: dict[str, Any], status: str, returncode: int | None) -> dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat()
    return {
        "stage": stage["name"],
        "status": status,
        "command": stage["command"],
        "returncode": returncode,
        "success": returncode == 0 if returncode is not None else status == "dry-run",
        "updatedAt": now,
        "outputPath": stage["outputPath"],
    }


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


if __name__ == "__main__":
    raise SystemExit(main())
