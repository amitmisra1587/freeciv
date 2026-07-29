#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

OUT="runs/phase67_engine_capture_lock_gate"
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase62_land_strategy_spike.json \
  --load-scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --turns 80 \
  --players 7 \
  --saveturns 20 \
  --seed 1 \
  --timeout 1800 \
  --output-dir "$OUT" \
  --clean-output-dir \
  --extra-command 'lua cmd organic_history_political_transfer_contract_enabled = true'

grep -q 'organic_history_ownership_change .*source="engine" category="engine_combat" reason="conquest"' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_integration_lock .*loser=5 winner=4 reason="conquest" integration_until=' \
  "$OUT/server_stdout.log"

SAVE="$(find "$OUT" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
python3 - <<'PY' "$SAVE"
import csv
import gzip
import io
import re
import sys

text = gzip.open(sys.argv[1], "rt", encoding="utf-8").read()
cities = {}
for match in re.finditer(r"^c=\{([^\n]+)\n(.*?)^\}$", text, re.M | re.S):
    header = next(csv.reader(io.StringIO(match.group(1))))
    for row in csv.reader(io.StringIO(match.group(2))):
        city = dict(zip(header, row))
        cities[city["name"]] = city
athens = cities.get("Athens")
assert athens is not None, cities.keys()
assert int(athens["organic_history_integration_until"]) > 0, athens
assert int(athens["organic_history_previous_owner_plus1"]) == 6, athens
PY

echo "Phase 67 engine capture lock gate passed."
