#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_global_4000_bootstrap_gate
scenario=data/organic_history/scenarios/earth_global_4000_v1.sav
profile=tools/organic_history/profiles/global_4000_bootstrap_candidate.json

python3 -m json.tool "$profile" >/dev/null
python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py \
  tools/organic_history/global_historical_fit_report.py
python3 tools/organic_history/generate_history_artifacts.py --check >/dev/null

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile "$profile" \
  --load-scenario "$scenario" \
  --turns 70 \
  --players 4 \
  --saveturns 10 \
  --output-dir "$gate_dir/bootstrap" \
  --clean-output-dir \
  --timeout 600 \
  --extra-command "lua cmd organic_history_emergence_probability = 100" >/dev/null

for actor in greece persia rome; do
  if ! grep -q "organic_history_bootstrap .*actor=\"$actor\".*applied=true" "$gate_dir"/bootstrap/server_*.log; then
    echo "FAIL: expected bootstrap for $actor"
    exit 1
  fi
done

python3 - "$gate_dir/bootstrap/run_metadata.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "bootstrap_logs": int(metadata.get("organicBootstrapLogCount") or 0) >= 3,
    "metadata": metadata.get("scenarioMetadataActive"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: bootstrap gate checks failed: {checks}")
PY

echo "SUCCESS: global 4000 bootstrap gate passed"
