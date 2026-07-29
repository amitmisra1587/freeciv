# Organic-history Freeciv session handoff

This file preserves the Freeciv plan and a reconstructed history of the
conversation that accidentally continued inside a Workforce Insights Navigator
chat. It is a detailed handoff rather than a verbatim transcript; earlier turns
had already been compacted into checkpoints.

## Repository and branches

- Repository: `https://github.com/amitmisra1587/freeciv.git`
- Local checkout: `/Users/amitmisra/code/freeciv`
- Phase 60 archive branch:
  `amitmisra/phase60-lua-campaign-archive`
- Phase 60 archive commit: `602aad6a0f`
- Main implementation lineage began on:
  `amitmisra/organic-strategy-directives`
- Pushed handoff branch containing all completed work and the Phase 68 start:
  `amitmisra/organic-history-real-gameplay-handoff`
- Phase 56 baseline commit: `bd2792fb52`

Generated `runs/` output and the separate `organic-civ-prototype/` directory
are intentionally excluded from commits.

## Goal

Replace scripted Lua conquest with a hybrid system:

- Lua selects historically plausible strategic intent.
- C/default AI executes diplomacy, production, ferrying, movement, combat,
  occupation, consolidation, exhaustion, and recovery.
- Freeciv resolves outcomes through normal game mechanics.
- Direct city transfers are restricted to political events such as succession,
  secession, civil war, collapse, and peaceful handoff.

The design target is historical gravity rather than predetermined history.
AI-only games producing coherent rise, conflict, decline, succession, and
recovery arcs across many seeds are the primary acceptance test.

Phase 56 remains the comparison baseline until the replacement passes the
full `100 x 200` parity evaluation.

## Why Phase 60 was rejected

The Phase 60 Lua campaign prototype calculated campaign outcomes itself and
then directly transferred cities. Diagnostics showed:

- 48 campaign events but only 29 unique cities.
- 19 repeated attempts, with one city targeted six times.
- Phase 60b had 23 repeats, with one city targeted seven times.
- The top attacker produced roughly one-third of campaign events.
- Abstract manpower remained capped and military attrition did not bind.

This produced scripted outcomes rather than a dynamic strategy game.

## Implemented phases

### Phase 61: archive and baseline

- Archived the Phase 60 prototype on
  `amitmisra/phase60-lua-campaign-archive`.
- Restored a clean Phase 56 implementation base.
- Preserved Phase 56 as a selectable reference.

### Phase 62: ownership diagnostics and real-combat feasibility

Commit: `97a564db62` - Classify organic history ownership changes.

- Centralized scripted transfers through one wrapper.
- Classified ownership changes as engine combat, incitement, diplomatic trade,
  political civil war/collapse/secession/succession, scripted absorption, or
  scripted conquest.
- Added ownership diagnostics and parser support.

Commit: `4185165ec6` - Prove engine-mediated strategic campaigns.

- Added zero-default target bias to default AI.
- Reused normal war desire, target-city value, unit attack tasks, pathfinding,
  and ferry logic.
- Proved Rome could capture Athens through real land combat.
- Proved Portugal could cross the Atlantic and capture Cusco through normal
  ferrying and combat.

### Phase 63: persistent strategic directives

Commit: `1c256d3b8b` - Persist organic strategy directives.

Persisted directive fields include:

- source and version
- posture
- objective type
- target player and city
- intensity
- war-desire bonus
- conquest-worth multiplier
- expiration
- campaign identifier
- integration state

Postures:

- none
- recover
- defend
- consolidate
- prepare
- offensive
- exhausted

Lua setter/query APIs and backward-compatible savegame2/savegame3 handling were
added. Continuation gates verify exact save/load continuity.

### Phase 64: directive execution

Commit: `efe911a247` - Execute organic strategy directives.

- Offensive directives bias war desire and conquest value.
- Posture changes military production.
- Intensity limits committed units.
- A bounded coordinator sends real units and ferries toward the objective after
  homeland defenders are assigned.
- Prepare/offensive suppress unrelated wars.
- Exhausted/recover/consolidate seek ceasefires through normal treaty handlers.
- Humans are never auto-accepted or forced into diplomacy.
- Hostile AI counterparts can refuse peace.
- Inactive directives consume no additional RNG.

### Phase 65: condition-driven strategy market

Commit: `89c17c0a53` - Add organic strategy state machine.

- Added deterministic claim-based objective scoring.
- Candidate score uses claim strength, lifecycle type, distance, city value,
  local defense, relative force, target crisis, mandate, recovery, and
  overextension.
- Added deterministic tie-breaking without new RNG.
- Added transitions through prepare, offensive, defend, consolidate, exhausted,
  and recover.
- Offensive directives initiate normal default-AI war countdowns.
- Directive ownership is persisted so organic logic cannot seize unrelated
  external directives.
- Disabled/filtered/ineligible markets clean up only their own directives and
  owned war countdowns.
