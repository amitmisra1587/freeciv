#!/usr/bin/env python3
"""Validate that an organic-history scenario fixture loads and emits diagnostics."""

from __future__ import annotations

import argparse
import csv
import gzip
import json
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
REGIONS_PATH = ROOT / "data" / "organic_history" / "scenario_regions.json"


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate an organic-history scenario fixture.")
    parser.add_argument("scenario", type=Path)
    parser.add_argument("--ruleset-serv", type=Path, default=Path("data/organic_history.serv"))
    parser.add_argument("--turns", type=int, default=20)
    parser.add_argument("--players", type=int, default=8)
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "runs" / "organic_history_scenario_validate")
    parser.add_argument("--starts-plan", type=Path, default=None,
                        help="Validate expected fixed players/cities from a scenario starts JSON plan.")
    args = parser.parse_args()

    scenario = args.scenario if args.scenario.is_absolute() else ROOT / args.scenario
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    starts_plan = resolve_starts_plan(args.starts_plan, scenario)
    starts_summary = validate_starts_plan(scenario, starts_plan) if starts_plan else {}
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
          and int(metadata.get("organicMetricLogCount") or 0) > 0
          and starts_summary.get("startPlanSuccess", True))
    summary = {
        "scenario": str(scenario),
        "outputDir": str(output_dir),
        "returncode": result.returncode,
        "success": ok,
        "hookLogCount": metadata.get("hookLogCount"),
        "organicMetricLogCount": metadata.get("organicMetricLogCount"),
        "saveCount": metadata.get("saveCount"),
    }
    summary.update(starts_summary)
    print(json.dumps(summary, sort_keys=True))
    return 0 if ok else 1


def read_json(path: Path) -> dict[str, object]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_starts_plan(plan_arg: Path | None, scenario: Path) -> Path | None:
    if plan_arg is not None:
        return plan_arg if plan_arg.is_absolute() else ROOT / plan_arg
    scenario_name = scenario.name
    if scenario_name.endswith(".sav.gz"):
        fixture = scenario_name.removesuffix(".sav.gz")
    elif scenario_name.endswith(".sav"):
        fixture = scenario_name.removesuffix(".sav")
    else:
        fixture = scenario.stem
    plan = scenario.with_name(f"{fixture}_starts.json")
    if plan.exists():
        return plan
    return None


def validate_starts_plan(scenario: Path, plan_path: Path) -> dict[str, object]:
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    valid_regions = load_region_ids()
    save_text = read_save_text(scenario)
    players = parse_save_players(save_text)
    research = parse_research(save_text)
    tech_vector = parse_technology_vector(save_text)
    missing_players: list[str] = []
    missing_cities: list[str] = []
    misplaced_cities: list[str] = []
    gold_mismatches: list[str] = []
    missing_techs: list[str] = []
    research_mismatches: list[str] = []
    metadata_missing: list[str] = []
    metadata_invalid_regions: list[str] = []
    player_matches = 0
    city_matches = 0
    coordinate_matches = 0
    gold_matches = 0
    tech_matches = 0
    research_matches = 0

    for actor in plan.get("actors", []):
        actor_id = actor["id"]
        core_region = actor.get("coreRegion")
        if not core_region:
            metadata_missing.append(f"{actor_id}:coreRegion")
        elif str(core_region) not in valid_regions:
            metadata_invalid_regions.append(f"{actor_id}:coreRegion={core_region}")
        if not actor.get("successorNames"):
            metadata_missing.append(f"{actor_id}:successorNames")
        if not actor.get("successorNation"):
            metadata_missing.append(f"{actor_id}:successorNation")

        player = next((candidate for candidate in players
                       if candidate.get("name") == actor["leader"]
                       and candidate.get("nation") == actor["nation"]), None)
        if player is None:
            missing_players.append(actor["id"])
            continue
        player_matches += 1
        if "gold" in actor:
            if player.get("gold") == actor["gold"]:
                gold_matches += 1
            else:
                gold_mismatches.append(actor["id"])

        player_number = player.get("number")
        research_row = research.get(player_number) if isinstance(player_number, int) else None
        if research_row is not None and actor.get("research"):
            if research_row.get("now_name") == actor["research"]:
                research_matches += 1
            else:
                research_mismatches.append(actor["id"])
        for tech in actor.get("techs", []):
            if research_row is not None and tech_known(research_row, tech_vector, tech):
                tech_matches += 1
            else:
                missing_techs.append(f"{actor['id']}:{tech}")

        city_plans = [actor["city"]] + actor.get("extraCities", [])
        for city_plan in city_plans:
            city_region = city_plan.get("region", core_region)
            if not city_region:
                metadata_missing.append(f"{actor_id}:{city_plan['name']}:region")
            elif str(city_region) not in valid_regions:
                metadata_invalid_regions.append(
                    f"{actor_id}:{city_plan['name']}:region={city_region}")
            if "core" not in city_plan:
                metadata_missing.append(f"{actor_id}:{city_plan['name']}:core")
            city = next((candidate for candidate in player.get("cities", [])
                         if candidate.get("name") == city_plan["name"]), None)
            if city is None:
                missing_cities.append(f"{actor['id']}:{city_plan['name']}")
                continue
            city_matches += 1
            if city.get("x") == city_plan["x"] and city.get("y") == city_plan["y"]:
                coordinate_matches += 1
            else:
                misplaced_cities.append(f"{actor['id']}:{city_plan['name']}")

    actor_count = len(plan.get("actors", []))
    expected_city_count = sum(1 + len(actor.get("extraCities", []))
                              for actor in plan.get("actors", []))
    success = (not missing_players and not missing_cities and not misplaced_cities
               and not gold_mismatches and not missing_techs and not research_mismatches
               and not metadata_missing and not metadata_invalid_regions)
    return {
        "startPlan": str(plan_path),
        "startPlanSuccess": success,
        "expectedActorCount": actor_count,
        "expectedCityCount": expected_city_count,
        "expectedPlayerMatches": player_matches,
        "expectedCityMatches": city_matches,
        "expectedCityCoordinateMatches": coordinate_matches,
        "expectedGoldMatches": gold_matches,
        "expectedTechMatches": tech_matches,
        "expectedResearchMatches": research_matches,
        "missingPlayers": missing_players,
        "missingCities": missing_cities,
        "misplacedCities": misplaced_cities,
        "goldMismatches": gold_mismatches,
        "missingTechs": missing_techs,
        "researchMismatches": research_mismatches,
        "metadataMissing": metadata_missing,
        "metadataInvalidRegions": metadata_invalid_regions,
        "metadataSuccess": not metadata_missing and not metadata_invalid_regions,
    }


