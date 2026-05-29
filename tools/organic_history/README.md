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
`data/organic_history/scenario_regions.json`; the Lua ruleset logs
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

The first practical authored fixture is `earth_ancient_v1.sav`. Regenerate it
with:

```bash
python3 tools/organic_history/create_scenario_fixture.py --include-v1
```

Its historical actor/start plan is
`data/organic_history/scenarios/earth_ancient_v1_starts.json`; validation checks
that the saved fixture contains the expected fixed players, city coordinates,
starting gold, known technologies, and current research:

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
- first version transfers one non-primary-capital candidate city
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
