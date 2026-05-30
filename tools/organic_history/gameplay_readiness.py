#!/usr/bin/env python3
"""Summarize organic-history command-gated gameplay readiness."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Summarize readiness of organic-history gameplay profiles.")
    parser.add_argument("--comparison", action="append", type=Path,
                        default=[], help="Comparison summary JSON path.")
    parser.add_argument("--continuation", type=Path, default=None,
                        help="Continuation summary JSON path.")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    report = build_report(args.comparison, args.continuation)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(json.dumps(report, sort_keys=True))
    return 0 if report["commandGatedReady"] else 1


def build_report(comparison_paths: list[Path], continuation_path: Path | None) -> dict[str, Any]:
    comparisons = [summarize_comparison(path) for path in comparison_paths]
    continuation = summarize_continuation(continuation_path)
    blockers = []
    warnings = []

    if not comparisons:
        blockers.append("no comparison summaries supplied")
    for comparison in comparisons:
        if not comparison["safeToIterate"]:
            blockers.append(f"{comparison['name']}: comparison is not safe to iterate")
        if comparison["candidateWorseThanBaseline"]:
            blockers.append(f"{comparison['name']}: candidate worse than baseline")
        verdict = comparison["dynasticStressVerdict"]
        if verdict in ("unsafe", "needs_tuning"):
            blockers.append(f"{comparison['name']}: dynastic verdict {verdict}")
        if verdict in ("inert_stable_control", "not_run"):
            warnings.append(f"{comparison['name']}: dynastic verdict {verdict}")

    default_blockers = list(blockers)
    if not continuation["success"]:
        default_blockers.append("continuation/save-load is not successful")

    return {
        "comparisons": comparisons,
        "continuation": continuation,
        "commandGatedReady": not blockers,
        "defaultOnReady": not default_blockers,
        "blockers": blockers,
        "warnings": warnings,
        "defaultOnBlockers": default_blockers,
        "recommendation": recommendation(blockers, default_blockers),
    }


def summarize_comparison(path: Path) -> dict[str, Any]:
    data = read_json(path)
    dynastic = data.get("dynasticStressVerdict", {})
    rates = data.get("rates", {})
    deltas = data.get("deltas", {})
    return {
        "name": path.stem,
        "path": str(path),
        "baseline": data.get("baseline"),
        "candidate": data.get("candidate"),
        "safeToIterate": bool(data.get("safeToIterate")),
        "candidateWorseThanBaseline": bool(data.get("candidateWorseThanBaseline")),
        "candidatePromising": bool(data.get("candidatePromising")),
        "dynasticStressVerdict": dynastic.get("verdict", "unknown"),
        "dynasticReason": dynastic.get("reason"),
        "checks": num(dynastic.get("checks")),
        "triggered": num(dynastic.get("triggered")),
        "triggerRate": num(dynastic.get("triggerRate")),
        "checkRate": num(rates.get("civilWarCheckRate")),
        "checksPer1000MechanicLogs": num(rates.get("civilWarChecksPer1000MechanicLogs")),
        "meanDynasticBonus": num(data.get("candidateMeanDynasticBonus")),
        "meanInstitutionStressModifier": num(data.get("candidateMeanInstitutionStressModifier")),
        "failureDelta": num(deltas.get("failures")),
        "meanFinalCityDelta": num(deltas.get("meanFinalCities")),
        "meanMaxCityShareDelta": num(deltas.get("meanMaxCityShare")),
        "scenarioComparison": bool(data.get("comparisonContext", {}).get("scenarioComparison")),
    }


def summarize_continuation(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {
            "path": None,
            "success": False,
            "blocker": "no continuation summary supplied",
        }
    data = read_json(path)
    if "results" in data:
        return summarize_historical_continuation(path, data)
    continued = data.get("continued", {})
    return {
        "path": str(path),
        "success": bool(data.get("success")),
        "continuedReturncode": continued.get("runReturncode"),
        "continuedFinalTurn": continued.get("finalTurn"),
        "loadSource": data.get("loadSource"),
        "notes": data.get("notes", []),
        "blocker": None if data.get("success") else "continuation/save-load failed",
    }


def summarize_historical_continuation(path: Path, data: dict[str, Any]) -> dict[str, Any]:
    results = data.get("results", [])
    failed = [
        result for result in results
        if isinstance(result, dict) and not result.get("success")
    ]
    scenarios = sorted({
        str(result.get("scenario"))
        for result in results
        if isinstance(result, dict) and result.get("scenario")
    })
    modes = sorted({
        str(result.get("mode"))
        for result in results
        if isinstance(result, dict) and result.get("mode")
    })
    resumed_lineage = next(
        (result for result in results
         if isinstance(result, dict) and result.get("mode") == "resumed_lineage"),
        {},
    )
    return {
        "path": str(path),
        "success": bool(data.get("success")) and not failed,
        "kind": "historical_scenarios",
        "scenarioCount": len([scenario for scenario in scenarios if scenario != "None"]),
        "modes": modes,
        "failedResults": len(failed),
        "resumedLineageSuccess": bool(resumed_lineage.get("success")),
        "resumedLineageChecks": resumed_lineage.get("checks", {}),
        "blocker": None if data.get("success") and not failed else "historical continuation gate failed",
    }


def recommendation(blockers: list[str], default_blockers: list[str]) -> str:
    if blockers:
        return "Do not iterate gameplay further until command-gated blockers are resolved."
    if default_blockers:
        return "Command-gated gameplay is ready for further iteration; keep mechanics default-off."
    return "Candidate is ready to evaluate for default-on gameplay."


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def num(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0


if __name__ == "__main__":
    raise SystemExit(main())
