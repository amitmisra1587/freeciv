#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

OUT="runs/phase62_overseas_strategy_gate"
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase62_overseas_strategy_spike.json \
  --load-scenario data/organic_history/scenarios/earth_1450_v1.sav \
  --turns 150 \
  --players 8 \
  --saveturns 15 \
  --seed 1 \
  --timeout 3000 \
  --output-dir "$OUT" \
  --clean-output-dir

python3 tools/organic_history/analyze_campaign.py \
  --run-dir "$OUT" \
  --output "$OUT/run_summary.json" >/dev/null

python3 - <<'PY'
import json
import re
from pathlib import Path

summary = json.loads(
    Path("runs/phase62_overseas_strategy_gate/run_summary.json").read_text()
)
log = Path("runs/phase62_overseas_strategy_gate/server_stdout.log").read_text()
ownership = summary["ownershipChanges"]
setup = re.search(
    r'action="setup" attacker=1 target=7 city="Cusco" city_id=(\d+)',
    log,
)
assert setup
target_city_id = int(setup.group(1))
combat = [
    event for event in ownership["events"]
    if event.get("category") == "engine_combat"
]
target = [
    event for event in combat
    if event.get("city_id") == target_city_id
    and event.get("winner") == 1
    and event.get("loser") == 7
    and event.get("turn", 999) <= 122
]
assert summary["success"]
assert log.count('action="setup"') == 1
assert 'organic_history_strategy_ai' in log
assert target, ownership
assert ownership["sources"].get("script", 0) == 0
PY

echo "Phase 62 overseas strategy gate passed."
