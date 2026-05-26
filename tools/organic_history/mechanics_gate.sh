#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$ROOT"

export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c@78/lib/pkgconfig:/opt/homebrew/opt/icu4c/lib/pkgconfig:/opt/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

if [ ! -d build-organic ]; then
  meson setup build-organic '-Dclients=[]' '-Dfcmp=[]' '-Dtools=[]' -Daudio=none -Dmwand=false -Dnls=false -Ddebug=true
fi

ninja -C build-organic
python3 tools/organic_history/run_experiment.py \
  --ruleset-serv data/organic_history.serv \
  --preset mechanics_probe \
  --output-dir runs/organic_history_mechanics_gate \
  --clean
python3 -m json.tool runs/organic_history_mechanics_gate/experiment_summary.json
