#!/usr/bin/env python3
"""Create organic-history scenario fixtures from an unlocked Earth map."""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SCENARIO_DIR = ROOT / "data" / "organic_history" / "scenarios"
EARTH_SMALL_SOURCE = ROOT / "data" / "scenarios" / "earth-small.sav"
EARTH_LARGE_SOURCE = ROOT / "data" / "scenarios" / "earth-large.sav"
ANCIENT_V1_PLAN = DEFAULT_SCENARIO_DIR / "earth_ancient_v1_starts.json"
V1_PLAN_FILES = [
    DEFAULT_SCENARIO_DIR / "earth_ancient_v1_starts.json",
    DEFAULT_SCENARIO_DIR / "earth_medieval_v1_starts.json",
    DEFAULT_SCENARIO_DIR / "earth_1450_v1_starts.json",
    DEFAULT_SCENARIO_DIR / "earth_global_4000_v1_starts.json",
]

FIXTURES = {
    "earth_ancient_v0": {
        "name": "Organic History Earth Ancient v0",
        "description": "Minimal ancient-era organic-history fixed Earth fixture for AI-only regional testing.",
    },
    "earth_medieval_v0": {
        "name": "Organic History Earth Medieval v0",
        "description": "Minimal medieval-era organic-history fixed Earth fixture for AI-only regional testing.",
    },
    "earth_1450_v0": {
        "name": "Organic History Earth 1450 v0",
        "description": "Minimal 1450-era organic-history fixed Earth fixture for AI-only regional and colonization testing.",
    },
    "earth_global_4000_v0": {
        "name": "Organic History Earth Global 4000 BCE v0",
        "description": "Large Earth 4000 BCE organic-history fixture for dynamic civilization emergence testing.",
        "source": EARTH_LARGE_SOURCE,
    },
}

def main() -> int:
    parser = argparse.ArgumentParser(description="Create organic-history scenario fixtures.")
    parser.add_argument("--source", type=Path, default=EARTH_SMALL_SOURCE)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_SCENARIO_DIR)
    parser.add_argument("--include-v1", action="store_true",
                        help="Generate all available earth_*_v1.sav fixtures with server/Lua authoring.")
    parser.add_argument("--v1-plan", type=Path, default=ANCIENT_V1_PLAN)
    parser.add_argument("--all-v1-plans", action="store_true",
                        help="Generate all known v1 plans instead of only --v1-plan.")
    parser.add_argument("--build-dir", type=Path, default=ROOT / "build-organic")
    parser.add_argument("--server", type=Path, default=None,
                        help="Explicit freeciv server binary path for v1 authoring.")
    parser.add_argument("--authoring-dir", type=Path,
                        default=ROOT / "runs" / "organic_history_scenario_authoring" / "earth_ancient_v1")
    parser.add_argument("--authoring-timeout", type=float, default=60.0)
    args = parser.parse_args()

    source = args.source if args.source.is_absolute() else ROOT / args.source
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    source_text = source.read_text(encoding="utf-8")
    output_dir.mkdir(parents=True, exist_ok=True)
    for fixture_id, metadata in FIXTURES.items():
        fixture_source = metadata.get("source", source)
        fixture_source = fixture_source if fixture_source.is_absolute() else ROOT / fixture_source
        fixture_text = rewrite_metadata(fixture_source.read_text(encoding="utf-8"),
                                        metadata["name"], metadata["description"],
                                        fixture_source)
        output_path = output_dir / f"{fixture_id}.sav"
        output_path.write_text(fixture_text, encoding="utf-8")
        print(output_path)
    if args.include_v1:
        plan_paths = V1_PLAN_FILES if args.all_v1_plans else [args.v1_plan]
        for plan_path in plan_paths:
            create_v1_fixture(source_text, output_dir, args, plan_path)
    return 0


def rewrite_metadata(source_text: str, name: str, description: str,
                     source_path: Path = EARTH_SMALL_SOURCE) -> str:
    text = replace_field(source_text, "name", f'_("{name}")')
    text = replace_field(text, "description", f'_("{description}")')
    return replace_field(text, "authors", f'"The Freeciv Project; organic-history fixture generated from {source_path.name}"')


