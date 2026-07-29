#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

INITIAL="runs/phase65_strategy_cleanup_initial"
RESUMED="runs/phase65_strategy_cleanup_resumed"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase65_strategy_market_spike.json \
  --load-scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --turns 4 \
  --players 7 \
  --saveturns 2 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$INITIAL" \
  --clean-output-dir

SAVE="$(find "$INITIAL" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
test -n "$SAVE"
gzip -cd "$SAVE" >"$INITIAL/final.sav"
grep -q '^ai.strategy_source=2$' "$INITIAL/final.sav"
grep -q '^ai.strategy_posture=5$' "$INITIAL/final.sav"
grep -q '^ai.strategy_planned_war_target=6$' "$INITIAL/final.sav"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-save "$SAVE" \
  --turns 6 \
  --players 7 \
  --saveturns 2 \
  --timeout 900 \
  --output-dir "$RESUMED" \
  --clean-output-dir \
  --extra-command 'lua cmd organic_history_strategy_market_enabled = false'

grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="clear" .*reason="market_disabled"' \
  "$RESUMED/server_stdout.log"
grep -q 'organic_history_strategy_war_plan .*player=4 target=6 .*result="cancelled"' \
  "$RESUMED/server_stdout.log"

FINAL="$(find "$RESUMED" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
python3 - <<'PY' "$FINAL"
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
assert rows[6][0] != "War", rows[6]
assert re.search(r"^ai\.strategy_source=0$", section.group(1), re.M)
assert re.search(r"^ai\.strategy_planned_war_target=-1$",
                 section.group(1), re.M)
PY

echo "Phase 65 strategy cleanup gate passed."
