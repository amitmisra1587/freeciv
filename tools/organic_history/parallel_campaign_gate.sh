#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_parallel_campaign_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/run_campaign.py \
  tools/organic_history/analyze_campaign.py

python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --seeds 1-2 \
  --turns 3 \
  --players 4 \
  --saveturns 3 \
  --timeout 120 \
  --jobs 2 \
  --max-load-average 999 \
  --output-dir "$gate_dir/generated" \
  --clean \
  --label parallel_generated_gate >/dev/null

python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/global_4000_emergence_candidate.json \
  --scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --seeds 1-2 \
  --turns 5 \
  --players 4 \
  --saveturns 5 \
  --timeout 180 \
  --jobs 2 \
  --max-load-average 999 \
  --output-dir "$gate_dir/global" \
  --clean \
  --label parallel_global_gate >/dev/null

python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --seeds 1-2 \
  --turns 3 \
  --players 4 \
  --saveturns 3 \
  --timeout 120 \
  --jobs 2 \
  --max-load-average 999 \
  --output-dir "$gate_dir/generated" \
  --label parallel_generated_resume_gate >/dev/null

python3 - "$gate_dir" <<'PY'
import json
import sys
from pathlib import Path

gate_dir = Path(sys.argv[1])
checks = {}
for name in ("generated", "global"):
    summary = json.loads((gate_dir / name / "campaign_summary.json").read_text(encoding="utf-8"))
    manifest = json.loads((gate_dir / name / "campaign_manifest.json").read_text(encoding="utf-8"))
    ports = list(manifest.get("ports", {}).values())
    checks[f"{name}_success"] = summary.get("runsSucceeded") == 2 and summary.get("runsFailed") == 0
    checks[f"{name}_unique_ports"] = len(ports) == len(set(ports)) == 2
    checks[f"{name}_progress"] = (gate_dir / name / "campaign_progress.jsonl").exists()

progress_lines = (gate_dir / "generated" / "campaign_progress.jsonl").read_text(encoding="utf-8").splitlines()
checks["resume_skipped_success"] = any('"event": "seed_skipped_success"' in line for line in progress_lines)

if not all(checks.values()):
    raise SystemExit(f"FAIL: parallel campaign checks failed: {checks}")
PY

echo "SUCCESS: parallel campaign gate passed"
