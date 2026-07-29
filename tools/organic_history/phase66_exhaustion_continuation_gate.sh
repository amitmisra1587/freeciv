#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

INITIAL="runs/phase66_exhaustion_continuation_initial"
RESUMED="runs/phase66_exhaustion_continuation_resumed"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase66_condition_exhaustion_spike.json \
  --load-scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --turns 3 \
  --players 7 \
  --saveturns 1 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$INITIAL" \
  --clean-output-dir

SAVE="$(find "$INITIAL" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
test -n "$SAVE"
gzip -cd "$SAVE" >"$INITIAL/final.sav"
grep -q '^ai.strategy_source=2$' "$INITIAL/final.sav"
grep -q '^ai.strategy_posture=5$' "$INITIAL/final.sav"
grep -q '^ai.strategy_started_turn=1$' "$INITIAL/final.sav"
grep -q '^ai.strategy_war_started_turn=1$' "$INITIAL/final.sav"
grep -q '^ai.strategy_peak_intensity=786$' "$INITIAL/final.sav"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-save "$SAVE" \
  --turns 8 \
  --players 7 \
  --saveturns 4 \
  --timeout 900 \
  --output-dir "$RESUMED" \
  --clean-output-dir

grep -Eq 'organic_history_strategy_exhaustion .*player=4 .*war_turns=[2-9] ' \
  "$RESUMED/server_stdout.log"
grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="exhausted" posture="exhausted" reason="exhaustion_threshold"' \
  "$RESUMED/server_stdout.log"
grep -q 'organic_history_strategy_peace .*player=4 target=6 .*result="ceasefire"' \
  "$RESUMED/server_stdout.log"
grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="recover" posture="recover" reason="peace_obtained"' \
  "$RESUMED/server_stdout.log"

echo "Phase 66 exhaustion continuation gate passed."
