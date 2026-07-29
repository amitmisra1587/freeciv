#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

INITIAL="runs/phase63_strategy_persistence_initial"
RESUMED="runs/phase63_strategy_persistence_resumed"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase62_overseas_strategy_spike.json \
  --load-scenario data/organic_history/scenarios/earth_1450_v1.sav \
  --turns 20 \
  --players 8 \
  --saveturns 5 \
  --seed 1 \
  --timeout 1200 \
  --output-dir "$INITIAL" \
  --clean-output-dir

SAVE="$(find "$INITIAL" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
test -n "$SAVE"

gzip -cd "$SAVE" >"$INITIAL/final.sav"
grep -q '^ai.strategy_version=1$' "$INITIAL/final.sav"
grep -q '^ai.strategy_posture=5$' "$INITIAL/final.sav"
grep -q '^ai.strategy_objective=2$' "$INITIAL/final.sav"
grep -q '^ai.strategy_target_player=7$' "$INITIAL/final.sav"
TARGET_CITY_ID="$(sed -n 's/^ai.strategy_target_city=//p' "$INITIAL/final.sav" | grep -v '^-1$' | head -1)"
test -n "$TARGET_CITY_ID"
grep -q '^ai.strategy_intensity=1000$' "$INITIAL/final.sav"
grep -q '^ai.strategy_war_desire_bonus=8000$' "$INITIAL/final.sav"
grep -q '^ai.strategy_conquest_worth_pct=1200$' "$INITIAL/final.sav"
grep -q '^ai.strategy_expires=122$' "$INITIAL/final.sav"
grep -q '^ai.strategy_campaign_id=62$' "$INITIAL/final.sav"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-save "$SAVE" \
  --turns 30 \
  --players 8 \
  --saveturns 5 \
  --timeout 1200 \
  --output-dir "$RESUMED" \
  --clean-output-dir \
  --extra-command 'lua cmd local p=find.player(1); local t=p:ai_strategy_target_player(); local c=p:ai_strategy_target_city(); log.normal("organic_history_strategy_resume posture=%q objective=%q target=%d city=%d intensity=%d war_bonus=%d conquest_pct=%d expires=%d campaign=%d integration_until=%d", p:ai_strategy_posture(), p:ai_strategy_objective(), t and t.id or -1, c and c.id or -1, p:ai_strategy_intensity(), p:ai_strategy_war_bonus(), p:ai_strategy_conquest_pct(), p:ai_strategy_expires(), p:ai_strategy_campaign(), p:ai_strategy_integration_until())'

grep -q "organic_history_strategy_resume posture=\"offensive\" objective=\"city\" target=7 city=${TARGET_CITY_ID} " \
  "$RESUMED/server_stdout.log"
grep -q 'intensity=1000 war_bonus=8000 conquest_pct=1200 expires=122 campaign=62 integration_until=-1' \
  "$RESUMED/server_stdout.log"

echo "Phase 63 strategy persistence gate passed."
