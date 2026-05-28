#!/usr/bin/env python3
"""Create minimal organic-history scenario fixtures from an unlocked Earth map."""

from __future__ import annotations

import argparse
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]

FIXTURES = {
    "earth_ancient_v0": {
        "name": "Organic History Earth Ancient v0",
        "description": "Minimal ancient-era organic-history fixed Earth fixture for AI-only regional testing.",
    },
    "earth_medieval_v0": {
        "name": "Organic History Earth Medieval v0",
        "description": "Minimal medieval-era organic-history fixed Earth fixture for AI-only regional testing.",
    },
    "earth_1450_v0": {
        "name": "Organic History Earth 1450 v0",
        "description": "Minimal 1450-era organic-history fixed Earth fixture for AI-only regional and colonization testing.",
    },
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Create organic-history scenario fixtures.")
    parser.add_argument("--source", type=Path, default=ROOT / "data" / "scenarios" / "earth-small.sav")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "data" / "organic_history" / "scenarios")
    args = parser.parse_args()

    source = args.source if args.source.is_absolute() else ROOT / args.source
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    source_text = source.read_text(encoding="utf-8")
    output_dir.mkdir(parents=True, exist_ok=True)
    for fixture_id, metadata in FIXTURES.items():
        fixture_text = rewrite_metadata(source_text, metadata["name"], metadata["description"])
        output_path = output_dir / f"{fixture_id}.sav"
        output_path.write_text(fixture_text, encoding="utf-8")
        print(output_path)
    return 0


def rewrite_metadata(source_text: str, name: str, description: str) -> str:
    text = replace_field(source_text, "name", f'_("{name}")')
    text = replace_field(text, "description", f'_("{description}")')
    return replace_field(text, "authors", '"The Freeciv Project; organic-history fixture generated from earth-small.sav"')


def replace_field(text: str, key: str, value: str) -> str:
    return re.sub(rf"^{re.escape(key)}=.*$", f"{key}={value}", text, count=1, flags=re.MULTILINE)


if __name__ == "__main__":
    raise SystemExit(main())
