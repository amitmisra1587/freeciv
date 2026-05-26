#!/usr/bin/env python3
"""Parse Freeciv SCORELOG2 files into JSON metrics."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


EXPECTED_TAGS = {
    "cities",
    "pop",
    "score",
    "techs",
    "gov",
    "culture",
    "unitsbuilt",
    "unitslost",
    "unitskilled",
    "landarea",
    "settledarea",
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse a Freeciv SCORELOG2 file.")
    parser.add_argument("scorelog", type=Path)
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    metrics = parse_scorelog(args.scorelog)
    text = json.dumps(metrics, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0


def parse_scorelog(path: Path) -> dict[str, Any]:
    tags: dict[int, str] = {}
    turns: dict[int, dict[str, Any]] = {}
    players: dict[int, dict[str, Any]] = {}
    data: dict[int, dict[int, dict[str, int | float | str]]] = {}
    game_id = None
    parse_warnings: list[str] = []

    with path.open(encoding="utf-8") as scorelog:
        for line_number, raw_line in enumerate(scorelog, start=1):
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            command, _, rest = line.partition(" ")
            try:
                if command == "id":
                    game_id = rest
                elif command == "tag":
                    tag_id_text, descr = rest.split(" ", 1)
                    tags[int(tag_id_text)] = descr
                elif command == "turn":
                    turn_text, year_text, label = rest.split(" ", 2)
                    turn = int(turn_text)
                    turns[turn] = {
                        "turn": turn,
                        "year": parse_number(year_text),
                        "label": label,
                    }
                elif command == "addplayer":
                    turn_text, player_id_text, name = rest.split(" ", 2)
                    player_id = int(player_id_text)
                    player = players.setdefault(player_id, {"id": player_id})
                    player["name"] = name
                    player.setdefault("firstTurn", int(turn_text))
                elif command == "delplayer":
                    turn_text, player_id_text = rest.split(" ", 1)
                    player_id = int(player_id_text)
                    player = players.setdefault(player_id, {"id": player_id})
                    player["lastTurn"] = int(turn_text)
                elif command == "data":
                    turn_text, tag_id_text, player_id_text, value_text = rest.split(" ", 3)
                    turn = int(turn_text)
                    tag_id = int(tag_id_text)
                    player_id = int(player_id_text)
                    tag = tags.get(tag_id, f"tag_{tag_id}")
                    value = parse_number(value_text)
                    data.setdefault(turn, {}).setdefault(player_id, {})[tag] = value
                else:
                    parse_warnings.append(f"{line_number}: unknown command {command}")
            except ValueError as exc:
                parse_warnings.append(f"{line_number}: failed to parse {command}: {exc}")

    final_turn = max(data.keys() | turns.keys()) if data or turns else None
    per_turn = build_per_turn(turns, players, data)
    final_players = build_final_players(final_turn, players, data)
    summary = build_summary(final_turn, players, data, tags, parse_warnings)

    return {
        "gameId": game_id,
        "tags": {str(tag_id): tag for tag_id, tag in sorted(tags.items())},
        "turns": [turns[turn] for turn in sorted(turns)],
        "players": {str(player_id): players[player_id]
                    for player_id in sorted(players)},
        "perTurn": per_turn,
        "finalTurn": final_turn,
        "finalPlayers": final_players,
        "summary": summary,
        "parseWarnings": parse_warnings,
    }


def parse_number(value: str) -> int | float | str:
    try:
        return int(value)
    except ValueError:
        try:
            return float(value)
        except ValueError:
            return value


def build_per_turn(
    turns: dict[int, dict[str, Any]],
    players: dict[int, dict[str, Any]],
    data: dict[int, dict[int, dict[str, int | float | str]]],
) -> list[dict[str, Any]]:
    rows = []
    for turn in sorted(data):
        turn_info = turns.get(turn, {"turn": turn})
        for player_id in sorted(data[turn]):
            player_metrics = data[turn][player_id]
            row = {
                "turn": turn,
                "year": turn_info.get("year"),
                "label": turn_info.get("label"),
                "playerId": player_id,
                "playerName": players.get(player_id, {}).get("name"),
            }
            row.update(player_metrics)
            rows.append(row)
    return rows


def build_final_players(
    final_turn: int | None,
    players: dict[int, dict[str, Any]],
    data: dict[int, dict[int, dict[str, int | float | str]]],
) -> dict[str, dict[str, Any]]:
    if final_turn is None:
        return {}
    final_data = data.get(final_turn, {})
    result = {}
    for player_id in sorted(final_data):
        player = dict(players.get(player_id, {"id": player_id}))
        player.update(final_data[player_id])
        result[str(player_id)] = player
    return result


def build_summary(
    final_turn: int | None,
    players: dict[int, dict[str, Any]],
    data: dict[int, dict[int, dict[str, int | float | str]]],
    tags: dict[int, str],
    parse_warnings: list[str],
) -> dict[str, Any]:
    if final_turn is None or not data:
        return {
            "aliveScorelogPlayers": 0,
            "finalTotalCities": 0,
            "parseWarning": True,
        }

    first_turn = min(data)
    final_data = data.get(final_turn, {})
    first_data = data.get(first_turn, {})
    final_cities = numeric_values(final_data, "cities")
    first_cities = numeric_values(first_data, "cities")
    final_scores = numeric_values(final_data, "score")
    final_techs = numeric_values(final_data, "techs")
    final_total_cities = sum(final_cities)
    first_total_cities = sum(first_cities)
    deleted_players = [player_id for player_id, player in players.items()
                       if player.get("lastTurn") is not None]
    missing_tags = sorted(EXPECTED_TAGS - set(tags.values()))
    max_city_share = share(max(final_cities) if final_cities else 0,
                           final_total_cities)
    max_score_share = share(max(final_scores) if final_scores else 0,
                            sum(final_scores))

    summary = {
        "aliveScorelogPlayers": len(final_data),
        "firstTurn": first_turn,
        "finalTurn": final_turn,
        "finalTotalCities": final_total_cities,
        "firstTotalCities": first_total_cities,
        "maxCityShare": round(max_city_share, 3),
        "maxScoreShare": round(max_score_share, 3),
        "cityCountDelta": final_total_cities - first_total_cities,
        "scoreSpread": spread(final_scores),
        "techSpread": spread(final_techs),
        "deletedPlayers": deleted_players,
        "missingExpectedTags": missing_tags,
        "dominationWarning": max_city_share >= 0.75 or max_score_share >= 0.75,
        "stagnationWarning": final_total_cities <= first_total_cities,
        "extinctionWarning": bool(deleted_players),
        "parseWarning": bool(parse_warnings or missing_tags),
    }
    return summary


def numeric_values(
    turn_data: dict[int, dict[str, int | float | str]],
    tag: str,
) -> list[float]:
    values = []
    for metrics in turn_data.values():
        value = metrics.get(tag)
        if isinstance(value, (int, float)):
            values.append(float(value))
    return values


def share(value: float, total: float) -> float:
    return value / total if total else 0.0


def spread(values: list[float]) -> float:
    return max(values) - min(values) if values else 0


if __name__ == "__main__":
    raise SystemExit(main())
