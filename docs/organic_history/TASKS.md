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

## Phase 27: Expanded global evidence sweep

- [x] Run the expanded 5x200 global pilot on
  `earth_global_4000_v1` with `global_4000_emergence_candidate`.
  Result: 5/5 runs succeeded to turn 201 with zero Freeciv assertions.
- [x] Pilot runtime: 1156.9-1270.0s/seed, mean 1220.2s/seed. A 100x200
  sequential sweep is roughly 34 hours at this size/profile.
- [x] Pilot aggregate: mean final cities 161.2, mean max city share 0.253, no
  domination/stagnation warnings.
- [x] Pilot emergence coverage:
  Greece, Persia, Rome, Nubia, Celts, Aztec, and Inca emerged in all 5 seeds;
  Steppe emerged in 4/5; Japan in 4/5; Song in 3/5. Crowded Near East/Punic,
  Chola, Franks, Iberian, and Ming actors mostly delayed.
- [x] Fix large-Earth region boxes after pilot diagnostics showed broad overlap
  was misclassifying Old World AI-founded cities as Americas/Africa.
- [x] Tune collapse diagnostics so `unknown` region cities do not become release
  candidates. This keeps unknown cities in totals but avoids noisy false
  peripheral release suggestions.
- [x] Validate the region/diagnostic tuning with the global gate, an 80-turn
  smoke, and a 200-turn smoke. The 200-turn post-tuning smoke reached turn 201
  with zero assertions, final cities 166, and max city share 0.247.
- [x] Decision: do not start the full 100x200 historical-fit sweep yet. Run a
  smaller post-tuning 5x200 confirmation batch first, because the original 5x200
  pilot used the pre-fix region model.
- [ ] Run post-tuning 5x200 confirmation, then launch 100x200 in 20-seed batches
  if it remains assertion-clean and diagnostic quality holds.
- [x] Run the full post-tuning 100x200 global sweep in five 20-seed batches.
  Result: 100/100 runs succeeded, zero Freeciv assertions, no domination or
  stagnation warnings.
- [x] Write aggregate artifacts:
  `runs/organic_history_phase27_global_sweeps/full_100x200/full_100x200_summary.json`,
  `full_100x200_emergence_summary.json`, and
  `full_100x200_collapse_summary.json`.
- [x] 100x200 aggregate: mean final cities 165.06, median final cities 165,
  min/max final cities 117/194, mean max city share 0.255, median max city share
  0.246.
- [x] 100x200 emergence rates: Assyria, Aztec, Carthage, Celts, Franks, Greece,
  Inca, Nubia, Persia, Phoenicia, and Rome emerged in all 100 seeds; Japan 94,
  Abbasid 92, Chola 80, Steppe 78, Song 70, Ming 60, Portugal 42, Castile 29,
  Hittite 4.
- [x] Collapse diagnostics remain diagnostics-only. Highest max collapse risks in
  the 100x200 summary were India 0.843, Egypt 0.780, Greece 0.768, Assyria
  0.756, China 0.749, and Nubia 0.694.

## Phase 28: Lifecycle mechanics and faster evidence loops

- [x] Implement `run_campaign.py --jobs N` with bounded parallel workers,
  deterministic per-seed ports, per-seed output isolation, campaign progress
  logging, and successful-seed skipping on resume.
- [x] Add optional local load guard flags to `run_campaign.py`
  (`--max-load-average`, `--load-check-interval`, `--load-guard-timeout`) so
  long parallel sweeps can pause seed launches under host pressure.
- [x] Add `tools/organic_history/parallel_campaign_gate.sh`.
- [x] Verify parallel generated-map and global-scenario smoke campaigns with
  `--jobs 2`, plus resume/skip behavior.
- [x] Add `tools/organic_history/global_historical_fit_report.py` to generate
  per-civ pass/warn/fail historical-fit reports from global sweeps. Default mode
  is report-only; `--strict` can fail CI on actor failures.
- [x] Add historical-gravity safeguards to canonical data and reports:
  condition gates, escape routes, probabilistic outcome weights, and explicit
  separation between historical role data and generic mechanic triggers.
- [x] Emit `organic_history_global_historical_gravity` in generated Lua runtime
  data and include `historicalGravityAssessment` in the historical-fit report.
- [x] Add canonical lifecycle archetypes and actor mappings:
  initial core, imperial claimant, dynastic successor, maritime trader, steppe
  conqueror, island core, tribal horizon, and regional kingdom.
- [x] Emit `organic_history_global_lifecycle_archetypes` and
  `organic_history_global_actor_lifecycle_types` in generated Lua runtime data.
