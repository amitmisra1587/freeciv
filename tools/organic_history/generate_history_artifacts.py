#!/usr/bin/env python3
"""Generate scenario artifacts from canonical organic-history data."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL = ROOT / "data" / "organic_history" / "history" / "earth_global_4000.json"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model", type=Path, nargs="?", default=DEFAULT_MODEL)
    parser.add_argument("--check", action="store_true",
                        help="Compare generated artifacts to the paths listed in the model.")
    parser.add_argument("--write", action="store_true",
                        help="Write generated artifacts to the paths listed in the model.")
    args = parser.parse_args()

    model_path = resolve_path(args.model)
    model = read_json(model_path)
    validate_model(model, model_path)
    json_artifacts = build_json_artifacts(model)
    lua_runtime_block = build_lua_runtime_block(model)

    if args.write:
        for key, artifact in json_artifacts.items():
            path = resolve_path(model["artifacts"][key])
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json_text(artifact), encoding="utf-8")
        lua_script = model["artifacts"].get("luaRuntimeScript")
        if lua_script:
            path = resolve_path(lua_script)
            replace_generated_block(path, lua_runtime_block)

    if args.check:
        mismatches: list[str] = []
        for key, artifact in json_artifacts.items():
            path = resolve_path(model["artifacts"][key])
            if not path.exists():
                mismatches.append(f"{key}: missing {path}")
                continue
            current = read_json(path)
            if current != artifact:
                mismatches.append(f"{key}: differs from {path}")
        lua_script = model["artifacts"].get("luaRuntimeScript")
        if lua_script:
            path = resolve_path(lua_script)
            if not path.exists():
                mismatches.append(f"luaRuntimeScript: missing {path}")
            elif extract_generated_block(path.read_text(encoding="utf-8")) != lua_runtime_block:
                mismatches.append(f"luaRuntimeScript: generated block differs from {path}")
        if mismatches:
            raise SystemExit("FAIL: generated artifacts are stale: " + "; ".join(mismatches))

    if not args.write and not args.check:
        output: dict[str, Any] = dict(json_artifacts)
        output["luaRuntimeBlock"] = lua_runtime_block
        json.dump(output, sys.stdout, indent=2, ensure_ascii=False)
        print()

    return 0


def resolve_path(path: str | Path) -> Path:
    path = Path(path)
    return path if path.is_absolute() else ROOT / path


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def json_text(value: dict[str, Any]) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def validate_model(model: dict[str, Any], model_path: Path) -> None:
    required_top_level = {"fixture", "metadata", "artifacts", "map", "ruleset", "actors"}
    missing = sorted(required_top_level - model.keys())
    if missing:
        raise SystemExit(f"ERROR: {model_path} missing required keys: {', '.join(missing)}")

    artifacts = model["artifacts"]
    for key in ("startsPlan", "timeline"):
        if key not in artifacts:
            raise SystemExit(f"ERROR: {model_path} artifacts missing {key}")

    actors = model["actors"]
    if not isinstance(actors, list) or not actors:
        raise SystemExit(f"ERROR: {model_path} must define at least one actor")
    region_ids = validate_regions(model, model_path)

    ids: set[str] = set()
    nations: dict[str, list[str]] = {}
    initial_count = 0
    for actor in actors:
        actor_id = require_str(actor, "id", model_path)
        if actor_id in ids:
            raise SystemExit(f"ERROR: duplicate actor id in {model_path}: {actor_id}")
        ids.add(actor_id)
        role = require_str(actor, "role", model_path)
        require_str(actor, "leader", model_path)
        nation = require_str(actor, "nation", model_path)
        require_str(actor, "style", model_path)
        core_region = require_str(actor, "coreRegion", model_path)
        validate_region_id(core_region, region_ids, model_path, f"actor {actor_id} coreRegion")
        validate_claims(actor, region_ids, model_path)
        nations.setdefault(nation, []).append(actor_id)

        if role == "initial":
            initial_count += 1
            require_dict(actor, "start", model_path)
            require_dict(actor, "city", model_path)
            city_region = actor["city"].get("region", core_region)
            validate_region_id(city_region, region_ids, model_path,
                               f"actor {actor_id} city region")
            require_str(actor, "successorNation", model_path)
            if not actor.get("successorNames"):
                raise SystemExit(f"ERROR: initial actor {actor_id} missing successorNames")
        elif role == "emergent":
            emergence = require_dict(actor, "emergence", model_path)
            require_str(emergence, "city", model_path)
            if "earliestTurn" not in emergence:
                raise SystemExit(f"ERROR: emergent actor {actor_id} missing earliestTurn")
        else:
            raise SystemExit(f"ERROR: actor {actor_id} has unsupported role {role!r}")

    duplicates = {nation: actor_ids for nation, actor_ids in nations.items()
                  if len(actor_ids) > 1}
    if duplicates:
        detail = ", ".join(f"{nation}: {', '.join(actor_ids)}"
                           for nation, actor_ids in sorted(duplicates.items()))
        raise SystemExit(
            f"ERROR: duplicate Freeciv nations in {model_path}: {detail}. "
            "Use unique nation slots for active and dormant actors."
        )
    if initial_count == 0:
        raise SystemExit(f"ERROR: {model_path} must define initial actors")


def validate_regions(model: dict[str, Any], model_path: Path) -> set[str]:
    regions = model.get("regions", {})
    boxes = regions.get("boxes", {})
    order = regions.get("order", [])
    if not isinstance(boxes, dict) or not boxes:
        return set()
    if not isinstance(order, list) or not all(isinstance(region_id, str) for region_id in order):
        raise SystemExit(f"ERROR: {model_path} regions.order must be a string list")

    box_ids = set(boxes)
    missing_from_boxes = [region_id for region_id in order if region_id not in box_ids]
    if missing_from_boxes:
        raise SystemExit(
            f"ERROR: {model_path} regions.order references missing boxes: "
            + ", ".join(missing_from_boxes)
        )
    missing_from_order = sorted(box_ids - set(order))
    if missing_from_order:
        raise SystemExit(
            f"ERROR: {model_path} regions.boxes missing from order: "
            + ", ".join(missing_from_order)
        )
    for region_id, box in boxes.items():
        for key in ("name", "x_min", "x_max", "y_min", "y_max"):
            if key not in box:
                raise SystemExit(f"ERROR: {model_path} region {region_id} missing {key}")
    return box_ids


def validate_claims(actor: dict[str, Any], region_ids: set[str], model_path: Path) -> None:
    claims = actor.get("claims", {})
    for claim_type in ("core", "historical", "contested", "colonial", "cultural", "respawn"):
        values = claims.get(claim_type, [])
        if not isinstance(values, list):
            raise SystemExit(
                f"ERROR: {model_path} actor {actor['id']} claims.{claim_type} must be a list"
            )
        for region_id in values:
            validate_region_id(region_id, region_ids, model_path,
                               f"actor {actor['id']} claims.{claim_type}")


def validate_region_id(
    region_id: str,
    region_ids: set[str],
    model_path: Path,
    context: str,
) -> None:
    if region_ids and region_id not in region_ids:
        raise SystemExit(f"ERROR: {model_path} {context} references unknown region {region_id}")


def require_str(value: dict[str, Any], key: str, model_path: Path) -> str:
    candidate = value.get(key)
    if not isinstance(candidate, str) or not candidate:
        raise SystemExit(f"ERROR: {model_path} has missing or invalid string key {key}")
    return candidate


def require_dict(value: dict[str, Any], key: str, model_path: Path) -> dict[str, Any]:
    candidate = value.get(key)
    if not isinstance(candidate, dict):
        raise SystemExit(f"ERROR: {model_path} has missing or invalid object key {key}")
    return candidate


def build_json_artifacts(model: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        "startsPlan": build_starts_plan(model),
        "timeline": build_timeline(model),
    }


GENERATED_START = "-- BEGIN GENERATED GLOBAL HISTORY DATA"
GENERATED_END = "-- END GENERATED GLOBAL HISTORY DATA"


def build_lua_runtime_block(model: dict[str, Any]) -> str:
    lines = [
        GENERATED_START,
        "-- Generated by tools/organic_history/generate_history_artifacts.py.",
        "-- Edit data/organic_history/history/earth_global_4000.json instead.",
        lua_assignment("organic_history_global_scenario_actor_metadata",
                       build_lua_actor_metadata(model)),
        "",
        lua_assignment("organic_history_global_scenario_city_metadata",
                       build_lua_city_metadata(model)),
        "",
        lua_assignment("organic_history_global_scenario_region_order",
                       build_lua_region_order(model)),
        "",
        lua_assignment("organic_history_global_scenario_regions",
                       build_lua_regions(model)),
        "",
        lua_assignment("organic_history_global_actor_region_claims",
                       build_lua_region_claims(model)),
        "",
        lua_assignment("organic_history_global_actor_flavor_diagnostics",
                       build_lua_flavor_diagnostics(model)),
        "",
        lua_assignment("organic_history_global_actor_objectives",
                       build_lua_actor_objectives(model)),
        "",
        lua_assignment("organic_history_global_historical_gravity",
                       model.get("historicalGravity", {})),
        "",
        lua_assignment("organic_history_global_lifecycle_archetypes",
                       model.get("lifecycleArchetypes", {})),
        "",
        lua_assignment("organic_history_global_actor_lifecycle_types",
                       model.get("actorLifecycleTypes", {})),
        "",
        lua_assignment("organic_history_global_emergence_actors",
                       build_lua_emergence_actors(model)),
        GENERATED_END,
    ]
    return "\n".join(lines) + "\n"


def build_lua_actor_metadata(model: dict[str, Any]) -> dict[str, Any]:
    metadata: dict[str, Any] = {}
    for actor in model["actors"]:
        metadata[actor["id"]] = {
            "leader": actor["leader"],
            "nation": actor["nation"],
            "core_region": actor["coreRegion"],
            "successor_nation": actor.get("successorNation", actor["nation"]),
            "successor_names": actor.get("successorNames", []),
            "core_cities": core_cities_for_actor(actor),
        }
    return metadata


def core_cities_for_actor(actor: dict[str, Any]) -> dict[str, bool]:
    cities: dict[str, bool] = {}
    if actor["role"] == "initial":
        cities[actor["city"]["name"]] = True
        for city in actor.get("extraCities", []):
            if city.get("core", False):
                cities[city["name"]] = True
    elif actor["role"] == "emergent":
        cities[actor["emergence"]["city"]] = True
    return cities


def build_lua_city_metadata(model: dict[str, Any]) -> dict[str, Any]:
    metadata: dict[str, Any] = {}
    for actor in model["actors"]:
        if actor["role"] == "initial":
            city = actor["city"]
            metadata[city["name"]] = city_metadata(actor, city)
            for extra_city in actor.get("extraCities", []):
                metadata[extra_city["name"]] = city_metadata(actor, extra_city)
        elif actor["role"] == "emergent":
            emergence = actor["emergence"]
            metadata[emergence["city"]] = {
                "actor": actor["id"],
                "region": actor["coreRegion"],
                "core": True,
                "x": emergence["x"],
                "y": emergence["y"],
            }
    return metadata


def city_metadata(actor: dict[str, Any], city: dict[str, Any]) -> dict[str, Any]:
    return {
        "actor": actor["id"],
        "region": city.get("region", actor["coreRegion"]),
        "core": city.get("core", False),
        "x": city["x"],
        "y": city["y"],
    }


def build_lua_region_order(model: dict[str, Any]) -> list[str]:
    return model.get("regions", {}).get("order", [])


def build_lua_regions(model: dict[str, Any]) -> dict[str, Any]:
    return model.get("regions", {}).get("boxes", {})


def build_lua_region_claims(model: dict[str, Any]) -> dict[str, Any]:
    claims: dict[str, Any] = {}
    for actor in model["actors"]:
        actor_claims = actor.get("claims", {})
        entry = {
            "core": actor_claims.get("core", [actor["coreRegion"]]),
            "historical": actor_claims.get("historical", []),
            "contested": actor_claims.get("contested", []),
            "colonial": actor_claims.get("colonial", []),
            "cultural": actor_claims.get("cultural", []),
            "respawn": actor_claims.get("respawn", []),
        }
        if actor.get("noHistoricalConversion"):
            entry["noHistoricalConversion"] = True
        claims[actor["id"]] = entry
    return claims


def build_lua_flavor_diagnostics(model: dict[str, Any]) -> dict[str, Any]:
    diagnostics: dict[str, Any] = {}
    for actor in model["actors"]:
        diagnostics[actor["id"]] = {
            "policy_hints": actor.get("policyHints", []),
            "uhv_diagnostics": actor.get("uhvDiagnostics", []),
        }
    return diagnostics


def build_lua_actor_objectives(model: dict[str, Any]) -> dict[str, Any]:
    objectives: dict[str, Any] = {}
    for actor in model["actors"]:
        actor_objectives = actor.get("objectives", [])
        if actor_objectives:
            objectives[actor["id"]] = actor_objectives
    return objectives


def build_lua_emergence_actors(model: dict[str, Any]) -> dict[str, Any]:
    actors: dict[str, Any] = {}
    for actor in model["actors"]:
        if actor["role"] != "emergent":
            continue
        emergence = actor["emergence"]
        value: dict[str, Any] = {
            "leader": actor["leader"],
            "nation": actor["nation"],
            "style": actor["style"],
            "city": emergence["city"],
            "x": emergence["x"],
            "y": emergence["y"],
            "core_region": actor["coreRegion"],
            "earliest_turn": emergence["earliestTurn"],
            "predecessors": emergence.get("predecessors", []),
            "gold": actor.get("gold", 50),
            "techs": actor.get("techs", []),
        }
        if actor.get("traits"):
            value["traits"] = actor["traits"]
        if actor.get("probability") is not None:
            value["probability"] = actor["probability"]
        if actor.get("bootstrapPackage"):
            value["bootstrapPackage"] = actor["bootstrapPackage"]
        if actor.get("burst"):
            value["burst"] = actor["burst"]
        if actor.get("dynasticTransferMaxCities") is not None:
            value["dynasticTransferMaxCities"] = actor["dynasticTransferMaxCities"]
        if emergence.get("fallbackRegions"):
            value["fallback_regions"] = emergence["fallbackRegions"]
        actors[actor["id"]] = value
    return actors


def lua_assignment(name: str, value: Any) -> str:
    return f"{name} = {lua_value(value, 0)}"


def lua_value(value: Any, indent: int) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int | float):
        return str(value)
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, list):
        return lua_list(value, indent)
    if isinstance(value, dict):
        return lua_table(value, indent)
    if value is None:
        return "nil"
    raise TypeError(f"Unsupported Lua value: {value!r}")


def lua_list(values: list[Any], indent: int) -> str:
    if not values:
        return "{}"
    return "{" + ", ".join(lua_value(value, indent) for value in values) + "}"


def lua_table(values: dict[str, Any], indent: int) -> str:
    if not values:
        return "{}"

    child_indent = indent + 2
    lines = ["{"]
    for index, key in enumerate(sorted(values)):
        suffix = "," if index < len(values) - 1 else ""
        lines.append(
            " " * child_indent
            + f"{lua_key(key)} = {lua_value(values[key], child_indent)}{suffix}"
        )
    lines.append(" " * indent + "}")
    return "\n".join(lines)


def lua_key(key: str) -> str:
    if key.replace("_", "a").isalnum() and not key[0].isdigit():
        return key
    return f"[{lua_string(key)}]"


def lua_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def replace_generated_block(path: Path, block: str) -> None:
    text = path.read_text(encoding="utf-8")
    current = extract_generated_block(text)
    path.write_text(text.replace(current, block), encoding="utf-8")


def extract_generated_block(text: str) -> str:
    start = text.find(GENERATED_START)
    end = text.find(GENERATED_END)
    if start < 0 or end < 0 or end < start:
        raise SystemExit("ERROR: generated Lua block markers not found")
    end += len(GENERATED_END)
    if end < len(text) and text[end] == "\n":
        end += 1
    return text[start:end]


def build_starts_plan(model: dict[str, Any]) -> dict[str, Any]:
    actors = model["actors"]
    initial_actors = [actor for actor in actors if actor["role"] == "initial"]
    emergent_actors = [actor for actor in actors if actor["role"] == "emergent"]
    map_config = model["map"]
    starts_plan: dict[str, Any] = {
        "fixture": model["fixture"],
        "metadata": model["metadata"],
        "baseScenario": map_config["source"],
        "startposNations": map_config.get("startposNations", True),
        "ruleset": model["ruleset"],
        "generationMode": model["generationMode"],
        "notes": model.get("startsNotes", []),
        "actors": [initial_actor_start(actor) for actor in initial_actors],
        "dormantActors": [
            {
                "id": actor["id"],
                "leader": actor["leader"],
                "nation": actor["nation"],
                "style": actor["style"],
            }
            for actor in emergent_actors
        ],
    }
    return starts_plan


def initial_actor_start(actor: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {
        "id": actor["id"],
        "leader": actor["leader"],
        "nation": actor["nation"],
        "style": actor["style"],
        "coreRegion": actor["coreRegion"],
        "successorNation": actor["successorNation"],
        "successorNames": actor["successorNames"],
    }
    for optional_key in ("research", "techs", "gold", "traits", "start", "city", "extraCities"):
        if optional_key in actor:
            result[optional_key] = actor[optional_key]
    return result


def build_timeline(model: dict[str, Any]) -> dict[str, Any]:
    actors = model["actors"]
    map_config = model["map"]
    initial_actors = [actor["id"] for actor in actors if actor["role"] == "initial"]
    emergence_actors = []
    for actor in actors:
        if actor["role"] != "emergent":
            continue
        emergence = actor["emergence"]
        emergence_actors.append({
            "id": actor["id"],
            "earliestTurn": emergence["earliestTurn"],
            "city": emergence["city"],
            "x": emergence["x"],
            "y": emergence["y"],
            "coreRegion": actor["coreRegion"],
            "predecessors": emergence.get("predecessors", []),
        })

    return {
        "fixture": model["fixture"],
        "map": {
            "source": map_config["source"],
            "width": map_config["width"],
            "height": map_config["height"],
        },
        "initialActors": initial_actors,
        "emergenceActors": emergence_actors,
        "notes": model.get("timelineNotes", []),
    }


if __name__ == "__main__":
    raise SystemExit(main())
