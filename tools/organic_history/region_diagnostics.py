#!/usr/bin/env python3
"""Derive generated-map regional hegemony diagnostics from Freeciv saves."""

from __future__ import annotations

import argparse
import csv
import gzip
import json
from pathlib import Path
import re
from typing import Any, TextIO


PLAYER_RE = re.compile(r"^\[player(?P<id>\d+)\]$")
MAP_ROW_RE = re.compile(r'^t\d+="(?P<tiles>.*)"$')


def main() -> int:
    parser = argparse.ArgumentParser(description="Compute generated-map region diagnostics.")
    parser.add_argument("--run-dir", type=Path, default=None)
    parser.add_argument("--save", type=Path, default=None)
    parser.add_argument("--regions", type=Path, default=None,
                        help="Optional JSON region definitions with x/y boxes.")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    save_path = args.save or find_final_save(args.run_dir)
    if save_path is None:
        raise SystemExit("No save specified and no final save found.")
    metrics = region_metrics(save_path, args.regions)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(json.dumps(metrics["summary"], sort_keys=True))
    return 0


def find_final_save(run_dir: Path | None) -> Path | None:
    if run_dir is None:
        return None
    saves = sorted(run_dir.glob("*final.sav*"))
    return saves[-1] if saves else None


def region_metrics(save_path: Path, regions_path: Path | None = None) -> dict[str, Any]:
    cities, map_width, map_height = parse_save_cities(save_path)
    region_defs = load_region_defs(regions_path)
    regions: dict[str, dict[str, Any]] = {
        region_id: {"name": definition.get("name", region_id), "totalCities": 0, "players": {}}
        for region_id, definition in region_defs.items()
    }
    for city in cities:
        region = classify_region(city["x"], city["y"], map_width, map_height, region_defs)
        entry = regions.setdefault(region, {"totalCities": 0, "players": {}})
        entry["totalCities"] += 1
        player_id = str(city["playerId"])
        entry["players"][player_id] = entry["players"].get(player_id, 0) + 1

    for region, entry in regions.items():
        leader, count = leader_for(entry["players"])
        leader_share = count / entry["totalCities"] if entry["totalCities"] else 0
        entry["leader"] = int(leader) if leader is not None else None
        entry["leaderShare"] = round(leader_share, 3)
        if entry["totalCities"] == 0:
            entry["classification"] = "empty"
        else:
            entry["classification"] = ("hegemon" if leader_share >= 0.67
                                      else "contested")

    total_regions = len(regions)
    hegemon_regions = sum(1 for entry in regions.values()
                          if entry["classification"] == "hegemon")
    contested_regions = sum(1 for entry in regions.values()
                            if entry["classification"] == "contested")
    empty_regions = sum(1 for entry in regions.values()
                        if entry["classification"] == "empty")
    return {
        "save": str(save_path),
        "regionDefinitions": str(regions_path) if regions_path else "generated_grid_3x3",
        "map": {"width": map_width, "height": map_height},
        "cities": cities,
        "regions": regions,
        "summary": {
            "totalCities": len(cities),
            "nonEmptyRegions": total_regions - empty_regions,
            "emptyRegions": empty_regions,
            "hegemonRegions": hegemon_regions,
            "contestedRegions": contested_regions,
        },
    }


def parse_save_cities(save_path: Path) -> tuple[list[dict[str, Any]], int, int]:
    cities = []
    map_rows: list[str] = []
    current_player = None
    in_city_table = False
    city_header: list[str] = []
    with open_save(save_path) as save:
        for raw_line in save:
            line = raw_line.strip()
            player_match = PLAYER_RE.match(line)
            if player_match:
                current_player = int(player_match.group("id"))
                in_city_table = False
                city_header = []
                continue
            map_match = MAP_ROW_RE.match(line)
            if map_match:
                map_rows.append(map_match.group("tiles"))
            if current_player is None:
                continue
            if line.startswith("c={"):
                city_header = parse_csv_line(line.split("{", 1)[1])
                in_city_table = True
                continue
            if in_city_table:
                if line == "}":
                    in_city_table = False
                    city_header = []
                    continue
                row = parse_csv_line(line)
                if len(row) == len(city_header):
                    city = dict(zip(city_header, row))
                    cities.append({
                        "playerId": current_player,
                        "id": to_int(city.get("id")),
                        "name": city.get("name", ""),
                        "x": to_int(city.get("x")),
                        "y": to_int(city.get("y")),
                        "size": to_int(city.get("size")),
                    })
    map_height = len(map_rows)
    map_width = max((len(row) for row in map_rows), default=1)
    return cities, map_width, map_height


def parse_csv_line(line: str) -> list[str]:
    return next(csv.reader([line]))


def classify_region(
    x: int,
    y: int,
    width: int,
    height: int,
    region_defs: dict[str, dict[str, Any]] | None = None,
) -> str:
    if region_defs:
        for region_id, region in region_defs.items():
            if (x >= to_int(region.get("x_min")) and x <= to_int(region.get("x_max"))
                    and y >= to_int(region.get("y_min")) and y <= to_int(region.get("y_max"))):
                return region_id
        return "unknown"
    col = min(2, max(0, int((x / max(1, width)) * 3)))
    row = min(2, max(0, int((y / max(1, height)) * 3)))
    return f"r{row}c{col}"


def load_region_defs(path: Path | None) -> dict[str, dict[str, Any]]:
    if path is None:
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    regions = data.get("regions", {})
    if not isinstance(regions, dict):
        raise SystemExit(f"Invalid regions JSON: {path}")
    return {str(key): value for key, value in regions.items()
            if isinstance(value, dict)}


def leader_for(players: dict[str, int]) -> tuple[str | None, int]:
    if not players:
        return None, 0
    return max(players.items(), key=lambda item: item[1])


def open_save(path: Path) -> TextIO:
    if path.suffix == ".gz":
        return gzip.open(path, "rt", encoding="utf-8", errors="replace")
    return path.open(encoding="utf-8", errors="replace")


def to_int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