def create_v1_fixture(
    source_text: str,
    output_dir: Path,
    args: argparse.Namespace,
    plan_path: Path,
) -> None:
    plan_path = plan_path if plan_path.is_absolute() else ROOT / plan_path
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    if plan.get("baseScenario"):
        source_path = Path(str(plan["baseScenario"]))
        source_path = source_path if source_path.is_absolute() else ROOT / source_path
        source_text = source_path.read_text(encoding="utf-8")
    else:
        source_path = args.source if args.source.is_absolute() else ROOT / args.source
    actors = plan.get("actors", [])
    if not actors:
        raise SystemExit(f"No actors found in {plan_path}")
    expected_cities = expected_city_count(plan)
    fixture = str(plan["fixture"])
    metadata = plan.get("metadata", {})
    name = str(metadata.get("name", fixture))
    description = str(metadata.get("description", f"Script-assisted fixture {fixture}; see {plan_path.name}."))

    base_authoring_dir = args.authoring_dir if args.authoring_dir.is_absolute() else ROOT / args.authoring_dir
    authoring_dir = base_authoring_dir if fixture == "earth_ancient_v1" else base_authoring_dir.parent / fixture
    clean_authoring_dir(authoring_dir)
    authoring_dir.mkdir(parents=True, exist_ok=True)

    base_path = authoring_dir / f"{fixture}_base.sav"
    startpos_nations = "TRUE" if plan.get("startposNations", True) else "FALSE"
    base_text = rewrite_metadata(source_text, name, description, source_path)
    base_text = replace_field(base_text, "startpos_nations", startpos_nations)
    base_text = replace_setting_row(base_text, "aifill", "0")
    base_text = replace_setting_row(base_text, "mapseed", "1")
    base_text = replace_setting_row(base_text, "startcity", "FALSE")
    base_path.write_text(base_text, encoding="utf-8")

    lua_path = authoring_dir / f"{fixture}_author.lua"
    write_v1_lua(plan, lua_path)

    server = find_server(args.server, args.build_dir)
    if server is None:
        raise SystemExit("ERROR: Freeciv server binary not found. Build first with: ninja -C build-organic")

    stdout_path = authoring_dir / "server_stdout.log"
    stderr_path = authoring_dir / "server_stderr.log"
    saved_prefix = authoring_dir / f"{fixture}_scensave"
    command = [
        str(server),
        "--exit-on-end",
        "--port", str(authoring_port(authoring_dir)),
        "--saves", str(authoring_dir),
        "--ruleset", "organic_history",
        "-f", str(base_path),
    ]
    env = server_environment()
    with stdout_path.open("w", encoding="utf-8") as stdout, stderr_path.open("w", encoding="utf-8") as stderr:
        proc = subprocess.Popen(command, cwd=authoring_dir, env=env, text=True,
                                stdin=subprocess.PIPE, stdout=stdout, stderr=stderr)
        try:
            send_commands(proc, authoring_start_commands(plan))
            wait_for_log(stdout_path, "organic_history turn_begin turn=1",
                         proc, args.authoring_timeout)
            send_commands(proc, [f"lua file {lua_path}"])
            wait_for_log(stdout_path,
                         f'organic_history_authoring_summary fixture="{plan["fixture"]}" placed={expected_cities} expected={expected_cities}',
                         proc, args.authoring_timeout)
            time.sleep(0.5)
            send_commands(proc, [f"scensave {saved_prefix}", "quit"])
            proc.wait(timeout=args.authoring_timeout)
        except Exception:
            stop_process(proc)
            raise

    if proc.returncode != 0:
        raise SystemExit(f"ERROR: v1 authoring server failed with {proc.returncode}; see {stdout_path}")

    generated = saved_prefix.with_suffix(".sav.gz")
    if not generated.exists():
        raise SystemExit(f"ERROR: v1 authoring did not create {generated}; see {stdout_path}")

    scenario_text = read_save_text(generated)
    scenario_text = rewrite_metadata(scenario_text, name, description, source_path)
    scenario_text = replace_field(scenario_text, "startpos_nations", startpos_nations)
    scenario_text = replace_field(scenario_text, "id", '""')
    scenario_text = replace_field(scenario_text, "serverid", '""')
    scenario_text = replace_field(scenario_text, "last_turn_change_time", "0")
    scenario_text = replace_section_field(scenario_text, "game", "phase_seconds", "0")
    scenario_text = replace_section_field(scenario_text, "map", "random_seed", "1")
    scenario_text = strip_script_vars(scenario_text)
    scenario_text = normalize_startpos_nations(scenario_text)
    scenario_text = normalize_shuffled_players(scenario_text, len(actors))
    scenario_text = normalize_research(scenario_text, plan)
    output_path = output_dir / f"{fixture}.sav"
    output_path.write_text(scenario_text, encoding="utf-8")
    print(output_path)


