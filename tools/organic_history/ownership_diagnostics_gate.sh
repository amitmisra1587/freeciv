#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path("tools/organic_history").resolve()))
from analyze_campaign import parse_log_metrics

with tempfile.TemporaryDirectory() as tmp:
    run_dir = Path(tmp)
    (run_dir / "server_stdout.log").write_text(
        "\n".join(
            [
                '3: organic_history_ownership_change turn=10 city="Roma" city_id=101 loser=1 winner=2 source="engine" category="engine_combat" reason="conquest" success=true',
                '3: organic_history_ownership_change turn=20 city="Lugdunum" city_id=102 loser=2 winner=3 source="script" category="political_succession" reason="dynastic_transfer" success=true',
                '3: organic_history_ownership_change turn=30 city="Carthage" city_id=103 loser=4 winner=2 source="script" category="scripted_conquest" reason="conquest_death" success=true',
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    metrics = parse_log_metrics(run_dir)
    ownership = metrics["ownershipChanges"]
    assert metrics["counts"]["ownershipChange"] == 3
    assert ownership["sources"] == {"engine": 1, "script": 2}
    assert ownership["categories"]["engine_combat"] == 1
    assert ownership["categories"]["political_succession"] == 1
    assert ownership["categories"]["scripted_conquest"] == 1
    assert len(ownership["events"]) == 3
    assert ownership["events"][0]["city_id"] == 101
PY

python3 - <<'PY'
from pathlib import Path

source = Path("data/organic_history/script.lua").read_text(encoding="utf-8")
direct_calls = [
    line.strip()
    for line in source.splitlines()
    if "edit.transfer_city" in line
]
assert direct_calls == [
    "local transferred = edit.transfer_city(city, new_owner)"
], direct_calls
PY

echo "Ownership diagnostics gate passed."
