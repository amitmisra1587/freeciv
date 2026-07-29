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

```

Run the parallel campaign gate after changing campaign orchestration:

```bash
tools/organic_history/parallel_campaign_gate.sh
```

`run_campaign.py` supports bounded local parallelism:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/global_4000_emergence_candidate.json \
  --scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --seeds 1-20 \
  --turns 200 \
  --players 4 \
  --saveturns 25 \
  --timeout 3000 \
  --jobs 2 \
  --output-dir runs/organic_history_parallel_example
```

Each seed keeps its own output directory, scorelog, save files, server logs,
`run_metadata.json`, and `run_summary.json`. The manifest records the explicit
port assigned to each seed, and `campaign_progress.jsonl` records submissions,
starts, skips, completions, and failures. Resume behavior skips successful seeds
when `--clean` is omitted.

For long local sweeps on an interactive Mac, use a load guard so queued seeds
wait until the machine is below the threshold:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/global_4000_emergence_candidate.json \
  --scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --seeds 1-100 \
  --turns 200 \
  --players 4 \
  --jobs 2 \
  --max-load-average 18 \
  --load-check-interval 30 \
  --output-dir runs/organic_history_global_100x200
```

`--max-load-average 0` disables the guard, which is the default for short gates.

Run the ownership diagnostics gate after changing city-transfer mechanics or
ownership-change reporting:

```bash
tools/organic_history/ownership_diagnostics_gate.sh
```

The Lua ruleset emits `organic_history_ownership_change` for every observed
engine transfer and every script-initiated transfer. Categories distinguish
real combat (`engine_combat`), political transfers such as succession or
secession, and legacy scripted conquest/absorption. `analyze_campaign.py`
exposes these counts and events under `ownershipChanges`.

Run the Phase 62 real-combat feasibility gates after changing temporary
strategy-target AI hooks or ferry coordination:

```bash
tools/organic_history/phase62_land_strategy_gate.sh
tools/organic_history/phase62_overseas_strategy_gate.sh
```

The land fixture focuses Rome on Athens. The overseas fixture focuses Portugal
on Cusco. Both provide a finite prepared force, then require the target city to
be captured by the expected attacker through engine combat before the temporary
directive expires. Script-initiated ownership changes fail the gates.

Run the strategy persistence gate after changing directive state, Lua bindings,
or player save/load:

```bash
tools/organic_history/phase63_strategy_persistence_gate.sh
```

It saves an active overseas offensive directive, checks the versioned savegame
fields, resumes without reapplying the profile, and verifies Lua read-back
before resumed AI processing.

Run the Phase 29 diagnostics-only lifecycle probe after editing lifecycle probe
profiles, contact/discovery diagnostics, or probe reporting:

```bash
tools/organic_history/phase29_probe_gate.sh
```

The gate enables the Phase 29 lifecycle probe profile plus deterministic
threshold overrides, then checks that dynastic-transfer, expansion-pressure,
partial-contraction, and arrival diagnostics are all structured and nonzero
without changing city ownership or triggering secession.

For longer Phase 29 evidence runs, use:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase29_lifecycle_probe.json \
  --scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --seeds 1-20 \
  --turns 200 \
  --players 4 \
  --saveturns 25 \
  --timeout 3000 \
  --jobs 2 \
  --max-load-average 18 \
  --load-check-interval 30 \
  --output-dir runs/organic_history_phase29_probe_20x200
```

Contact/discovery diagnostics are report-only. `organic_history_arrival` logs
the first time an actor owns a city in a region, `organic_history_ocean_crossing`
logs first region-arrival proxies across Atlantic/Pacific group boundaries, and
`organic_history_contact` logs first shared-region contact proxies between
actors. These are not diplomacy, disease, or colonial gameplay mechanics.

Run the Phase 29 active contraction gate after editing the first bounded
contraction effect:

```bash
tools/organic_history/phase29_contraction_gate.sh
```

The candidate profile keeps full collapse, cluster release, civil war, and
fallback secession disabled. It only permits sustained-risk single-city
peripheral release behind `organic_history_partial_contraction_enabled`.

Run the Phase 29 successor inheritance gate after editing dynastic transfer
activation:

```bash
tools/organic_history/phase29_successor_inheritance_gate.sh
```

The candidate profile keeps raw mechanics bounded: eligible dynastic successors
can be activated through their normal emergence path and inherit one validated
local predecessor city. Strong/healthy predecessors still log protected outcomes
instead of being forced to collapse.

Run the Phase 30 diagnostics gate after editing contraction or inheritance
activation/skip reporting:

