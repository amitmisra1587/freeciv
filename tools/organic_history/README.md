# Organic History Tools

This directory contains automation for AI agents working on the organic-history Freeciv fork.

## Build

From the repository root:

```bash
export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c@78/lib/pkgconfig:/opt/homebrew/opt/icu4c/lib/pkgconfig:/opt/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
meson setup build-organic '-Dclients=[]' '-Dfcmp=[]' '-Dtools=[]' -Daudio=none -Dmwand=false -Dnls=false -Ddebug=true
ninja -C build-organic
```

If Meson configuration already exists:

```bash
ninja -C build-organic
```

On macOS, if Meson reports `Dependency "icu-uc" not found`, ICU may already be installed but hidden from `pkg-config`. Use the `PKG_CONFIG_PATH` export above. `-Daudio=none`, `-Dmwand=false`, and `-Dnls=false` keep the Phase 0 build focused on the server harness.

## AI-Only Baseline Smoke

```bash
python3 tools/organic_history/run_ai_game.py --turns 20 --players 4 --output-dir runs/organic_history_baseline_001
```

The harness finds a server binary, writes a temporary server command file, runs the server non-interactively, captures stdout/stderr, and records metadata.

Verified local baseline:

```text
runs/organic_history_baseline_001/
turns: 20
players: 4
seed: 1
elapsedSeconds: 22.772
saveCount: 21
success: true
```

## Organic Ruleset Gate

```bash
tools/organic_history/gate.sh
```

The gate builds `build-organic` if needed, then runs:

```bash
python3 tools/organic_history/run_ai_game.py \
  --ruleset-serv data/organic_history.serv \
  --turns 20 \
  --players 4 \
  --output-dir runs/organic_history_gate \
  --clean-output-dir
```

Verified local organic ruleset gate:

```text
runs/organic_history_gate/
turns: 20
players: 4
seed: 1
saveCount: 21
success: true
```

The organic ruleset currently adds only a diagnostic Lua `turn_begin` log. It
also emits logging-only per-player metrics, candidate stability scores, and
event diagnostics. It does not implement spawning, stability effects, collapse,
successor states, or gameplay mechanics.

## Parsers

Parse one run's scorelog and final save:

```bash
python3 tools/organic_history/parse_scorelog.py \
  runs/organic_history_gate/score.log \
  --output runs/organic_history_gate/score_metrics.json

final_save="$(find runs/organic_history_gate -maxdepth 1 -name '*final.sav.gz' | sort | tail -1)"
python3 tools/organic_history/parse_savegame.py "$final_save" \
  --output runs/organic_history_gate/save_metrics.json

python3 tools/organic_history/analyze_campaign.py \
  --run-dir runs/organic_history_gate \
  --output runs/organic_history_gate/run_summary.json
```

## Campaigns

Run a small campaign:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --seeds 1-3 \
  --turns 50 \
  --players 6 \
  --saveturns 10 \
  --output-dir runs/organic_history_campaign_smoke \
  --clean \
  --timeout 240
```

Run the verified campaign gate:

```bash
tools/organic_history/campaign_gate.sh
```

Verified local campaign gate:

```text
runs/organic_history_campaign_gate/
runsRequested: 3
runsSucceeded: 3
turns: 50
players: 6
organicMetricLogs: 1050
organicStabilityLogs: 1050
```

Run the overnight preset:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --preset overnight \
  --output-dir runs/organic_history_overnight \
  --clean
```

Campaign outputs:

```text
campaign_manifest.json
campaign_summary.json
campaign_metrics.csv
failed_runs.json
seed_0001/run_metadata.json
seed_0001/score.log
seed_0001/score_metrics.json
seed_0001/save_metrics.json
seed_0001/run_summary.json
seed_0001/run_metrics.csv
```

For failures, inspect the relevant `seed_*/server_commands.serv`,
`server_stdout.log`, `server_stderr.log`, `run_metadata.json`, and `score.log`.

## Calibration and Mechanics Experiments

Calibrate diagnostic thresholds:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --preset calibration_long \
  --output-dir runs/organic_history_calibration_long \
  --clean

python3 tools/organic_history/calibrate_thresholds.py \
  runs/organic_history_calibration_long \
  --output runs/organic_history_calibration_long/thresholds.json
```

Run the disabled-by-default civil-war mechanics gate:

```bash
tools/organic_history/mechanics_gate.sh
```

Run the full long orchestration:

```bash
tools/organic_history/full_overnight.sh
```

The first gameplay mechanic uses Freeciv's built-in
`Player:civil_war(probability)` and is only active when explicitly enabled via
campaign commands. Normal gates keep mechanics off.

## Next Tooling Targets

1. Inspect `runs/organic_history_mechanics_ab_long/experiment_summary.json`.
2. Tune civil-war thresholds only through experiment commands.
3. Add robust save/load continuation once Freeciv loaded-save automation is solved.
4. Add scenario fixtures for China, India, colonization, and collapse tests.
