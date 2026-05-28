#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

python3 tools/organic_history/create_scenario_fixture.py --include-v1 >/dev/null

gate_dir=runs/organic_history_scenario_gate

python3 tools/organic_history/validate_scenario.py \
  data/organic_history/scenarios/earth_ancient_v0.sav \
  --output-dir "$gate_dir/earth_ancient_v0" \
  --turns 20 \
  --players 8 \
  --timeout 240

python3 tools/organic_history/region_diagnostics.py \
  --run-dir "$gate_dir/earth_ancient_v0" \
  --regions data/organic_history/scenario_regions.json \
  --output "$gate_dir/earth_ancient_v0/region_metrics.json" >/dev/null

python3 tools/organic_history/validate_scenario.py \
  data/organic_history/scenarios/earth_ancient_v1.sav \
  --starts-plan data/organic_history/scenarios/earth_ancient_v1_starts.json \
  --output-dir "$gate_dir/earth_ancient_v1" \
  --turns 20 \
  --players 7 \
  --timeout 240

python3 tools/organic_history/region_diagnostics.py \
  --run-dir "$gate_dir/earth_ancient_v1" \
  --regions data/organic_history/scenario_regions.json \
  --output "$gate_dir/earth_ancient_v1/region_metrics.json" >/dev/null

if ! grep -q "organic_history_region" "$gate_dir"/earth_ancient_v*/server_*.log; then
  echo "FAIL: no organic_history_region logs found"
  exit 1
fi

if ! grep -q "organic_history_city_pressure" "$gate_dir"/earth_ancient_v*/server_*.log; then
  echo "FAIL: no organic_history_city_pressure logs found"
  exit 1
fi

if ! grep -q "organic_history_institution" "$gate_dir"/earth_ancient_v*/server_*.log; then
  echo "FAIL: no organic_history_institution logs found"
  exit 1
fi

if ! grep -q "organic_history_event_risk" "$gate_dir"/earth_ancient_v*/server_*.log; then
  echo "FAIL: no organic_history_event_risk logs found"
  exit 1
fi

echo "SUCCESS: scenario gate passed"
