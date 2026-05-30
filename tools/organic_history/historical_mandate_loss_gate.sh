#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

profile=tools/organic_history/profiles/historical_mandate_loss_candidate.json
gate_dir=runs/organic_history_historical_mandate_loss_gate

python3 -m json.tool "$profile" >/dev/null

rm -rf "$gate_dir"
mkdir -p "$gate_dir"

run_candidate() {
  name=$1
  scenario=$2
  players=$3

  python3 tools/organic_history/run_campaign.py \
    --ruleset-serv data/organic_history.serv \
    --profile "$profile" \
    --scenario "$scenario" \
    --seeds 1 \
    --turns 40 \
    --players "$players" \
    --saveturns 10 \
    --timeout 240 \
    --output-dir "$gate_dir/$name" \
    --label "historical_mandate_loss_${name}" \
    --clean >/dev/null

  python3 - "$gate_dir/$name/campaign_summary.json" <<'PY'
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
aggregate = summary.get("aggregate", {})
if summary.get("runsSucceeded") != 1 or summary.get("runsFailed") != 0:
    raise SystemExit(f"FAIL: campaign did not succeed: {sys.argv[1]}")
if int(aggregate.get("organicStateCapacityLogs") or 0) <= 0:
    raise SystemExit(f"FAIL: no state-capacity logs: {sys.argv[1]}")
if int(aggregate.get("organicDynasticProbeLogs") or 0) <= 0:
    raise SystemExit(f"FAIL: no dynastic probe logs: {sys.argv[1]}")
PY
}

run_resume() {
  name=$1
  scenario=$2
  players=$3
  source_dir="$gate_dir/${name}_source"
  continued_dir="$gate_dir/${name}_continued"

  python3 tools/organic_history/run_ai_game.py \
    --ruleset-serv data/organic_history.serv \
    --profile "$profile" \
    --load-scenario "$scenario" \
    --turns 10 \
    --players "$players" \
    --saveturns 5 \
    --output-dir "$source_dir" \
    --timeout 180 >/dev/null

  save=$(python3 - "$source_dir/run_metadata.json" <<'PY'
import json
import sys
from pathlib import Path

print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["finalSave"])
PY
)

  python3 tools/organic_history/run_ai_game.py \
    --ruleset-serv data/organic_history.serv \
    --profile "$profile" \
    --load-save "$save" \
    --turns 20 \
    --players "$players" \
    --saveturns 5 \
    --output-dir "$continued_dir" \
    --timeout 180 >/dev/null

  python3 - "$continued_dir/run_metadata.json" <<'PY'
import json
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
checks = {
    "success": metadata.get("success"),
    "advanced": metadata.get("continuationAdvanced"),
    "scenarioMetadata": metadata.get("scenarioMetadataActive"),
    "stateCapacity": int(metadata.get("organicStateCapacityLogCount") or 0) > 0,
    "dynasticProbe": int(metadata.get("organicDynasticProbeLogCount") or 0) > 0,
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: continuation checks failed: {checks}")
PY
}

run_candidate ancient data/organic_history/scenarios/earth_ancient_v1.sav 7
run_candidate medieval data/organic_history/scenarios/earth_medieval_v1.sav 7
run_candidate 1450 data/organic_history/scenarios/earth_1450_v1.sav 8

run_resume ancient data/organic_history/scenarios/earth_ancient_v1.sav 7
run_resume medieval data/organic_history/scenarios/earth_medieval_v1.sav 7
run_resume 1450 data/organic_history/scenarios/earth_1450_v1.sav 8

echo "SUCCESS: historical mandate-loss gate passed"
