#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

OUT="runs/phase67_civil_war_lock_gate"
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_medieval_v1.sav \
  --turns 3 \
  --players 7 \
  --saveturns 1 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$OUT" \
  --clean-output-dir \
  --extra-command 'lua cmd organic_history_political_transfer_contract_enabled = true; organic_history_mechanics_enabled = true; organic_history_civil_war_enabled = true; organic_history_civil_war_min_turn = 0; organic_history_civil_war_min_cities = 1; organic_history_civil_war_stress_threshold = 0; organic_history_civil_war_cooldown = 0; organic_history_civil_war_probability = 100; local parent=find.player(5); local rebel=edit.civil_war(parent, 100); log.normal("phase67_civil_war_fixture parent=%d rebel=%d", parent.id, rebel and rebel.id or -1)'

grep -q 'phase67_civil_war_fixture parent=5 rebel=' "$OUT/server_stdout.log"
grep -q 'organic_history_ownership_change .*source="engine" category="political_civil_war" reason="civil_war"' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_integration_lock .*loser=5 .*reason="civil_war" integration_until=' \
  "$OUT/server_stdout.log"
grep -q 'organic_history_mechanic type=civil_war_skip turn=2 player=5 .*reason="recovery_immunity"' \
  "$OUT/server_stdout.log"

SAVE="$(find "$OUT" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
gzip -cd "$SAVE" >"$OUT/final.sav"
grep -Eq '^organic_history_political_recovery_csv="[^"]*5:[0-9]+:[0-9]+' \
  "$OUT/final.sav"

echo "Phase 67 civil-war lock gate passed."
