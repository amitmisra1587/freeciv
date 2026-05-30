#!/usr/bin/env python3
"""Summarize per-civilization outcomes from organic-history campaigns."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import re
from typing import Any, Iterable


DYNASTIC_RE = re.compile(r"\borganic_history_dynastic_probe\b.*\bplayer=(?P<player>-?\d+).*?\baction=\"?(?P<action>[A-Za-z0-9_]+)\"?")
MECHANIC_RE = re.compile(r"\borganic_history_mechanic\b.*\btype=(?P<type>[A-Za-z0-9_]+).*?\bplayer=(?P<player>-?\d+)")
SECESSION_RE = re.compile(r"\borganic_history_secession\b.*\btype=(?P<type>[A-Za-z0-9_]+).*?\bplayer=(?P<player>-?\d+)")
CITY_PRESSURE_RE = re.compile(r"\borganic_history_city_pressure\b.*\bplayer=(?P<player>-?\d+).*?\bunrest=(?P<unrest>-?\d+(?:\.\d+)?).*?\bautonomy=(?P<autonomy>-?\d+(?:\.\d+)?)")
MANDATE_RE = re.compile(r"\borganic_history_mandate\b.*\bplayer=(?P<player>-?\d+).*?\bmandate=(?P<mandate>-?\d+(?:\.\d+)?).*?\bstress_reduction=(?P<reduction>-?\d+)")
SECESSION_DETAIL_FIELDS = [
    "turn",
    "player",
    "successor",
    "successor_name",
    "successor_nation",
    "parent_actor",
    "core_region",
    "city",
    "city_region",
    "city_core",
    "peripheral",
    "transferred",
]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Summarize per-civilization outcomes from campaign artifacts.")
    parser.add_argument("--campaign", action="append", type=Path, required=True,
                        help="Campaign directory containing seed_*/run_summary.json.")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--csv-output", type=Path, required=True)
    parser.add_argument("--focus-civ", default=None,
                        help="Optional civilization/player name to check against thresholds.")
    parser.add_argument("--min-mean-final-cities", type=float, default=None)
    parser.add_argument("--min-any-max-cities", type=float, default=None)
    parser.add_argument("--min-total-checks", type=int, default=None)
    args = parser.parse_args()

    report = build_report(args.campaign, args)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    write_csv(args.csv_output, report)
    print(json.dumps(report["summary"], sort_keys=True))
    focus = report.get("focusCheck")
    return 1 if focus and not focus["passed"] else 0


def build_report(campaign_dirs: list[Path], args: argparse.Namespace) -> dict[str, Any]:
    campaigns = [summarize_campaign(campaign_dir) for campaign_dir in campaign_dirs]
    report = {
        "campaigns": campaigns,
        "summary": {
            "campaigns": len(campaigns),
            "civilizations": sum(len(campaign["civilizations"]) for campaign in campaigns),
            "runs": sum(campaign["runs"] for campaign in campaigns),
            "safeCampaigns": sum(1 for campaign in campaigns if campaign["runsFailed"] == 0),
        },
    }
    if args.focus_civ:
        report["focusCheck"] = focus_check(report, args)
    return report


def summarize_campaign(campaign_dir: Path) -> dict[str, Any]:
    campaign_summary = read_json(campaign_dir / "campaign_summary.json")
    records_by_civ: dict[str, list[dict[str, Any]]] = {}
    for run_summary_path in sorted(campaign_dir.glob("seed_*/run_summary.json")):
        run_summary = read_json(run_summary_path)
        run_dir = run_summary_path.parent
        log_metrics = parse_player_logs(run_dir)
        for record in run_player_records(run_summary, log_metrics):
            records_by_civ.setdefault(record["civilization"], []).append(record)

    civilizations = [
        summarize_civilization(civilization, records)
        for civilization, records in sorted(records_by_civ.items())
    ]
    return {
        "campaign": str(campaign_dir),
        "label": campaign_summary.get("label"),
        "scenario": campaign_summary.get("scenario"),
        "turns": campaign_summary.get("turns"),
        "runs": campaign_summary.get("runsRequested", len(list(campaign_dir.glob("seed_*")))),
        "runsSucceeded": campaign_summary.get("runsSucceeded", 0),
        "runsFailed": campaign_summary.get("runsFailed", 0),
        "aggregate": campaign_summary.get("aggregate", {}),
        "civilizations": civilizations,
    }


def run_player_records(
    run_summary: dict[str, Any],
    log_metrics: dict[int, dict[str, Any]],
) -> Iterable[dict[str, Any]]:
    per_turn = run_summary.get("perTurn", [])
    by_player: dict[int, list[dict[str, Any]]] = {}
    for row in per_turn:
        player_id = row.get("playerId")
        if isinstance(player_id, int):
            by_player.setdefault(player_id, []).append(row)

    final_total_cities = num(run_summary.get("finalTotalCities"))
    for player_id, rows in sorted(by_player.items()):
        rows = sorted(rows, key=lambda row: num(row.get("turn")))
        first = rows[0]
        final = rows[-1]
        cities = [num(row.get("cities")) for row in rows]
        score = [num(row.get("score")) for row in rows]
        techs = [num(row.get("techs")) for row in rows]
        logs = log_metrics.get(player_id, {})
        final_cities = cities[-1] if cities else 0
        record = {
            "run": run_summary.get("runDir"),
            "seed": run_summary.get("seed"),
            "playerId": player_id,
            "civilization": str(final.get("playerName") or first.get("playerName") or f"player_{player_id}"),
            "firstCities": cities[0] if cities else 0,
            "finalCities": final_cities,
            "maxCities": max(cities) if cities else 0,
            "cityDelta": final_cities - (cities[0] if cities else 0),
            "finalScore": score[-1] if score else 0,
            "maxScore": max(score) if score else 0,
            "finalTechs": techs[-1] if techs else 0,
            "finalCityShare": share(final_cities, final_total_cities),
            "survived": final_cities > 0,
            "dynasticChecks": int(logs.get("dynasticActions", {}).get("check", 0)),
            "dynasticTriggers": int(logs.get("mechanics", {}).get("civil_war_triggered", 0)),
            "secessionTriggers": int(logs.get("secession", {}).get("secession_triggered", 0)),
            "dynasticNoops": int(logs.get("mechanics", {}).get("civil_war_noop", 0)),
            "meanUnrest": mean(logs.get("unrest", [])),
            "meanAutonomy": mean(logs.get("autonomy", [])),
            "meanMandate": mean(logs.get("mandate", [])),
            "meanMandateReduction": mean(logs.get("mandateReduction", [])),
            "secessionEvents": logs.get("secessionEvents", []),
            "successorNames": unique_values(
                event.get("successor_name") for event in logs.get("secessionEvents", [])
            ),
            "transferredCities": unique_values(
                event.get("city") for event in logs.get("secessionEvents", [])
            ),
        }
        record["classification"] = classify_record(record)
        yield record


def parse_player_logs(run_dir: Path) -> dict[int, dict[str, Any]]:
    metrics: dict[int, dict[str, Any]] = {}
    for log_path in sorted(run_dir.glob("server_*.log")):
        for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
            dynastic_match = DYNASTIC_RE.search(line)
            if dynastic_match:
                entry = player_entry(metrics, dynastic_match.group("player"))
                action = dynastic_match.group("action")
                actions = entry.setdefault("dynasticActions", {})
                actions[action] = actions.get(action, 0) + 1
            mechanic_match = MECHANIC_RE.search(line)
            if mechanic_match:
                entry = player_entry(metrics, mechanic_match.group("player"))
                mechanic_type = mechanic_match.group("type")
                mechanics = entry.setdefault("mechanics", {})
                mechanics[mechanic_type] = mechanics.get(mechanic_type, 0) + 1
            secession_match = SECESSION_RE.search(line)
            if secession_match:
                entry = player_entry(metrics, secession_match.group("player"))
                secession_type = secession_match.group("type")
                secessions = entry.setdefault("secession", {})
                secessions[secession_type] = secessions.get(secession_type, 0) + 1
                if secession_type == "secession_triggered":
                    entry.setdefault("secessionEvents", []).append(
                        parse_line_fields(line, SECESSION_DETAIL_FIELDS))
            pressure_match = CITY_PRESSURE_RE.search(line)
            if pressure_match:
                entry = player_entry(metrics, pressure_match.group("player"))
                entry.setdefault("unrest", []).append(float(pressure_match.group("unrest")))
                entry.setdefault("autonomy", []).append(float(pressure_match.group("autonomy")))
            mandate_match = MANDATE_RE.search(line)
            if mandate_match:
                entry = player_entry(metrics, mandate_match.group("player"))
                entry.setdefault("mandate", []).append(float(mandate_match.group("mandate")))
                entry.setdefault("mandateReduction", []).append(float(mandate_match.group("reduction")))
    return metrics


def player_entry(metrics: dict[int, dict[str, Any]], player_text: str) -> dict[str, Any]:
    player_id = int(player_text)
    return metrics.setdefault(player_id, {})


def summarize_civilization(civilization: str, records: list[dict[str, Any]]) -> dict[str, Any]:
    classifications = count_values(record["classification"] for record in records)
    secession_events = [
        event for record in records for event in record.get("secessionEvents", [])
    ]
    summary = {
        "civilization": civilization,
        "runs": len(records),
        "survivalRate": round(mean([1 if record["survived"] else 0 for record in records]), 3),
        "meanFinalCities": round(mean([record["finalCities"] for record in records]), 3),
        "meanMaxCities": round(mean([record["maxCities"] for record in records]), 3),
        "meanCityDelta": round(mean([record["cityDelta"] for record in records]), 3),
        "meanFinalCityShare": round(mean([record["finalCityShare"] for record in records]), 3),
        "meanFinalScore": round(mean([record["finalScore"] for record in records]), 3),
        "meanFinalTechs": round(mean([record["finalTechs"] for record in records]), 3),
        "dynasticChecks": int(sum(record["dynasticChecks"] for record in records)),
        "dynasticTriggers": int(sum(record["dynasticTriggers"] for record in records)),
        "secessionTriggers": int(sum(record["secessionTriggers"] for record in records)),
        "dynasticNoops": int(sum(record["dynasticNoops"] for record in records)),
        "meanUnrest": round(mean([record["meanUnrest"] for record in records]), 3),
        "meanAutonomy": round(mean([record["meanAutonomy"] for record in records]), 3),
        "meanMandate": round(mean([record["meanMandate"] for record in records]), 3),
        "meanMandateReduction": round(mean([record["meanMandateReduction"] for record in records]), 3),
        "classifications": classifications,
        "successorNames": unique_values(
            event.get("successor_name") for event in secession_events
        ),
        "transferredCities": unique_values(
            event.get("city") for event in secession_events
        ),
        "secessionLineages": secession_events,
    }
    summary["dominantClassification"] = max(
        classifications.items(), key=lambda item: item[1]
    )[0] if classifications else "unknown"
    summary["records"] = records
    return summary


def classify_record(record: dict[str, Any]) -> str:
    if not record["survived"] or record["finalCities"] <= 0:
        return "collapsed_extinct"
    if record["finalCityShare"] >= 0.4 and record["meanMandate"] >= 0.25:
        return "stable_regional_hegemon"
    if record["cityDelta"] >= 5:
        return "expansionist_survivor"
    if record["dynasticChecks"] > 0 or record["meanUnrest"] >= 0.35:
        return "unstable_survivor"
    if record["finalCities"] <= 2:
        return "stagnant_minor"
    return "survivor"


def write_csv(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "campaign", "scenario", "civilization", "runs", "survivalRate",
        "meanFinalCities", "meanCityDelta", "meanFinalCityShare",
        "meanFinalScore", "meanFinalTechs", "dynasticChecks",
        "dynasticTriggers", "secessionTriggers", "meanUnrest", "meanMandate",
        "successorNames", "transferredCities", "dominantClassification",
    ]
    with path.open("w", encoding="utf-8", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fields)
        writer.writeheader()
        for campaign in report["campaigns"]:
            for civ in campaign["civilizations"]:
                writer.writerow({
                    "campaign": campaign["campaign"],
                    "scenario": campaign.get("scenario"),
                    "civilization": civ["civilization"],
                    "runs": civ["runs"],
                    "survivalRate": civ["survivalRate"],
                    "meanFinalCities": civ["meanFinalCities"],
                    "meanCityDelta": civ["meanCityDelta"],
                    "meanFinalCityShare": civ["meanFinalCityShare"],
                    "meanFinalScore": civ["meanFinalScore"],
                    "meanFinalTechs": civ["meanFinalTechs"],
                    "dynasticChecks": civ["dynasticChecks"],
                    "dynasticTriggers": civ["dynasticTriggers"],
                    "secessionTriggers": civ["secessionTriggers"],
                    "meanUnrest": civ["meanUnrest"],
                    "meanMandate": civ["meanMandate"],
                    "successorNames": ";".join(civ["successorNames"]),
                    "transferredCities": ";".join(civ["transferredCities"]),
                    "dominantClassification": civ["dominantClassification"],
                })


def count_values(values: Iterable[str]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for value in values:
        counts[value] = counts.get(value, 0) + 1
    return dict(sorted(counts.items()))


def unique_values(values: Iterable[Any]) -> list[str]:
    return sorted({str(value) for value in values if value not in (None, "")})


def focus_check(report: dict[str, Any], args: argparse.Namespace) -> dict[str, Any]:
    matches = [
        civilization
        for campaign in report["campaigns"]
        for civilization in campaign["civilizations"]
        if civilization["civilization"] == args.focus_civ
    ]
    failures = []
    if not matches:
        failures.append(f"civilization {args.focus_civ!r} not found")
        return {
            "civilization": args.focus_civ,
            "passed": False,
            "failures": failures,
            "matches": [],
        }

    if args.min_mean_final_cities is not None:
        if not any(match["meanFinalCities"] >= args.min_mean_final_cities
                   for match in matches):
            failures.append(f"meanFinalCities below {args.min_mean_final_cities}")
    if args.min_any_max_cities is not None:
        max_cities = max(record["maxCities"]
                         for match in matches
                         for record in match["records"])
        if max_cities < args.min_any_max_cities:
            failures.append(f"maxCities below {args.min_any_max_cities}")
    if args.min_total_checks is not None:
        total_checks = sum(match["dynasticChecks"] for match in matches)
        if total_checks < args.min_total_checks:
            failures.append(f"dynasticChecks below {args.min_total_checks}")

    return {
        "civilization": args.focus_civ,
        "passed": not failures,
        "failures": failures,
        "matches": matches,
    }


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def num(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0


def share(value: float, total: float) -> float:
    return value / total if total else 0.0


def mean(values: Iterable[float]) -> float:
    values = list(values)
    return sum(values) / len(values) if values else 0.0


def parse_line_fields(line: str, fields: list[str]) -> dict[str, Any]:
    return {
        field: parse_scalar(match.group(1))
        for field in fields
        if (match := re.search(rf'\b{re.escape(field)}=("(?:[^"\\]|\\.)*"|\S+)', line))
    }


def parse_scalar(text: str) -> Any:
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"':
        return text[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    if text in ("true", "false"):
        return text == "true"
    try:
        return int(text)
    except ValueError:
        try:
            value = float(text)
        except ValueError:
            return text
        return int(value) if value.is_integer() else value


if __name__ == "__main__":
    raise SystemExit(main())
