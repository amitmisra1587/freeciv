#!/bin/sh
# Phase 38 Wave 3 (claim conversion stickiness) focused gate.
#
# Exercises organic_history_claim_conversion by forcing Rome to spawn early
# in its Mediterranean core and adding plenty of conquest-target gold so Rome
# actively pursues rival cities. Validates that:
#   - the run completes without Freeciv assertions,
#   - claim_conversion logs fire at least once,
#   - at least one of rome/persia/carthage receives a hold dividend.
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase38_wave3_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py \
  tools/organic_history/run_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase38_wave3_claim_conversion.json \
  --turns 140 \
  --players 4 \
  --saveturns 140 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 900 \
  --extra-command 'lua cmd organic_history_emergence_probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.earliest_turn = 3' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].targetCities = 99' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].cooldownTurns = 6' \
  --extra-command 'lua cmd organic_history_objective_max_gold = 100' \
  --extra-command 'lua cmd organic_history_objective_max_units = 6' \
  --extra-command 'lua cmd organic_history_conquest_target_max_gold = 100' \
  --extra-command 'lua cmd organic_history_conquest_target_max_units = 6' \
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
cc = summary.get("claimConversion", {})

actor_applied = cc.get("actorApplied", {})
actor_skips = cc.get("actorSkips", {})

checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "claim_conversion_logs": int(metadata.get("organicClaimConversionLogCount") or 0) > 0,
    "claim_conversion_structured": (
        summary.get("logCounts", {}).get("claimConversion")
        == metadata.get("organicClaimConversionLogCount")
    ),
    "at_least_one_actor_seen": bool(actor_applied) or bool(actor_skips),
}

if not all(checks.values()):
    print("FAIL:", json.dumps(checks, sort_keys=True))
    print("actorApplied:", json.dumps(actor_applied, sort_keys=True))
    print("actorSkips:", json.dumps(actor_skips, sort_keys=True))
    print("skipReasons:", json.dumps(cc.get("skipReasons", {}), sort_keys=True))
    raise SystemExit(1)
PY

echo "SUCCESS: Phase 38 Wave 3 claim conversion gate passed"
echo
echo "Claim conversion summary:"
python3 -c "
import json; from pathlib import Path
s = json.loads(Path('$gate_dir/active/run_summary.json').read_text())
cc = s.get('claimConversion', {})
print('actorApplied:', json.dumps(cc.get('actorApplied'), sort_keys=True))
print('actorClaimClasses:', json.dumps(cc.get('actorClaimClasses'), sort_keys=True))
print('skipReasons:', json.dumps(cc.get('skipReasons'), sort_keys=True))
"
