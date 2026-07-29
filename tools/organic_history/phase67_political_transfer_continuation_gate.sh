#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ninja -C build-organic

INITIAL="runs/phase67_political_transfer_continuation_initial"
RESUMED="runs/phase67_political_transfer_continuation_resumed"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase67_political_transfer_contract.json \
  --load-scenario data/organic_history/scenarios/earth_medieval_v1.sav \
  --turns 1 \
  --players 7 \
  --saveturns 1 \
  --seed 1 \
  --timeout 900 \
  --output-dir "$INITIAL" \
  --clean-output-dir \
  --extra-command 'lua cmd organic_history_political_batch_csv = "2:4:0:1:phase67_resume_batch:china"; organic_history_political_batch_hydrated_turn = 2'

SAVE="$(find "$INITIAL" -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
test -n "$SAVE"

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-save "$SAVE" \
  --turns 3 \
  --players 7 \
  --saveturns 1 \
  --timeout 900 \
  --output-dir "$RESUMED" \
  --clean-output-dir \
  --extra-command 'lua cmd local steppe=find.player(5); local franks=find.player(0); for city in franks:cities_iterate() do if city.name == "Beshbalik" then organic_history_transfer_city(city, steppe, "political_succession", "phase67_resume_reverse") end end; local chola=find.player(3); for city in chola:cities_iterate() do organic_history_transfer_city(city, franks, "political_secession", "phase67_resume_recovery"); break end; local song=find.player(4); for city in song:cities_iterate() do organic_history_transfer_city(city, franks, "political_secession", "phase67_resume_batch"); break end'

grep -q 'organic_history_political_transfer .*city="Beshbalik" .*reason="phase67_resume_reverse" applied=false skip_reason="reverse_transfer"' \
  "$RESUMED/server_stdout.log"
grep -q 'organic_history_political_transfer .*reason="phase67_resume_recovery" applied=false skip_reason="recovery_immunity"' \
  "$RESUMED/server_stdout.log"
grep -q 'organic_history_political_transfer .*reason="phase67_resume_batch" applied=false skip_reason="cluster_cap"' \
  "$RESUMED/server_stdout.log"

echo "Phase 67 political transfer continuation gate passed."
