#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

tools/organic_history/phase30_diagnostics_gate.sh >/dev/null
tools/organic_history/phase31_near_east_gate.sh >/dev/null
tools/organic_history/phase31_conquest_target_gate.sh >/dev/null
tools/organic_history/phase31_core_consolidation_gate.sh >/dev/null
tools/organic_history/phase31_contraction_debt_gate.sh >/dev/null

echo "SUCCESS: Phase 31 lifecycle gate passed"
