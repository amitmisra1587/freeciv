#!/bin/sh
# Phase 43 cross-scenario generalization gate.
#
# Validates that the Wave 3 (claim conversion) mechanic still fires and behaves
# on a NON-global fixture (default earth_medieval_v1, an 80x50 map that uses the
# default region/claim tables). Runs a small same-seed A/B (Wave 3 vs
# mechanics-off control) through run_experiment --scenario, then scores it with
# phase43_scenario_generalization.py. The gate passes when the mechanic is
# ACTIVE and NON-REGRESSIVE (verdict generalizes or active_inconclusive); it
# fails on inert (mechanic does not fire) or regresses (new assertions/collapse).
#
# Env overrides: FIXTURE, SEEDS, TURNS, PLAYERS, JOBS, MAX_LOAD.
set -eu

cd "$(dirname "$0")/../.."

fixture="${FIXTURE:-earth_medieval_v1}"
seeds="${SEEDS:-1-2}"
turns="${TURNS:-120}"
players="${PLAYERS:-7}"
jobs="${JOBS:-2}"
max_load="${MAX_LOAD:-14}"

scenario="data/organic_history/scenarios/${fixture}.sav"
profile="tools/organic_history/profiles/phase38_wave3_claim_conversion.json"
gate_dir="runs/organic_history_phase43_generalization_gate/${fixture}"

python3 -m py_compile \
  tools/organic_history/run_experiment.py \
  tools/organic_history/run_campaign.py \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py \
  tools/organic_history/phase43_scenario_generalization.py

if [ ! -f "$scenario" ]; then
  echo "ERROR: scenario fixture not found: $scenario" >&2
  exit 2
fi

server="$(find build-organic -type f \( -name freeciv-server -o -name fcser \) 2>/dev/null | head -n 1 || true)"
if [ -z "$server" ]; then
  echo "ERROR: Freeciv server binary not found. Build first with:" >&2
  echo "  meson setup build-organic -Dclients=[] -Dfcmp=[] -Dtools=[] -Ddebug=true && ninja -C build-organic" >&2
  exit 2
fi

python3 tools/organic_history/run_experiment.py \
  --scenario "$scenario" \
  --profile "$profile" \
  --label "p43_gate_${fixture}" \
  --seeds "$seeds" \
  --turns "$turns" \
  --players "$players" \
  --saveturns "$turns" \
  --timeout 1200 \
  --jobs "$jobs" \
  --max-load-average "$max_load" \
  --load-check-interval 30 \
  --output-dir "$gate_dir" \
  --clean >/dev/null

baseline_dir="$gate_dir/baseline"
candidate_dir="$(find "$gate_dir" -maxdepth 1 -type d -name "p43_gate_${fixture}_*" ! -name "*_baseline" | head -n 1)"

if [ -z "$candidate_dir" ]; then
  echo "ERROR: could not locate candidate arm under $gate_dir" >&2
  exit 1
fi

python3 tools/organic_history/phase43_scenario_generalization.py \
  --candidate "$candidate_dir" \
  --control "$baseline_dir" \
  --fixture "$fixture" \
  --output "$gate_dir/phase43_generalization_report.json" \
  | tee "$gate_dir/phase43_generalization_compact.json"

python3 - "$gate_dir/phase43_generalization_report.json" <<'PY'
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
verdict = report.get("verdict")
criteria = report.get("criteria", {})

ok = verdict in ("generalizes", "active_inconclusive")
if not ok:
    print(f"FAIL: verdict={verdict}", file=sys.stderr)
    print("criteria:", json.dumps(criteria, sort_keys=True), file=sys.stderr)
    raise SystemExit(1)

print(f"SUCCESS: Phase 43 generalization gate passed ({verdict})")
print("criteria:", json.dumps(criteria, sort_keys=True))
PY
