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

## Phase 6: Prototype-Parity Diagnostics

- [x] Add logging-only city pressure state using Freeciv cities as the province
  analogue.
- [x] Parse and aggregate `organic_history_city_pressure` diagnostics in run and
  campaign summaries.
- [x] Add logging-only scenario archetype/state-form, institutional cohesion, and
  reform-pressure diagnostics.
- [x] Add logging-only pressure-event risk diagnostics for succession, fiscal,
  plague, trade disruption, climate, and frontier pressure.
- [x] Add `tools/organic_history/city_pressure_gate.sh`.
- [x] Research hand-authored scenario start generation. Recommended path is
  script-assisted generation with Freeciv Lua edit APIs (`edit.create_player`,
  `edit.city_create`) followed by `scensave`, not broad manual save editing.
- [x] Build `earth_ancient_v1` with fixed historical players/cities.
- [x] Extend `earth_ancient_v1` with ancient-era technologies, diplomacy, and
  scenario-specific calibration once the fixture has campaign coverage.
  Era setup now validates starting gold, known technologies, and current
  research. Diplomacy is metadata scaffolding only until a safe Freeciv
  scenario diplomacy authoring path exists.
- [x] Run 120-turn dynastic stress A/B after era enrichment:
  generated-map comparison is `safeToIterate: true` with 10 checks, 0 triggers,
  and mean dynastic bonus 0.359; `earth_ancient_v1` comparison is
  `safeToIterate: true` with 0 checks/triggers and mean dynastic bonus 0.003.

## Phase 9: Command-Gated Gameplay Profiles

- [x] Add `mechanics_profile.py --mode dynastic` to generate a reusable
  `dynastic_stress_v1` command-gated gameplay profile.
- [x] Add explicit dynastic stress verdicts:
  `active_safe_triggering`, `active_safe_no_triggers`,
  `inert_stable_control`, `unsafe`, `needs_tuning`, and `not_run`.
- [x] Run profile-driven 160-turn A/B:
  generated-map comparison is `safeToIterate: true`,
  `active_safe_triggering`, 22 checks, 2 triggers, trigger rate 0.091;
  `earth_ancient_v1` comparison is `safeToIterate: true`,
  `active_safe_triggering`, 7 checks, 1 trigger, trigger rate 0.143.
- [x] Add bounded institution stress modifiers behind
  `organic_history_institution_stress_modifiers_enabled`; default dynastic
  profile keeps them disabled.
- [x] Default-on readiness verdict: **not ready**. Mechanics must remain
  command-gated until continuation/save-load is fixed or safely worked around
  and longer A/B runs remain safe.

## Phase 10: Gameplay Readiness

- [x] Add `tools/organic_history/gameplay_readiness.py`.
- [x] Generate readiness report from profile-driven 160-turn dynastic A/B:
  `runs/organic_history_phase10_readiness/gameplay_readiness.json`.
- [x] Command-gated readiness verdict: **ready for further iteration**.
- [x] Default-on readiness verdict: **not ready** because continuation/save-load
  is still unsuccessful.
- [x] Implement Phase 11 mandate/reunification pressure diagnostics and bounded
  command-gated stability modifier.

## Phase 11: Mandate / Reunification Stability

- [x] Add `organic_history_mandate` diagnostics from regional hegemony, prestige,
  institution cohesion/reform pressure, and city pressure.
- [x] Add `mechanics_profile.py --mode mandate` with
  `organic_history_mandate_enabled` and bounded
  `organic_history_mandate_max_stress_reduction`.
- [x] Apply mandate as a command-gated stress reduction only; no direct city
  ownership, diplomacy, production, or terrain effects.
- [x] Run 80-turn A/B:
  generated-map comparison is `safeToIterate: true`,
  `active_safe_no_triggers`, 4 checks, 0 triggers, mean mandate reduction 0.049;
  `earth_ancient_v1` comparison is `safeToIterate: true`,
  `inert_stable_control`, 0 checks/triggers, mean mandate reduction 0.196.

## Phase 12: Fiscal / Frontier Pressure

- [x] Add command-gated fiscal/frontier pressure modifiers to effective stress.
- [x] Add `mechanics_profile.py --mode pressure`.
- [x] Run 80-turn A/B:
  generated-map comparison is `safeToIterate: true`,
  `active_safe_no_triggers`, 4 checks, 0 triggers, mean pressure modifier 0.797;
  `earth_ancient_v1` comparison is `safeToIterate: true`,
  `inert_stable_control`, 0 checks/triggers, mean pressure modifier 0.330.

## Phase 13: Multi-Era Scenario Fixtures