```bash
tools/organic_history/phase30_diagnostics_gate.sh
```

The gate wraps the Phase 29 probe, contraction, and successor-inheritance gates
and also requires per-actor reason counts plus candidate-quality fields. For
Phase 30 diagnostics pilots, use
`tools/organic_history/profiles/phase30_lifecycle_diagnostics_candidate.json`.

Run the Phase 30 successor inheritance gate after editing bounded inheritance
transfer limits or predecessor selection:

```bash
tools/organic_history/phase30_successor_inheritance_gate.sh
```

The gate forces a local Mesopotamian successor case and verifies that the
Phase 30 cluster cap can transfer multiple safe local cities while preserving
the older one-city inheritance gate.

Run the other focused Phase 30 lifecycle gates after editing their slices:

```bash
tools/organic_history/phase30_contraction_gate.sh
tools/organic_history/phase30_iberia_gate.sh
tools/organic_history/phase30_sumer_gate.sh
tools/organic_history/phase30_burst_gate.sh
```

These gates cover bounded contraction clusters, Iberia-local successor handling,
Sumer/Mesopotamian city-density support for Abbasid handoff, and bounded burst
support for Assyria/Persia/Rome/Steppe. All remain profile-gated through
`phase30_lifecycle_diagnostics_candidate.json`.

For combined Phase 30 active lifecycle pilots, use:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase30_lifecycle_diagnostics_candidate.json \
  --scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --seeds 1-20 \
  --turns 200 \
  --players 4 \
  --saveturns 25 \
  --timeout 3000 \
  --jobs 2 \
  --max-load-average 18 \
  --load-check-interval 30 \
  --output-dir runs/organic_history_phase30_lifecycle_candidate_20x200
```

For combined Phase 29 active lifecycle pilots, use:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/phase29_lifecycle_active_candidate.json \
  --scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --seeds 1-20 \
  --turns 200 \
  --players 4 \
  --saveturns 25 \
  --timeout 3000 \
  --jobs 2 \
  --max-load-average 18 \
  --load-check-interval 30 \
  --output-dir runs/organic_history_phase29_lifecycle_active_20x200
```

Generate a per-civilization historical-fit report from a global sweep:

```bash
python3 tools/organic_history/generate_civilization_evidence.py \
  --campaign-dir runs/organic_history_phase29_lifecycle_active_20x200

python3 tools/organic_history/global_historical_fit_report.py \
  --sweep-dir runs/organic_history_phase29_lifecycle_active_20x200
```

The report writes `global_historical_fit_report.json` under the sweep directory.
It compares observed spawn rate, survival/scale proxies, collapse risk, and
release-candidate diagnostics against first-pass expectations. By default it is
report-only; pass `--strict` to exit non-zero when any actor has a fail verdict.text
The report also includes `historicalGravityAssessment` per actor to distinguish
pressure reasons from escape routes such as strong core control, restrained
expansion, and low rival pressure.text
`global_historical_fit_report.py` accepts either the legacy
`full_100x200_summary.json` or the normal `campaign_summary.json` written by
`run_campaign.py`.
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
tools/organic_history/full_overnight.sh \
  --output-dir runs/organic_history_full_overnight \
  --resume
```

Preview or inspect the long orchestration:

```bash
tools/organic_history/full_overnight.sh \
  --output-dir runs/organic_history_full_overnight \
  --dry-run

python3 tools/organic_history/overnight_status.py \
  runs/organic_history_full_overnight
```

The first gameplay mechanic uses Freeciv's built-in
`Player:civil_war(probability)` and is only active when explicitly enabled via
campaign commands. Normal gates keep mechanics off.

Generate a mechanics profile from calibration output:

```bash
python3 tools/organic_history/mechanics_profile.py \
  --campaign-dir runs/organic_history_full_overnight/03_calibration/campaign \
  --thresholds-output runs/organic_history_full_overnight/04_thresholds/thresholds.json \
  --profile-output runs/organic_history_full_overnight/04_thresholds/mechanics_v1_profile.json
```

The default profile mode is conservative (`--mode safe`). If a long A/B run is
safe but inert, generate a bounded probe profile instead:

```bash
python3 tools/organic_history/mechanics_profile.py \
  --campaign-dir runs/organic_history_full_overnight/03_calibration/campaign \
  --thresholds-output runs/organic_history_profile_v2_probe/thresholds.json \
  --profile-output runs/organic_history_profile_v2_probe/mechanics_v2_probe_profile.json \
  --mode probe