- [x] Include lifecycle type, target city curves, escape routes, and outcome
  weights in `global_historical_fit_report.py`.
- [x] Add command-gated bootstrap package v1:
  `organic_history_bootstrap_enabled` applies one bounded lifecycle package per
  emerged actor after safe city creation, without creating players, reassigning
  nations, or transferring cities.
- [x] Add `tools/organic_history/profiles/global_4000_bootstrap_candidate.json`
  for bootstrap A/B sweeps while preserving the emergence-only baseline profile.
- [x] Add `tools/organic_history/global_4000_bootstrap_gate.sh` and bootstrap
  log counting in run metadata/analyzer output.
- [x] Run bootstrap 5x120 smoke:
  5/5 seeds succeeded, 0 assertions, mean final cities 137.2, mean max city
  share 0.245, no domination/stagnation warnings.
- [x] Refine large-Earth geography and actor claims with generated canonical
  subregions: Nile, Mesopotamia, Anatolia, Levant, Iran, Italy, Gaul, Iberia,
  Aegean/Balkans, Maghreb/Punic West, North/South China, Japan/Korea,
  Mongolian Steppe, Mesoamerica, and Andes.
- [x] Extend `validate_scenario.py` to accept canonical global subregions and
  regenerate `earth_global_4000_v1.sav` from the updated starts plan.
- [x] Run forced 170-turn subregion smoke with bootstrap profile and emergence
  probability 100: success to turn 171, 0 assertions, and confirmed region logs
  for Rome/Italy, Castile/Iberia, Japan/Japan-Korea, Aztec/Mesoamerica,
  Inca/Andes, Steppe/Mongolian Steppe, Chola/South India, Franks/Gaul, and
  Abbasid/Mesopotamia.
- [x] Add diagnostics-only dynastic transfer v1:
  `organic_history_dynastic_transfer_probe_enabled` evaluates dynastic-successor
  pressure using predecessor mandate/crisis, target-region holder state, and
  lifecycle metadata, then logs `protected` escape routes or `candidate`
  pressure with `applied=false`.
- [x] Add `tools/organic_history/dynastic_transfer_gate.sh`, which forces a
  short candidate probe and verifies no city transfers or secessions occur.
- [x] Add diagnostics-only regional expansion pressure v1:
  `organic_history_expansion_pressure_probe_enabled` compares current city count
  to lifecycle target curves, checks under-owned core/historical claims, and
  logs `candidate` or protected escape-route outcomes with `applied=false`.
- [x] Add `tools/organic_history/expansion_pressure_gate.sh`, which forces a
  short target-curve gap and verifies structured expansion-pressure diagnostics
  without city ownership changes.
- [x] Add diagnostics-only partial contraction v1:
  `organic_history_partial_contraction_probe_enabled` consumes collapse risk,
  release candidates, and lifecycle contraction rules, tracks sustained-risk
  streaks, and logs `protected`, `monitor`, or `candidate` with `applied=false`.
- [x] Add `tools/organic_history/partial_contraction_gate.sh`, which forces a
  short peripheral-risk candidate and verifies no city transfer or secession.

## Phase 26: DoC-Informed Global Historical Model

- [x] Treat the Dawn of Civilization comparison as design/data guidance, not as a
  fixed event-script blueprint.
- [x] Reorder the roadmap so large-Earth dynamic actor lifecycle safety comes
  before 100-run global sweeps, DoC-scale actor expansion, or multi-city
  collapse/resurrection mechanics.
- [x] Identify the global 200-turn assertion source: duplicate Freeciv nation
  ownership between active/dormant players, notably China/Song sharing the
  `Chinese` nation slot.
- [x] Give Song the unique `Han` nation slot in the global 4000 fixture data and
  Lua emergence metadata.
- [x] Add duplicate player-nation validation to scenario generation and scenario
  validation.
- [x] Make `run_ai_game.py` treat Freeciv assertion logs as failures and record
  `freecivAssertionLogCount`.
- [x] Verify the regenerated 160x90 global fixture runs to turn 200 with zero
  assertions and resumes from the final save through turn 220 with zero
  assertions.
- [x] Add `tools/organic_history/global_4000_lifecycle_gate.sh`.
- [x] Add the first canonical global historical data model at
  `data/organic_history/history/earth_global_4000.json`.
- [x] Add `tools/organic_history/generate_history_artifacts.py --check` and wire
  it into global gates so the global starts plan and timeline do not drift from
  the canonical model.
