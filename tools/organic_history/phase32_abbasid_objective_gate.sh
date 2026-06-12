#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase32_abbasid_objective_gate

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
  --extra-command 'lua cmd organic_history_global_emergence_actors.abbasid.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.abbasid.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.abbasid.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.abbasid[1].targetCities = 99' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.abbasid[1].cooldownTurns = 8' \
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
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "objective_logs": int(metadata.get("organicObjectiveLogCount") or 0) > 0,
    "abbasid_applied": int(objective.get("actorReasons", {}).get("abbasid:settlement_city") or 0) >= 1,
    "objective_structured": summary.get("logCounts", {}).get("objective") == metadata.get("organicObjectiveLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 32 Abbasid objective checks failed: {checks}")
PY

echo "SUCCESS: Phase 32 Abbasid objective gate passed"
