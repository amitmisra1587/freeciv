#!/usr/bin/env python3
"""Check whether an organic-history save can be loaded and continued."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any

from analyze_campaign import analyze_run


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a save/load continuation check.")
    parser.add_argument("--ruleset-serv", type=Path, default=Path("data/organic_history.serv"))
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--players", type=int, default=6)
    parser.add_argument("--first-turns", type=int, default=80)
    parser.add_argument("--final-turns", type=int, default=160)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "runs" / "organic_history_continuation_check")
    parser.add_argument("--clean", action="store_true")
    parser.add_argument("--timeout", type=int, default=240)
    args = parser.parse_args()

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    if args.clean and output_dir.exists():
        if not is_relative_to(output_dir.resolve(), (ROOT / "runs").resolve()):
            print(f"ERROR: refusing to clean output outside runs/: {output_dir}", file=sys.stderr)
            return 2
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    first_dir = output_dir / "first"
    continued_dir = output_dir / "continued"
    first_result = run_segment(args, first_dir, args.first_turns)
    first_summary = analyze_or_failure(first_dir, first_result.returncode)
    load_source = find_latest_autosave(first_dir)

    continued_result = None
    continued_summary: dict[str, Any] = {
        "success": False,
        "error": "first segment did not produce a non-final autosave",
    }
    if first_summary.get("success") and load_source:
        continued_result = run_segment(args, continued_dir, args.final_turns,
                                       load_save=Path(load_source))
        continued_summary = analyze_or_failure(continued_dir,
                                               continued_result.returncode)

    summary = {
        "success": bool(first_summary.get("success")
                        and continued_summary.get("success")
                        and num(continued_summary.get("finalTurn")) > num(first_summary.get("finalTurn"))),
        "first": compact(first_summary),
        "loadSource": str(load_source) if load_source else None,
        "loadSourceIsAutosave": bool(load_source and "-auto.sav" in str(load_source)),
        "continued": compact(continued_summary),
        "continuedGreaterThanFirst": num(continued_summary.get("finalTurn")) > num(first_summary.get("finalTurn")),
        "notes": [],
    }
    if not summary["success"]:
        summary["notes"].append("Continuation is not blocking mechanics work yet; inspect segment logs before making mechanics default-on.")
    write_json(output_dir / "continuation_summary.json", summary)
    print(json.dumps(summary, sort_keys=True))
    return 0


def run_segment(
    args: argparse.Namespace,
    run_dir: Path,
    turns: int,
    load_save: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    command = [
        sys.executable,
        "tools/organic_history/run_ai_game.py",
        "--turns", str(turns),
        "--players", str(args.players),
        "--seed", str(args.seed),
        "--output-dir", str(run_dir),
        "--clean-output-dir",
        "--timeout", str(args.timeout),
    ]
    if load_save:
        command.extend(["--load-save", str(load_save)])
    else:
        command.extend(["--ruleset-serv", str(args.ruleset_serv)])
    return subprocess.run(command, cwd=ROOT, text=True)


def analyze_or_failure(run_dir: Path, returncode: int) -> dict[str, Any]:
    try:
        summary = analyze_run(run_dir)
    except Exception as exc:  # noqa: BLE001 - summary should capture failure.
        summary = {"success": False, "runDir": str(run_dir), "error": str(exc)}
    summary["runReturncode"] = returncode
    final_save = find_final_save(run_dir)
    summary["finalSave"] = str(final_save) if final_save else None
    write_json(run_dir / "run_summary.json", summary)
    return summary


def find_final_save(run_dir: Path) -> Path | None:
    saves = sorted(run_dir.glob("*final.sav*"))
    return saves[-1] if saves else None


def find_latest_autosave(run_dir: Path) -> Path | None:
    saves = sorted(run_dir.glob("*-auto.sav*"))
    return saves[-1] if saves else None


def compact(summary: dict[str, Any]) -> dict[str, Any]:
    return {
        "success": summary.get("success"),
        "runDir": summary.get("runDir"),
        "finalTurn": summary.get("finalTurn"),
        "finalSave": summary.get("finalSave"),
        "runReturncode": summary.get("runReturncode"),
        "logCounts": summary.get("logCounts"),
    }


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


if __name__ == "__main__":
    raise SystemExit(main())
