#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_global_4000_lifecycle_gate
scenario=data/organic_history/scenarios/earth_global_4000_v1.sav
starts_plan=data/organic_history/scenarios/earth_global_4000_v1_starts.json
timeline=data/organic_history/scenarios/earth_global_4000_timeline.json
profile=tools/organic_history/profiles/global_4000_emergence_candidate.json

python3 -m json.tool "$starts_plan" >/dev/null
python3 -m json.tool "$timeline" >/dev/null
python3 -m json.tool "$profile" >/dev/null
python3 tools/organic_history/generate_history_artifacts.py --check >/dev/null

python3 tools/organic_history/validate_scenario.py \
  "$scenario" \
  --starts-plan "$starts_plan" \
  --turns 20 \
  --players 4 \
  --output-dir "$gate_dir/validate" \
  --timeout 300 >/dev/null

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile "$profile" \
  --load-scenario "$scenario" \
  --turns 200 \
  --players 4 \
  --saveturns 25 \
  --output-dir "$gate_dir/smoke_200" \
  --clean-output-dir \
  --timeout 2400 >/dev/null

save=$(
  python3 - "$gate_dir/smoke_200/run_metadata.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "final_turn": int(metadata.get("finalTurnSeen") or 0) >= 201,
    "metadata": metadata.get("scenarioMetadataActive"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: 200-turn global lifecycle checks failed: {checks}")
print(metadata["finalSave"])
PY
)

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --profile "$profile" \
  --load-save "$save" \
  --turns 220 \
  --players 18 \
  --saveturns 5 \
  --output-dir "$gate_dir/continued_220" \
  --clean-output-dir \
  --timeout 900 >/dev/null

python3 - "$gate_dir/continued_220/run_metadata.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
checks = {
    "success": metadata.get("success"),
    "advanced": metadata.get("continuationAdvanced"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "metadata": metadata.get("scenarioMetadataActive"),
    "metrics": int(metadata.get("organicMetricLogCount") or 0) > 0,
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: continued global lifecycle checks failed: {checks}")
PY

echo "SUCCESS: global 4000 lifecycle gate passed"
