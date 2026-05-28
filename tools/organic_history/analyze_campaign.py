#!/usr/bin/env python3
"""Combine organic-history run artifacts into per-run summaries."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import re
from typing import Any

from parse_savegame import parse_savegame
from parse_scorelog import parse_scorelog


STRESS_RE = re.compile(r"\borganic_history_stability\b.*\bstress=(?P<stress>-?\d+)")
RISK_RE = re.compile(r'\borganic_history_stability\b.*\brisk="?(?P<risk>[A-Za-z_]+)"?')
MECHANIC_RE = re.compile(r"\borganic_history_mechanic\b.*\btype=(?P<type>[A-Za-z0-9_]+)")
REASON_RE = re.compile(r'\breason="?(?P<reason>[A-Za-z0-9_]+)"?')
FLOAT_FIELD_RE = r'\b{field}=(-?\d+(?:\.\d+)?)'
CITY_PRESSURE_FIELDS = [
    "population_pressure",
    "food_pressure",
    "economic_pressure",
    "garrison_pressure",
    "development",
    "unrest",
    "autonomy",
    "climate_stress",
    "migration_pressure",
]
INSTITUTION_FIELDS = ["cohesion", "reform_pressure"]
EVENT_RISK_FIELDS = ["succession", "fiscal", "plague", "trade_disruption", "climate", "frontier"]


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze one organic-history run directory.")
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--csv-output", type=Path, default=None)
    args = parser.parse_args()

    run_dir = args.run_dir
    summary = analyze_run(run_dir)
    output = args.output or run_dir / "run_summary.json"
    csv_output = args.csv_output or run_dir / "run_metrics.csv"
    output.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n",
                      encoding="utf-8")
    write_run_metrics_csv(summary, csv_output)
    print(json.dumps(compact_summary(summary), sort_keys=True))
    return 0 if summary.get("success") else 1


def analyze_run(run_dir: Path) -> dict[str, Any]:
    metadata = read_json(run_dir / "run_metadata.json")
    scorelog_path = Path(metadata.get("scorelogPath") or run_dir / "score.log")
    score_metrics_path = run_dir / "score_metrics.json"
    if scorelog_path.exists():
        score_metrics = parse_scorelog(scorelog_path)
        score_metrics_path.write_text(json.dumps(score_metrics, indent=2, sort_keys=True) + "\n",
                                      encoding="utf-8")
    else:
        score_metrics = {"summary": {"parseWarning": True}, "perTurn": []}

    final_save = metadata.get("finalSave")
    final_save_path = Path(final_save) if final_save else find_final_save(run_dir)
    save_metrics_path = run_dir / "save_metrics.json"
    if final_save_path and final_save_path.exists():
        save_metrics = parse_savegame(final_save_path)
        save_metrics_path.write_text(json.dumps(save_metrics, indent=2, sort_keys=True) + "\n",
                                     encoding="utf-8")
    else:
        save_metrics = {"summary": {"parseWarning": True}}

    log_metrics = parse_log_metrics(run_dir)
    score_summary = score_metrics.get("summary", {})
    save_summary = save_metrics.get("summary", {})
    final_players = score_metrics.get("finalPlayers", {})
    success = bool(metadata.get("success")) and scorelog_path.exists()

    return {
        "runDir": str(run_dir),
        "success": success,
        "seed": metadata.get("seed"),
        "turnsRequested": metadata.get("turns"),
        "playersRequested": metadata.get("players"),
        "finalTurn": score_metrics.get("finalTurn") or metadata.get("finalTurnSeen"),
        "elapsedSeconds": metadata.get("elapsedSeconds"),
        "saveCount": metadata.get("saveCount"),
        "scorelogPath": str(scorelog_path),
        "scoreMetricsPath": str(score_metrics_path),
        "saveMetricsPath": str(save_metrics_path),
        "rulesetdir": save_metrics.get("rulesetdir"),
        "alivePlayers": score_summary.get("aliveScorelogPlayers"),
        "saveAlivePlayers": save_summary.get("alivePlayers"),
        "finalTotalCities": score_summary.get("finalTotalCities"),
        "saveTotalCities": save_summary.get("totalCities"),
        "maxCityShare": score_summary.get("maxCityShare"),
        "maxScoreShare": score_summary.get("maxScoreShare"),
        "cityCountDelta": score_summary.get("cityCountDelta"),
        "scoreSpread": score_summary.get("scoreSpread"),
        "techSpread": score_summary.get("techSpread"),
        "warnings": {
            "domination": score_summary.get("dominationWarning", False),
            "stagnation": score_summary.get("stagnationWarning", False),
            "extinction": score_summary.get("extinctionWarning", False),
            "parse": score_summary.get("parseWarning", False),
        },
        "logCounts": log_metrics["counts"],
        "organicStress": log_metrics["stress"],
        "cityPressure": log_metrics["cityPressure"],
        "institutions": log_metrics["institutions"],
        "eventRisks": log_metrics["eventRisks"],
        "mechanics": log_metrics["mechanics"],
        "finalPlayers": final_players,
        "perTurn": score_metrics.get("perTurn", []),
    }


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def find_final_save(run_dir: Path) -> Path | None:
    saves = sorted(run_dir.glob("*final.sav*"))
    return saves[-1] if saves else None


def parse_log_metrics(run_dir: Path) -> dict[str, Any]:
    counts = {
        "turnBegin": 0,
        "metric": 0,
        "stability": 0,
        "event": 0,
        "mechanic": 0,
        "region": 0,
        "prestige": 0,
        "cityPressure": 0,
        "institution": 0,
        "eventRisk": 0,
    }
    mechanics = {
        "civilWarChecks": 0,
        "civilWarEligibleChecks": 0,
        "civilWarTriggered": 0,
        "civilWarNoop": 0,
        "civilWarSkips": 0,
        "civilWarSkipReasons": {},
        "civilWarCooldowns": 0,
        "civilWarInert": False,
    }
    stress_values: list[int] = []
    high_risk = 0
    city_pressure_values: dict[str, list[float]] = {field: [] for field in CITY_PRESSURE_FIELDS}
    institution_values: dict[str, list[float]] = {field: [] for field in INSTITUTION_FIELDS}
    event_risk_values: dict[str, list[float]] = {field: [] for field in EVENT_RISK_FIELDS}
    for log_path in sorted(run_dir.glob("server_*.log")):
        for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
            if "organic_history turn_begin" in line:
                counts["turnBegin"] += 1
            if "organic_history_metric" in line:
                counts["metric"] += 1
            if "organic_history_event" in line:
                counts["event"] += 1
            if "organic_history_region" in line:
                counts["region"] += 1
            if "organic_history_prestige" in line:
                counts["prestige"] += 1
            if "organic_history_city_pressure" in line:
                counts["cityPressure"] += 1
                collect_float_fields(line, CITY_PRESSURE_FIELDS, city_pressure_values)
            if "organic_history_institution" in line:
                counts["institution"] += 1
                collect_float_fields(line, INSTITUTION_FIELDS, institution_values)
            if "organic_history_event_risk" in line:
                counts["eventRisk"] += 1
                collect_float_fields(line, EVENT_RISK_FIELDS, event_risk_values)
            if "organic_history_stability" in line:
                counts["stability"] += 1
                stress_match = STRESS_RE.search(line)
                if stress_match:
                    stress_values.append(int(stress_match.group("stress")))
                risk_match = RISK_RE.search(line)
                if risk_match and risk_match.group("risk").lower() == "high":
                    high_risk += 1
            if "organic_history_mechanic type=" in line:
                counts["mechanic"] += 1
                mechanic_match = MECHANIC_RE.search(line)
                if mechanic_match:
                    mechanic_type = mechanic_match.group("type")
                    if mechanic_type == "civil_war_check":
                        mechanics["civilWarChecks"] += 1
                        mechanics["civilWarEligibleChecks"] += 1
                    elif mechanic_type == "civil_war_triggered":
                        mechanics["civilWarTriggered"] += 1
                    elif mechanic_type == "civil_war_noop":
                        mechanics["civilWarNoop"] += 1
                    elif mechanic_type == "civil_war_skip":
                        mechanics["civilWarSkips"] += 1
                        reason_match = REASON_RE.search(line)
                        reason = reason_match.group("reason") if reason_match else "unknown"
                        skip_reasons = mechanics["civilWarSkipReasons"]
                        skip_reasons[reason] = skip_reasons.get(reason, 0) + 1
                    elif mechanic_type == "civil_war_cooldown":
                        mechanics["civilWarCooldowns"] += 1
    mechanics["civilWarInert"] = (counts["mechanic"] > 0
                                  and mechanics["civilWarChecks"] == 0
                                  and mechanics["civilWarTriggered"] == 0)
    mean_stress = (sum(stress_values) / len(stress_values)
                   if stress_values else 0.0)
    return {
        "counts": counts,
        "stress": {
            "count": len(stress_values),
            "mean": round(mean_stress, 3),
            "max": max(stress_values) if stress_values else 0,
            "highRiskTurns": high_risk,
        },
        "mechanics": mechanics,
        "cityPressure": summarize_float_fields(city_pressure_values),
        "institutions": summarize_float_fields(institution_values),
        "eventRisks": summarize_float_fields(event_risk_values),
    }


def write_run_metrics_csv(summary: dict[str, Any], csv_output: Path) -> None:
    rows = summary.get("perTurn", [])
    if not rows:
        csv_output.write_text("", encoding="utf-8")
        return
    fieldnames = sorted({key for row in rows for key in row})
    with csv_output.open("w", encoding="utf-8", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def compact_summary(summary: dict[str, Any]) -> dict[str, Any]:
    return {
        "runDir": summary.get("runDir"),
        "success": summary.get("success"),
        "seed": summary.get("seed"),
        "finalTurn": summary.get("finalTurn"),
        "finalTotalCities": summary.get("finalTotalCities"),
        "maxCityShare": summary.get("maxCityShare"),
        "logCounts": summary.get("logCounts"),
        "organicStress": summary.get("organicStress"),
        "cityPressure": summary.get("cityPressure"),
        "institutions": summary.get("institutions"),
        "eventRisks": summary.get("eventRisks"),
        "mechanics": summary.get("mechanics"),
    }


def collect_float_fields(
    line: str,
    fields: list[str],
    values: dict[str, list[float]],
) -> None:
    for field in fields:
        match = re.search(FLOAT_FIELD_RE.format(field=re.escape(field)), line)
        if match:
            values[field].append(float(match.group(1)))


def summarize_float_fields(values: dict[str, list[float]]) -> dict[str, Any]:
    return {
        field: {
            "count": len(field_values),
            "mean": round(mean(field_values), 3),
            "max": round(max(field_values), 3) if field_values else 0,
        }
        for field, field_values in values.items()
    }


def mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


if __name__ == "__main__":
    raise SystemExit(main())