- [x] Generate/check the canonical large-Earth Lua runtime block in
  `data/organic_history/script.lua` so global actor metadata, city metadata,
  region claims, and emergence actors are sourced from
  `earth_global_4000.json`.
- [x] Add diagnostic-only region claims and `organic_history_claim_pressure`
  logging for authored actors, with campaign summary parsing.
- [x] Replace date/probability-only global emergence with conditional v2 modes:
  empty-core, lineage-successor, weak-holder, and foreign-core claimant.
- [x] Add relocation search across core regions plus delayed no-site handling so
  saturated cores do not become permanent blocks or per-turn log noise.
- [x] Switch global scenario authoring to the extended nation set and keep Song on
  a unique Korean runtime slot to avoid active China/Han conflicts.
- [x] Expand canonical global data with a first DoC-inspired ancient/classical
  wave: Nubia, Assyria, Hittite, Phoenicia, Carthage, and Celts.
- [x] Keep relocation conservative after expansion: actors may relocate near their
  target inside the core region, but no longer jump across continent-scale
  regions.
- [x] Add diagnostics-only collapse/resurrection groundwork:
  `organic_history_collapse` and `organic_history_collapse_candidate` logs
  summarize collapse risk and candidate release cities without transferring
  ownership or creating successors.
- [x] Add diagnostics-only DoC flavor scaffolding:
  `organic_history_flavor` logs UHV-style diagnostics and policy hints from the
  canonical global actor data without changing AI behavior or UI.
- [x] Validate the expanded global fixture through the standard global gate and
  the 200-turn plus continuation lifecycle gate.
- [ ] Promote collapse/resurrection from diagnostics to command-gated mechanics
  only after release-candidate quality is reviewed across longer sweeps.
- [ ] Promote flavor diagnostics into visible objectives, dynamic names,
  diplomacy, contact/colonial systems, or UI only after long-run diagnostics are
  reviewed.

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

## Phase 18: Successor and Core-Region Quality

- [x] Add authored core-region and successor metadata to all v1 starts plans:
  `coreRegion`, per-city `region`/`core`, `successorNation`, and
  `successorNames`.
- [x] Add East Asia to scenario region metadata for Japan-facing 1450 outcomes.
- [x] Teach Lua to prefer authored city metadata over coordinate boxes when
  assigning city pressure and regional hegemony regions.
- [x] Teach Lua to use authored actor core regions for institution/mandate
  calculations when the player is a known scenario actor.
- [x] Improve fallback secession city scoring:
  - keep capital/government-center exclusions
  - prefer peripheral/non-core cities
  - penalize authored core cities without making fallback impossible
- [x] Improve fallback successor identity:
  - parent actor lineage
  - successor nation fallback
  - parent/region-aware successor names
- [x] Extend validation to check v1 metadata shape and region IDs.
- [x] Extend run and civilization outcome summaries with secession lineage
  details: successor name/nation, parent actor, core region, transferred city,
  city region, core/peripheral flags.
- [x] Add `mechanics_profile.py --mode successor` for the command-gated
  pressure+mandate+fallback-secession profile.

Decision:

- Successor/secession quality should now be evaluated with lineage details, not
  just event counts.
- The mechanics remain command-gated; metadata improves diagnostics and fallback
  behavior without making secession default-on.

## Phase 19: Long-Run Successor Profile Study

- [x] Generate a fresh `successor_secession_v1` profile from current generated-map
  calibration output.
- [x] Add `run_experiment.py --scenario` and `--label` so authored scenario A/B
  runs can use the same wrapper as generated-map experiments.
- [x] Run 3 x 200-turn matched A/B campaigns for:
  - generated fixed maps
  - `earth_ancient_v1`
  - `earth_medieval_v1`
  - `earth_1450_v1`
- [x] Harden authored scenario metadata:
  - activate only when authored fixtures are detected by exact city/tile matches
  - require exact authored city coordinates before applying city metadata
  - avoid generated maps inheriting authored actor identities from matching names
- [x] Tune medieval regressions exposed by the long-run study:
  - Steppe/Temujin: add `Beshbalik`, more gold, stronger expansionist/aggressive traits
  - Chola/Rajaraja: add `Kanchipuram`, more gold, trader/expansion/builder traits
- [x] Regenerate and validate the balanced medieval fixture.
- [x] Re-run the balanced medieval A/B and outcome report.

Final Phase 19 A/B results:

- Generated fixed: `safeToIterate=true`, `active_safe_triggering`, mean final
  cities `84.0 -> 77.333`, mean max city share `0.259 -> 0.257`, fallback
  secessions `28`, no failures.
