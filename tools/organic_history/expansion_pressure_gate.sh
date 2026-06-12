#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_expansion_pressure_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --turns 12 \
  --players 4 \
  --saveturns 12 \
  --output-dir "$gate_dir/probe" \
  --clean-output-dir \
  --timeout 300 \
  --extra-command 'lua cmd organic_history_mechanics_enabled = true' \
  --extra-command 'lua cmd organic_history_expansion_pressure_probe_enabled = true' \
  --extra-command 'lua cmd organic_history_global_lifecycle_archetypes.initial_core.targetCityCurve.turnsAfterBirth10 = {5, 8}' \
  >/dev/null

python3 tools/organic_history/analyze_campaign.py \
  --run-dir "$gate_dir/probe" \
  --output "$gate_dir/probe/run_summary.json" \
  --csv-output "$gate_dir/probe/run_metrics.csv" >/dev/null

if grep -q 'organic_history_event type=city_transferred' "$gate_dir"/probe/server_*.log; then
  echo "FAIL: expansion pressure probe changed city ownership"
  exit 1
fi

python3 - "$gate_dir/probe/run_metadata.json" "$gate_dir/probe/run_summary.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
actions = summary.get("expansionPressure", {}).get("actions", {})
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "logs": int(metadata.get("organicExpansionPressureLogCount") or 0) > 0,
    "candidate": int(actions.get("candidate") or 0) > 0,
    "structured": summary.get("logCounts", {}).get("expansionPressure") == metadata.get("organicExpansionPressureLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: expansion pressure checks failed: {checks}")
PY

echo "SUCCESS: expansion pressure gate passed"
