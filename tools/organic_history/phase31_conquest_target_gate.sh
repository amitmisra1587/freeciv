#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase31_conquest_target_gate

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
  --extra-command 'lua cmd organic_history_global_emergence_actors.assyria.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.assyria.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.persia.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.persia.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.persia.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.steppe.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.steppe.probability = 100' \
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
target = summary.get("conquestTarget", {})
actor_actions = target.get("actorActions", {})
fields = target.get("fields", {})
expected = ["assyria", "persia", "rome", "steppe"]
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "logs": int(metadata.get("organicConquestTargetLogCount") or 0) > 0,
    "applied_all": all(int(actor_actions.get(f"{actor}:applied") or 0) >= 1 for actor in expected),
    "rival_target_logged": int(fields.get("rival_region_cities", {}).get("max") or 0) > 0,
    "bounded_units": int(fields.get("created_units", {}).get("max") or 0) <= 3,
    "structured": summary.get("logCounts", {}).get("conquestTarget") == metadata.get("organicConquestTargetLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 31 conquest-target checks failed: {checks}")
PY

echo "SUCCESS: Phase 31 conquest-target gate passed"
