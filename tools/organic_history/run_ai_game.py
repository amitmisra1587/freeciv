#!/usr/bin/env python3
"""Run a small headless Freeciv AI-only game for organic-history testing."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a headless Freeciv AI-only baseline game.")
    parser.add_argument("--build-dir", type=Path, default=ROOT / "build-organic")
    parser.add_argument("--server", type=Path, default=None, help="Explicit freeciv server binary path.")
    parser.add_argument("--ruleset-serv", type=Path, default=None, help="Optional .serv file to load before baseline commands.")
    parser.add_argument("--load-save", type=Path, default=None, help="Load an existing savegame before applying commands.")
    parser.add_argument("--load-scenario", type=Path, default=None, help="Load a scenario savegame and start it with AI players.")
    parser.add_argument("--turns", type=int, default=20)
    parser.add_argument("--players", type=int, default=4)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--saveturns", type=int, default=1, help="Save every N turns.")
    parser.add_argument("--scorefile", type=Path, default=None, help="Scorelog path; defaults to <output-dir>/score.log.")
    parser.add_argument("--skill", default="hard", help="Server AI skill command, for example hard or normal.")
    parser.add_argument("--profile", type=Path, default=None,
                        help="Optional mechanics profile JSON with luaCommands to apply before --extra-command values.")
    parser.add_argument("--extra-command", action="append", default=[], help="Additional server command before start; repeatable.")
    parser.add_argument("--clean-output-dir", action="store_true", help="Remove an existing run output directory before running.")
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--port", type=int, default=None, help="Freeciv server port; defaults to a run-specific port.")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "runs" / "organic_history_baseline_001")
    args = parser.parse_args()

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    if args.clean_output_dir:
        clean_output_dir(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    scorefile = output_dir / (args.scorefile.name if args.scorefile else "score.log")
    if scorefile.exists():
        scorefile.unlink()
    server = args.server if args.server else find_server(args.build_dir)
    if server is None:
        print("ERROR: Freeciv server binary not found. Build first with: meson setup build-organic -Dclients=[] -Dfcmp=[] -Dtools=[] -Ddebug=true && ninja -C build-organic", file=sys.stderr)
        return 2

    if args.load_save and args.load_scenario:
        print("ERROR: use only one of --load-save or --load-scenario.", file=sys.stderr)
        return 2

    start_game = args.load_save is None
    resume_game = args.load_save is not None
    profile_commands = load_profile_commands(args.profile)
    commands = baseline_commands(args.turns, args.players, args.seed,
                                 args.saveturns, scorefile.name, args.skill,
                                 profile_commands + args.extra_command,
                                 start_game=start_game,
                                 resume_game=resume_game)
    ruleset_path = None
    scenario_ruleset = None
    if args.ruleset_serv:
        ruleset_path = args.ruleset_serv if args.ruleset_serv.is_absolute() else ROOT / args.ruleset_serv
        if args.load_scenario:
            scenario_ruleset = ruleset_from_serv(ruleset_path)
            if scenario_ruleset is None:
                print(f"ERROR: --load-scenario requires a simple rulesetdir in {ruleset_path}", file=sys.stderr)
                return 2
        elif not args.load_save:
            commands.insert(0, f"read {ruleset_path}")

    command_file = output_dir / "server_commands.serv"
    command_file.write_text("\n".join(commands) + "\n", encoding="utf-8")
    started = time.time()
    port = args.port if args.port is not None else run_port(output_dir, args.seed)
    command = [str(server), "--exit-on-end", "--port", str(port), "--saves", str(output_dir)]
    if scenario_ruleset:
        command.extend(["--ruleset", scenario_ruleset])
    load_save = None
    load_scenario = None
    load_save_turn = None
    load_path = args.load_save or args.load_scenario
    if load_path:
        resolved_load_path = load_path if load_path.is_absolute() else ROOT / load_path
        if args.load_scenario:
            load_scenario = resolved_load_path
        else:
            load_save = resolved_load_path
            load_save_turn = save_turn_from_path(load_save)
        command.extend(["-f", str(resolved_load_path)])
    command.extend(["-r", str(command_file)])
    run_env = server_environment()
    try:
        completed = subprocess.run(
            command,
            cwd=output_dir,
            env=run_env,
            text=True,
            capture_output=True,
            timeout=args.timeout,
        )
    except subprocess.TimeoutExpired as exc:
        (output_dir / "server_stdout.log").write_text(timeout_output(exc.stdout), encoding="utf-8")
        (output_dir / "server_stderr.log").write_text(timeout_output(exc.stderr), encoding="utf-8")
        metadata = {
            "server": str(server),
            "command": command,
            "commandFile": str(command_file),
            "port": port,
            "rulesetServ": str(ruleset_path) if ruleset_path else None,
            "scenarioRuleset": scenario_ruleset,
            "scorelogPath": str(scorefile),
            "loadSave": str(load_save) if load_save else None,
            "loadSaveTurn": load_save_turn,
            "loadScenario": str(load_scenario) if load_scenario else None,
            "profile": str(args.profile) if args.profile else None,
            "stdoutPath": str(output_dir / "server_stdout.log"),
            "stderrPath": str(output_dir / "server_stderr.log"),
            "returncode": None,
            "timedOut": True,
            "timeoutSeconds": args.timeout,
            "turns": args.turns,
            "players": args.players,
            "seed": args.seed,
            "saveturns": args.saveturns,
            "success": False,
        }
        write_metadata(output_dir, metadata)
        print(json.dumps(metadata, sort_keys=True), file=sys.stderr)
        return 124
    elapsed = time.time() - started
    (output_dir / "server_stdout.log").write_text(completed.stdout, encoding="utf-8")
    (output_dir / "server_stderr.log").write_text(completed.stderr, encoding="utf-8")
    metadata = {
        "server": str(server),
        "command": command,
        "commandFile": str(command_file),
        "port": port,
        "rulesetServ": str(ruleset_path) if ruleset_path else None,
        "scenarioRuleset": scenario_ruleset,
        "scorelogPath": str(scorefile),
        "loadSave": str(load_save) if load_save else None,
        "loadSaveTurn": load_save_turn,
        "loadScenario": str(load_scenario) if load_scenario else None,
        "profile": str(args.profile) if args.profile else None,
        "stdoutPath": str(output_dir / "server_stdout.log"),
        "stderrPath": str(output_dir / "server_stderr.log"),
        "returncode": completed.returncode,
        "elapsedSeconds": round(elapsed, 3),
        "turns": args.turns,
        "players": args.players,
        "seed": args.seed,
        "saveturns": args.saveturns,
    }
    failure_fragments = [
        "game will not start",
        "Option 'randseed' not recognized",
        "Unknown command",
        "Value out of range",
        "lua error",
        "assertion '",
    ]
    combined_log = completed.stdout + completed.stderr
    save_files = [save_file for save_file in output_dir.glob("*.sav*")
                  if save_file.stat().st_mtime >= started]
    final_saves = [save_file for save_file in save_files
                   if "-final.sav" in save_file.name]
    metadata["logFailureFragments"] = [fragment for fragment in failure_fragments
                                       if fragment in combined_log]
    metadata["saveCount"] = len(save_files)
    metadata["autosaveCount"] = len(save_files) - len(final_saves)
    metadata["finalSave"] = str(sorted(final_saves)[-1]) if final_saves else None
    metadata["scorelogExists"] = scorefile.exists()
    metadata["hookLogCount"] = combined_log.count("organic_history turn_begin")
    metadata["organicMetricLogCount"] = combined_log.count("organic_history_metric")
    metadata["organicStabilityLogCount"] = combined_log.count("organic_history_stability")
    metadata["organicEventLogCount"] = combined_log.count("organic_history_event")
    metadata["organicRegionLogCount"] = combined_log.count("organic_history_region")
    metadata["organicPrestigeLogCount"] = combined_log.count("organic_history_prestige")
    metadata["organicCityPressureLogCount"] = combined_log.count("organic_history_city_pressure")
    metadata["organicInstitutionLogCount"] = combined_log.count("organic_history_institution")
    metadata["organicEventRiskLogCount"] = combined_log.count("organic_history_event_risk")
    metadata["organicStateCapacityLogCount"] = combined_log.count("organic_history_state_capacity")
    metadata["organicDynasticProbeLogCount"] = combined_log.count("organic_history_dynastic_probe")
    metadata["organicDynasticTransferLogCount"] = combined_log.count("organic_history_dynastic_transfer")
    metadata["organicLineageHandoffLogCount"] = combined_log.count("organic_history_lineage_handoff")
    metadata["organicExpansionPressureLogCount"] = combined_log.count("organic_history_expansion_pressure")
    metadata["organicPartialContractionLogCount"] = combined_log.count("organic_history_partial_contraction")
    metadata["organicClaimPressureLogCount"] = combined_log.count("organic_history_claim_pressure")
    metadata["organicEmergenceConditionLogCount"] = combined_log.count("organic_history_emergence_condition")
    metadata["organicBootstrapLogCount"] = combined_log.count("organic_history_bootstrap")
    metadata["organicUrbanizationLogCount"] = combined_log.count("organic_history_urbanization")
    metadata["organicBurstLogCount"] = combined_log.count("organic_history_burst")
    metadata["organicNearEastHandoffLogCount"] = combined_log.count("organic_history_near_east_handoff")
    metadata["organicConquestTargetLogCount"] = combined_log.count("organic_history_conquest_target")
    metadata["organicConquestConversionLogCount"] = combined_log.count("organic_history_conquest_conversion")
    metadata["organicSettlerConversionLogCount"] = combined_log.count("organic_history_settler_conversion")
    metadata["organicObjectiveLogCount"] = combined_log.count("organic_history_objective")
    metadata["organicIberianSiteLogCount"] = combined_log.count("organic_history_iberian_site ")
    metadata["organicIberianSitePoolLogCount"] = combined_log.count("organic_history_iberian_site_pool")
    metadata["organicIberianActivationLogCount"] = combined_log.count("organic_history_iberian_activation_order")
    metadata["organicCoreConsolidationLogCount"] = combined_log.count("organic_history_core_consolidation")
    metadata["organicContractionRecipientLogCount"] = combined_log.count("organic_history_contraction_recipient")
    metadata["organicTargetOverlapLogCount"] = combined_log.count("organic_history_target_overlap")
    metadata["organicTechFloorLogCount"] = combined_log.count("organic_history_tech_floor ")
    metadata["organicClaimConversionLogCount"] = combined_log.count("organic_history_claim_conversion ")
    metadata["organicFallbackSuccessorLogCount"] = combined_log.count("organic_history_fallback_successor ")
    metadata["organicHomelandDefenseLogCount"] = combined_log.count("organic_history_homeland_defense ")
    metadata["organicCollapseLogCount"] = combined_log.count("organic_history_collapse")
    metadata["organicFlavorLogCount"] = combined_log.count("organic_history_flavor")
    metadata["organicArrivalLogCount"] = combined_log.count("organic_history_arrival")
    metadata["organicOceanCrossingLogCount"] = combined_log.count("organic_history_ocean_crossing")
    metadata["organicContactLogCount"] = combined_log.count("organic_history_contact")
    metadata["freecivAssertionLogCount"] = combined_log.count("assertion '")
    metadata["finalTurnSeen"] = final_turn_seen(save_files)
    metadata["scenarioMetadataLogCount"] = combined_log.count("organic_history_scenario_metadata")
    metadata["scenarioMetadataActive"] = (
        "organic_history_scenario_metadata active=true" in combined_log
        or "organic_history_scenario_metadata_status" in combined_log
        and "active=true" in combined_log
    )
    if load_save_turn is not None and metadata["finalTurnSeen"] is not None:
        metadata["continuedTurnCount"] = metadata["finalTurnSeen"] - load_save_turn
        metadata["continuationAdvanced"] = metadata["continuedTurnCount"] > 0
    else:
        metadata["continuedTurnCount"] = None
        metadata["continuationAdvanced"] = None
    success = (completed.returncode == 0
               and not metadata["logFailureFragments"]
               and metadata["saveCount"] > 0
               and metadata["scorelogExists"])
    if load_save is not None:
        success = (success
                   and bool(metadata["continuationAdvanced"])
                   and metadata["hookLogCount"] > 0
                   and metadata["organicMetricLogCount"] > 0)
    metadata["success"] = success
    write_metadata(output_dir, metadata)
    print(json.dumps(metadata, sort_keys=True))
    return 0 if metadata["success"] else 1


def clean_output_dir(output_dir: Path) -> None:
    resolved = output_dir.resolve()
    runs_dir = (ROOT / "runs").resolve()
    if not is_relative_to(resolved, runs_dir):
        raise SystemExit(f"Refusing to clean output directory outside runs/: {output_dir}")
    if output_dir.exists():
        shutil.rmtree(output_dir)


def timeout_output(output: str | bytes | None) -> str:
    if output is None:
        return ""
    if isinstance(output, bytes):
        return output.decode("utf-8", errors="replace")
    return output


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def run_port(output_dir: Path, seed: int) -> int:
    path_total = sum(str(output_dir.resolve()).encode("utf-8"))
    return 5600 + ((path_total + seed) % 1000)


def ruleset_from_serv(path: Path) -> str | None:
    if not path.exists():
        return None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) == 2 and parts[0] == "rulesetdir":
            return parts[1]
    return None


def load_profile_commands(path: Path | None) -> list[str]:
    if path is None:
        return []

    resolved = path if path.is_absolute() else ROOT / path
    profile = json.loads(resolved.read_text(encoding="utf-8"))
    commands = profile.get("luaCommands", [])
    if not isinstance(commands, list) or not all(isinstance(command, str) for command in commands):
        raise SystemExit(f"ERROR: profile {resolved} must contain a luaCommands string list.")
    return commands


def find_server(build_dir: Path) -> Path | None:
    candidates = []
    if build_dir.exists():
        candidates.extend(build_dir.rglob("freeciv-server"))
        candidates.extend(build_dir.rglob("fcser"))
    for name in ("freeciv-server", "fcser"):
        path = shutil.which(name)
        if path:
            candidates.append(Path(path))
    executable = [candidate for candidate in candidates if candidate.is_file() and candidate.stat().st_mode & 0o111]
    return executable[0] if executable else None


def write_metadata(output_dir: Path, metadata: dict[str, object]) -> None:
    (output_dir / "run_metadata.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def baseline_commands(turns: int, players: int, seed: int, saveturns: int,
                      scorefile_name: str, skill: str,
                      extra_commands: list[str], start_game: bool = True,
                      resume_game: bool = False) -> list[str]:
    commands = [
        "cmdlevel hack",
        "set timeout 1",
        f"set endturn {max(1, turns)}",
        f"set saveturns {max(1, saveturns)}",
        "set autosaves TURN|GAMEOVER",
        f"set scorefile {scorefile_name}",
        "set scoreloglevel ALL",
        "set scorelog enabled",
    ]
    if start_game:
        commands[1:1] = [
            f"set gameseed {seed}",
            f"set mapseed {seed}",
            "set minplayers 0",
            f"set aifill {players}",
        ]
    commands.extend(extra_commands)
    if skill and start_game:
        commands.append(skill)
    if start_game:
        commands.append("start")
    elif resume_game and "start" not in extra_commands:
        commands.append("start")
    return commands


def final_turn_seen(save_files: list[Path]) -> int | None:
    max_turn = None
    for save_file in save_files:
        if not save_file.name.startswith("freeciv-T"):
            continue
        turn_text = save_file.name.removeprefix("freeciv-T").split("-", 1)[0]
        try:
            turn = int(turn_text)
        except ValueError:
            continue
        max_turn = turn if max_turn is None else max(max_turn, turn)
    return max_turn


def save_turn_from_path(save_file: Path) -> int | None:
    if not save_file.name.startswith("freeciv-T"):
        return None
    turn_text = save_file.name.removeprefix("freeciv-T").split("-", 1)[0]
    try:
        return int(turn_text)
    except ValueError:
        return None


def server_environment() -> dict[str, str]:
    env = os.environ.copy()
    data_path = str(ROOT / "data")
    if env.get("FREECIV_DATA_PATH"):
        data_path = data_path + os.pathsep + env["FREECIV_DATA_PATH"]
    env["FREECIV_DATA_PATH"] = data_path
    scenario_paths = [
        str(ROOT / "data" / "organic_history" / "scenarios"),
        str(ROOT / "data" / "scenarios"),
    ]
    scenario_path = os.pathsep.join(scenario_paths)
    if env.get("FREECIV_SCENARIO_PATH"):
        scenario_path = scenario_path + os.pathsep + env["FREECIV_SCENARIO_PATH"]
    env["FREECIV_SCENARIO_PATH"] = scenario_path
    return env


if __name__ == "__main__":
    raise SystemExit(main())
