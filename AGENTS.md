# Agent Instructions: Organic History Freeciv Fork

This repository is being adapted into an organic-history Freeciv fork. The user is not expected to write code manually; AI agents should be able to build, run, test, and iterate independently.

## Project Goal

Build a Freeciv-based historical 4X where history emerges through pressures rather than fixed scripts: dynastic cycles, regional hegemony, civil wars, successor states, colonial autonomy, native/regional agency, and observer-friendly diagnostics.

## First Rule

Do not start by changing gameplay. First keep build/run/metrics working. Every mechanic must have a smoke test or diagnostic metric.

## Build Baseline

Preferred server-only development build:

```bash
meson setup build-organic '-Dclients=[]' '-Dfcmp=[]' '-Dtools=[]' -Ddebug=true
ninja -C build-organic
```

On macOS or dependency-light environments, use the stricter server-only form:

```bash
export PKG_CONFIG_PATH="/opt/homebrew/opt/icu4c@78/lib/pkgconfig:/opt/homebrew/opt/icu4c/lib/pkgconfig:/opt/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
meson setup build-organic '-Dclients=[]' '-Dfcmp=[]' '-Dtools=[]' -Daudio=none -Dmwand=false -Dnls=false -Ddebug=true
ninja -C build-organic
```

If `build-organic` already exists, use:

```bash
ninja -C build-organic
```

Find the server binary with:

```bash
find build-organic -type f \( -name 'freeciv-server' -o -name 'fcser' \)
```

## Ruleset Policy

Do not edit upstream rulesets such as `data/classic`, `data/civ2civ3`, or `data/sandbox` directly. Copy one into `data/organic_history` and modify the copy.

## Tooling Location

Organic-history harnesses and diagnostics belong under:

```text
tools/organic_history/
```

Design notes and task queues should go under:

```text
docs/organic_history/
```

## Gate

Use the local gate when it exists:

```bash
tools/organic_history/gate.sh
```

The gate runs the server-only build and a 20-turn AI-only game through
`data/organic_history.serv`. Use the campaign gate for parser and multi-seed
coverage:

```bash
tools/organic_history/campaign_gate.sh
```

The campaign gate runs the single-run gate plus a 3-seed AI-only campaign and
writes summaries under `runs/organic_history_campaign_gate/`.

Use the mechanics gate for the first disabled-by-default civil-war mechanic:

```bash
tools/organic_history/mechanics_gate.sh
```

Use the full overnight runner for calibration, continuation check, mechanics
gate, and long A/B comparison. It supports `--dry-run`, `--resume`, and
`--output-dir`:

```bash
tools/organic_history/full_overnight.sh --output-dir runs/organic_history_full_overnight --resume
```

Inspect progress with:

```bash
python3 tools/organic_history/overnight_status.py runs/organic_history_full_overnight
```

Organic-history mechanics must remain off by default. Enable them only through
explicit `lua cmd organic_history_mechanics_enabled = true` campaign commands.

## Coding Rules

- Preserve existing GPL headers in files you edit.
- Prefer adding `organic_history`-prefixed files/modules over invasive edits.
- Keep changes small and buildable.
- For C changes, run the server build before finishing.
- For ruleset changes, verify the server loads the ruleset.
- For mechanics changes, add metrics before tuning.

## Initial Work Sequence

1. Build server-only Freeciv.
2. Run one AI-only baseline with the stock ruleset.
3. Copy a standard ruleset to `data/organic_history`.
4. Add `data/organic_history.modpack` and `data/organic_history.serv`.
5. Verify the copied ruleset loads unchanged.
6. Add metrics parser.
7. Add a multi-seed campaign runner.
8. Add logging-only stability diagnostics.
9. Add disabled-by-default civil-war mechanics.
10. Compare baseline and mechanics campaigns before tuning.
