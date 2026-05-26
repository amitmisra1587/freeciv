# Organic History Task Queue

## Phase 0: Agent Rails

- [x] Add repo-level agent instructions in `AGENTS.md`.
- [x] Add `tools/organic_history/run_ai_game.py`.
- [x] Add `tools/organic_history/gate.sh`.
- [x] Configure and build server-only Freeciv in `build-organic`.
- [x] Run AI-only baseline to turn 20.
- [x] Save logs and autosaves under `runs/organic_history_baseline_001`.
- [x] Verify `tools/organic_history/gate.sh` end to end.

## Verified Commands

```bash
cd /Users/amitmisra/code/freeciv
export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c@78/lib/pkgconfig:/opt/homebrew/opt/icu4c/lib/pkgconfig:/opt/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
meson setup build-organic '-Dclients=[]' '-Dfcmp=[]' '-Dtools=[]' -Daudio=none -Dmwand=false -Dnls=false -Ddebug=true
ninja -C build-organic
python3 tools/organic_history/run_ai_game.py --turns 20 --players 4 --output-dir runs/organic_history_baseline_001 --timeout 120
tools/organic_history/gate.sh
```

## Baseline Result

```text
server: build-organic/freeciv-server
turns: 20
players: 4 AI
seed: 1
elapsedSeconds: 22.772
saveCount: 21
result: success
gate: success, 20 turns, 4 AI players, 21 saves
```

## Phase 1: Ruleset Skeleton

- [x] Copy `data/civ2civ3` to `data/organic_history`.
- [x] Add `data/organic_history.serv`.
- [x] Add `data/organic_history.modpack`.
- [x] Verify the copied ruleset loads unchanged.
- [x] Wire `tools/organic_history/gate.sh` to `data/organic_history.serv`.
- [x] Add a logging-only Lua `turn_begin` hook.
- [x] Verify hook logs are emitted in an AI-only run.
- [x] Keep spawning, stability, collapse, and gameplay mechanics out of scope.

## Phase 1 Verified Commands

```bash
cd /Users/amitmisra/code/freeciv
python3 tools/organic_history/run_ai_game.py --ruleset-serv data/organic_history.serv --turns 1 --players 4 --output-dir runs/organic_history_ruleset_load --timeout 120
python3 tools/organic_history/run_ai_game.py --ruleset-serv data/organic_history.serv --turns 20 --players 4 --output-dir runs/organic_history_ruleset_smoke --timeout 120
python3 tools/organic_history/run_ai_game.py --ruleset-serv data/organic_history.serv --turns 5 --players 4 --output-dir runs/organic_history_lua_hook --timeout 120
grep -h "organic_history turn_begin" runs/organic_history_lua_hook/server_*.log
tools/organic_history/gate.sh
```

## Phase 1 Result

```text
ruleset load: success, 1 turn, 4 AI players, 2 saves
ruleset smoke: success, 20 turns, 4 AI players, 21 saves
lua hook: success, 5 hook log lines, 6 saves
gate: success, 20 turns, 4 AI players, 21 saves
```

## Next Tasks

## Phase 2: Overnight Simulation Lab

- [x] Isolate scorelogs under each run directory.
- [x] Add richer run metadata for scorelogs, final saves, hook counts, and
  organic diagnostic counts.
- [x] Add `tools/organic_history/parse_scorelog.py`.
- [x] Add `tools/organic_history/parse_savegame.py`.
- [x] Add `tools/organic_history/analyze_campaign.py`.
- [x] Add logging-only `organic_history_metric`,
  `organic_history_stability`, and `organic_history_event` diagnostics.
- [x] Add `tools/organic_history/run_campaign.py`.
- [x] Add `tools/organic_history/campaign_gate.sh`.
- [x] Add `--preset overnight`.
- [x] Verify a 3-seed campaign gate.

## Phase 2 Verified Commands

```bash
cd /Users/amitmisra/code/freeciv
tools/organic_history/gate.sh
tools/organic_history/campaign_gate.sh
python3 tools/organic_history/run_campaign.py --ruleset-serv data/organic_history.serv --preset overnight --output-dir runs/organic_history_overnight --clean
```

## Phase 2 Result

```text
single gate: success, 20 turns, 4 AI players, scorelog isolated
campaign gate: success, 3 runs, 50 turns, 6 AI players
organicMetricLogs: 1050
organicStabilityLogs: 1050
runsSucceeded: 3
runsFailed: 0
```

## Next Tasks

## Phase 3: Calibration and Gated Mechanics

- [x] Add long campaign presets: `calibration_long`, `mechanics_probe`,
  `mechanics_ab_long`.
- [x] Add `tools/organic_history/calibrate_thresholds.py`.
- [x] Add non-blocking `tools/organic_history/continuation_check.py`.
- [x] Add disabled-by-default civil-war mechanic configuration.
- [x] Add gated stress-driven `Player:civil_war(probability)` checks.
- [x] Count mechanics logs in run and campaign analysis.
- [x] Add `tools/organic_history/run_experiment.py`.
- [x] Add `tools/organic_history/compare_campaigns.py`.
- [x] Add `tools/organic_history/mechanics_gate.sh`.
- [x] Add `tools/organic_history/full_overnight.sh`.

## Phase 3 Commands

```bash
cd /Users/amitmisra/code/freeciv
tools/organic_history/mechanics_gate.sh
tools/organic_history/full_overnight.sh
```

## Next Tasks

- [ ] Inspect `runs/organic_history_mechanics_ab_long/experiment_summary.json`.
- [ ] Tune civil-war thresholds through experiment commands only.
- [ ] Solve loaded-save continuation automation before making mechanics default-on.
- [ ] Add scenario fixtures for China, India, colonization, and collapse tests.
