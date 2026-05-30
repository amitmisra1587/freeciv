#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

python3 - <<'PY'
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path.cwd()
RUN_ROOT = ROOT / "runs" / "organic_history_historical_continuation_gate"
PROFILE = "tools/organic_history/profiles/historical_successor_candidate.json"

SCENARIOS = [
    ("ancient", "data/organic_history/scenarios/earth_ancient_v1.sav", 7),
    ("medieval", "data/organic_history/scenarios/earth_medieval_v1.sav", 7),
    ("1450", "data/organic_history/scenarios/earth_1450_v1.sav", 8),
]


def main() -> int:
    if RUN_ROOT.exists():
        shutil.rmtree(RUN_ROOT)
    RUN_ROOT.mkdir(parents=True)
    failures = []
    results = []

    for scenario_name, scenario_path, players in SCENARIOS:
        for mode, profile in (("plain", None), ("successor", PROFILE)):
            result = run_pair(scenario_name, scenario_path, players, mode, profile)
            results.append(result)
            if not result["success"]:
                failures.append(result)

    lineage_result = run_resumed_lineage_check()
    results.append(lineage_result)
    if not lineage_result["success"]:
        failures.append(lineage_result)

    (RUN_ROOT / "historical_continuation_summary.json").write_text(
        json.dumps({"success": not failures, "results": results}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    if failures:
        print(json.dumps({"success": False, "failures": failures}, sort_keys=True))
        return 1
    print("SUCCESS: historical continuation gate passed")
    return 0


def run_pair(
    scenario_name: str,
    scenario_path: str,
    players: int,
    mode: str,
    profile: str | None,
) -> dict[str, object]:
    source_dir = RUN_ROOT / f"{scenario_name}_{mode}_source"
    continued_dir = RUN_ROOT / f"{scenario_name}_{mode}_continued"

    source_cmd = [
        sys.executable,
        "tools/organic_history/run_ai_game.py",
        "--ruleset-serv",
        "data/organic_history.serv",
        "--load-scenario",
        scenario_path,
        "--turns",
        "10",
        "--players",
        str(players),
        "--saveturns",
        "5",
        "--output-dir",
        str(source_dir),
        "--timeout",
        "180",
    ]
    add_profile(source_cmd, profile)
    source_run = subprocess.run(source_cmd, cwd=ROOT, text=True)
    source_meta = read_json(source_dir / "run_metadata.json")

    continued_cmd = [
        sys.executable,
        "tools/organic_history/run_ai_game.py",
        "--ruleset-serv",
        "data/organic_history.serv",
        "--load-save",
        str(source_meta.get("finalSave") or ""),
        "--turns",
        "20",
        "--players",
        str(players),
        "--saveturns",
        "5",
        "--output-dir",
        str(continued_dir),
        "--timeout",
        "180",
    ]
    add_profile(continued_cmd, profile)
    continued_run = subprocess.run(continued_cmd, cwd=ROOT, text=True)
    continued_meta = read_json(continued_dir / "run_metadata.json")

    checks = {
        "sourceReturncode": source_run.returncode == 0,
        "sourceSuccess": bool(source_meta.get("success")),
        "sourceScenarioMetadata": bool(source_meta.get("scenarioMetadataActive")),
        "continuedReturncode": continued_run.returncode == 0,
        "continuedSuccess": bool(continued_meta.get("success")),
        "continuedAdvanced": bool(continued_meta.get("continuationAdvanced")),
        "continuedHooks": int(continued_meta.get("hookLogCount") or 0) > 0,
        "continuedMetrics": int(continued_meta.get("organicMetricLogCount") or 0) > 0,
        "continuedScenarioMetadata": bool(continued_meta.get("scenarioMetadataActive")),
    }
    if mode == "successor":
        checks["continuedDynasticProbe"] = int(continued_meta.get("organicDynasticProbeLogCount") or 0) > 0

    return {
        "scenario": scenario_name,
        "mode": mode,
        "success": all(checks.values()),
        "checks": checks,
        "source": summarize(source_meta),
        "continued": summarize(continued_meta),
    }


def run_resumed_lineage_check() -> dict[str, object]:
    source_save = RUN_ROOT / "ancient_successor_source" / "freeciv-T0011-Y-3500-final.sav.gz"
    output_dir = RUN_ROOT / "ancient_resume_rome_lineage"
    lineage_commands = [
        "lua cmd organic_history_secession_min_cities = 2",
        ("lua cmd local p = find.player('Romulus'); "
         "organic_history_try_secession_fallback(11, p, 80, {bonus = 0}, 80, p:num_cities())"),
    ]
    command = [
        sys.executable,
        "tools/organic_history/run_ai_game.py",
        "--ruleset-serv",
        "data/organic_history.serv",
        "--load-save",
        str(source_save),
        "--turns",
        "20",
        "--players",
        "7",
        "--saveturns",
        "5",
        "--output-dir",
        str(output_dir),
        "--timeout",
        "180",
    ]
    add_profile(command, PROFILE)
    add_commands(command, lineage_commands)
    completed = subprocess.run(command, cwd=ROOT, text=True)
    metadata = read_json(output_dir / "run_metadata.json")
    stdout = (output_dir / "server_stdout.log").read_text(encoding="utf-8", errors="replace")
    triggered = [
        line for line in stdout.splitlines()
        if "organic_history_secession type=secession_triggered" in line
    ]
    lineage_ok = any(
        'parent_actor="rome"' in line
        and ('successor_nation="Roman"' in line
             or 'successor_nation="Western Roman"' in line)
        and 'city="Neapolis"' in line
        and "transferred=1" in line
        for line in triggered
    )
    checks = {
        "returncode": completed.returncode == 0,
        "continuedSuccess": bool(metadata.get("success")),
        "continuedAdvanced": bool(metadata.get("continuationAdvanced")),
        "continuedScenarioMetadata": bool(metadata.get("scenarioMetadataActive")),
        "lineageTriggered": bool(triggered),
        "romanLineage": lineage_ok,
    }
    return {
        "scenario": "ancient",
        "mode": "resumed_lineage",
        "success": all(checks.values()),
        "checks": checks,
        "continued": summarize(metadata),
        "triggered": triggered,
    }


def add_commands(command: list[str], extra_commands: list[str]) -> None:
    for extra_command in extra_commands:
        command.extend(["--extra-command", extra_command])


def add_profile(command: list[str], profile: str | None) -> None:
    if profile is not None:
        command.extend(["--profile", profile])


def read_json(path: Path) -> dict[str, object]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def summarize(metadata: dict[str, object]) -> dict[str, object]:
    return {
        "success": metadata.get("success"),
        "finalTurnSeen": metadata.get("finalTurnSeen"),
        "loadSaveTurn": metadata.get("loadSaveTurn"),
        "continuedTurnCount": metadata.get("continuedTurnCount"),
        "hookLogCount": metadata.get("hookLogCount"),
        "organicMetricLogCount": metadata.get("organicMetricLogCount"),
        "organicDynasticProbeLogCount": metadata.get("organicDynasticProbeLogCount"),
        "scenarioMetadataActive": metadata.get("scenarioMetadataActive"),
    }


if __name__ == "__main__":
    raise SystemExit(main())
PY
