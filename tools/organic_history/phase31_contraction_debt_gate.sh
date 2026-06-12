#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase31_contraction_debt_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase31_lifecycle_candidate.json \
  --turns 12 \
  --players 4 \
  --saveturns 12 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 360 \
  --extra-command 'lua cmd organic_history_sumer_urbanization_enabled = false' \
  --extra-command 'lua cmd organic_history_emergence_enabled = false' \
  --extra-command 'lua cmd organic_history_partial_contraction_risk_threshold = 0.50' \
  --extra-command 'lua cmd organic_history_partial_contraction_debt_enabled = true' \
  --extra-command 'lua cmd organic_history_partial_contraction_debt_overextension_threshold = 0.0' \
  --extra-command 'lua cmd organic_history_partial_contraction_debt_peripheral_threshold = 0.0' \
  --extra-command 'lua cmd organic_history_partial_contraction_debt_required = 1' \
  --extra-command 'lua cmd organic_history_partial_contraction_debt_threshold_bonus = 0.49' \
  --extra-command 'lua cmd organic_history_partial_contraction_cluster_risk_threshold = 0.01' \
  --extra-command 'lua cmd organic_history_partial_contraction_cluster_peripheral_share = 0.01' \
  --extra-command 'lua cmd organic_history_partial_contraction_cooldown = 1' \
  --extra-command 'lua cmd organic_history_partial_contraction_max_release_cities = 3' \
  --extra-command 'lua cmd organic_history_partial_contraction_min_remaining_cities = 1' \
  --extra-command 'lua cmd organic_history_global_actor_region_claims.egypt.historical = {}' \
  --extra-command 'lua cmd organic_history_global_actor_region_claims.egypt.contested = {}' \
  --extra-command 'lua cmd organic_history_global_lifecycle_archetypes.initial_core.contractionRules.minCities = 1' \
  --extra-command 'lua cmd organic_history_global_lifecycle_archetypes.initial_core.contractionRules.sustainedRiskTurns = 1' \
  --extra-command 'lua cmd organic_history_gate_debt_done = false; function organic_history_gate_debt(turn, year) if not organic_history_gate_debt_done then organic_history_gate_debt_done = true; local p = find.player("Narmer"); local specs = {{50, 43, "Ineb-Hedj East"}, {53, 43, "Ineb-Hedj North"}, {54, 41, "Ineb-Hedj Canal"}, {49, 42, "Ineb-Hedj South"}, {51, 41, "Ineb-Hedj West"}}; local c = 0; if p ~= nil then for _, spec in ipairs(specs) do local t = find.tile(spec[1], spec[2]); if t ~= nil and t:city() == nil and edit.city_create(p, t, spec[3], nil) then c = c + 1 end end end; log.normal("organic_history_gate_setup contraction_debt_cities=%d", c) end; return false end; signal.connect("turn_begin", "organic_history_gate_debt")' \
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
actions = summary.get("partialContraction", {}).get("actions", {})
fields = summary.get("partialContraction", {}).get("fields", {})
thresholds = [
    (float(match.group(1)), float(match.group(2)))
    for match in re.finditer(r'threshold=([0-9.]+).*effective_threshold=([0-9.]+)', stdout)
]
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "debt_logged": int(fields.get("overextension_debt", {}).get("count") or 0) > 0,
    "debt_accumulated": float(fields.get("overextension_debt", {}).get("max") or 0) >= 1,
    "threshold_reduced": any(effective < threshold for threshold, effective in thresholds),
    "released": int(actions.get("released") or 0) >= 1,
    "structured": summary.get("logCounts", {}).get("partialContraction") == metadata.get("organicPartialContractionLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 31 contraction-debt checks failed: {checks}")
PY

echo "SUCCESS: Phase 31 contraction-debt gate passed"