def write_v1_lua(plan: dict[str, object], lua_path: Path) -> None:
    actors = plan["actors"]
    dormant_actors = plan.get("dormantActors", [])
    fixture = lua_string(plan["fixture"])
    lines = [
        "local starts = {",
    ]
    for actor in actors:
        city = actor["city"]
        start = actor["start"]
        techs = actor.get("techs", [])
        traits = actor.get("traits", {})
        trait_items = sorted(traits.items()) if isinstance(traits, dict) else []
        extra_cities = actor.get("extraCities", [])
        city_items = [city] + (extra_cities if isinstance(extra_cities, list) else [])
        lines.append(
            "  {id = %s, player = %s, nation = %s, city = %s, "
            "x = %d, y = %d, start_x = %d, start_y = %d, gold = %d, techs = {%s}, traits = {%s}, cities = {%s}},"
            % (
                lua_string(actor["id"]),
                lua_string(actor["leader"]),
                lua_string(actor["nation"]),
                lua_string(city["name"]),
                city["x"], city["y"], start["x"], start["y"],
                int(actor.get("gold", 50)),
                ", ".join(lua_string(tech) for tech in techs),
                ", ".join(f"[{lua_string(trait)}] = {int(value)}"
                          for trait, value in trait_items),
                ", ".join(
                    "{name = %s, x = %d, y = %d}" % (
                        lua_string(city_item["name"]),
                        city_item["x"],
                        city_item["y"],
                    )
                    for city_item in city_items
                ),
            )
        )
    lines.extend([
        "}",
        "local dormant_players = {",
    ])
    for actor in dormant_actors if isinstance(dormant_actors, list) else []:
        lines.append(
            "  {id = %s, player = %s, nation = %s},"
            % (
                lua_string(actor["id"]),
                lua_string(actor["leader"]),
                lua_string(actor["nation"]),
            )
        )
    lines.extend([
        "}",
        "",
        "local placed = 0",
        "for _, start in ipairs(starts) do",
        "  local player = find.player(start.player)",
        "  if player == nil then",
        "    error(string.format('missing player %s', start.player))",
        "  end",
        "  local nation = player.nation",
        "  if nation == nil or nation:rule_name() ~= start.nation then",
        "    error(string.format('player %s has unexpected nation', start.player))",
        "  end",
        "  local actor_cities = 0",
        "  for _, city in ipairs(start.cities) do",
        "    local tile = find.tile(city.x, city.y)",
        "    if tile == nil then",
        "      error(string.format('missing tile %d,%d', city.x, city.y))",
        "    end",
        "    if tile:city() ~= nil then",
        "      error(string.format('tile %d,%d already has a city', city.x, city.y))",
        "    end",
        "    local ok = edit.city_create(player, tile, city.name, nil)",
        "    if not ok then",
        "      error(string.format('failed to create city %s at %d,%d', city.name, city.x, city.y))",
        "    end",
        "    placed = placed + 1",
        "    actor_cities = actor_cities + 1",
        "  end",
        "  local gold_delta = start.gold - player:gold()",
        "  if gold_delta ~= 0 then",
        "    edit.change_gold(player, gold_delta)",
        "  end",
        "  local granted = 0",
        "  for _, tech_name in ipairs(start.techs) do",
        "    local tech = find.tech_type(tech_name)",
        "    if tech == nil then",
        "      error(string.format('missing technology %s', tech_name))",
        "    end",
        "    edit.give_tech(player, tech, 0, false, 'organic_history_scenario')",
        "    granted = granted + 1",
        "  end",
        "  local trait_mods = 0",
        "  for trait_name, trait_mod in pairs(start.traits) do",
        "    if not edit.trait_mod(player, trait_name, trait_mod) then",
        "      error(string.format('failed to set trait %s for %s', trait_name, start.player))",
        "    end",
        "    trait_mods = trait_mods + 1",
        "  end",
        "  log.normal('organic_history_authoring_era fixture=%q id=%q player=%q gold=%d techs=%d',",
        f"             {fixture}, start.id, player.name, start.gold, granted)",
        "  log.normal('organic_history_authoring_traits fixture=%q id=%q player=%q traits=%d',",
        f"             {fixture}, start.id, player.name, trait_mods)",
        "  log.normal('organic_history_authoring_start fixture=%q id=%q player=%q nation=%q city=%q x=%d y=%d start_x=%d start_y=%d',",
        f"             {fixture}, start.id, player.name, nation:rule_name(), start.city, start.x, start.y, start.start_x, start.start_y)",
        "  log.normal('organic_history_authoring_actor fixture=%q id=%q player=%q cities=%d',",
        f"             {fixture}, start.id, player.name, actor_cities)",
        "end",
        "local killed_units = 0",
        "for _, start in ipairs(starts) do",
        "  local player = find.player(start.player)",
        "  for unit in player:units_iterate() do",
        "    edit.unit_kill(unit, 'editor', nil)",
        "    killed_units = killed_units + 1",
        "  end",
        "end",
        "for _, dormant in ipairs(dormant_players) do",
        "  local player = find.player(dormant.player)",
        "  if player == nil then",
        "    error(string.format('missing dormant player %s', dormant.player))",
        "  end",
        "  for unit in player:units_iterate() do",
        "    edit.unit_kill(unit, 'editor', nil)",
        "    killed_units = killed_units + 1",
        "  end",
        "  log.normal('organic_history_authoring_dormant fixture=%q id=%q player=%q nation=%q',",
        f"             {fixture}, dormant.id, player.name, player.nation:rule_name())",
        "end",
        "log.normal('organic_history_authoring_units_removed fixture=%q units=%d',",
        f"           {fixture}, killed_units)",
        f"log.normal('organic_history_authoring_summary fixture=%q placed=%d expected=%d', {fixture}, placed, {expected_city_count(plan)})",
        "",
    ])
    lua_path.write_text("\n".join(lines), encoding="utf-8")