- Ancient v1: `safeToIterate=true`, `active_safe_triggering`, mean final cities
  `76.333 -> 70.0`, mean max city share `0.234 -> 0.209`, fallback secessions
  `12`, no failures.
- Balanced medieval v1: `safeToIterate=true`, `active_safe_triggering`, mean
  final cities `68.667 -> 74.667`, mean max city share `0.341 -> 0.202`,
  fallback secessions `15`, no failures.
- 1450 v1: `safeToIterate=true`, `active_safe_triggering`, mean final cities
  `91.667 -> 92.667`, mean max city share `0.216 -> 0.187`, fallback
  secessions `29`, no failures.

Focus outcomes after tuning:

- Rome/Romulus: `15.667 -> 10.333` final cities with 3 Roman secessions; still
  an expansionist survivor.
- Persia/Cyrus: `14.0 -> 10.0` final cities with 3 Persian secessions; still an
  expansionist survivor.
- Steppe/Temujin: `16.333 -> 10.333` final cities with 4 Mongol secessions; now
  remains an expansionist survivor.
- Chola/Rajaraja: `7.333 -> 7.0` final cities with 3 Indian secessions; no
  longer collapses, but remains a watch item.
- Castile/Isabella: `4.0 -> 8.333` final cities with 3 Iberian secessions.
- Ming/Xuande, Ottoman proxy/Mehmed II, and Venice proxy/Francesco Foscari all
  stay expansionist survivors while producing lineage-aware secessions.

Decision:

- The successor profile is safe and active across generated, ancient, medieval,
  and 1450 long-run studies.
- Keep it command-gated. It is a candidate gameplay profile, not default-on
  behavior.
- Next finish-line work should address default-on blockers: continuation/save-load
  robustness, generated-map parent/core metadata, and richer trade/tech/social
  pressure systems.

## Phase 20: Historical Scenario Continuation Readiness

- [x] Defer generated-map lineage work per user direction; focus on historical
  scenarios first.
- [x] Reproduce the continuation blocker:
  - fresh historical scenario runs succeeded
  - `--load-save` continuations timed out because loaded games never resumed the
    turn loop
- [x] Fix `run_ai_game.py --load-save`:
  - automatically appends `start` for loaded games
  - skips rereading the ruleset `.serv` after a game has already started
  - records `loadSaveTurn`, `continuedTurnCount`, `continuationAdvanced`, and
    scenario metadata status
- [x] Add resumed scenario metadata status logging in Lua.
- [x] Add `tools/organic_history/historical_continuation_gate.sh`.
- [x] Gate coverage:
  - `earth_ancient_v1` plain and successor continuation
  - balanced `earth_medieval_v1` plain and successor continuation
  - `earth_1450_v1` plain and successor continuation
  - resumed Roman lineage fallback check
- [x] Verify authored metadata and successor lineage after resume:
  - `scenarioMetadataActive=true`
  - organic-history hooks and metrics resume
  - successor-mode dynastic probes resume
  - resumed Roman fallback produces `parent_actor="rome"`,
    `successor_nation="Roman"`, and transfers non-capital Neapolis
- [x] Update `gameplay_readiness.py` to understand historical continuation gate
  summaries.

Phase 20 readiness result:

- Historical continuation gate: passed.
- Historical readiness report:
  - `commandGatedReady=true`
  - `defaultOnReady=true` for the supplied historical scenario evidence
  - no blockers
  - recommendation: candidate is ready to evaluate for default-on gameplay

Decision:

- The historical-scenario save/load blocker is fixed for the tested short
  ancient, balanced medieval, and 1450 continuations.
- The successor profile can now be evaluated as a near-default historical
  scenario candidate.
- Generated maps remain out of scope for this phase.

## Phase 21: Historical Near-Default Candidate Packaging

- [x] Commit the verified Phase 18-20 baseline:
  `d74012fdb8 Prepare historical successor readiness`.
- [x] Add packaged historical candidate profile:
  `tools/organic_history/profiles/historical_successor_candidate.json`.
- [x] Teach `run_ai_game.py` and `run_campaign.py` to accept `--profile`.
- [x] Update `historical_continuation_gate.sh` to consume the packaged profile.
- [x] Add `tools/organic_history/historical_candidate_gate.sh`.
- [x] Run packaged candidate gate: passed.
- [x] Run 3 x 120-turn packaged historical candidate validations:
  - ancient v1: 3/3 succeeded, mean final cities `50.333`, secessions `4`
  - balanced medieval v1: 3/3 succeeded, mean final cities `53.667`,
    secessions `6`
  - 1450 v1: 3/3 succeeded, mean final cities `81.333`, secessions `2`