python3 tools/organic_history/run_experiment.py \
  --preset mechanics_probe \
  --profile runs/organic_history_profile_v2_probe/mechanics_v2_probe_profile.json \
  --output-dir runs/organic_history_mechanics_v2_probe \
  --clean
```

For authored scenario A/B runs, pass the scenario and label through the
experiment wrapper:

```bash
python3 tools/organic_history/run_experiment.py \
  --ruleset-serv data/organic_history.serv \
  --profile runs/organic_history_phase19_successor_profile/successor_secession_v1_profile.json \
  --scenario data/organic_history/scenarios/earth_1450_v1.sav \
  --label phase19_1450_successor \
  --seeds 1-3 \
  --turns 200 \
  --players 8 \
  --output-dir runs/organic_history_phase19_ab_1450 \
  --clean
```

Campaign and experiment summaries include civil-war eligibility diagnostics:
`civilWarSkipReasons`, `civilWarInertRuns`, `candidateMechanicInert`, and
`civilWarChecksPer1000MechanicLogs`. Use these before relaxing thresholds.

Run generated-map regional diagnostics for a run:

```bash
python3 tools/organic_history/region_diagnostics.py \
  --run-dir runs/organic_history_gate \
  --output runs/organic_history_gate/region_metrics.json
```

## Scenario Fixtures

Generate the minimal organic-history Earth fixtures:

```bash
python3 tools/organic_history/create_scenario_fixture.py
```

Validate that the ancient fixture loads with the organic-history ruleset and Lua
diagnostics:

```bash
tools/organic_history/scenario_gate.sh
```

Run a short scenario campaign:

```bash
python3 tools/organic_history/run_campaign.py \
  --preset scenario_ancient \
  --output-dir runs/organic_history_scenario_ancient_gate \
  --clean
```

Compare a like-for-like generated-map baseline with the scenario campaign:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --seeds 1-3 \
  --turns 80 \
  --players 8 \
  --saveturns 10 \
  --timeout 600 \
  --output-dir runs/organic_history_generated_80_gate \
  --clean \
  --label generated_80

python3 tools/organic_history/compare_campaigns.py \
  --baseline runs/organic_history_generated_80_gate \
  --candidate runs/organic_history_scenario_ancient_gate \
  --output runs/organic_history_scenario_comparison/comparison_summary.json \
  --csv-output runs/organic_history_scenario_comparison/comparison_metrics.csv
```

Scenario region boxes are stored in
`data/organic_history/scenario_regions.json`; the Lua ruleset also carries
authored actor/city metadata for v1 starts so known historical cities use their
intended core regions before falling back to coordinate boxes. Authored metadata
activates only when an authored scenario fixture is detected by exact city/tile
matches, so generated maps do not inherit scenario actor identities from matching
leader or city names. The ruleset logs
`organic_history_region`, `organic_history_prestige`,
`organic_history_city_pressure`, `organic_history_institution`, and
`organic_history_event_risk` diagnostics without changing gameplay.

## Prototype-Parity Diagnostics

City pressure diagnostics are the first Freeciv-side analogue to the prototype's
province pressure model. They remain logging-only and track bounded per-city
signals for unrest, autonomy, development, food/economic/garrison pressure,
climate stress, migration pressure, and occupation turns.

Run the focused gate:

```bash
tools/organic_history/city_pressure_gate.sh
```

Campaign summaries aggregate:

```text
organicCityPressureLogs
organicInstitutionLogs
organicEventRiskLogs
meanCityUnrest
meanCityAutonomy
meanMigrationPressure
meanInstitutionCohesion
meanReformPressure
meanSuccessionRisk
meanFiscalRisk
```

The first institution diagnostics are also logging-only. They infer broad
prototype-like archetypes/state forms from dominant scenario regions and city
counts, then log cohesion and reform pressure. Event-risk diagnostics forecast
succession, fiscal, plague, trade disruption, climate, and frontier pressure
without applying effects.

For hand-authored future scenarios, prefer script-assisted generation from a
base scenario using Freeciv's Lua edit APIs (`edit.create_player`,
`edit.city_create`) and save with `scensave`, rather than directly editing all
savegame player/city sections by hand.

Regenerate all authored v1 fixtures with:

```bash
python3 tools/organic_history/create_scenario_fixture.py --include-v1 --all-v1-plans
```

Historical actor/start plans are stored as `earth_*_v1_starts.json`; validation
checks that the saved fixtures contain the expected fixed players, city
coordinates, starting gold, known technologies, current research, and authored
core-region/successor metadata:

