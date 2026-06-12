#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

gate_dir=runs/organic_history_phase32_rome_mediterranean_gate

python3 -m py_compile \
  tools/organic_history/run_ai_game.py \
  tools/organic_history/analyze_campaign.py \
  tools/organic_history/run_campaign.py \
  tools/organic_history/generate_civilization_evidence.py \
  tools/organic_history/global_historical_fit_report.py

python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --load-scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --profile tools/organic_history/profiles/phase32_objective_proof.json \
  --turns 90 \
  --players 4 \
  --saveturns 90 \
  --output-dir "$gate_dir/active" \
  --clean-output-dir \
  --timeout 720 \
  --extra-command 'lua cmd organic_history_emergence_probability = 100' \
  --extra-command 'lua cmd organic_history_objective_max_units = 5' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.earliest_turn = 2' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.probability = 100' \
  --extra-command 'lua cmd organic_history_global_emergence_actors.rome.predecessors = {}' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].targetCities = 99' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].startTurnAfterBirth = 0' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].durationTurns = 80' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].cooldownTurns = 5' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].maxApplications = 4' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].targetRegions = {"italy", "gaul", "iberia"}' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].offensiveUnits = 3' \
  --extra-command 'lua cmd organic_history_global_actor_objectives.rome[1].defenders = 1' \
  --extra-command 'lua cmd organic_history_gate_rome_mediterranean_done = false; function organic_history_gate_rome_mediterranean_targets(turn, year) if not organic_history_gate_rome_mediterranean_done then organic_history_gate_rome_mediterranean_done = true; local p = find.player("Narmer"); local specs = {{"Gate Gaul Rival", 30, 26}, {"Gate Iberia Rival", 26, 33}, {"Gate Italy Rival", 37, 31}, {"Gate Punic Rival", 25, 38}}; local created = 0; if p ~= nil then for _, spec in ipairs(specs) do local t = find.tile(spec[2], spec[3]); if t ~= nil and t:city() == nil and (edit.can_create_city == nil or edit.can_create_city(p, t)) and edit.city_create(p, t, spec[1], nil) then created = created + 1 end end end; log.normal("organic_history_gate_rome_mediterranean_targets created=%d", created) end; return false end; signal.connect("turn_begin", "organic_history_gate_rome_mediterranean_targets")' \
  >/dev/null

python3 tools/organic_history/analyze_campaign.py \
  --run-dir "$gate_dir/active" \
  --output "$gate_dir/active/run_summary.json" \
  --csv-output "$gate_dir/active/run_metrics.csv" >/dev/null

python3 - "$gate_dir/active/run_metadata.json" "$gate_dir/active/run_summary.json" <<'PY'
import json
import re
import sys
from pathlib import Path

metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
stdout = Path(metadata["stdoutPath"]).read_text(encoding="utf-8",
                                                errors="replace")
objective = summary.get("objective", {})
conversion = summary.get("conquestConversion", {})
created_match = re.search(
    r"organic_history_gate_rome_mediterranean_targets created=(\d+)",
    stdout)
created_targets = int(created_match.group(1)) if created_match else 0
positive_conversion = sum(
    int(conversion.get("actorReasons", {}).get(f"rome:{reason}") or 0)
    for reason in (
        "durable_region_gain",
        "captured_then_lost",
        "rival_declined_no_hold",
    )
)
checks = {
    "success": metadata.get("success"),
    "assertions": int(metadata.get("freecivAssertionLogCount") or 0) == 0,
    "rival_targets_created": created_targets >= 2,
    "objective_logs": int(metadata.get("organicObjectiveLogCount") or 0) > 0,
    "objective_applied_twice": int(objective.get("actorActions", {}).get("rome:applied") or 0) >= 2,
    "objective_structured": summary.get("logCounts", {}).get("objective") == metadata.get("organicObjectiveLogCount"),
    "conversion_tracking": int(conversion.get("actorActions", {}).get("rome:tracking") or 0) >= 2,
    "conversion_resolved": int(conversion.get("actorActions", {}).get("rome:resolved") or 0) >= 2,
    "conversion_positive_signal": positive_conversion >= 1,
    "conversion_structured": summary.get("logCounts", {}).get("conquestConversion") == metadata.get("organicConquestConversionLogCount"),
}
if not all(checks.values()):
    raise SystemExit(f"FAIL: Phase 32 Rome Mediterranean checks failed: {checks}")
print(json.dumps({
    "createdTargets": created_targets,
    "romeObjectiveReasons": {
        key: value for key, value
        in objective.get("actorReasons", {}).items()
        if key.startswith("rome:")
    },
    "romeConversionReasons": {
        key: value for key, value
        in conversion.get("actorReasons", {}).items()
        if key.startswith("rome:")
    },
}, sort_keys=True))
PY

echo "SUCCESS: Phase 32 Rome Mediterranean gate passed"
