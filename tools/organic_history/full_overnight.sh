#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$ROOT"

tools/organic_history/gate.sh
tools/organic_history/campaign_gate.sh

python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --preset calibration_long \
  --output-dir runs/organic_history_calibration_long \
  --clean

python3 tools/organic_history/calibrate_thresholds.py \
  runs/organic_history_calibration_long \
  --output runs/organic_history_calibration_long/thresholds.json

python3 tools/organic_history/continuation_check.py \
  --ruleset-serv data/organic_history.serv \
  --seed 1 \
  --players 6 \
  --first-turns 80 \
  --final-turns 160 \
  --output-dir runs/organic_history_continuation_check \
  --clean

tools/organic_history/mechanics_gate.sh

python3 tools/organic_history/run_experiment.py \
  --ruleset-serv data/organic_history.serv \
  --preset mechanics_ab_long \
  --thresholds runs/organic_history_calibration_long/thresholds.json \
  --output-dir runs/organic_history_mechanics_ab_long \
  --clean