def expected_city_count(plan: dict[str, object]) -> int:
    total = 0
    for actor in plan["actors"]:
        extra = actor.get("extraCities", [])
        total += 1 + (len(extra) if isinstance(extra, list) else 0)
    return total


def authoring_start_commands(plan: dict[str, object]) -> list[str]:
    commands = [
        "cmdlevel hack",
        "set gameseed 1",
        "set timeout 100",
        "set endturn 20",
        "set minplayers 0",
        "set aifill 0",
        "set animals 0",
        "set techlevel 0",
        "set startunits c",
    ]
    actors = list(plan["actors"])
    dormant_actors = plan.get("dormantActors", [])
    if isinstance(dormant_actors, list):
        actors.extend(dormant_actors)

    for actor in actors:
        leader = quote_server_arg(actor["leader"])
        commands.append(f"create {leader} classic")
        commands.append(
            "playernation %s %s 1 %s %s"
            % (
                leader,
                quote_server_arg(actor["nation"]),
                leader,
                quote_server_arg(actor["style"]),
            )
        )
    commands.append("start")
    return commands


def send_commands(proc: subprocess.Popen[str], commands: list[str]) -> None:
    if proc.stdin is None:
        raise RuntimeError("server stdin is unavailable")
    for command in commands:
        proc.stdin.write(command + "\n")
        proc.stdin.flush()
        time.sleep(0.05)


def wait_for_log(path: Path, fragment: str, proc: subprocess.Popen[str],
                 timeout: float) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if path.exists() and fragment in path.read_text(encoding="utf-8", errors="replace"):
            return
        if proc.poll() is not None:
            break
        time.sleep(0.2)
    raise RuntimeError(f"Timed out waiting for {fragment!r} in {path}")


def stop_process(proc: subprocess.Popen[str]) -> None:
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


def clean_authoring_dir(authoring_dir: Path) -> None:
    resolved = authoring_dir.resolve()
    runs_dir = (ROOT / "runs").resolve()
    if not is_relative_to(resolved, runs_dir):
        raise SystemExit(f"Refusing to clean authoring directory outside runs/: {authoring_dir}")
    if authoring_dir.exists():
        shutil.rmtree(authoring_dir)


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
    except ValueError:
        return False
    return True


def find_server(explicit: Path | None, build_dir: Path) -> Path | None:
    candidates: list[Path] = []
    if explicit is not None:
        candidates.append(explicit if explicit.is_absolute() else ROOT / explicit)
    resolved_build_dir = build_dir if build_dir.is_absolute() else ROOT / build_dir
    if resolved_build_dir.exists():
        candidates.extend(resolved_build_dir.rglob("freeciv-server"))
        candidates.extend(resolved_build_dir.rglob("fcser"))
    for name in ("freeciv-server", "fcser"):
        path = shutil.which(name)
        if path:
            candidates.append(Path(path))
    for candidate in candidates:
        if candidate.is_file() and candidate.stat().st_mode & 0o111:
            return candidate
    return None


