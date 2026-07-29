#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

OUT="runs/phase65_strategy_market_gate"
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase65_strategy_market_spike.json \
  --load-scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --turns 14 \
  --players 7 \
  --saveturns 7 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$OUT" \
  --clean-output-dir

grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="prepare" posture="prepare" .*target=6 ' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="offensive" posture="offensive" .*target=6 ' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_strategy_war_plan .*player=4 target=6 ' \
  "$OUT/server_stdout.log"
if grep -q 'organic_history_strategy_spike .*action="war" attacker=4 target=6' \
    "$OUT/server_stdout.log"; then
  echo "Phase 65 fixture used the scripted war spike" >&2
  exit 1
fi

PREPARE_LINE="$(grep -n 'organic_history_strategy_state .*player=4 actor="rome" action="prepare"' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
OFFENSIVE_LINE="$(grep -n 'organic_history_strategy_state .*player=4 actor="rome" action="offensive"' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
WAR_PLAN_LINE="$(grep -n 'organic_history_strategy_war_plan .*player=4 target=6' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
test "$PREPARE_LINE" -lt "$OFFENSIVE_LINE"
test "$OFFENSIVE_LINE" -lt "$WAR_PLAN_LINE"

SAVE="$(find "$OUT" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
python3 - <<'PY' "$SAVE"
import csv
import gzip
import io
import re
import sys

text = gzip.open(sys.argv[1], "rt", encoding="utf-8").read()
section = re.search(r"\[player4\]\n(.*?)(?=\n\[|\Z)", text, re.S)
assert section
block = re.search(r"diplstate=\{[^\n]*\n(.*?)\n\}", section.group(1), re.S)
assert block
rows = list(csv.reader(io.StringIO(block.group(1))))
assert len(rows) > 6
assert rows[6][0] == "War", rows[6]
strategy = dict(re.findall(r"^ai\.strategy_([^=]+)=(.*)$",
                           section.group(1), re.M))
assert strategy.get("posture") == "5", strategy
assert strategy.get("source") == "2", strategy
assert int(strategy.get("target_player", "-1")) == 6, strategy
assert int(strategy.get("campaign_id", "0")) >= 100000, strategy
PY

echo "Phase 65 strategy market gate passed."