- [x] Add `earth_medieval_v1_starts.json` and generate `earth_medieval_v1.sav`.
- [x] Add `earth_1450_v1_starts.json` and generate `earth_1450_v1.sav`.
- [x] Validate medieval and 1450 starts plans.
- [x] Run 60-turn multi-era calibration:
  ancient 2/2, medieval 2/2, and 1450 2/2 successful.

## Phase 14: Long-Run Civilization Outcome Study

- [x] Add `tools/organic_history/civilization_outcomes.py`.
- [x] Run 200-turn outcome campaigns with pressure gameplay profile:
  generated-map 3/3, ancient v1 3/3, medieval v1 3/3, 1450 v1 3/3.
- [x] Generate:
  `runs/organic_history_outcome_study/civilization_outcomes.json`,
  `civilization_outcomes.csv`, and `outcome_study_report.json`.
- [x] Dispatch per-scenario analysis agents for generated, ancient, medieval,
  and 1450 outcomes.

Headline findings:

- No full eliminations across 12 long-run simulations.
- Generated-map outcomes are active and multipolar: 41 checks, 3 triggers.
- Ancient v1: China/Egypt/Sumer/India strongest; Rome/Persia weak; 20 checks,
  0 triggers.
- Medieval v1: Abbasid/Chola/Byzantium strong; Song/Steppe weak; 18 checks,
  0 triggers.
- 1450 v1: Inca/Aztec/Venice strongest, Iberians weak; 36 checks, 3 triggers.

Next tuning priorities:

- Add lineage/region-aware successor handling or fallback rebel states.
- Fix authored-scenario region/core-region assignment.
- Make mandate cyclic: high mandate stabilizes, low mandate/autonomy adds
  stress.
- Boost or script starts for Rome/Persia, Song/Steppe, Portugal/Castile.
- Add colonial/contact/disease/autonomy pressure for 1450 New World and
  maritime powers.
- Constrain successor names/nations by parent region/civ.

## Phase 15: Rome-First Historical Arc Tuning

- [x] Diagnose Rome problem: Rome was surviving but not rising. Baseline
  `earth_ancient_v1` outcome ended at 3, 3, and 2 cities with 0 dynastic checks.
- [x] Add focused civilization threshold checks to
  `civilization_outcomes.py`.
- [x] Add scenario actor trait support in `create_scenario_fixture.py`.
- [x] Tune Rome's ancient start:
  - second city: Neapolis
  - higher starting gold
  - Trade tech
  - Expansionist/Aggressive/Builder trait modifiers
- [x] Run 3 x 200-turn Rome-focused campaign:
  - Rome final cities: 16, 15, 13
  - Rome max cities: 16, 15, 15
  - Rome dynastic checks: 6 total
  - Rome triggers: 0
  - outcome check: passed

Decision:

- Start/trait tuning solved the immediate Rome problem. Rome now reaches
  regional-power scale.
- Do not add a Rome-specific new mechanic yet.
- Next Rome work should tune crisis/collapse after rise, likely by improving
  no-successor fallback and low-mandate/autonomy stress.

## Phase 16: Rome Crisis / Secession Fallback

- [x] Add `organic_history_secession` diagnostics for civil-war noops and
  fallback eligibility.
- [x] Add region/lineage-aware successor naming helpers, starting with Roman
  secession names.
- [x] Add command-gated fallback secession:
  - `organic_history_secession_fallback_enabled`
  - `organic_history_secession_min_cities`
  - `organic_history_secession_max_cities`
- [x] Use Freeciv Lua edit APIs to create a successor and transfer one
  non-capital candidate city when built-in `Player:civil_war()` noops.
- [x] Extend analysis/outcome tooling for secession logs/triggers.
- [x] Run Rome 3 x 200-turn A/B:
  - safeToIterate: true
  - candidate worse than baseline: false
  - secession events: 9 total fallback triggers
  - Rome final cities: 13, 11, 18
  - Rome max cities: 13, 13, 18
  - Rome secessions: 4

Decision:

- Fallback secession solves the visible-crisis problem for Rome without
  preventing Rome's rise.
- Keep fallback secession command-gated.
- Next tuning should improve city selection, successor naming/nation selection,
  and test generated/China/Persia scenarios before broader use.

## Phase 17: Multi-Civilization Tuning

- [x] Tune underperforming civ starts using traits, techs, gold, and extra cities:
  Persia/Cyrus, Song/Taizu, Steppe/Temujin, Portugal/Henry, Castile/Isabella.
- [x] Regenerate and validate ancient, medieval, and 1450 v1 fixtures.
- [x] Add a secession guard to avoid transferring capital/government-center
  cities after a 1450 crash exposed unsafe Venice fallback selection.
- [x] Run tuned 3 x 200-turn campaigns for ancient, medieval, and 1450.

Outcome improvements:

