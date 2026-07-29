#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

INITIAL="runs/phase65_strategy_continuation_initial"
RESUMED="runs/phase65_strategy_continuation_resumed"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase65_strategy_market_spike.json \
  --load-scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --turns 2 \
  --players 7 \
  --saveturns 1 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$INITIAL" \
  --clean-output-dir

SAVE="$(find "$INITIAL" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
test -n "$SAVE"
gzip -cd "$SAVE" >"$INITIAL/final.sav"
grep -q '^organic_history_strategy_market_enabled=true$' "$INITIAL/final.sav"
grep -q '^organic_history_strategy_actor_filter_csv="rome"$' \
  "$INITIAL/final.sav"
grep -q '^ai.strategy_posture=4$' "$INITIAL/final.sav"
grep -q '^ai.strategy_source=2$' "$INITIAL/final.sav"
grep -q '^ai.strategy_target_player=6$' "$INITIAL/final.sav"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-save "$SAVE" \
  --turns 8 \
  --players 7 \
  --saveturns 4 \
  --timeout 900 \
  --output-dir "$RESUMED" \
  --clean-output-dir

grep -q 'organic_history_strategy_state .*player=4 actor="rome" action="offensive" posture="offensive" .*target=6 ' \
  "$RESUMED/server_stdout.log"
grep -q 'organic_history_strategy_war_plan .*player=4 target=6 ' \
  "$RESUMED/server_stdout.log"
if grep -Eq 'organic_history_strategy_state .*player=([0-35-9]|[1-9][0-9]+) ' \
    "$RESUMED/server_stdout.log"; then
  echo "Saved actor filter was not preserved" >&2
  exit 1
fi

echo "Phase 65 strategy continuation gate passed."
