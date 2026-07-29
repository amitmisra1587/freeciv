#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

OUT="runs/phase66_condition_exhaustion_gate"
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase66_condition_exhaustion_spike.json \
  --load-scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --turns 8 \
  --players 7 \
  --saveturns 7 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$OUT" \
  --clean-output-dir

grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="offensive" posture="offensive" .*expires=52 ' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_strategy_exhaustion .*player=4 .*score=0.175 .*war_turns=3 ' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="exhausted" posture="exhausted" reason="exhaustion_threshold"' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="temper" posture="offensive" reason="exhaustion_intensity" .*intensity=722 ' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_strategy_peace .*player=4 target=6 .*result="ceasefire"' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="recover" posture="recover" reason="peace_obtained"' \
  "$OUT/server_stdout.log"

OFFENSIVE_LINE="$(grep -n 'organic_history_strategy_state .*player=4 actor="rome" action="offensive"' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
TEMPER_LINE="$(grep -n 'organic_history_strategy_state .*player=4 actor="rome" action="temper"' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
EXHAUSTED_LINE="$(grep -n 'organic_history_strategy_state .*player=4 actor="rome" action="exhausted"' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
PEACE_LINE="$(grep -n 'organic_history_strategy_peace .*player=4 target=6' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
RECOVER_LINE="$(grep -n 'organic_history_strategy_state .*player=4 actor="rome" action="recover"' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
test "$OFFENSIVE_LINE" -lt "$EXHAUSTED_LINE"
test "$OFFENSIVE_LINE" -lt "$TEMPER_LINE"
test "$TEMPER_LINE" -lt "$EXHAUSTED_LINE"
test "$EXHAUSTED_LINE" -lt "$PEACE_LINE"
test "$PEACE_LINE" -lt "$RECOVER_LINE"

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
assert rows[6][0] != "War", rows[6]
started = re.search(r"^ai\.strategy_started_turn=(-?\d+)$",
                    section.group(1), re.M)
war_started = re.search(r"^ai\.strategy_war_started_turn=(-?\d+)$",
                        section.group(1), re.M)
assert started and int(started.group(1)) >= 1
assert war_started and int(war_started.group(1)) >= int(started.group(1))
PY

echo "Phase 66 condition exhaustion gate passed."
