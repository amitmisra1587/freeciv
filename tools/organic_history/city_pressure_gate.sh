#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

python3 tools/organic_history/create_scenario_fixture.py >/dev/null

python3 tools/organic_history/validate_scenario.py \
  data/organic_history/scenarios/earth_ancient_v0.sav \
  --output-dir runs/organic_history_city_pressure_gate \
  --turns 20 \
  --players 8 \
  --timeout 240 >/dev/null

python3 tools/organic_history/analyze_campaign.py \
  --run-dir runs/organic_history_city_pressure_gate \
  --output runs/organic_history_city_pressure_gate/run_summary.json \
  --csv-output runs/organic_history_city_pressure_gate/run_metrics.csv >/dev/null

python3 - <<'PY'
import json
from pathlib import Path

summary = json.loads(Path("runs/organic_history_city_pressure_gate/run_summary.json").read_text())
counts = summary.get("logCounts", {})
missing = [
    name for name in ("cityPressure", "institution", "eventRisk")
    if int(counts.get(name) or 0) <= 0
]
if missing:
    raise SystemExit(f"FAIL: missing organic diagnostics: {', '.join(missing)}")

city_pressure = summary.get("cityPressure", {})
for field in ("unrest", "autonomy", "migration_pressure"):
    if city_pressure.get(field, {}).get("count", 0) <= 0:
        raise SystemExit(f"FAIL: missing city pressure field {field}")

print("SUCCESS: city pressure gate passed")
PY
