#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --turns 20 \
  --players 8 \
  --saveturns 5 \
  --output-dir runs/organic_history_dynastic_stress_gate \
  --clean-output-dir \
  --timeout 240 \
  --extra-command "lua cmd organic_history_mechanics_enabled = true" \
  --extra-command "lua cmd organic_history_civil_war_enabled = true" \
  --extra-command "lua cmd organic_history_dynastic_stress_enabled = true" \
  --extra-command "lua cmd organic_history_dynastic_stress_max_bonus = 10" >/dev/null

python3 tools/organic_history/analyze_campaign.py \
  --run-dir runs/organic_history_dynastic_stress_gate \
  --output runs/organic_history_dynastic_stress_gate/run_summary.json \
  --csv-output runs/organic_history_dynastic_stress_gate/run_metrics.csv >/dev/null

python3 - <<'PY'
import json
from pathlib import Path

summary = json.loads(Path("runs/organic_history_dynastic_stress_gate/run_summary.json").read_text())
counts = summary.get("logCounts", {})
if int(counts.get("dynasticProbe") or 0) <= 0:
    raise SystemExit("FAIL: no organic_history_dynastic_probe logs found")
dynastic = summary.get("dynasticProbe", {})
fields = dynastic.get("fields", {})
for field in ("base_stress", "succession_risk", "bonus", "effective_stress"):
    if fields.get(field, {}).get("count", 0) <= 0:
        raise SystemExit(f"FAIL: missing dynastic probe field {field}")
if int(summary.get("logCounts", {}).get("mechanic") or 0) <= 0:
    raise SystemExit("FAIL: dynastic probe did not exercise mechanic logging")
print("SUCCESS: dynastic stress gate passed")
PY
