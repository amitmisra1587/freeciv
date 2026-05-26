#!/usr/bin/env python3
"""Extract lightweight metrics from Freeciv savegames."""

from __future__ import annotations

import argparse
import gzip
import json
from pathlib import Path
import re
from typing import Any, TextIO


PLAYER_RE = re.compile(r"^player(\d+)$")
SCORE_RE = re.compile(r"^score(\d+)$")


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse lightweight Freeciv savegame metrics.")
    parser.add_argument("savegame", type=Path)
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    metrics = parse_savegame(args.savegame)
    text = json.dumps(metrics, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0


def parse_savegame(path: Path) -> dict[str, Any]:
    sections = read_sections(path)
    players = build_players(sections)
    return {
        "rulesetdir": sections.get("savefile", {}).get("rulesetdir"),
        "turn": sections.get("game", {}).get("turn"),
        "year": sections.get("game", {}).get("year"),
        "players": players,
        "summary": {
            "alivePlayers": sum(1 for player in players if player.get("isAlive")),
            "totalCities": sum_int(player.get("cities") for player in players),
            "totalUnits": sum_int(player.get("units") for player in players),
        },
    }


def read_sections(path: Path) -> dict[str, dict[str, Any]]:
    sections: dict[str, dict[str, Any]] = {}
    current_section: str | None = None
    with open_savegame(path) as savegame:
        for raw_line in savegame:
            line = raw_line.strip()
            if not line or line.startswith(";") or line.startswith("#"):
                continue
            if line.startswith("[") and line.endswith("]"):
                current_section = line[1:-1]
                sections.setdefault(current_section, {})
                continue
            if current_section is None or "=" not in line:
                continue
            key, value = line.split("=", 1)
            sections[current_section][key] = parse_value(value)
    return sections


def open_savegame(path: Path) -> TextIO:
    if path.suffix == ".gz":
        return gzip.open(path, "rt", encoding="utf-8", errors="replace")
    return path.open(encoding="utf-8", errors="replace")


def parse_value(value: str) -> Any:
    value = value.strip()
    if value == "TRUE":
        return True
    if value == "FALSE":
        return False
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1].replace('\\"', '"')
    try:
        return int(value)
    except ValueError:
        try:
            return float(value)
        except ValueError:
            return value


def build_players(sections: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    players = []
    for section_name in sorted(sections, key=section_sort_key):
        player_match = PLAYER_RE.match(section_name)
        if not player_match:
            continue
        player_id = int(player_match.group(1))
        player_section = sections[section_name]
        score_section = sections.get(f"score{player_id}", {})
        players.append({
            "id": player_id,
            "name": player_section.get("name"),
            "nation": player_section.get("nation"),
            "isAlive": player_section.get("is_alive"),
            "government": player_section.get("government_name"),
            "cities": player_section.get("ncities", 0),
            "units": player_section.get("nunits", 0),
            "score": score_section,
        })
    return players


def section_sort_key(section_name: str) -> tuple[str, int]:
    for regex in (PLAYER_RE, SCORE_RE):
        match = regex.match(section_name)
        if match:
            return (regex.pattern, int(match.group(1)))
    return (section_name, -1)


def sum_int(values: list[Any]) -> int:
    return sum(value for value in values if isinstance(value, int))


if __name__ == "__main__":
    raise SystemExit(main())
