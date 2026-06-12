#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_dynastic_transfer_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --turns 8 \
  --players 4 \
  --saveturns 8 \
  --output-dir "$gate_dir/probe" \
  --clean-output-dir \
  --timeout 240 \
  --extra-command 'lua cmd organic_history_mechanics_enabled = true' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_probe_enabled = true' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_low_mandate_threshold = 1.0' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_min_predecessor_cities = 1' \
  --extra-command 'lua cmd organic_history_global_actor_lifecycle_types.greece = "dynastic_successor"' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.greece.earliest_turn = 3' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.greece.predecessors = {"sumer"}' \
  >/dev/null

python3 tools/organic_history/analyze_campaign.py \
  --run-dir "$gate_dir/probe" \
  --output "$gate_dir/probe/run_summary.json" \
  --csv-output "$gate_dir/probe/run_metrics.csv" >/dev/null

if grep -q 'organic_history_event type=city_transferred' "$gate_dir"/probe/server_*.log; then
  echo "FAIL: dynastic transfer probe changed city ownership"
  exit 1
fi

if grep -q 'organic_history_secession type=secession_triggered' "$gate_dir"/probe/server_*.log; then
  echo "FAIL: dynastic transfer probe triggered secession"
  exit 1
fi

python3 - "$gate_dir/probe/run_metadata.json" "$gate_dir/probe/run_summary.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
actions = summary.get("dynasticTransfer", {}).get("actions", {})
reasons = summary.get("dynasticTransfer", {}).get("reasons", {})
actor_reasons = summary.get("dynasticTransfer", {}).get("actorReasons", {})
fields = summary.get("dynasticTransfer", {}).get("fields", {})
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "logs": int(metadata.get("organicDynasticTransferLogCount") or 0) > 0,
    "candidate": int(actions.get("candidate") or 0) > 0,
    "reason_counts": bool(reasons),
    "actor_reason_counts": bool(actor_reasons),
    "candidate_quality": int(fields.get("transfer_city_available", {}).get("count") or 0) > 0,
    "structured": summary.get("logCounts", {}).get("dynasticTransfer") == metadata.get("organicDynasticTransferLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: dynastic transfer checks failed: {checks}")
PY

echo "SUCCESS: dynastic transfer gate passed"
