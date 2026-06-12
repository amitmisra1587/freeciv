#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase29_successor_inheritance_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase29_successor_inheritance_v1_candidate.json \
  --turns 12 \
  --players 4 \
  --saveturns 12 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 360 \
  --extra-command 'lua cmd organic_history_gate_extra_city_done = false; function organic_history_gate_extra_city(turn, year) if not organic_history_gate_extra_city_done then organic_history_gate_extra_city_done = true; local p = find.player("Gilgamesh"); local t = find.tile(50, 43); local c = 0; if p ~= nil and t ~= nil and t:city() == nil and edit.city_create(p, t, "Akkad", nil) then c = 1 end; log.normal("organic_history_gate_setup successor_extra_city=%d", c) end; return false end; signal.connect("turn_begin", "organic_history_gate_extra_city")' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_low_mandate_threshold = 1.0' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_min_predecessor_cities = 1' \
  --extra-command 'lua cmd organic_history_global_actor_lifecycle_types.greece = "dynastic_successor"' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.greece.earliest_turn = 3' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.greece.core_region = "mesopotamia"' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.greece.city = "Ashur"' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.greece.x = 50' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.greece.y = 37' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.greece.predecessors = {"sumer"}' \
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
actions = summary.get("dynasticTransfer", {}).get("actions", {})
reasons = summary.get("dynasticTransfer", {}).get("reasons", {})
actor_reasons = summary.get("dynasticTransfer", {}).get("actorReasons", {})
fields = summary.get("dynasticTransfer", {}).get("fields", {})
stdout = Path(metadata["stdoutPath"]).read_text(encoding="utf-8", errors="replace")
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "dynastic_logs": int(metadata.get("organicDynasticTransferLogCount") or 0) > 0,
    "inherited_once": int(actions.get("inherited") or 0) == 1,
    "reason_counts": bool(reasons),
    "actor_reason_counts": bool(actor_reasons),
    "candidate_quality": int(fields.get("transfer_city_available", {}).get("count") or 0) > 0,
    "inherited_spawn": 'action="inherited_spawn"' in stdout,
    "transfer_detail": 'action="inherited"' in stdout and "transferred=1" in stdout,
    "structured": summary.get("logCounts", {}).get("dynasticTransfer") == metadata.get("organicDynasticTransferLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 29 successor inheritance checks failed: {checks}")
PY

echo "SUCCESS: Phase 29 successor inheritance gate passed"
