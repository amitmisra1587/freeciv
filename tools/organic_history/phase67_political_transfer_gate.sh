#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

OUT="runs/phase67_political_transfer_gate"
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase67_political_transfer_contract.json \
  --load-scenario data/organic_history/scenarios/earth_medieval_v1.sav \
  --turns 3 \
  --players 7 \
  --saveturns 1 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$OUT" \
  --clean-output-dir

grep -q 'organic_history_political_transfer .*city="Beshbalik" .*reason="phase67_cluster" applied=true ' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_political_transfer .*city="Sarai" .*reason="phase67_cluster" applied=false skip_reason="cluster_cap"' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_political_transfer .*city="Sarai" .*reason="phase67_second" applied=true ' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_political_transfer .*city="Karakorum" .*reason="phase67_last_core" applied=false skip_reason="retained_core"' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_political_transfer .*city="Beshbalik" .*reason="phase67_reverse" applied=false skip_reason="reverse_transfer"' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_political_transfer .*reason="phase67_recovery_followup" applied=false skip_reason="recovery_immunity"' \
  "$OUT/server_stdout.log"

SAVE="$(find "$OUT" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
python3 - <<'PY' "$SAVE"
import gzip
import csv
import io
import re
import sys

text = gzip.open(sys.argv[1], "rt", encoding="utf-8").read()
player = re.search(r"\[player5\]\n(.*?)(?=\n\[|\Z)", text, re.S)
assert player
assert re.search(r"^ncities=1$", player.group(1), re.M), player.group(1)
cities = {}
for match in re.finditer(r"^c=\{([^\n]+)\n(.*?)^\}$", text, re.M | re.S):
    header = next(csv.reader(io.StringIO(match.group(1))))
    for row in csv.reader(io.StringIO(match.group(2))):
        city = dict(zip(header, row))
        cities[city["name"]] = city
for name in ("Beshbalik", "Sarai", "Kanchipuram"):
    assert int(cities[name]["organic_history_integration_until"]) >= 20, (
        name,
        cities[name],
    )
assert re.search(
    r'^organic_history_political_recovery_csv="[^"]+"$', text, re.M
), "missing persisted recovery immunity"
PY

echo "Phase 67 political transfer contract gate passed."
