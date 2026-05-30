#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

profile=tools/organic_history/profiles/historical_successor_candidate.json
gate_dir=runs/organic_history_historical_candidate_gate

python3 -m json.tool "$profile" >/dev/null
tools/organic_history/historical_continuation_gate.sh >/dev/null

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
    --label "historical_candidate_${name}" \
    --clean >/dev/null
}

run_candidate ancient data/organic_history/scenarios/earth_ancient_v1.sav 7
run_candidate medieval data/organic_history/scenarios/earth_medieval_v1.sav 7
run_candidate 1450 data/organic_history/scenarios/earth_1450_v1.sav 8

python3 - <<'PY'
import json
from pathlib import Path

root = Path("runs/organic_history_historical_candidate_gate")
failures = []
results = []
for name in ("ancient", "medieval", "1450"):
    summary = json.loads((root / name / "campaign_summary.json").read_text(encoding="utf-8"))
    aggregate = summary.get("aggregate", {})
    result = {
        "name": name,
        "success": summary.get("runsSucceeded") == 1 and summary.get("runsFailed") == 0,
        "mechanicLogs": int(aggregate.get("organicMechanicLogs") or 0),
        "dynasticProbeLogs": int(aggregate.get("organicDynasticProbeLogs") or 0),
        "metricLogs": int(aggregate.get("organicMetricLogs") or 0),
    }
    result["success"] = (
        result["success"]
        and result["mechanicLogs"] > 0
        and result["dynasticProbeLogs"] > 0
        and result["metricLogs"] > 0
    )
    results.append(result)
    if not result["success"]:
        failures.append(result)

(root / "historical_candidate_gate_summary.json").write_text(
    json.dumps({"success": not failures, "results": results}, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
if failures:
    raise SystemExit(f"FAIL: historical candidate gate failed: {failures}")
print("SUCCESS: historical candidate gate passed")
PY
