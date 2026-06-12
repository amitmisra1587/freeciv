#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase32_diagnostics_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py \
  tools/organic_history/run_campaign.py \
  tools/organic_history/generate_civilization_evidence.py \
  tools/organic_history/global_historical_fit_report.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase31_lifecycle_candidate.json \
  --turns 50 \
  --players 4 \
  --saveturns 50 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 600 \
  --extra-command 'lua cmd organic_history_emergence_probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.assyria.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.assyria.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.assyria.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.steppe.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.steppe.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.portugal.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.portugal.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.portugal.predecessors = {}' \
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
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "conquest_conversion_logs": int(metadata.get("organicConquestConversionLogCount") or 0) > 0,
    "settler_conversion_logs": int(metadata.get("organicSettlerConversionLogCount") or 0) > 0,
    "iberian_site_logs": int(metadata.get("organicIberianSiteLogCount") or 0) > 0,
    "conquest_resolved": int(summary.get("conquestConversion", {}).get("actions", {}).get("resolved") or 0) > 0,
    "settler_resolved": int(summary.get("settlerConversion", {}).get("actions", {}).get("resolved") or 0) > 0,
    "iberian_structured": int(summary.get("iberianSite", {}).get("fields", {}).get("candidate_count", {}).get("count") or 0) > 0,
    "conquest_structured": summary.get("logCounts", {}).get("conquestConversion") == metadata.get("organicConquestConversionLogCount"),
    "settler_structured": summary.get("logCounts", {}).get("settlerConversion") == metadata.get("organicSettlerConversionLogCount"),
    "iberian_structured_count": summary.get("logCounts", {}).get("iberianSite") == metadata.get("organicIberianSiteLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 32 diagnostics checks failed: {checks}")
PY

echo "SUCCESS: Phase 32 diagnostics gate passed"
