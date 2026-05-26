#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$ROOT"

export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c@78/lib/pkgconfig:/opt/homebrew/opt/icu4c/lib/pkgconfig:/opt/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

if [ ! -d build-organic ]; then
  meson setup build-organic '-Dclients=[]' '-Dfcmp=[]' '-Dtools=[]' -Daudio=none -Dmwand=false -Dnls=false -Ddebug=true
fi

ninja -C build-organic
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --turns 20 \
  --players 4 \
  --output-dir runs/organic_history_gate \
  --clean-output-dir