```bash
python3 tools/organic_history/validate_scenario.py \
  data/organic_history/scenarios/earth_ancient_v1.sav \
  --starts-plan data/organic_history/scenarios/earth_ancient_v1_starts.json \
  --turns 20 \
  --players 7 \
  --output-dir runs/organic_history_ancient_v1_validate \
  --timeout 240
```

The starts plan also contains diplomacy metadata. Those entries are not applied
to Freeciv diplomatic state yet because the safe server/Lua authoring path does
not expose arbitrary initial diplomacy editing.

`earth_ancient_v1` currently validates:

- seven fixed actors/cities and coordinates
- starting gold
- known ancient technologies
- current research targets
- authored `coreRegion`, per-city `region`/`core`, `successorNation`, and
  `successorNames` metadata used by Lua diagnostics and fallback secession

The 120-turn dynastic stress A/B after era enrichment is safe:

```text
generated-map:    safeToIterate=true, checks=10, triggers=0, meanDynasticBonus=0.359
earth_ancient_v1: safeToIterate=true, checks=0,  triggers=0, meanDynasticBonus=0.003
```

## Next Command-Gated Mechanic

Phase 6 calibration succeeded for both generated-map and `earth_ancient_v1`
80-turn campaigns. Generated maps showed higher city unrest, migration pressure,
reform pressure, and lower institution cohesion; `earth_ancient_v1` stayed more
cohesive and had near-zero succession risk.

Selected mechanic: **dynastic stress / succession-risk probe**. It should feed a
small, bounded succession-risk bonus into the existing civil-war eligibility
calculation, rather than adding a new effect. This is lower risk than direct
migration/climate instability because it reuses existing event-risk,
institution, and civil-war diagnostics and remains behind explicit commands.

Guardrails:

- Keep all mechanics off by default.
- Require `organic_history_mechanics_enabled`,
  `organic_history_civil_war_enabled`, and a new dynastic probe flag.
- Log base stress, succession risk, cohesion/reform pressure, effective stress,
  and skip/action before relaxing thresholds.
- Keep the existing civil-war min turn, min cities, cooldown, probability, and
  one-success-per-turn constraints.
- Stop if comparisons lose `safeToIterate`, show failures, or show runaway
  trigger/check rates.

Run the focused gate:

```bash
tools/organic_history/dynastic_stress_gate.sh
```

Probe results from the initial 80-turn calibration:

```text
generated-map:   safeToIterate=true, checks=3, triggers=1, meanDynasticBonus=0.074
earth_ancient_v1: safeToIterate=true, checks=0, triggers=0, meanDynasticBonus=0.0
```

The generated-map probe shows the path can become active under pressure. The
authored ancient scenario remains stable, which is the expected control result.

Generate the reusable command-gated dynastic gameplay profile:

```bash
python3 tools/organic_history/mechanics_profile.py \
  --campaign-dir runs/organic_history_phase8_generated_120 \
  --thresholds-output runs/organic_history_phase9_dynastic_profile/thresholds.json \
  --profile-output runs/organic_history_phase9_dynastic_profile/dynastic_stress_v1_profile.json \
  --mode dynastic
```

The profile emits commands for civil war plus dynastic stress. Institution
stress modifiers are available but disabled in the base profile:

```text
organic_history_institution_stress_modifiers_enabled = false
organic_history_institution_stress_max_modifier = 4
```

Phase 9 160-turn profile results:

```text
generated-map:    safeToIterate=true, verdict=active_safe_triggering, checks=22, triggers=2
earth_ancient_v1: safeToIterate=true, verdict=active_safe_triggering, checks=7,  triggers=1
```

Default-on readiness: not ready. Keep all mechanics command-gated until
continuation/save-load is fixed or safely worked around and longer A/B runs stay
safe.

Summarize gameplay readiness across comparison artifacts:

```bash
python3 tools/organic_history/gameplay_readiness.py \
  --comparison runs/organic_history_phase9_dynastic_160_calibration/generated_comparison.json \
  --comparison runs/organic_history_phase9_dynastic_160_calibration/ancient_v1_comparison.json \
  --continuation runs/organic_history_full_overnight/05_continuation/check/continuation_summary.json \
  --output runs/organic_history_phase10_readiness/gameplay_readiness.json
```

Current readiness verdict:

```text
commandGatedReady=true
defaultOnReady=false
defaultOnBlocker=continuation/save-load is not successful
```

## Mandate / Reunification Stability

Mandate pressure is the first positive stability counterweight to dynastic
civil-war pressure. It logs `organic_history_mandate` every turn and can reduce
dynastic effective stress for regional hegemons when explicitly enabled.

