#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase29_contraction_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase29_contraction_v1_candidate.json \
  --turns 12 \
  --players 4 \
  --saveturns 12 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 360 \
  --extra-command 'lua cmd organic_history_gate_extra_city_done = false; function organic_history_gate_extra_city(turn, year) if not organic_history_gate_extra_city_done then organic_history_gate_extra_city_done = true; local p = find.player("Narmer"); local t = find.tile(50, 43); local c = 0; if p ~= nil and t ~= nil and t:city() == nil and edit.city_create(p, t, "Ineb-Hedj", nil) then c = 1 end; log.normal("organic_history_gate_setup extra_city=%d", c) end; return false end; signal.connect("turn_begin", "organic_history_gate_extra_city")' \
  --extra-command 'lua cmd organic_history_emergence_enabled = false' \
  --extra-command 'lua cmd organic_history_partial_contraction_risk_threshold = 0.01' \
  --extra-command 'lua cmd organic_history_partial_contraction_cooldown = 1' \
  --extra-command 'lua cmd organic_history_global_actor_region_claims.egypt.historical = {}' \
  --extra-command 'lua cmd organic_history_global_lifecycle_archetypes.initial_core.contractionRules.minCities = 1' \
  --extra-command 'lua cmd organic_history_global_lifecycle_archetypes.initial_core.contractionRules.sustainedRiskTurns = 1' \
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
actions = summary.get("partialContraction", {}).get("actions", {})
reasons = summary.get("partialContraction", {}).get("reasons", {})
actor_reasons = summary.get("partialContraction", {}).get("actorReasons", {})
fields = summary.get("partialContraction", {}).get("fields", {})
transfers = [
    line
    for line in Path(metadata["stdoutPath"]).read_text(encoding="utf-8", errors="replace").splitlines()
    if "organic_history_event type=city_transferred" in line
]
release_details = [
    line
    for line in Path(metadata["stdoutPath"]).read_text(encoding="utf-8", errors="replace").splitlines()
    if "organic_history_partial_contraction" in line
    and 'action="released"' in line
    and "transferred=1" in line
]
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "partial_logs": int(metadata.get("organicPartialContractionLogCount") or 0) > 0,
    "released_once": int(actions.get("released") or 0) == 1,
    "reason_counts": bool(reasons),
    "actor_reason_counts": bool(actor_reasons),
    "candidate_quality": int(fields.get("safe_release_candidates", {}).get("count") or 0) > 0,
    "release_detail_once": len(release_details) == 1,
    "city_transfer_hook_at_most_once": len(transfers) <= 1,
    "no_secession_fallback": not summary.get("secession"),
    "structured": summary.get("logCounts", {}).get("partialContraction") == metadata.get("organicPartialContractionLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 29 contraction checks failed: {checks}")
PY

echo "SUCCESS: Phase 29 contraction gate passed"