- Persia/Cyrus: mean final cities 7.0 -> 8.667; max cities 9.0 -> 12.0;
  7 checks, 3 secessions.
- Song/Taizu: mean final cities 4.333 -> 15.667; max cities 5.333 -> 16.667;
  7 checks, 4 secessions.
- Steppe/Temujin: mean final cities 5.0 -> 8.0; max cities 6.667 -> 9.0;
  3 checks, 2 secessions.
- Portugal/Henry: mean final cities 3.333 -> 9.0; max cities 5.0 -> 12.0;
  5 checks, 2 secessions.
- Castile/Isabella: mean final cities 6.333 -> 6.667; max cities 7.0 -> 9.0;
  2 checks, 1 secession.

Decision:

- Start/trait tuning is effective for under-expanding civs.
- Castile improved only modestly; it may need Iberian/geography-specific tuning
  later.
- The fallback secession guard is required before broader use.
- [x] Run Phase 6 calibration campaigns:
  `runs/organic_history_phase6_generated_80`,
  `runs/organic_history_phase6_ancient_v1_80`, and
  `runs/organic_history_phase6_calibration/comparison_summary.json`.
  Both campaigns succeeded and `safeToIterate` is true.
- [x] Select the next command-gated gameplay mechanic from calibrated diagnostics.

## Phase 7: Dynastic Stress Civil-War Probe

- [x] Decision: use dynastic stress / succession-risk as the next
  command-gated mechanic, feeding a bounded succession-risk bonus into the
  existing civil-war eligibility path.
- [x] Add disabled-by-default Lua controls for the dynastic stress probe. It
  must require explicit mechanics, civil-war, and dynastic probe commands.
- [x] Log dynastic probe diagnostics with base stress, succession risk,
  institution cohesion/reform pressure, effective stress, and skip/action.
- [x] Keep gameplay effects limited to the existing command-gated
  `Player:civil_war(probability)` call; do not add new default-on effects.
- [x] Probe generated-map and `earth_ancient_v1` 80-turn campaigns before any
  long A/B or tuning.
- [x] Add `tools/organic_history/dynastic_stress_gate.sh`.

Phase 7 probe result:

- Generated-map probe: 3/3 runs succeeded, `safeToIterate: true`,
  `civilWarChecks: 3`, `civilWarTriggered: 1`, mean dynastic bonus `0.074`.
- `earth_ancient_v1` probe: 3/3 runs succeeded, `safeToIterate: true`,
  `civilWarChecks: 0`, `civilWarTriggered: 0`, mean dynastic bonus `0.0`.
- Interpretation: the probe is active and can produce bounded checks/triggers
  where pressure exists, while the authored ancient scenario remains stable.

## Phase 7 Probe Commands

Run after the disabled-by-default dynastic probe controls/logs exist:

```bash
cd /Users/amitmisra/code/freeciv

python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --seeds 1-3 \
  --turns 80 \
  --players 8 \
  --saveturns 10 \
  --timeout 600 \
  --extra-command "lua cmd organic_history_mechanics_enabled = true" \
  --extra-command "lua cmd organic_history_civil_war_enabled = true" \
  --extra-command "lua cmd organic_history_dynastic_stress_enabled = true" \
  --extra-command "lua cmd organic_history_dynastic_stress_max_bonus = 10" \
  --output-dir runs/organic_history_dynastic_stress_generated_80 \
  --clean \
  --label dynastic_stress_generated_80

python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --seeds 1-3 \
  --turns 80 \
  --players 7 \
  --saveturns 10 \
  --timeout 600 \
  --extra-command "lua cmd organic_history_mechanics_enabled = true" \
  --extra-command "lua cmd organic_history_civil_war_enabled = true" \
  --extra-command "lua cmd organic_history_dynastic_stress_enabled = true" \
  --extra-command "lua cmd organic_history_dynastic_stress_max_bonus = 10" \
  --output-dir runs/organic_history_dynastic_stress_ancient_v1_80 \
  --clean \
  --label dynastic_stress_ancient_v1_80

python3 tools/organic_history/compare_campaigns.py \
  --baseline runs/organic_history_phase6_generated_80 \
  --candidate runs/organic_history_dynastic_stress_generated_80 \
  --output runs/organic_history_dynastic_stress_calibration/generated_comparison.json \
  --csv-output runs/organic_history_dynastic_stress_calibration/generated_comparison.csv

python3 tools/organic_history/compare_campaigns.py \
  --baseline runs/organic_history_phase6_ancient_v1_80 \
  --candidate runs/organic_history_dynastic_stress_ancient_v1_80 \
  --output runs/organic_history_dynastic_stress_calibration/ancient_v1_comparison.json \
  --csv-output runs/organic_history_dynastic_stress_calibration/ancient_v1_comparison.csv
```
