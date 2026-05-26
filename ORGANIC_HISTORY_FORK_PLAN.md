# Organic History Freeciv Fork Plan

## Why Move To Freeciv

The Python prototype proved useful ideas: organic state formation, dynastic cycles, macro-region agency, colonial successors, concessions, observer replay, and diagnostics. But it is still a custom simulation shell. Freeciv already has the hard parts of a 4X game: map, cities, units, turns, AI, savegames, clients, server commands, rulesets, scenarios, and modpack infrastructure. The right move is to port the design into Freeciv in layers instead of continuing to build a full game engine from scratch.

The goal is not to make a normal Freeciv balance mod. The goal is a fork/modpack where history emerges through pressures: states consolidate, fragment, rename, spawn successors, colonize, resist colonization, and sometimes reunify.

## Architecture Read From This Checkout

- Source root: `/Users/amitmisra/code/freeciv`
- Build system: Meson/Ninja, see `INSTALL`.
- Server logic: `server/`
- Shared game model/rules: `common/`
- AI modules: `ai/`
- Clients: `client/`
- Rulesets/modpacks/scenarios: `data/`
- Standard ruleset examples: `data/classic/`, `data/civ2civ3/`, `data/sandbox/`, etc.
- Rulesets are selected with server command `rulesetdir <dir>` or `.serv` files.
- Rulesets may include `script.lua`; `data/classic/script.lua` already demonstrates `signal.connect(...)` hooks.
- Scenarios are essentially savegames with a `[scenario]` section; see `doc/README.scenarios`.

Important Freeciv guidance from `data/classic/game.ruleset`: do not edit standard rulesets directly. Copy a ruleset directory and modify the copy.

## First Principle

Start as a ruleset/modpack plus scenario workflow. Fork C server internals only when Lua/ruleset/scenario hooks cannot express the mechanic.

This avoids a giant fork too early and makes debugging easier. Once a mechanic proves valuable in Lua/ruleset form, port hot paths or missing primitives into C.

## Suggested Branch Structure

Create a long-lived branch:

```bash
cd ~/code/freeciv
git checkout -b organic-history
```

Add a custom ruleset/modpack:

```text
data/organic_history.modpack
data/organic_history/
  game.ruleset
  governments.ruleset
  nations.ruleset
  techs.ruleset
  units.ruleset
  buildings.ruleset
  terrain.ruleset
  effects.ruleset
  cities.ruleset
  actions.ruleset
  styles.ruleset
  parser.lua
  script.lua
  README.organic_history
```

Initial source should be copied from `data/civ2civ3/` or `data/classic/`. I would start from `civ2civ3` if the default modern Freeciv balance is desired, or `classic` if simpler behavior is easier to control. The current checkout has `classic` docs and a small Lua script example, but Freeciv's default is no longer classic.

Add a server file:

```text
data/organic_history.serv
```

with at least:

```text
rulesetdir organic_history
```

Later add server settings for map size, barbarians, diplomacy, victory, AI skill, and observer defaults.

## Build And Run Baseline

Minimal server-focused dev build:

```bash
cd ~/code/freeciv
export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c@78/lib/pkgconfig:/opt/homebrew/opt/icu4c/lib/pkgconfig:/opt/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
meson setup build-organic '-Dclients=[]' '-Dfcmp=[]' '-Dtools=[]' -Daudio=none -Dmwand=false -Dnls=false -Ddebug=true
ninja -C build-organic
```

The stricter flags keep Phase 0 server-only and avoid local GUI/audio/NLS dependencies. `PKG_CONFIG_PATH` is needed on this macOS machine because ICU is installed but not visible to Meson by default.

If you want a local client too, use a separate build directory, for example with the default GTK client if dependencies are installed:

```bash
meson setup build-organic-gui -Ddebug=true
ninja -C build-organic-gui
```

Run server with the custom ruleset:

```bash
./build-organic/freeciv-server -r data/organic_history.serv
```

