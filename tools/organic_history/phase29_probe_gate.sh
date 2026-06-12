#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase29_probe_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py \
  tools/organic_history/run_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase29_lifecycle_probe.json \
  --turns 12 \
  --players 4 \
  --saveturns 12 \
  --output-dir "$gate_dir/probe" \
  --clean-output-dir \
  --timeout 360 \
  --extra-command 'lua cmd organic_history_emergence_enabled = false' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_low_mandate_threshold = 1.0' \
  --extra-command 'lua cmd organic_history_dynastic_transfer_min_predecessor_cities = 1' \
  --extra-command 'lua cmd organic_history_global_actor_lifecycle_types.greece = "dynastic_successor"' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.greece.earliest_turn = 3' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.greece.predecessors = {"sumer"}' \
  --extra-command 'lua cmd organic_history_global_lifecycle_archetypes.initial_core.targetCityCurve.turnsAfterBirth10 = {5, 8}' \
  --extra-command 'lua cmd organic_history_partial_contraction_risk_threshold = 0.01' \
  --extra-command 'lua cmd organic_history_global_actor_region_claims.egypt.core = {}' \
  --extra-command 'lua cmd organic_history_global_lifecycle_archetypes.initial_core.contractionRules.minCities = 1' \
  --extra-command 'lua cmd organic_history_global_lifecycle_archetypes.initial_core.contractionRules.sustainedRiskTurns = 1' \
  >/dev/null

python3 tools/organic_history/analyze_campaign.py \
  --run-dir "$gate_dir/probe" \
  --output "$gate_dir/probe/run_summary.json" \
  --csv-output "$gate_dir/probe/run_metrics.csv" >/dev/null

if grep -q 'organic_history_event type=city_transferred' "$gate_dir"/probe/server_*.log; then
  echo "FAIL: Phase 29 probe changed city ownership"
  exit 1
fi

if grep -q 'organic_history_secession type=secession_triggered' "$gate_dir"/probe/server_*.log; then
  echo "FAIL: Phase 29 probe triggered secession"
  exit 1
fi

python3 - "$gate_dir/probe/run_metadata.json" "$gate_dir/probe/run_summary.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
actions = {
    "dynastic": summary.get("dynasticTransfer", {}).get("actions", {}),
    "expansion": summary.get("expansionPressure", {}).get("actions", {}),
    "contraction": summary.get("partialContraction", {}).get("actions", {}),
}
dynastic = summary.get("dynasticTransfer", {})
contraction = summary.get("partialContraction", {})
log_counts = summary.get("logCounts", {})
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "dynastic_logs": int(metadata.get("organicDynasticTransferLogCount") or 0) > 0,
    "dynastic_candidate": int(actions["dynastic"].get("candidate") or 0) > 0,
    "expansion_logs": int(metadata.get("organicExpansionPressureLogCount") or 0) > 0,
    "expansion_candidate": int(actions["expansion"].get("candidate") or 0) > 0,
    "contraction_logs": int(metadata.get("organicPartialContractionLogCount") or 0) > 0,
    "contraction_candidate": int(actions["contraction"].get("candidate") or 0) > 0,
    "dynastic_reasons": bool(dynastic.get("reasons")),
    "dynastic_actor_reasons": bool(dynastic.get("actorReasons")),
    "dynastic_candidate_quality": int(dynastic.get("fields", {}).get("transfer_city_available", {}).get("count") or 0) > 0,
    "contraction_reasons": bool(contraction.get("reasons")),
    "contraction_actor_reasons": bool(contraction.get("actorReasons")),
    "contraction_candidate_quality": int(contraction.get("fields", {}).get("safe_release_candidates", {}).get("count") or 0) > 0,
    "arrival_logs": int(metadata.get("organicArrivalLogCount") or 0) > 0,
    "arrival_structured": log_counts.get("arrival") == metadata.get("organicArrivalLogCount"),
    "dynastic_structured": log_counts.get("dynasticTransfer") == metadata.get("organicDynasticTransferLogCount"),
    "expansion_structured": log_counts.get("expansionPressure") == metadata.get("organicExpansionPressureLogCount"),
    "contraction_structured": log_counts.get("partialContraction") == metadata.get("organicPartialContractionLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 29 probe checks failed: {checks}")
PY

echo "SUCCESS: Phase 29 probe gate passed"