Generate the mandate profile:

```bash
python3 tools/organic_history/mechanics_profile.py \
  --campaign-dir runs/organic_history_phase8_generated_120 \
  --thresholds-output runs/organic_history_phase11_mandate_profile/thresholds.json \
  --profile-output runs/organic_history_phase11_mandate_profile/mandate_stability_v1_profile.json \
  --mode mandate
```

Commands introduced by the profile:

```text
organic_history_mandate_enabled = true
organic_history_mandate_max_stress_reduction = 4
```

Phase 11 80-turn A/B:

```text
generated-map:    safeToIterate=true, verdict=active_safe_no_triggers, checks=4, triggers=0, meanMandateReduction=0.049
earth_ancient_v1: safeToIterate=true, verdict=inert_stable_control, checks=0, triggers=0, meanMandateReduction=0.196
```

Mandate does not change ownership, diplomacy, production, terrain, or ruleset
balance. It only modifies effective stress through a command-gated bounded
reduction.

## Fiscal / Frontier Pressure

Pressure mode adds fiscal and frontier pressure as bounded command-gated
effective-stress modifiers while keeping mandate stability enabled as a
counterweight:

```bash
python3 tools/organic_history/mechanics_profile.py \
  --campaign-dir runs/organic_history_phase8_generated_120 \
  --thresholds-output runs/organic_history_phase12_pressure_profile/thresholds.json \
  --profile-output runs/organic_history_phase12_pressure_profile/pressure_events_v1_profile.json \
  --mode pressure
```

Phase 12 80-turn A/B:

```text
generated-map:    safeToIterate=true, verdict=active_safe_no_triggers, checks=4, triggers=0, meanPressureModifier=0.797
earth_ancient_v1: safeToIterate=true, verdict=inert_stable_control, checks=0, triggers=0, meanPressureModifier=0.330
```

## Multi-Era Scenarios

Generate all authored v1 scenarios:

```bash
python3 tools/organic_history/create_scenario_fixture.py --include-v1 --all-v1-plans
```

Authored starts plans now exist for:

- `earth_ancient_v1`
- `earth_medieval_v1`
- `earth_1450_v1`

Phase 13 60-turn calibration succeeded for all three era fixtures.

Authored starts now also provide core-region and successor metadata. Lua uses
that metadata for known scenario actors/cities before falling back to compact-map
coordinate boxes, which makes mandate/core-region diagnostics and secession
selection less dependent on distorted 80x50 geography.

## Civilization Outcome Studies

Run per-civilization outcome analysis after long campaigns:

```bash
python3 tools/organic_history/civilization_outcomes.py \
  --campaign runs/organic_history_outcome_study/generated_200 \
  --campaign runs/organic_history_outcome_study/ancient_v1_200 \
  --campaign runs/organic_history_outcome_study/medieval_v1_200 \
  --campaign runs/organic_history_outcome_study/1450_v1_200 \
  --output runs/organic_history_outcome_study/civilization_outcomes.json \
  --csv-output runs/organic_history_outcome_study/civilization_outcomes.csv
```

Phase 14 long-run study summary:

```text
generated-map: 3/3 runs, 41 checks, 3 triggers, no eliminations
ancient_v1:    3/3 runs, 20 checks, 0 triggers, no eliminations
medieval_v1:   3/3 runs, 18 checks, 0 triggers, no eliminations
1450_v1:       3/3 runs, 36 checks, 3 triggers, no eliminations
```

The mechanics are measurable and safe, but deep historical arcs are not yet
strong enough: collapse is rare, no-successor civil wars block fragmentation,
some scenario starts are underpowered, and successor names/nations are not yet
region-aware.

## Rome-First Tuning

Rome's initial problem was under-expansion, not collapse. Baseline
`earth_ancient_v1` outcomes ended with Rome at 3, 3, and 2 cities and no
dynastic checks.

The tuned ancient scenario gives Rome a stronger start:

- second city: Neapolis
- higher starting gold
- `Trade` in addition to military techs
- Expansionist/Aggressive/Builder trait modifiers

Check Rome against explicit thresholds:

```bash
python3 tools/organic_history/civilization_outcomes.py \
  --campaign runs/organic_history_rome_tuning/ancient_v1_rome_tuned_200 \
  --output runs/organic_history_rome_tuning/rome_tuned_outcomes.json \
  --csv-output runs/organic_history_rome_tuning/rome_tuned_outcomes.csv \
  --focus-civ Romulus \
  --min-mean-final-cities 5 \
  --min-any-max-cities 6 \
  --min-total-checks 1
```

