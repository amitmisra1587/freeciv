#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$ROOT"

export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c@78/lib/pkgconfig:/opt/homebrew/opt/icu4c/lib/pkgconfig:/opt/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

if [ ! -d build-organic ]; then
  meson setup build-organic '-Dclients=[]' '-Dfcmp=[]' '-Dtools=[]' -Daudio=none -Dmwand=false -Dnls=false -Ddebug=true
fi

ninja -C build-organic
tools/organic_history/gate.sh
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --seeds 1-3 \
  --turns 50 \
  --players 6 \
  --saveturns 10 \
  --output-dir runs/organic_history_campaign_gate \
  --clean \
  --timeout 240
python3 -m json.tool runs/organic_history_campaign_gate/campaign_summary.json
