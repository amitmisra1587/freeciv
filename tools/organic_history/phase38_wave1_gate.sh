#!/bin/sh
# Phase 38 Wave 1 (tech floor) focused gate.
#
# Exercises organic_history_tech_floor against the Iberian late-spawn path:
# forces Castile and Portugal to activate early, with the Wave 1 profile that
# enables organic_history_tech_floor_enabled. Verifies that:
#   - the run completes without Freeciv assertions,
#   - tech_floor logs fire at activation,
#   - tech_floor applied=true for at least one of the forced actors,
#   - existing Iberia objective/settler diagnostics still work.
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase38_wave1_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py \
  tools/organic_history/run_campaign.py \
  tools/organic_history/generate_civilization_evidence.py \
  tools/organic_history/global_historical_fit_report.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase38_wave1_tech_floor.json \
  --turns 120 \
  --players 4 \
  --saveturns 120 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 900 \
  --extra-command 'lua cmd organic_history_emergence_probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.earliest_turn = 90' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.portugal.earliest_turn = 95' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.portugal.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.portugal.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.castile[1].targetCities = 99' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.portugal[1].targetCities = 99' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.castile[1].cooldownTurns = 8' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.portugal[1].cooldownTurns = 8' \
  >/dev/null

python3 tools/organic_history/analyze_campaign.py \
  --run-dir "$gate_dir/active" \
  --output "$gate_dir/active/run_summary.json" \
  --csv-output "$gate_dir/active/run_metrics.csv" >/dev/null

python3 - "$gate_dir/active/run_metadata.json" "$gate_dir/active/run_summary.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
tech_floor = summary.get("techFloor", {})
objective = summary.get("objective", {})
settlers = summary.get("settlerConversion", {})

actor_applied = tech_floor.get("actorApplied", {})
actor_reasons = tech_floor.get("actorReasons", {})

checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "tech_floor_logs": int(metadata.get("organicTechFloorLogCount") or 0) > 0,
    "tech_floor_structured": (
        summary.get("logCounts", {}).get("techFloor")
        == metadata.get("organicTechFloorLogCount")
    ),
    "castile_or_portugal_seen": (
        any(k.startswith("castile:") for k in actor_reasons)
        or any(k.startswith("portugal:") for k in actor_reasons)
    ),
    "at_least_one_applied": (
        int(actor_applied.get("castile") or 0)
        + int(actor_applied.get("portugal") or 0)
    ) >= 1,
    "objective_still_works": int(metadata.get("organicObjectiveLogCount") or 0) > 0,
    "settler_still_tracked": (
        int(settlers.get("actorActions", {}).get("castile:tracking") or 0) >= 1
        and int(settlers.get("actorActions", {}).get("portugal:tracking") or 0) >= 1
    ),
}

if not all(checks.values()):
    print("FAIL:", json.dumps(checks, sort_keys=True))
    print("tech_floor.actorApplied:", json.dumps(actor_applied, sort_keys=True))
    print("tech_floor.actorReasons:", json.dumps(actor_reasons, sort_keys=True))
    print("tech_floor.skipReasons:",
          json.dumps(tech_floor.get("skipReasons", {}), sort_keys=True))
    raise SystemExit(1)
PY

echo "SUCCESS: Phase 38 Wave 1 tech floor gate passed"