- Save continuation and disabled-market cleanup gates pass.

### Phase 66: real exhaustion and recovery

Commit: `5d9d587f91` - Model real campaign exhaustion.

Persisted campaign baselines:

- campaign and war start turns
- starting unit and city counts
- starting units-lost and units-killed counters
- peak intensity

Exhaustion uses real outcomes:

- units lost and killed
- turns at war
- distant deployed units
- treasury burden
- unhappy cities
- city-count gains and losses
- living simultaneous wars
- mandate and overextension

Exhaustion first tempers offensive intensity, then can enter exhausted posture,
seek a normal ceasefire, and transition to recovery. Recovery can finish early
when peace, fiscal stability, low crisis, and high recovery conditions are met.

Captured-unit score accounting was corrected to increment `units_lost` exactly
once.

### Phase 67: bounded political decline

Commit: `77bd3bea60` - Bound organic political decline.

- Added persisted city integration locks and previous-owner tracking.
- Prevented immediate recapture through generic military targeting, rampage,
  paradrop, diplomats/incitement, city treaty clauses, strategy coordination,
  and scripted transfers.
- Added reverse-transfer rejection.
- Added bounded same-region, one-recipient political clusters.
- Added retained authored or de-facto cores.
- Added recovery immunity following political contraction.
- Reclassified independent absorption as peaceful handoff only when the
  political contract is enabled; Phase 56 telemetry remains unchanged when it
  is disabled.
- Added probability-respecting bounded civil war rather than raw random bulk
  splitting.
- Excluded capitals, government centers, and cities containing GameLoss units
  from bounded civil-war candidates.
- Removed barbarian and pirate nations from successor candidates.
- Added transactional preflight before successor creation/activation.
- Added persistent decline stages:
  administrative pressure, autonomy warning, separatism warning, bounded
  release.
- Persisted collapse cooldowns and same-turn political batch state.

## Validation completed

The following gates passed during implementation:

- ownership diagnostics
- land real-combat strategy
- overseas/ferry real-combat strategy
- directive persistence
- willing and hostile exhaustion diplomacy
- strategy market
- strategy continuation
- strategy cleanup
- condition-driven exhaustion
- real-loss exhaustion
- exhaustion continuation
- political transfer contract
- political transfer continuation
- staged decline warning and cooldown
- engine combat integration lock
- civil-war lock and recovery
- bounded civil-war probability control
- peaceful handoff
- earlier successor inheritance gates
- base organic-history gate

Long land and overseas simulations completed without assertions.

## Phase 68 work in progress

The current uncommitted work begins Phase 68:

- Profile inheritance support in `run_ai_game.py`.
- Profile inheritance support in `run_experiment.py`.
- `profiles/phase68_real_gameplay_candidate.json`, which inherits Phase 56,
  disables `organic_history_conquest_death_enabled`, and enables the generic
  strategy, exhaustion, and political-transfer systems.
- Dynamic-quality parsing in `analyze_campaign.py`.

The intended metrics are:

- real-combat share of normal conquest
- political transfer share
- capture retention after 5/10/20 turns
- repeated ownership changes and ping-pong
- attacker concentration and HHI
- campaign phases, failures, and captures
- exhaustion samples
- decline stages and integration locks

The Phase 68 candidate passed a 20-turn, 24-player global-scenario smoke with
conquest-death disabled and zero scripted-conquest ownership events. It has not
yet been run through paired multi-seed candidate sweeps.

## Remaining plan

1. Validate the completed dynamic-quality analyzer.
2. Run a single-seed Phase 68 smoke test.
3. Run paired Phase 56 versus Phase 68 tests at 5, 10, and 20 seeds.
4. Generate historical fit, extent, destiny, and dynamic-quality reports.
5. Test `earth_medieval_v1` and `earth_1450_v1`.
6. Run save/load continuation comparisons.
7. Run the decision-quality `100 x 200` comparison.
8. Retire scripted conquest-death only if real-combat campaign dynamics reach
   the pre-registered parity thresholds.

Hard requirements:

- 100% of normal conquest captures are engine-combat captures.
- No Lua city transfers on normal conquest paths.
- Direct transfers are reason-tagged political events only.
- No ownership ping-pong inside integration locks.
- Directives-off behavior remains stock-equivalent.
- No assertions, Lua warnings, or save/load divergence.

## Workforce Insights Navigator context

The Freeciv work was accidentally performed in a chat that originally covered
the Workforce Insights Navigator. Before the detour, that project had:

- a deterministic generator-first country dashboard
- extracted reproducible data and frozen-source labeling
- local-only validation after removal of a stale Actions workflow
- a local GeoCities parody
- an age-by-impact experiment that was subsequently reverted
- exact-skill hover/focus tooltips for skill-family gaps
- a refreshed merge-ready dashboard branch

Those dashboard changes are in the separate
`workforce-insights-navigator` repository and are not part of this Freeciv
branch.
