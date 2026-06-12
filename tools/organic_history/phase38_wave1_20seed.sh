#!/bin/sh
# Phase 38 Wave 1 20-seed regression launcher.
#
# Launch only AFTER the Phase 38 Wave 1 6-seed activation check returns clean
# (no new failures vs same-seed control). Compares Wave 1 (tech floor enabled)
# against the Phase 33 baseline (current accepted candidate) at the same seed
# count as the Phase 33 rebaseline, so the comparison is apples-to-apples.
set -eu

cd "$(dirname "$0")/../.."

python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase38_wave1_tech_floor.json \
  --seeds 1-20 \
  --turns 200 \
  --players 4 \
  --saveturns 200 \
  --output-dir runs/organic_history_phase38_wave1_20x200 \
  --clean \
  --jobs 6 \
  --max-load-average 18 \
  --load-check-interval 30 \
  --timeout 1800

python3 tools/organic_history/global_historical_fit_report.py \
  --sweep-dir runs/organic_history_phase38_wave1_20x200 \
  --output runs/organic_history_phase38_wave1_20x200/fit_report.json

python3 tools/organic_history/phase38_wave1_compare.py \
  --candidate runs/organic_history_phase38_wave1_20x200 \
  --control runs/organic_history_phase33_current_candidate_20x200 \
  --output runs/organic_history_phase38_wave1_20x200/wave1_vs_phase33_report.json

echo
echo "Phase 38 Wave 1 vs Phase 33 baseline report:"
python3 -c "import json; d=json.load(open('runs/organic_history_phase38_wave1_20x200/wave1_vs_phase33_report.json')); print(json.dumps({'verdict':d['verdict'],'newFailures':d['newFailures'],'newPasses':d['newPasses'],'candidateStatusCounts':d['candidateStatusCounts'],'controlStatusCounts':d['controlStatusCounts']},indent=2,sort_keys=True))"