Exact binary paths may differ slightly depending on Meson output; use `find build-organic -type f \( -name 'freeciv-server' -o -name 'fcser' \)` if needed.

Current Phase 0 status:

```text
server-only build: passed
baseline run: runs/organic_history_baseline_001
turns: 20
players: 4 AI
seed: 1
save count: 21
result: success
```

## Phase 0: Baseline Reproducibility

Before changing design, prove we can run Freeciv reproducibly.

1. Build server.
2. Run an AI-only game on a generated map with the default ruleset.
3. Save at fixed turns.
4. Confirm the same seed/settings produce comparable results.
5. Create a tiny script to run N AI-only games and collect score/city/player survival metrics.

Deliverable:

```text
tools/organic_history/run_ai_game.py
runs/organic_history_baseline_001/
```

Do not touch game design until this loop works.

## Phase 1: Organic History Ruleset Skeleton

Create `data/organic_history` copied from an existing ruleset.

Initial changes should be modest:

- Disable or soften default victory conditions if they end games too early.
- Tune governments to create more state-form variety.
- Add or rename governments toward historical forms: Empire, Kingdom, Confederation, Merchant League, City League, Republic, Federation, Nomadic Confederation.
- Add effects that make large empires stronger in some ways and brittle in others.
- Add buildings or small wonders representing state capacity, bureaucracy, frontier administration, trade hubs, religious centers.
- Add techs that unlock state capacity and overseas expansion pacing.

Keep the first ruleset valid and playable before adding ambitious Lua.

Validation:

- Server loads `data/organic_history.serv`.
- AI can play 100 turns without crash.
- Save/load works.

## Phase 2: Lua Prototype Layer

Use `data/organic_history/script.lua` as the first place to prototype organic-history behavior.

Known example from `data/classic/script.lua`:

```lua
function city_destroyed_callback(city, loser, destroyer)
  city.tile:create_extra("Ruins", NIL)
  return false
end

signal.connect("city_destroyed", "city_destroyed_callback")
```

Start by discovering available signals and API in `common/scriptcore/` and `server/scripting/`. Then add small hooks:

- On turn start/end, compute player stress.
- On city loss, adjust legitimacy/prestige attributes.
- On city disorder/unhappiness, increase local separatism.
- On player war/peace events, track war exhaustion/prestige.
- On city founding/conquest, track regional ownership.

Store values in script-side tables or Freeciv attributes if available.

First Lua mechanics:

1. `dynastic_stress[player]`
2. `prestige[player]`
3. `regional_claim[player][region]`
4. `separatism[city]`

Emit notifications/logs first. Do not change ownership until metrics prove the triggers fire at sane frequency.

## Phase 3: Scenario Strategy

Freeciv scenarios are savegames. Use that instead of trying to encode the entire Earth in a ruleset.

Path:

1. Generate or choose an Earth map in Freeciv format.
2. Create a scenario with major starting civs and city/province distribution.
3. Save via `/scensave` or client scenario tools.
4. Add scenario-specific Lua data through `[scenario] datafile` if needed.

Start with three scenarios, not one giant final map:

- `organic_earth_ancient_v0`: ancient world broad strokes.
- `organic_earth_1000_v0`: medieval balance with old-world states already formed.
- `organic_earth_1450_v0`: colonization testbed.

The Python full-Earth generator can still help by producing seed data, but Freeciv scenario format will be the runtime target.

## Phase 4: Metrics First

Port the prototype's evaluation discipline into Freeciv.

Metrics to collect per run:

- player/civ survival by turn
- city count per player over time
- territory/city ownership churn
- largest player share
- regional hegemon cycles: China, India, Europe, Near East, Americas
- number of civil wars/successor states
- colony founding and overseas city count
- independence/revolt outcomes
- government changes
- tech era progression
- war count and duration
- collapse/reunification cycles

Create a batch runner that starts the Freeciv server, runs AI-only games, saves/logs at fixed turns, and parses output/savegames.

Suggested deliverable:

