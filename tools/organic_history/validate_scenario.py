#!/usr/bin/env python3
"""Validate that an organic-history scenario fixture loads and emits diagnostics."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate an organic-history scenario fixture.")
    parser.add_argument("scenario", type=Path)
    parser.add_argument("--ruleset-serv", type=Path, default=Path("data/organic_history.serv"))
    parser.add_argument("--turns", type=int, default=20)
    parser.add_argument("--players", type=int, default=8)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "runs" / "organic_history_scenario_validate")
    args = parser.parse_args()

    scenario = args.scenario if args.scenario.is_absolute() else ROOT / args.scenario
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    command = [
        sys.executable,
        "tools/organic_history/run_ai_game.py",
        "--ruleset-serv", str(args.ruleset_serv),
        "--load-scenario", str(scenario),
        "--turns", str(args.turns),
        "--players", str(args.players),
        "--saveturns", "5",
        "--output-dir", str(output_dir),
        "--clean-output-dir",
        "--timeout", str(args.timeout),
    ]
    result = subprocess.run(command, cwd=ROOT, text=True)
    metadata = read_json(output_dir / "run_metadata.json")
    ok = (result.returncode == 0
          and metadata.get("success")
          and int(metadata.get("hookLogCount") or 0) > 0
          and int(metadata.get("organicMetricLogCount") or 0) > 0)
    summary = {
        "scenario": str(scenario),
        "outputDir": str(output_dir),
        "returncode": result.returncode,
        "success": ok,
        "hookLogCount": metadata.get("hookLogCount"),
        "organicMetricLogCount": metadata.get("organicMetricLogCount"),
        "saveCount": metadata.get("saveCount"),
    }
    print(json.dumps(summary, sort_keys=True))
    return 0 if ok else 1


def read_json(path: Path) -> dict[str, object]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    raise SystemExit(main())
