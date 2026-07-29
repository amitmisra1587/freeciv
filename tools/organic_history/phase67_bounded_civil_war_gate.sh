#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

OUT="runs/phase67_bounded_civil_war_gate"
CONTROL="runs/phase67_bounded_civil_war_control"
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_medieval_v1.sav \
  --turns 3 \
  --players 7 \
  --saveturns 1 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$OUT" \
  --clean-output-dir \
  --extra-command 'lua cmd organic_history_political_transfer_contract_enabled = true; organic_history_mechanics_enabled = true; organic_history_civil_war_enabled = true; organic_history_civil_war_min_turn = 0; organic_history_civil_war_min_cities = 3; organic_history_civil_war_stress_threshold = 0; organic_history_civil_war_cooldown = 0; organic_history_civil_war_probability = 100'

grep -q 'organic_history_ownership_change .*loser=5 .*source="script" category="political_civil_war" reason="civil_war_bounded" success=true' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_mechanic type=civil_war_triggered .*player=5 successor=' \
  "$OUT/server_stdout.log"
if grep -q 'source="engine" category="political_civil_war" reason="civil_war"' \
    "$OUT/server_stdout.log"; then
  echo "Contract-enabled organic civil war used the raw bulk split" >&2
  exit 1
fi

SAVE="$(find "$OUT" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
python3 - <<'PY' "$SAVE"
import gzip
import re
import sys

text = gzip.open(sys.argv[1], "rt", encoding="utf-8").read()
parent = re.search(r"\[player5\]\n(.*?)(?=\n\[|\Z)", text, re.S)
assert parent
count = re.search(r"^ncities=(\d+)$", parent.group(1), re.M)
assert count and int(count.group(1)) >= 2, parent.group(1)
PY

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_medieval_v1.sav \
  --turns 3 \
  --players 7 \
  --saveturns 1 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$CONTROL" \
  --clean-output-dir \
  --extra-command 'lua cmd organic_history_political_transfer_contract_enabled = true; organic_history_mechanics_enabled = true; organic_history_civil_war_enabled = true; organic_history_civil_war_min_turn = 0; organic_history_civil_war_min_cities = 3; organic_history_civil_war_stress_threshold = 0; organic_history_civil_war_cooldown = 0; organic_history_civil_war_probability = 0'

if grep -q 'category="political_civil_war" reason="civil_war_bounded" success=true' \
    "$CONTROL/server_stdout.log"; then
  echo "Zero-probability bounded civil war transferred a city" >&2
  exit 1
fi

echo "Phase 67 bounded civil-war gate passed."
