#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase31_core_consolidation_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase31_lifecycle_candidate.json \
  --turns 18 \
  --players 4 \
  --saveturns 18 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 420 \
  --extra-command 'lua cmd organic_history_emergence_probability = 100' \
  --extra-command 'lua cmd organic_history_core_consolidation_enabled = true' \
  --extra-command 'lua cmd organic_history_core_consolidation_max_cities = 2' \
  --extra-command 'lua cmd organic_history_core_consolidation_cooldown = 20' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.abbasid.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.abbasid.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.abbasid.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.assyria.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.assyria.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.assyria.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.ming.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.ming.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.ming.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.predecessors = {}' \
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
core = summary.get("coreConsolidation", {})
actor_actions = core.get("actorActions", {})
fields = core.get("fields", {})
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "logs": int(metadata.get("organicCoreConsolidationLogCount") or 0) > 0,
    "created_when_safe": int(core.get("actions", {}).get("created") or 0) >= 1,
    "ming_created": int(actor_actions.get("ming:created") or 0) >= 1,
    "bounded_created": int(fields.get("created", {}).get("max") or 0) <= 1,
    "structured": summary.get("logCounts", {}).get("coreConsolidation") == metadata.get("organicCoreConsolidationLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 31 core-consolidation checks failed: {checks}")
PY

echo "SUCCESS: Phase 31 core-consolidation gate passed"
