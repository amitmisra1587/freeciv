#!/usr/bin/env python3
"""Print status for a resumable organic-history overnight run."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect organic-history overnight status.")
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    status = collect_status(args.output_dir)
    print(json.dumps(status, indent=2, sort_keys=True))
    return 0 if not status.get("failedStage") else 1


def collect_status(output_dir: Path) -> dict[str, Any]:
    manifest = read_json(output_dir / "manifest.json")
    stages = []
    failed_stage = None
    for stage_name in manifest.get("stages", []):
        status_path = output_dir / stage_name / "status.json"
        stage = read_json(status_path) or {
            "stage": stage_name,
            "status": "not-started",
            "success": False,
        }
        stages.append(stage)
        if stage.get("returncode") not in (None, 0) and failed_stage is None:
            failed_stage = stage_name
    return {
        "outputDir": str(output_dir),
        "stages": stages,
        "completedStages": [stage.get("stage") for stage in stages
                            if stage.get("success")],
        "failedStage": failed_stage,
        "nextStage": next((stage.get("stage") for stage in stages
                           if not stage.get("success")), None),
        "summaryPaths": summary_paths(output_dir),
    }


def summary_paths(output_dir: Path) -> dict[str, str]:
    paths = {
        "calibration": output_dir / "03_calibration" / "campaign" / "campaign_summary.json",
        "thresholds": output_dir / "04_thresholds" / "thresholds.json",
        "profile": output_dir / "04_thresholds" / "mechanics_v1_profile.json",
        "continuation": output_dir / "05_continuation" / "check" / "continuation_summary.json",
        "mechanicsGate": output_dir / "06_mechanics_gate" / "experiment" / "experiment_summary.json",
        "mechanicsABLong": output_dir / "07_mechanics_ab_long" / "experiment" / "experiment_summary.json",
    }
    return {key: str(path) for key, path in paths.items() if path.exists()}


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    raise SystemExit(main())
