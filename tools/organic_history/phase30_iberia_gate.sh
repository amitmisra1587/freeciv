#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase30_iberia_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase30_lifecycle_diagnostics_candidate.json \
  --turns 12 \
  --players 4 \
  --saveturns 12 \
  --output-dir "$gate_dir/non_iberian_rome" \
  --clean-output-dir \
  --timeout 360 \
  --extra-command 'lua cmd organic_history_emergence_probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.earliest_turn = 4' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.predecessors = {"rome"}' \
  >/dev/null

python3 tools/organic_history/analyze_campaign.py \
  --run-dir "$gate_dir/non_iberian_rome" \
  --output "$gate_dir/non_iberian_rome/run_summary.json" \
  --csv-output "$gate_dir/non_iberian_rome/run_metrics.csv" >/dev/null

python3 - "$gate_dir/non_iberian_rome/run_metadata.json" "$gate_dir/non_iberian_rome/run_summary.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
stdout = Path(metadata["stdoutPath"]).read_text(encoding="utf-8", errors="replace")
actor_reasons = summary.get("dynasticTransfer", {}).get("actorReasons", {})
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "castile_spawned": 'organic_history_emergence' in stdout and 'actor="castile"' in stdout and 'action="spawned"' in stdout,
    "not_inherited": 'actor="castile" action="inherited"' not in stdout,
    "no_continuity_suppression": "castile:dynastic_continuity" not in actor_reasons,
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 30 Iberia non-Iberian checks failed: {checks}")
PY

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase30_lifecycle_diagnostics_candidate.json \
  --turns 14 \
  --players 4 \
  --saveturns 14 \
  --output-dir "$gate_dir/iberian_inheritance" \
  --clean-output-dir \
  --timeout 360 \
  --extra-command 'lua cmd organic_history_emergence_probability = 100' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_low_mandate_threshold = 1.0' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_min_predecessor_cities = 1' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_min_remaining_cities = 1' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_max_cities = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.earliest_turn = 7' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.castile.predecessors = {"rome"}' \
  --extra-command 'lua cmd organic_history_gate_iberian_city_done = false; function organic_history_gate_iberian_city(turn, year) if not organic_history_gate_iberian_city_done and turn >= 4 then organic_history_gate_iberian_city_done = true; local p = find.player("Romulus"); local specs = {{25, 32, "Toletum"}, {23, 35, "Olisipo"}}; local c = 0; if p ~= nil then for _, spec in ipairs(specs) do local t = find.tile(spec[1], spec[2]); if t ~= nil and t:city() == nil and edit.city_create(p, t, spec[3], nil) then c = c + 1 end end end; log.normal("organic_history_gate_setup iberian_rome_cities=%d", c) end; return false end; signal.connect("turn_begin", "organic_history_gate_iberian_city")' \
  >/dev/null

python3 tools/organic_history/analyze_campaign.py \
  --run-dir "$gate_dir/iberian_inheritance" \
  --output "$gate_dir/iberian_inheritance/run_summary.json" \
  --csv-output "$gate_dir/iberian_inheritance/run_metrics.csv" >/dev/null

python3 - "$gate_dir/iberian_inheritance/run_metadata.json" "$gate_dir/iberian_inheritance/run_summary.json" <<'PY'
import json
import re
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
stdout = Path(metadata["stdoutPath"]).read_text(encoding="utf-8", errors="replace")
reasons = summary.get("dynasticTransfer", {}).get("actorReasons", {})
transfers = [
    int(match.group(1))
    for match in re.finditer(r'actor="castile" action="inherited".*transferred=(\d+)', stdout)
]
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "castile_inherited": max(transfers or [0]) >= 1,
    "bounded_reason": int(reasons.get("castile:bounded_cluster_inheritance") or 0) == 1,
    "structured": summary.get("logCounts", {}).get("dynasticTransfer") == metadata.get("organicDynasticTransferLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 30 Iberia inheritance checks failed: {checks}")
PY

echo "SUCCESS: Phase 30 Iberia gate passed"
