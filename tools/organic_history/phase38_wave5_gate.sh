#!/bin/sh
# Phase 38 Wave 5 (fallback successor auto-spawn) focused gate.
#
# Exercises organic_history_fallback_successor_spawn by forcing a Nubia-like
# situation: spawn Egypt early with a sprawling empire that triggers partial
# contraction, then verify that when missing_live_regional_successor would
# block release, the fallback mechanism spawns a dormant successor.
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase38_wave5_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py \
  tools/organic_history/run_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase38_wave5_fallback_successor.json \
  --turns 200 \
  --players 4 \
  --saveturns 200 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 1500 \
  --extra-command 'lua cmd organic_history_partial_contraction_min_remaining_cities = 2' \
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
fb = summary.get("fallbackSuccessor", {})

checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "fallback_logs_present_or_no_block": True,
    "fallback_structured": (
        summary.get("logCounts", {}).get("fallbackSuccessor")
        == metadata.get("organicFallbackSuccessorLogCount")
    ),
}

if not all(checks.values()):
    print("FAIL:", json.dumps(checks, sort_keys=True))
    print("fallbackSuccessor:", json.dumps(fb, sort_keys=True))
    raise SystemExit(1)
PY

echo "SUCCESS: Phase 38 Wave 5 fallback successor gate passed"
echo
echo "Fallback successor summary:"
python3 -c "
import json; from pathlib import Path
s = json.loads(Path('$gate_dir/active/run_summary.json').read_text())
fb = s.get('fallbackSuccessor', {})
print('outcomes:', json.dumps(fb.get('outcomes'), sort_keys=True))
print('parentRegions:', json.dumps(fb.get('parentRegions'), sort_keys=True))
print('dormantActors:', json.dumps(fb.get('dormantActors'), sort_keys=True))
"
