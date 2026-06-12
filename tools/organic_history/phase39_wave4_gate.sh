#!/bin/sh
# Phase 39 Wave 4 (homeland defense) focused gate.
#
# Runs a 200-turn organic game with the Wave 4 profile and verifies that
# homeland_defense diagnostic events are structured and that at least one
# core-city garrison is applied within actors' canonical eras.
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase39_wave4_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py \
  tools/organic_history/run_campaign.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase39_wave4_homeland_defense.json \
  --turns 200 \
  --players 4 \
  --saveturns 200 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 1500 \
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
hd = summary.get("homelandDefense", {})

checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "homeland_logs": int(metadata.get("organicHomelandDefenseLogCount") or 0) > 0,
    "homeland_structured": (
        summary.get("logCounts", {}).get("homelandDefense")
        == metadata.get("organicHomelandDefenseLogCount")
    ),
    "at_least_one_applied": bool(hd.get("actorApplied") or {}),
}

if not all(checks.values()):
    print("FAIL:", json.dumps(checks, sort_keys=True))
    print("homelandDefense:", json.dumps(hd, sort_keys=True))
    raise SystemExit(1)
PY

echo "SUCCESS: Phase 39 Wave 4 homeland defense gate passed"
echo
echo "Homeland defense summary:"
python3 -c "
import json; from pathlib import Path
s = json.loads(Path('$gate_dir/active/run_summary.json').read_text())
hd = s.get('homelandDefense', {})
print('actorApplied:', json.dumps(hd.get('actorApplied'), sort_keys=True))
print('skipReasons:', json.dumps(hd.get('skipReasons'), sort_keys=True))
"
