#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

python3 tools/organic_history/create_scenario_fixture.py >/dev/null

python3 tools/organic_history/validate_scenario.py \
  data/organic_history/scenarios/earth_ancient_v0.sav \
  --output-dir runs/organic_history_scenario_gate \
  --turns 20 \
  --players 8 \
  --timeout 240

python3 tools/organic_history/region_diagnostics.py \
  --run-dir runs/organic_history_scenario_gate \
  --regions data/organic_history/scenario_regions.json \
  --output runs/organic_history_scenario_gate/region_metrics.json >/dev/null

if ! grep -q "organic_history_region" runs/organic_history_scenario_gate/server_*.log; then
  echo "FAIL: no organic_history_region logs found"
  exit 1
fi

if ! grep -q "organic_history_city_pressure" runs/organic_history_scenario_gate/server_*.log; then
  echo "FAIL: no organic_history_city_pressure logs found"
  exit 1
fi

if ! grep -q "organic_history_institution" runs/organic_history_scenario_gate/server_*.log; then
  echo "FAIL: no organic_history_institution logs found"
  exit 1
fi

if ! grep -q "organic_history_event_risk" runs/organic_history_scenario_gate/server_*.log; then
  echo "FAIL: no organic_history_event_risk logs found"
  exit 1
fi

echo "SUCCESS: scenario gate passed"