Current tuned result:

```text
final cities: 16, 15, 13
max cities: 16, 15, 15
dynastic checks: 6
dynastic triggers: 0
```

Rome now reaches regional scale. The next Rome-specific work should tune
crisis/collapse after rise, not add more expansion buffs.

## Secession Fallback

Fallback secession makes built-in civil-war noops visible when explicitly
enabled. It is command-gated and runs only after `Player:civil_war()` returns no
successor.

Commands:

```text
organic_history_secession_fallback_enabled = true
organic_history_secession_min_cities = 10
organic_history_secession_max_cities = 1
```

Guardrails:

- max one fallback secession per turn
- existing civil-war cooldown still applies
- transfers one non-primary-capital, non-capital, non-government-center
  candidate city
- authored metadata biases selection toward peripheral/non-core cities and gives
  successors parent/region-aware names
- no default-on behavior

Rome 3 x 200-turn A/B result:

```text
safeToIterate=true
candidateWorseThanBaseline=false
fallback secession triggers=9 total
Rome final cities=13, 11, 18
Rome secessions=4
```

Rome still rises, but now shows visible crisis/secession after reaching scale.

Generate the metadata-aware successor profile:

```bash
python3 tools/organic_history/mechanics_profile.py \
  --campaign-dir runs/organic_history_phase8_generated_120 \
  --thresholds-output runs/organic_history_phase18_successor_profile/thresholds.json \
  --profile-output runs/organic_history_phase18_successor_profile/successor_secession_v1_profile.json \
  --mode successor
```

`civilization_outcomes.py` now preserves fallback secession lineage details:
successor name/nation, parent actor, core region, transferred city, city region,
and whether the transferred city was authored core or peripheral.

Phase 19 long-run successor-profile A/B:

```text
generated fixed:  safe=true, final cities 84.0 -> 77.333, max share 0.259 -> 0.257, secessions=28
ancient v1:       safe=true, final cities 76.333 -> 70.0, max share 0.234 -> 0.209, secessions=12
medieval v1:      safe=true, final cities 68.667 -> 74.667, max share 0.341 -> 0.202, secessions=15
1450 v1:          safe=true, final cities 91.667 -> 92.667, max share 0.216 -> 0.187, secessions=29
```

Phase 19 also hardened scenario metadata and retuned medieval Steppe/Chola
starts. The tuned medieval fixture gives Temujin a third core steppe city
(`Beshbalik`) and gives Rajaraja Chola a second core Indian city
(`Kanchipuram`) plus trade/expansion traits.

Historical continuation readiness:

```bash
tools/organic_history/historical_continuation_gate.sh
```

The gate creates fresh short saves and then resumes them for `earth_ancient_v1`,
balanced `earth_medieval_v1`, and `earth_1450_v1`, both plain and
successor-enabled. It verifies that loaded games advance turns, organic-history
hooks resume, authored scenario metadata remains active, successor-mode dynastic
probes continue, and a resumed Roman fallback secession keeps authored lineage.

Generate a historical readiness report from the long A/B summaries plus the
continuation gate:

```bash
python3 tools/organic_history/gameplay_readiness.py \
  --comparison runs/organic_history_phase19_ab_ancient/experiment_summary.json \
  --comparison runs/organic_history_phase19_ab_medieval_balanced/experiment_summary.json \
  --comparison runs/organic_history_phase19_ab_1450/experiment_summary.json \
  --continuation runs/organic_history_historical_continuation_gate/historical_continuation_summary.json \
  --output runs/organic_history_phase20_historical_readiness/readiness.json
```

Phase 20 result: historical continuation/save-load now passes for ancient,
balanced medieval, and 1450 scenarios. The readiness report says the successor
profile is ready to evaluate for default-on historical-scenario gameplay, while
generated-map lineage remains intentionally out of scope.

Packaged historical near-default candidate:

```bash
tools/organic_history/historical_candidate_gate.sh
```

The packaged profile lives at
`tools/organic_history/profiles/historical_successor_candidate.json`. It is still
explicitly selected, not globally default-on. Use it with campaign tools:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/historical_successor_candidate.json \
  --scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --seeds 1-3 \
  --turns 120 \
  --players 7 \
  --output-dir runs/organic_history_phase21_historical_candidate/ancient \
  --clean