def read_save_text(path: Path) -> str:
    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8") as save_file:
            return save_file.read()
    return path.read_text(encoding="utf-8")


def load_region_ids() -> set[str]:
    if not REGIONS_PATH.exists():
        return set()
    regions = json.loads(REGIONS_PATH.read_text(encoding="utf-8")).get("regions", {})
    return {str(region_id) for region_id in regions}


def parse_save_players(text: str) -> list[dict[str, object]]:
    players: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    city_header: list[str] | None = None

    for line in text.splitlines():
        player_match = re.fullmatch(r"\[player(\d+)\]", line)
        if player_match:
            if current is not None:
                players.append(current)
            current = {"number": int(player_match.group(1)), "cities": []}
            city_header = None
            continue
        if line.startswith("[") and current is not None:
            players.append(current)
            current = None
            city_header = None
            continue
        if current is None:
            continue

        if city_header is not None:
            if line == "}":
                city_header = None
                continue
            city = parse_city_row(city_header, line)
            if city is not None:
                current["cities"].append(city)  # type: ignore[index]
            continue

        if line.startswith("name="):
            current["name"] = parse_save_value(line)
        elif line.startswith("nation="):
            current["nation"] = parse_save_value(line)
        elif line.startswith("gold="):
            current["gold"] = int(parse_save_value(line))
        elif line.startswith("ncities="):
            current["ncities"] = int(parse_save_value(line))
        elif line.startswith("c={"):
            city_header = parse_csv_fields(line.removeprefix("c={"))

    if current is not None:
        players.append(current)
    return players


def parse_city_row(header: list[str], line: str) -> dict[str, object] | None:
    row = parse_csv_fields(line)
    if len(row) < len(header):
        return None
    values = dict(zip(header, row))
    try:
        return {
            "name": values["name"],
            "x": int(values["x"]),
            "y": int(values["y"]),
        }
    except (KeyError, ValueError):
        return None


def parse_save_value(line: str) -> str:
    return parse_csv_fields(line.split("=", 1)[1])[0]


def parse_csv_fields(text: str) -> list[str]:
    return next(csv.reader([text]))


def parse_technology_vector(text: str) -> list[str]:
    for line in text.splitlines():
        if line.startswith("technology_vector="):
            return parse_csv_fields(line.split("=", 1)[1])
    return []


def parse_research(text: str) -> dict[int, dict[str, object]]:
    rows: dict[int, dict[str, object]] = {}
    in_research = False
    header: list[str] | None = None
    for line in text.splitlines():
        if line == "[research]":
            in_research = True
            continue
        if in_research and line.startswith("["):
            break
        if not in_research:
            continue
        if line.startswith("r={"):
            header = parse_csv_fields(line.removeprefix("r={"))
            continue
        if header is None or line == "}":
            continue
        row = parse_csv_fields(line)
        if len(row) != len(header):
            continue
        values = dict(zip(header, row))
        try:
            number = int(values["number"])
        except (KeyError, ValueError):
            continue
        rows[number] = values
    return rows


def tech_known(research_row: dict[str, object], tech_vector: list[str], tech: str) -> bool:
    try:
        index = tech_vector.index(tech)
    except ValueError:
        return False
    done = str(research_row.get("done", ""))
    return index < len(done) and done[index] == "1"


if __name__ == "__main__":
    raise SystemExit(main())
