#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

OUT="runs/phase67_peaceful_handoff_gate"
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --turns 2 \
  --players 7 \
  --saveturns 1 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$OUT" \
  --clean-output-dir \
  --extra-command 'lua cmd organic_history_political_transfer_contract_enabled = true; organic_history_political_max_cluster = 3; organic_history_independent_player_id = 6; local donor=find.player(6); local recipient=find.player(4); local cities={}; for city in donor:cities_iterate() do table.insert(cities, city) end; for _,city in ipairs(cities) do organic_history_transfer_city(city, recipient, "political_peaceful_handoff", "independent_absorption") end'

test "$(grep -c 'organic_history_political_transfer .*category="political_peaceful_handoff" reason="independent_absorption" applied=true ' "$OUT/server_stdout.log")" -eq 2
if grep -q 'organic_history_political_transfer .*reason="independent_absorption" applied=false skip_reason="recovery_immunity"' \
    "$OUT/server_stdout.log"; then
  echo "Independent handoff incorrectly received recovery immunity" >&2
  exit 1
fi

SAVE="$(find "$OUT" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
gzip -cd "$SAVE" >"$OUT/final.sav"
if grep -Eq '^organic_history_political_recovery_csv="[^"]*6:' \
    "$OUT/final.sav"; then
  echo "Independent donor was persisted with recovery immunity" >&2
  exit 1
fi

echo "Phase 67 peaceful handoff gate passed."
