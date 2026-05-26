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
    parser.add_argument("--turns", type=int, default=20)
    parser.add_argument("--players", type=int, default=4)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--saveturns", type=int, default=1, help="Save every N turns.")
    parser.add_argument("--scorefile", type=Path, default=None, help="Scorelog path; defaults to <output-dir>/score.log.")
    parser.add_argument("--skill", default="hard", help="Server AI skill command, for example hard or normal.")
    parser.add_argument("--extra-command", action="append", default=[], help="Additional server command before start; repeatable.")
    parser.add_argument("--clean-output-dir", action="store_true", help="Remove an existing run output directory before running.")
    parser.add_argument("--timeout", type=int, default=90)
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

    commands = baseline_commands(args.turns, args.players, args.seed,
                                 args.saveturns, scorefile.name, args.skill,
                                 args.extra_command,
                                 start_game=args.load_save is None)
    ruleset_path = None
    if args.ruleset_serv:
        ruleset_path = args.ruleset_serv if args.ruleset_serv.is_absolute() else ROOT / args.ruleset_serv
        commands.insert(0, f"read {ruleset_path}")

    command_file = output_dir / "server_commands.serv"
    command_file.write_text("\n".join(commands) + "\n", encoding="utf-8")
    started = time.time()
    command = [str(server), "--exit-on-end", "--saves", str(output_dir)]
    load_save = None
    if args.load_save:
        load_save = args.load_save if args.load_save.is_absolute() else ROOT / args.load_save
        command.extend(["-f", str(load_save)])
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
            "rulesetServ": str(ruleset_path) if ruleset_path else None,
            "scorelogPath": str(scorefile),
            "loadSave": str(load_save) if load_save else None,
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
        "rulesetServ": str(ruleset_path) if ruleset_path else None,
        "scorelogPath": str(scorefile),
        "loadSave": str(load_save) if load_save else None,
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
    metadata["finalTurnSeen"] = final_turn_seen(save_files)
    metadata["success"] = (completed.returncode == 0
                           and not metadata["logFailureFragments"]
                           and metadata["saveCount"] > 0
                           and metadata["scorelogExists"])
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
                      extra_commands: list[str], start_game: bool = True) -> list[str]:
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


def server_environment() -> dict[str, str]:
    env = os.environ.copy()
    data_path = str(ROOT / "data")
    if env.get("FREECIV_DATA_PATH"):
        data_path = data_path + os.pathsep + env["FREECIV_DATA_PATH"]
    env["FREECIV_DATA_PATH"] = data_path
    scenario_path = str(ROOT / "data" / "scenarios")
    if env.get("FREECIV_SCENARIO_PATH"):
        scenario_path = scenario_path + os.pathsep + env["FREECIV_SCENARIO_PATH"]
    env["FREECIV_SCENARIO_PATH"] = scenario_path
    return env


if __name__ == "__main__":
    raise SystemExit(main())
