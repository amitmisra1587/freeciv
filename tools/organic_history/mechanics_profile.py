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
    args = parser.parse_args()

    thresholds = calibrate(args.campaign_dir)
    write_json(args.thresholds_output, thresholds)
    profile = build_profile(thresholds, args.thresholds_output)
    write_json(args.profile_output, profile)
    print(json.dumps({
        "thresholds": str(args.thresholds_output),
        "profile": str(args.profile_output),
        "commands": len(profile["luaCommands"]),
    }, sort_keys=True))
    return 0


def build_profile(thresholds: dict[str, Any], thresholds_path: Path) -> dict[str, Any]:
    recommended = thresholds.get("recommended", {})
    commands = [
        "lua cmd organic_history_mechanics_enabled = true",
        "lua cmd organic_history_civil_war_enabled = true",
        f"lua cmd organic_history_civil_war_stress_threshold = {int(recommended.get('civilWarStressThreshold', 45))}",
        f"lua cmd organic_history_civil_war_min_cities = {int(recommended.get('civilWarMinCities', 8))}",
        f"lua cmd organic_history_civil_war_probability = {int(recommended.get('civilWarProbability', 8))}",
        f"lua cmd organic_history_civil_war_cooldown = {int(recommended.get('civilWarCooldown', 40))}",
    ]
    return {
        "name": "mechanics_v1",
        "sourceThresholds": str(thresholds_path),
        "recommended": recommended,
        "luaCommands": commands,
    }


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
