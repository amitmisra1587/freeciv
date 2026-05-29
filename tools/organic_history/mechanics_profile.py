#!/usr/bin/env python3
"""Create mechanics profiles from calibrated campaign thresholds."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from calibrate_thresholds import calibrate


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate an organic-history mechanics profile.")
    parser.add_argument("--campaign-dir", type=Path, required=True)
    parser.add_argument("--thresholds-output", type=Path, required=True)
    parser.add_argument("--profile-output", type=Path, required=True)
    parser.add_argument("--mode", choices=["safe", "probe", "dynastic", "mandate"], default="safe",
                        help="Profile style: safe keeps defaults; probe lowers thresholds; dynastic adds succession-risk gameplay; mandate adds regional stability.")
    args = parser.parse_args()

    thresholds = calibrate(args.campaign_dir)
    write_json(args.thresholds_output, thresholds)
    profile = build_profile(thresholds, args.thresholds_output, args.mode)
    write_json(args.profile_output, profile)
    print(json.dumps({
        "thresholds": str(args.thresholds_output),
        "profile": str(args.profile_output),
        "commands": len(profile["luaCommands"]),
    }, sort_keys=True))
    return 0


def build_profile(thresholds: dict[str, Any], thresholds_path: Path, mode: str) -> dict[str, Any]:
    source_recommended = thresholds.get("recommended", {})
    recommended = profile_recommendations(thresholds, source_recommended, mode)
    commands = [
        "lua cmd organic_history_mechanics_enabled = true",
        "lua cmd organic_history_civil_war_enabled = true",
        f"lua cmd organic_history_civil_war_stress_threshold = {int(recommended.get('civilWarStressThreshold', 45))}",
        f"lua cmd organic_history_civil_war_min_cities = {int(recommended.get('civilWarMinCities', 8))}",
        f"lua cmd organic_history_civil_war_probability = {int(recommended.get('civilWarProbability', 8))}",
        f"lua cmd organic_history_civil_war_cooldown = {int(recommended.get('civilWarCooldown', 40))}",
    ]
    if mode in ("dynastic", "mandate"):
        commands.extend([
            "lua cmd organic_history_dynastic_stress_enabled = true",
            f"lua cmd organic_history_dynastic_stress_max_bonus = {int(recommended.get('dynasticStressMaxBonus', 10))}",
            f"lua cmd organic_history_institution_stress_modifiers_enabled = {str(bool(recommended.get('institutionStressModifiersEnabled', False))).lower()}",
            f"lua cmd organic_history_institution_stress_max_modifier = {int(recommended.get('institutionStressMaxModifier', 4))}",
        ])
    if mode == "mandate":
        commands.extend([
            "lua cmd organic_history_mandate_enabled = true",
            f"lua cmd organic_history_mandate_max_stress_reduction = {int(recommended.get('mandateMaxStressReduction', 4))}",
        ])
    return {
        "name": profile_name(mode),
        "mode": mode,
        "sourceThresholds": str(thresholds_path),
        "sourceRecommended": source_recommended,
        "recommended": recommended,
        "rationale": profile_rationale(thresholds, source_recommended, recommended, mode),
        "luaCommands": commands,
    }


def profile_recommendations(
    thresholds: dict[str, Any],
    source_recommended: dict[str, Any],
    mode: str,
) -> dict[str, Any]:
    if mode == "safe":
        return dict(source_recommended)

    stress = thresholds.get("stress", {})
    final_cities = thresholds.get("finalCities", {})
    current_min_cities = int(source_recommended.get("civilWarMinCities", 8))
    current_stress = int(source_recommended.get("civilWarStressThreshold", 45))
    stress_probe = int(round(num(stress.get("p90")) or num(stress.get("p75")) or current_stress))
    total_cities_p50 = num(final_cities.get("p50"))
    total_cities_min = num(final_cities.get("min"))
    city_probe = int(round(total_cities_p50 / 6)) if total_cities_p50 else current_min_cities
    if total_cities_min:
        city_probe = min(city_probe, int(round(total_cities_min / 4)))

    recommended = dict(source_recommended)
    recommended["civilWarStressThreshold"] = max(35, min(current_stress, stress_probe))
    recommended["civilWarMinCities"] = max(8, min(current_min_cities, city_probe))
    recommended["civilWarProbability"] = min(6, int(source_recommended.get("civilWarProbability", 8)))
    recommended["civilWarCooldown"] = max(40, int(source_recommended.get("civilWarCooldown", 40)))
    if mode in ("dynastic", "mandate"):
        recommended["civilWarStressThreshold"] = min(45, recommended["civilWarStressThreshold"])
        recommended["civilWarMinCities"] = min(8, recommended["civilWarMinCities"])
        recommended["civilWarProbability"] = min(6, recommended["civilWarProbability"])
        recommended["dynasticStressMaxBonus"] = 10
        recommended["institutionStressModifiersEnabled"] = False
        recommended["institutionStressMaxModifier"] = 4
    if mode == "mandate":
        recommended["mandateMaxStressReduction"] = 4
    return recommended


def profile_rationale(
    thresholds: dict[str, Any],
    source_recommended: dict[str, Any],
    recommended: dict[str, Any],
    mode: str,
) -> list[str]:
    if mode == "safe":
        return ["safe mode preserves calibration recommendations"]
    if mode == "dynastic":
        return [
            "dynastic mode is command-gated and keeps mechanics disabled by default",
            "succession-risk bonus feeds only existing civil-war eligibility",
            "stress threshold and minimum cities are bounded to keep short probes active",
            "probability is capped at 6 and cooldown is at least 40 to reduce runaway civil-war risk",
            "institution stress modifiers remain disabled in this base dynastic profile",
            f"source recommended {source_recommended}",
            f"dynastic recommended {recommended}",
        ]
    if mode == "mandate":
        return [
            "mandate mode is command-gated and keeps mechanics disabled by default",
            "regional mandate reduces dynastic effective stress for high-cohesion regional hegemons",
            "mandate does not change city ownership, diplomacy, production, or terrain",
            "civil-war probability remains capped and cooldown remains active",
            f"source recommended {source_recommended}",
            f"mandate recommended {recommended}",
        ]
    return [
        "probe mode is command-gated and keeps mechanics disabled by default",
        "stress threshold uses at most the calibrated p90 stress value to produce eligibility checks sooner than p95",
        "minimum cities is bounded below the v1 total-cities/3 rule because v1 produced zero eligibility checks",
        "probability is capped at 6 and cooldown is at least 40 to reduce runaway civil-war risk",
        f"v1 recommended {source_recommended}",
        f"probe recommended {recommended}",
    ]


def profile_name(mode: str) -> str:
    if mode == "safe":
        return "mechanics_v1"
    if mode == "dynastic":
        return "dynastic_stress_v1"
    if mode == "mandate":
        return "mandate_stability_v1"
    return "mechanics_v2_probe"


def num(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