- [x] Regenerate historical readiness report with Phase 19/20 long A/B evidence
  and the Phase 21 packaged continuation gate.

Decision:

- The successor profile is now available as a stable, repo-tracked historical
  candidate profile.
- It remains explicitly selected with `--profile`; it is not globally default-on.
- Historical scenarios can now use the candidate profile through repeatable gates
  and campaign commands.
- Generated maps remain out of scope.

## Phase 22: Mandate-Loss and State-Capacity Cycles

- [x] Preserve baseline: pushed Phase 18-21 commits to `origin/main`.
- [x] Audit mandate/state-capacity signal ranges from existing historical runs.
- [x] Add command-gated mandate-loss controls:
  - `organic_history_mandate_loss_enabled`
  - `organic_history_mandate_loss_threshold`
  - `organic_history_mandate_loss_min_cities`
  - `organic_history_mandate_loss_max_stress_modifier`
- [x] Add `organic_history_state_capacity` diagnostics with:
  mandate deficit, overextension, cohesion deficit, reform pressure, unrest,
  autonomy, frontier risk, crisis, recovery, status, and stress modifier.
- [x] Feed bounded state-capacity stress into dynastic/civil-war effective stress
  only when mechanics and mandate-loss profile are enabled.
- [x] Extend analysis/campaign summaries with state-capacity fields.
- [x] Add packaged profile:
  `tools/organic_history/profiles/historical_mandate_loss_candidate.json`.
- [x] Add gate:
  `tools/organic_history/historical_mandate_loss_gate.sh`.
- [x] Run focused 3 x 120-turn mandate-loss validations:
  - ancient v1: 3/3 succeeded, mean state-capacity modifier `0.035`,
    secessions `3`
  - balanced medieval v1: 3/3 succeeded, modifier `0.000`, secessions `2`
  - 1450 v1: 3/3 succeeded, modifier `0.000`, secessions `4`
- [x] Run a longer ancient activation probe:
  - 1 x 200 turns succeeded
  - mean state-capacity modifier `0.213`
  - secessions `5`
  - no failures or runaway civil-war triggers

Decision:

- Mandate-loss is implemented as a conservative, command-gated stress modifier,
  not a scripted collapse.
- It activates lightly in mature ancient pressure and remains inert in healthier
  early/mid historical runs.
- Keep it separate from the packaged historical successor candidate until longer
  A/B evidence shows it improves decline/recovery arcs.

## Phase 24: Global 4000 BCE Scenario and Dynamic Emergence

- [x] Confirm map size options:
  - current era fixtures use `earth-small.sav` at `80x50`
  - Freeciv also includes `earth-large.sav` at `160x90`
- [x] Add large-Earth fixture generation support.
- [x] Add global fixtures:
  - `earth_global_4000_v0.sav`
  - `earth_global_4000_v1.sav`
  - `earth_global_4000_v1_starts.json`
  - `earth_global_4000_timeline.json`
- [x] Add large-map region boxes and large-map city metadata.
- [x] Add command-gated dynamic emergence controls:
  - `organic_history_emergence_enabled`
  - `organic_history_emergence_probability`
- [x] Add first-pass emergence actor table for Greece, Persia, Rome, Franks,
  Abbasid, Chola, Song, Steppe, Castile, Portugal, Ming, Japan, Aztec, and Inca.
- [x] Add dormant future actors to the global fixture and activate them by giving
  them cities/tech/gold/traits instead of creating players during mature games.
- [x] Add packaged global profile:
  `tools/organic_history/profiles/global_4000_emergence_candidate.json`.
- [x] Add global gate:
  `tools/organic_history/global_4000_gate.sh`.
- [x] Run global gate: passed.
- [x] Run 3 x 120-turn global pilot:
  - 3/3 succeeded
  - mean final cities `145.333`
  - mean max city share `0.377`
  - Greece, Persia, Rome, and Franks emerged in all seeds by turn 120

Findings:

- `earth-large.sav` works as a 160x90 basis for the true-global scenario.
- Pre-creating dormant actors is safer than calling `edit.create_player()` deep
  into mature global games.
- Early pilots crashed around turn 101/105 when fallback secession attempted
  successor player creation under the large-map nation set.
- Global fallback secession is therefore disabled/deferred in the global
  emergence profile until large-Earth successor nation mapping is made safe.

Decision:

- The 160x90 global scenario is feasible for staged diagnostics.
- Dynamic emergence exists and is command-gated.
- Collapse/successor integration for the global scenario remains a separate
  follow-up; do not enable fallback secession on the global emergence profile yet.
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
