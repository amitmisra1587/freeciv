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

- [x] Inspect completed `runs/organic_history_full_overnight` long A/B output.
- [x] Confirm civil-war v1 is safe but inert (`safeToIterate: true`,
  `candidatePromising: false`, zero checks/triggers).
- [x] Add civil-war skip-reason and inertness diagnostics.
- [x] Add bounded `mechanics_profile.py --mode probe` support.
- [x] Run focused v2 probe:
  `runs/organic_history_mechanics_v2_probe/experiment_summary.json`.
- [ ] Run a longer v2 A/B only after the probe remains safe with non-zero checks.
- [ ] Solve loaded-save continuation automation before making mechanics default-on.
- [x] Add minimal Earth scenario fixtures and scenario gate.
- [ ] Replace minimal fixtures with hand-authored China, India, colonization, and
  collapse starts.

## Phase 4: Overnight Feedback Loop

- [x] Add resumable full overnight orchestration.
- [x] Add `tools/organic_history/overnight_status.py`.
- [x] Add `tools/organic_history/mechanics_profile.py`.
- [x] Let experiments consume mechanics profile JSON.
- [x] Update continuation checks to load non-final autosaves and record precise
  blockers.
- [x] Improve comparison verdicts with `safeToIterate`,
  `candidatePromising`, deltas, and rates.
- [x] Add generated-map regional/hegemony diagnostics.

## Phase 4 Commands

```bash
cd /Users/amitmisra/code/freeciv
tools/organic_history/full_overnight.sh --output-dir runs/organic_history_full_overnight --dry-run
python3 tools/organic_history/overnight_status.py runs/organic_history_full_overnight
tools/organic_history/full_overnight.sh --output-dir runs/organic_history_full_overnight --resume
```

## Next Tasks

- [x] Execute `runs/organic_history_full_overnight`.
- [x] Inspect long-run threshold and comparison outputs.
- [x] Decide whether civil-war v1 is safe to keep iterating.
- [x] Add minimal Earth/scenario fixtures for regional history tests.

## Phase 5A: Civil-War Eligibility Probes

- [x] Re-analyze long A/B artifacts with skip-reason diagnostics.
- [x] Identify v1 inertness root cause: dominant post-start skip pressure is
  `small_state` from too-high `civilWarMinCities`.
- [x] Generate a command-gated v2 probe profile from calibration data.
- [x] Run focused v2 probe with no failures, non-zero eligibility checks, and
  one civil-war trigger.
- [ ] If v2 remains safe, run a longer A/B before considering scenario-specific
  tuning.

## Phase 5B: Scenario Infrastructure

- [x] Document scenario format and organic-history region conventions.
- [x] Add generated minimal Earth fixtures:
  `earth_ancient_v0.sav`, `earth_medieval_v0.sav`, `earth_1450_v0.sav`.
- [x] Add `run_ai_game.py --load-scenario` with active organic-history ruleset
  loading.
- [x] Add scenario campaign presets (`scenario_ancient`, `scenario_medieval`,
  `scenario_1450`).
- [x] Add scenario region definitions and generated-map/scenario region
  diagnostics.
- [x] Add `scenario_gate.sh`.
- [x] Add logging-only regional hegemony and prestige diagnostics.
- [x] Compare generated-map and scenario campaigns with like-for-like 80-turn
  runs.
