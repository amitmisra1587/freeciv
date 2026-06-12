#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase30_sumer_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase30_lifecycle_diagnostics_candidate.json \
  --turns 18 \
  --players 4 \
  --saveturns 18 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 360 \
  --extra-command 'lua cmd organic_history_sumer_urbanization_target_cities = 3' \
  --extra-command 'lua cmd organic_history_sumer_urbanization_max_cities = 2' \
  --extra-command 'lua cmd organic_history_sumer_urbanization_cooldown = 1' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_low_mandate_threshold = 1.0' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_min_predecessor_cities = 1' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_min_remaining_cities = 1' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_max_cities = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.abbasid.earliest_turn = 8' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.abbasid.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.abbasid.predecessors = {"sumer"}' \
  >/dev/null

python3 tools/organic_history/analyze_campaign.py \
  --run-dir "$gate_dir/active" \
  --output "$gate_dir/active/run_summary.json" \
  --csv-output "$gate_dir/active/run_metrics.csv" >/dev/null

python3 - "$gate_dir/active/run_metadata.json" "$gate_dir/active/run_summary.json" <<'PY'
import json
import re
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
stdout = Path(metadata["stdoutPath"]).read_text(encoding="utf-8", errors="replace")
urban = summary.get("urbanization", {})
dynastic = summary.get("dynasticTransfer", {})
transfers = [
    int(match.group(1))
    for match in re.finditer(r'actor="abbasid" action="inherited".*transferred=(\d+)', stdout)
]
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "urban_logs": int(metadata.get("organicUrbanizationLogCount") or 0) > 0,
    "urban_created": int(urban.get("actions", {}).get("created") or 0) == 2,
    "urban_structured": summary.get("logCounts", {}).get("urbanization") == metadata.get("organicUrbanizationLogCount"),
    "abbasid_inherited": max(transfers or [0]) >= 1,
    "transfer_candidates": int(dynastic.get("fields", {}).get("transfer_city_count", {}).get("max") or 0) >= 1,
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 30 Sumer gate checks failed: {checks}")
PY

echo "SUCCESS: Phase 30 Sumer gate passed"