def server_environment() -> dict[str, str]:
    env = os.environ.copy()
    data_path = str(ROOT / "data")
    if env.get("FREECIV_DATA_PATH"):
        data_path = data_path + os.pathsep + env["FREECIV_DATA_PATH"]
    env["FREECIV_DATA_PATH"] = data_path
    scenario_path = os.pathsep.join([
        str(ROOT / "data" / "organic_history" / "scenarios"),
        str(ROOT / "data" / "scenarios"),
    ])
    if env.get("FREECIV_SCENARIO_PATH"):
        scenario_path = scenario_path + os.pathsep + env["FREECIV_SCENARIO_PATH"]
    env["FREECIV_SCENARIO_PATH"] = scenario_path
    return env


def authoring_port(authoring_dir: Path) -> int:
    path_total = sum(str(authoring_dir.resolve()).encode("utf-8"))
    return 5700 + (path_total % 1000)


def read_save_text(path: Path) -> str:
    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8") as save_file:
            return save_file.read()
    return path.read_text(encoding="utf-8")


def quote_server_arg(value: object) -> str:
    text = str(value)
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua_string(value: object) -> str:
    return json.dumps(str(value))


def replace_field(text: str, key: str, value: str) -> str:
    return re.sub(rf"^{re.escape(key)}=.*$", f"{key}={value}", text, count=1, flags=re.MULTILINE)


def replace_setting_row(text: str, setting: str, value: str) -> str:
    return re.sub(rf'^"{re.escape(setting)}",.*$',
                  f'"{setting}",{value},{value},"Changed"',
                  text, count=1, flags=re.MULTILINE)


def replace_section_field(text: str, section: str, key: str, value: str) -> str:
    lines = text.splitlines()
    in_section = False
    for index, line in enumerate(lines):
        if line == f"[{section}]":
            in_section = True
            continue
        if in_section and line.startswith("["):
            break
        if in_section and line.startswith(f"{key}="):
            lines[index] = f"{key}={value}"
            break
    return "\n".join(lines) + "\n"


def strip_script_vars(text: str) -> str:
    return re.sub(r"(?ms)^vars=\$.*?^\$", "vars=$$", text, count=1)


def normalize_startpos_nations(text: str) -> str:
    def normalize_line(match: re.Match[str]) -> str:
        nations = "#".join(sorted(match.group(2).split("#")))
        return f"{match.group(1)}{nations}{match.group(3)}"

    return re.sub(r'^(\d+,\d+,(?:TRUE|FALSE),")([^"]*)(")$',
                  normalize_line, text, flags=re.MULTILINE)


def normalize_shuffled_players(text: str, player_count: int) -> str:
    for index in range(player_count):
        text = re.sub(rf"^shuffled_player_{index}=.*$",
                      f"shuffled_player_{index}={index}",
                      text, count=1, flags=re.MULTILINE)
    return text


def normalize_research(text: str, plan: dict[str, object]) -> str:
    research_by_number = [
        actor.get("research", "Alphabet") for actor in plan["actors"]
    ]
    lines = text.splitlines()
    in_research = False
    in_table = False
    for index, line in enumerate(lines):
        if line == "[research]":
            in_research = True
            continue
        if in_research and line.startswith("["):
            break
        if not in_research:
            continue
        if line.startswith("r={"):
            in_table = True
            continue
        if in_table:
            if line == "}":
                in_table = False
                continue
            row = parse_csv_fields(line)
            if len(row) >= 7 and row[0].isdigit():
                number = int(row[0])
                if number < len(research_by_number):
                    row[6] = str(research_by_number[number])
                    lines[index] = format_research_row(row)
    return "\n".join(lines) + "\n"


def parse_csv_fields(text: str) -> list[str]:
    return next(csv.reader([text]))


def format_research_row(row: list[str]) -> str:
    string_columns = {1, 4, 6, 8}
    fields = [
        quote_save_string(value) if index in string_columns else value
        for index, value in enumerate(row)
    ]
    return ",".join(fields)


def quote_save_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


if __name__ == "__main__":
    raise SystemExit(main())
