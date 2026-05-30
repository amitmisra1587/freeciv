#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_global_4000_gate

python3 -m json.tool data/organic_history/scenarios/earth_global_4000_v1_starts.json >/dev/null
python3 -m json.tool data/organic_history/scenarios/earth_global_4000_timeline.json >/dev/null

python3 tools/organic_history/validate_scenario.py \
  data/organic_history/scenarios/earth_global_4000_v1.sav \
  --starts-plan data/organic_history/scenarios/earth_global_4000_v1_starts.json \
  --turns 20 \
  --players 4 \
  --output-dir "$gate_dir/validate" \
  --timeout 300 >/dev/null

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --turns 70 \
  --players 4 \
  --saveturns 10 \
  --output-dir "$gate_dir/emergence" \
  --clean-output-dir \
  --timeout 420 \
  --extra-command "lua cmd organic_history_mechanics_enabled = true" \
  --extra-command "lua cmd organic_history_emergence_enabled = true" \
  --extra-command "lua cmd organic_history_emergence_probability = 100" >/dev/null

for actor in greece persia rome; do
  if ! grep -q "organic_history_emergence .*actor=\"$actor\" action=\"spawned\"" "$gate_dir"/emergence/server_*.log; then
    echo "FAIL: expected emergence for $actor"
    exit 1
  fi
done

if ! grep -q 'organic_history_city_pressure .*city="Roma".*region="europe"' "$gate_dir"/emergence/server_*.log; then
  echo "FAIL: emerged Rome did not use European city metadata"
  exit 1
fi

save=$(python3 - "$gate_dir/emergence/run_metadata.json" <<'PY'
import json
import sys
from pathlib import Path

print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["finalSave"])
PY
)

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-save "$save" \
  --turns 90 \
  --players 7 \
  --saveturns 10 \
  --output-dir "$gate_dir/continued" \
  --clean-output-dir \
  --timeout 300 \
  --extra-command "lua cmd organic_history_mechanics_enabled = true" \
  --extra-command "lua cmd organic_history_emergence_enabled = true" \
  --extra-command "lua cmd organic_history_emergence_probability = 100" >/dev/null

python3 - "$gate_dir/continued/run_metadata.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
checks = {
    "success": metadata.get("success"),
    "advanced": metadata.get("continuationAdvanced"),
    "metadata": metadata.get("scenarioMetadataActive"),
    "metrics": int(metadata.get("organicMetricLogCount") or 0) > 0,
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: continued global checks failed: {checks}")
PY

echo "SUCCESS: global 4000 gate passed"
