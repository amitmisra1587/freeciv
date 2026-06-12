#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase32_objective_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py \
  tools/organic_history/run_campaign.py \
  tools/organic_history/generate_civilization_evidence.py \
  tools/organic_history/global_historical_fit_report.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase32_objective_proof.json \
  --turns 70 \
  --players 4 \
  --saveturns 70 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 600 \
  --extra-command 'lua cmd organic_history_emergence_probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].targetCities = 99' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].startTurnAfterBirth = 0' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].cooldownTurns = 5' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].targetRegions = {"gaul", "iberia"}' \
  --extra-command 'lua cmd organic_history_gate_rome_target_done = false; function organic_history_gate_rome_target(turn, year) if not organic_history_gate_rome_target_done then organic_history_gate_rome_target_done = true; local p = find.player("Narmer"); local t = find.tile(30, 26); if p ~= nil and t ~= nil and t:city() == nil then edit.city_create(p, t, "Gaul Rival", nil) end end; return false end; signal.connect("turn_begin", "organic_history_gate_rome_target")' \
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
objective = summary.get("objective", {})
conversion = summary.get("conquestConversion", {})
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "objective_logs": int(metadata.get("organicObjectiveLogCount") or 0) > 0,
    "objective_applied": int(objective.get("actorActions", {}).get("rome:applied") or 0) >= 1,
    "objective_structured": summary.get("logCounts", {}).get("objective") == metadata.get("organicObjectiveLogCount"),
    "conversion_tracking": int(conversion.get("actorActions", {}).get("rome:tracking") or 0) >= 1,
    "conversion_resolved": int(conversion.get("actorActions", {}).get("rome:resolved") or 0) >= 1,
    "conversion_structured": summary.get("logCounts", {}).get("conquestConversion") == metadata.get("organicConquestConversionLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 32 objective checks failed: {checks}")
PY

echo "SUCCESS: Phase 32 objective gate passed"
