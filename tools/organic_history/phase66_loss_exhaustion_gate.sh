#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

OUT="runs/phase66_loss_exhaustion_gate"
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase66_loss_exhaustion_spike.json \
  --load-scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --turns 8 \
  --players 7 \
  --saveturns 15 \
  --seed 1 \
  --timeout 1800 \
  --output-dir "$OUT" \
  --clean-output-dir

grep -Eq 'organic_history_strategy_exhaustion .*player=4 .*score=0\.[0-9]+ losses=[1-9][0-9]* ' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="exhausted" posture="exhausted" reason="exhaustion_threshold"' \
  "$OUT/server_stdout.log"

python3 - <<'PY'
import re
from pathlib import Path

log = Path("runs/phase66_loss_exhaustion_gate/server_stdout.log").read_text()
events = [
    (int(turn), float(score), int(losses), int(war_turns), float(duration))
    for turn, score, losses, war_turns, duration in re.findall(
        r"organic_history_strategy_exhaustion turn=(\d+) player=4 .*?"
        r"score=([0-9.]+) losses=(\d+) .*?war_turns=(\d+) "
        r"duration=([0-9.]+)",
        log,
    )
]
assert events
trigger = re.search(
    r'organic_history_strategy_state turn=(\d+) player=4 actor="rome" '
    r'action="exhausted" posture="exhausted" reason="exhaustion_threshold"',
    log,
)
assert trigger
trigger_turn = int(trigger.group(1))
eligible = [event for event in events if event[0] <= trigger_turn]
assert eligible
last = eligible[-1]
assert last[2] > 0, last
assert last[4] < 0.10, last
assert last[1] >= 0.05, last
PY

echo "Phase 66 loss exhaustion gate passed."
