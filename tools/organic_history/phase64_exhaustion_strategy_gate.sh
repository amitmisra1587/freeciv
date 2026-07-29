#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

OUT="runs/phase64_exhaustion_strategy_gate"
HOSTILE="runs/phase64_exhaustion_hostile_control"
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase64_exhaustion_strategy_spike.json \
  --load-scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --turns 12 \
  --players 7 \
  --saveturns 10 \
  --seed 1 \
  --timeout 1200 \
  --output-dir "$OUT" \
  --clean-output-dir

grep -q 'action="war" attacker=4 target=6' "$OUT/server_stdout.log"
grep -q 'action="exhausted" attacker=4 target=6 posture="exhausted"' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_strategy_peace .*player=4 target=6 .*result="ceasefire"' \
  "$OUT/server_stdout.log"
WAR_LINE="$(grep -n 'action="war" attacker=4 target=6' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
EXHAUST_LINE="$(grep -n 'action="exhausted" attacker=4 target=6' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
PEACE_LINE="$(grep -n 'organic_history_strategy_peace .*player=4 target=6' "$OUT/server_stdout.log" | head -1 | cut -d: -f1)"
test "$WAR_LINE" -lt "$EXHAUST_LINE"
test "$EXHAUST_LINE" -lt "$PEACE_LINE"
grep -q 'organic_history_strategy_build' "$OUT/server_stdout.log"

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
assert rows[6][0] != "War", rows[6]
ai = re.search(r"ai=\{[^\n]*\n(.*?)\n\}", section.group(1), re.S)
assert ai
ai_rows = list(csv.reader(io.StringIO(ai.group(1))))
assert int(ai_rows[6][0]) < 0, ai_rows[6]
PY

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase64_exhaustion_hostile_control.json \
  --load-scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --turns 12 \
  --players 7 \
  --saveturns 10 \
  --seed 1 \
  --timeout 1200 \
  --output-dir "$HOSTILE" \
  --clean-output-dir

if grep -q 'organic_history_strategy_peace .*player=4 target=6' \
    "$HOSTILE/server_stdout.log"; then
  echo "Hostile control accepted an exhausted ceasefire" >&2
  exit 1
fi

HOSTILE_SAVE="$(find "$HOSTILE" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
python3 - <<'PY' "$HOSTILE_SAVE"
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
assert rows[6][0] == "War", rows[6]
PY

echo "Phase 64 exhaustion strategy gate passed."
