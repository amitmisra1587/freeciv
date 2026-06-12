#!/bin/sh
set -eu

cd "$(dirname "$0")/../.."

tools/organic_history/phase29_probe_gate.sh
tools/organic_history/phase29_contraction_gate.sh
tools/organic_history/phase30_contraction_gate.sh
tools/organic_history/phase29_successor_inheritance_gate.sh
tools/organic_history/phase30_successor_inheritance_gate.sh
tools/organic_history/phase30_iberia_gate.sh
tools/organic_history/phase30_sumer_gate.sh
tools/organic_history/phase30_burst_gate.sh

echo "SUCCESS: Phase 30 diagnostics gate passed"