```text
tools/organic_history/freeciv_dynamism_campaign.py
tools/organic_history/parse_freeciv_save.py
runs/organic_freeciv_dynamism_001/
```

Acceptance bands should mirror the prototype but Freeciv-specific:

- China-like region sometimes fragments and sometimes reunifies.
- India-like region often multipolar, occasionally hegemonic.
- Europe remains multipolar more often than unified.
- New World colonization happens but is not monopolized.
- No single player dominates the world every run.
- AI-only games show visible map change by turn 100/200/300.

## Phase 5: Organic Mechanics To Prototype In Freeciv

### 1. Dynastic Cycle

Large settled empires accumulate stress from:

- low happiness/disorder
- lost cities
- high corruption/waste/unhappiness if exposed
- too many cities or too much distance from capital
- low treasury
- long war

Stress can cause:

- warning event
- rebel player or barbarian-like faction
- forced government change
- city flips to contender state

### 2. Prestige / Mandate

Prestige rises from:

- capturing cities
- winning wars
- wonders
- high culture/science/economy

Prestige falls from:

- city loss
- disorder
- bankruptcy
- collapse

High prestige helps reunify a region. Low prestige invites civil war.

### 3. Regional Hegemony

Define script regions for China, India, Europe, Near East, Steppe, Africa, Americas.

Track top owner/city share. If a civ controls a strong plurality in China, it gets a mandate/reunification bias. If it gets too large and unstable, it gets dynastic stress.

### 4. Steppe Pressure

Nomadic/frontier players accumulate pressure and periodically attack settled border regions. This should be a punctuated shock, not constant random war.

### 5. Colonization And Independence

For 1450-style scenarios or later eras:

- overseas colonies get autonomy stress
- distance from capital matters
- colonies can become dominions/republics
- New World states should not simply vanish every game

## Phase 6: When To Fork C Code

Stay in ruleset/Lua until you hit one of these limits:

- Lua cannot create/assign a new player cleanly.
- Lua cannot change city ownership reliably.
- Lua cannot inspect enough government/economy/war state.
- AI cannot understand the new mechanics at all.
- Performance becomes bad.

Then fork server C with clear targets:

- `server/scripting/`: expose missing Lua APIs.
- `server/plrhand.c`, `server/citytools.c`, `server/cityturn.c`: player/city ownership and turn hooks.
- `common/government.*`, `common/effects.*`: new effect types if rulesets cannot express them.
- `ai/`: teach AI dynastic/reunification/colonial strategy.

Do not fork client first unless UI/observer display blocks testing.

## Phase 7: First 10 Concrete Tasks

1. Build Freeciv server from this checkout.
2. Run an AI-only game with standard ruleset and save/log it.
3. Copy `data/civ2civ3` or `data/classic` to `data/organic_history`.
4. Add `data/organic_history.modpack` and `data/organic_history.serv`.
5. Confirm server loads the new ruleset unchanged.
6. Add a trivial `script.lua` turn hook that logs turn/player count.
7. Add a tiny batch runner for 3 AI-only games.
8. Add metrics parser for city/player survival and largest-player share.
9. Add dynastic stress as logging-only Lua state.
10. Only then add a first gameplay mutation: dynastic crisis notification or small rebel event.

## What To Bring From The Python Prototype

Bring concepts, not code:

- dynamism diagnostics
- dynastic stress
- mandate/reunification pressure
- identity/state-form evolution
- colonial autonomy/independence arcs
- native/regional agency
- observer-oriented reporting

Do not try to port the Python engine wholesale. Freeciv already has the engine. The port is conceptual and data-driven.

## Immediate Next Session Prompt

Use this in a new chat:

```text
We are in ~/code/freeciv. Read ORGANIC_HISTORY_FORK_PLAN.md. Start Phase 0/1: build a server-only Freeciv dev build, run a baseline AI-only game, copy a standard ruleset into data/organic_history, add organic_history.serv/modpack, and verify the server loads it. Do not implement gameplay mechanics until the baseline run and custom ruleset load are verified.
```