```

Phase 21 packaged-profile validation:

```text
ancient v1:  3/3 succeeded, mean final cities 50.333, secessions=4
medieval v1: 3/3 succeeded, mean final cities 53.667, secessions=6
1450 v1:     3/3 succeeded, mean final cities 81.333, secessions=2
```

Generated maps remain out of scope for this candidate profile.

Historical mandate-loss candidate:

```bash
tools/organic_history/historical_mandate_loss_gate.sh
```

The mandate-loss profile extends the packaged successor candidate with bounded
state-capacity pressure:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/historical_mandate_loss_candidate.json \
  --scenario data/organic_history/scenarios/earth_ancient_v1.sav \
  --seeds 1-3 \
  --turns 120 \
  --players 7 \
  --output-dir runs/organic_history_phase22_mandate_loss_candidate/ancient \
  --clean
```

Phase 22 result:

```text
ancient v1:  3/3 succeeded, state-capacity modifier mean 0.035, secessions=3
medieval v1: 3/3 succeeded, state-capacity modifier mean 0.000, secessions=2
1450 v1:     3/3 succeeded, state-capacity modifier mean 0.000, secessions=4
ancient long probe: 1/1 succeeded, modifier mean 0.213, secessions=5
```

The modifier is intentionally conservative: it only applies when mandate is low,
state size is above the configured minimum, and the mandate-loss profile is
selected. It feeds effective stress; it does not directly script collapse.

## Global 4000 BCE Scenario

The first true-global fixture uses Freeciv's built-in large Earth map:

```text
data/scenarios/earth-large.sav -> 160x90
```

Generated fixtures:

```text
data/organic_history/scenarios/earth_global_4000_v0.sav
data/organic_history/scenarios/earth_global_4000_v1.sav
data/organic_history/scenarios/earth_global_4000_v1_starts.json
data/organic_history/scenarios/earth_global_4000_timeline.json
```

The v1 fixture starts with four ancient cores: Egypt/Narmer, Sumer/Gilgamesh,
India/Chandragupta, and China/Qin Shi Huang. Later actors are pre-created as
dormant players and activated by command-gated emergence, which avoids mature-game
`edit.create_player()` crashes seen in early global pilots. Each active or
dormant actor must use a unique Freeciv nation slot; Freeciv treats nation
ownership as one-to-one with players.

Run the global gate:

```bash
tools/organic_history/global_4000_gate.sh
```

Run the longer lifecycle gate before large global sweeps or DoC-style actor
expansion:

```bash
tools/organic_history/global_4000_lifecycle_gate.sh
```

This gate runs the 160x90 global fixture to turn 200, checks that Freeciv logged
no assertions, then resumes the final save through turn 220.

The canonical global historical data layer is:

```text
data/organic_history/history/earth_global_4000.json
```

It generates and checks the global starts plan and timeline:

```bash
python3 tools/organic_history/generate_history_artifacts.py --check
```

Region-claim diagnostics are logged as `organic_history_claim_pressure`. They are
diagnostic-only and summarize each authored actor's city mix across core,
historical, contested, colonial, cultural, respawn, and peripheral regions plus
core-region rival pressure.

Global emergence v2 is enabled in the candidate profile with
`organic_history_emergence_conditional_enabled`. It logs
`organic_history_emergence_condition`, classifies attempts as empty-core,
lineage-successor, weak-holder, or foreign-core claimant, searches for relocated
city sites near the actor's target inside the actor's core region, and delays
saturated no-site cases instead of permanently blocking, jumping across a broad
continent-scale region, or retrying noisily every turn.

Scenario authoring uses the extended nation set so dormant actors can keep
non-core nation slots such as Chola and Manchu. Song currently uses the unique
Korean runtime slot to avoid conflicting with active China while retaining
Chinese successor metadata.

The first DoC-inspired global expansion wave adds dormant ancient/classical
actors for Nubia, Assyria, Hittite, Phoenicia, Carthage, and Celts. The expanded
global lifecycle gate remains assertion-clean.

Collapse/resurrection is currently diagnostics-only. The server logs
`organic_history_collapse` and `organic_history_collapse_candidate` to report
collapse risk, core/peripheral mix, and candidate release cities. These logs do
not transfer ownership, create successor players, or otherwise alter gameplay.

DoC flavor is currently diagnostics-only. The server logs
`organic_history_flavor` entries for canonical UHV-style diagnostics and policy
hints. These entries are intended for sweep analysis before any UI, dynamic-name,
diplomacy, contact/colonial, or objective behavior is promoted.

Historical gravity safeguards live in the canonical model under
`historicalGravity`. They define condition gates, player/AI escape routes, and
probabilistic outcome weights. Future mechanics should use these as generic
pressure safeguards: historical actor data defines claims/niches/flavor, while
runtime game state determines whether pressure applies.

