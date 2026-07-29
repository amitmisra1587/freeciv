#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

INITIAL="runs/phase67_decline_warning_initial"
RESUMED="runs/phase67_decline_warning_resumed"
COOLDOWN="runs/phase67_decline_warning_cooldown"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase67_decline_warning_spike.json \
  --load-scenario data/organic_history/scenarios/earth_medieval_v1.sav \
  --turns 1 \
  --players 7 \
  --saveturns 1 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$INITIAL" \
  --clean-output-dir

grep -q 'organic_history_decline_stage turn=1 actor="steppe" stage="administrative_pressure" streak=1 threshold=4' \
  "$INITIAL/server_stdout.log"
grep -q 'organic_history_decline_stage turn=2 actor="steppe" stage="autonomy_warning" streak=2 threshold=4' \
  "$INITIAL/server_stdout.log"
grep -q 'organic_history_decline_stage turn=3 actor="steppe" stage="separatism_warning" streak=3 threshold=4' \
  "$INITIAL/server_stdout.log"

SAVE="$(find "$INITIAL" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
gzip -cd "$SAVE" >"$INITIAL/final.sav"
grep -q '^organic_history_political_decline_streaks_csv="steppe:3"$' \
  "$INITIAL/final.sav"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-save "$SAVE" \
  --turns 4 \
  --players 7 \
  --saveturns 1 \
  --timeout 900 \
  --output-dir "$RESUMED" \
  --clean-output-dir \
  --extra-command 'lua cmd local steppe=find.player(5); local risk={era_over_capacity=true, collapse_risk=1, total=steppe:num_cities(), core_pop=100, era_load_ratio=1}; local claims={core={"europe"}, historical={}, contested={}}; organic_history_check_decisive_collapse(4, steppe, "steppe", risk, claims)'

grep -q 'organic_history_decline_stage turn=4 actor="steppe" stage="bounded_release" streak=4 threshold=4' \
  "$RESUMED/server_stdout.log"
grep -q 'organic_history_political_transfer .*category="political_collapse" reason="decisive_collapse_fragment" applied=true ' \
  "$RESUMED/server_stdout.log"
grep -q 'organic_history_political_transfer .*category="political_collapse" reason="decisive_collapse_fragment" applied=false skip_reason="cluster_cap"' \
  "$RESUMED/server_stdout.log"
grep -q 'organic_history_decisive_collapse turn=4 actor="steppe" action="fragment" cities_before=3 shed=1 ' \
  "$RESUMED/server_stdout.log"

RESUMED_SAVE="$(find "$RESUMED" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
gzip -cd "$RESUMED_SAVE" >"$RESUMED/final.sav"
grep -q '^organic_history_political_decline_last_csv="steppe:4"$' \
  "$RESUMED/final.sav"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-save "$RESUMED_SAVE" \
  --turns 7 \
  --players 8 \
  --saveturns 1 \
  --timeout 900 \
  --output-dir "$COOLDOWN" \
  --clean-output-dir \
  --extra-command 'lua cmd local steppe=find.player(5); local risk={era_over_capacity=true, collapse_risk=1, total=steppe:num_cities(), core_pop=100, era_load_ratio=1}; local claims={core={"europe"}, historical={}, contested={}}; organic_history_political_decline_set("steppe", 3); organic_history_check_decisive_collapse(5, steppe, "steppe", risk, claims)'

grep -q 'organic_history_decline_stage turn=5 actor="steppe" stage="bounded_release" streak=4 threshold=4' \
  "$COOLDOWN/server_stdout.log"
if grep -q 'reason="decisive_collapse_fragment" applied=true' \
    "$COOLDOWN/server_stdout.log"; then
  echo "Persisted collapse cooldown was bypassed" >&2
  exit 1
fi

echo "Phase 67 decline warning gate passed."