Lifecycle archetypes also live in the canonical model under
`lifecycleArchetypes` and `actorLifecycleTypes`. Generated Lua exposes
`organic_history_global_lifecycle_archetypes` and
`organic_history_global_actor_lifecycle_types`. These archetypes describe target
city curves, bootstrap packages, successor modes, contraction rules, escape
routes, and outcome weights; they are data only until profile-gated mechanics
consume them.

Bootstrap package v1 is command-gated by `organic_history_bootstrap_enabled`.
The baseline `global_4000_emergence_candidate.json` profile remains
emergence-only; use `global_4000_bootstrap_candidate.json` to test bounded
post-spawn gold and support-unit packages. `global_4000_bootstrap_gate.sh`
checks that early global emergences receive bootstrap support without Freeciv
assertions.

Dynastic transfer v1 is diagnostics-only and command-gated by
`organic_history_dynastic_transfer_probe_enabled`. It evaluates condition-gated
successor pressure for `dynastic_successor` lifecycle actors, logs protected
escape-route cases versus candidate pressure, and always logs `applied=false`.
It does not create players, transfer cities, rename nations, or change
ownership. Validate it with:

```bash
tools/organic_history/dynastic_transfer_gate.sh
```

Regional expansion pressure v1 is diagnostics-only and command-gated by
`organic_history_expansion_pressure_probe_enabled`. It compares an actor's
current city count to its lifecycle target city curve, checks whether core or
historical claims remain under-owned, and logs protected escape routes for
economic trouble, collapse crisis, or being on curve. It always logs
`applied=false` and does not create units or cities. Validate it with:

```bash
tools/organic_history/expansion_pressure_gate.sh
```

Partial contraction v1 is diagnostics-only and command-gated by
`organic_history_partial_contraction_probe_enabled`. It consumes collapse-risk
diagnostics plus lifecycle contraction rules, tracks sustained risk, and logs
candidate release pressure with `applied=false`. It does not transfer cities or
create successor players. Validate it with:

```bash
tools/organic_history/partial_contraction_gate.sh
```

Run the current emergence candidate:

```bash
python3 tools/organic_history/run_campaign.py \
  --ruleset-serv data/organic_history.serv \
  --profile tools/organic_history/profiles/global_4000_emergence_candidate.json \
  --scenario data/organic_history/scenarios/earth_global_4000_v1.sav \
  --seeds 1-3 \
  --turns 120 \
  --players 4 \
  --output-dir runs/organic_history_phase24_global_diagnostics/pilot_3x120 \
  --clean
```

Phase 24 pilot result:

```text
3/3 120-turn runs succeeded
mean final cities: 145.333
mean max city share: 0.377
emerged in all seeds by turn 120: Greece, Persia, Rome, Franks
```

Global fallback secession, built-in civil war, and dynastic stress are
intentionally disabled/deferred in the global emergence profile. Early large-map
pilots showed Freeciv nation-set crashes when creating successor players in
mature global games, and duplicate dormant-player nations can violate Freeciv's
player/nation ownership invariant. Dynamic emergence now uses unique dormant
players; global successor/collapse integration should be reintroduced only after
a safe successor nation mapping is implemented for large Earth.

## Multi-Civilization Tuning

The Rome tuning pattern now applies to other underperformers: tune starts/traits
first, then check whether the civ reaches meaningful scale and pressure.

Phase 17 tuned:

```text
Persia/Cyrus:    final cities 7.0 -> 8.667; max cities 9.0 -> 12.0
Song/Taizu:      final cities 4.333 -> 15.667; max cities 5.333 -> 16.667
Steppe/Temujin:  final cities 5.0 -> 8.0; max cities 6.667 -> 9.0
Portugal/Henry:  final cities 3.333 -> 9.0; max cities 5.0 -> 12.0
Castile/Isabella final cities 6.333 -> 6.667; max cities 7.0 -> 9.0
```

The tuning also exposed an unsafe fallback secession edge case in 1450 Venice:
capital/government-center cities must not be selected for fallback transfer.
The selection guard now excludes primary capitals, capitals, and government
centers.

Implementation/probe sequence:

```bash
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

## Next Tooling Targets

1. Extend `earth_ancient_v1` beyond initial actors/cities with technologies,
   diplomacy, and era-specific setup.
2. Run a longer dynastic stress A/B only if probes remain safe and have bounded
   non-zero checks/triggers.
3. Add robust save/load continuation once Freeciv loaded-save automation is solved.
