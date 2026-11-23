# Test report

Environment: Linux container, Godot 4.7.2-stable (official build), headless. Date of runs: 2026-11-23. Everything below was **actually executed**; numbers are copied from the run output.

## 1. Automated suites (`res://tests/test_runner.tscn`, all suites)
`---- 20654 checks, 0 failures, 408126 ms ----`

| Suite | Checks | Result | What it covers |
|---|---:|---|---|
| smoke | 7 | PASS | project/autoloads/main scenes load, all 7 scenarios build |
| core | 13,010 | PASS | state helpers, RNG determinism, map geometry/adjacency, content tables, modifiers |
| economy | 249 | PASS | budgets, trade routing, inflation, debt/bankruptcy, food, sinks |
| population | 567 | PASS | growth, classes, unrest, rebellion |
| construction | 19 | PASS | build queue, costs, slots, shortages |
| tech | 18 | PASS | research, allocation, level effects |
| military | 38 | PASS | recruitment, movement, combat, sieges, supply, retreat |
| diplomacy | 38 | PASS | treaties, war/peace, acceptance scoring, coalitions |
| ai | 569 | PASS | multi-turn AI behaviour, no-cheat checks, state validity |
| events | 1,686 | PASS | every event: trigger/option/effect validity, labelling, sources |
| victory | 19 | PASS | territorial victory (hold period), objectives, no early win |
| save | 54 | PASS | round-trip, versioning/migration, backup, corruption, **continuation identical to uninterrupted run** |
| scripts | 164 | PASS | every script parses/instantiates |
| loc | 4,216 | PASS | EN/TR key completeness, placeholders, Turkish characters, language switch |

A first full run found one real failure (victory suite, stale expectations after the victory-pacing change); the test and the missing `victory_type` default were fixed and the suite re-run green. After later edits (back-button handling, editor handler) `smoke`, `scripts`, `loc`, `save` were re-run: 4,441 checks, 0 failures.

## 2. AI-vs-AI soak simulations (`tests/sim.tscn`, seed 7, difficulty normal, all countries AI-driven)
| Scenario | Turns | ms/turn (desktop) | NaN/inf | Ending |
|---|---:|---:|---:|---|
| medieval_europe | 80 | 429 | 0 | running |
| hundred_years_war | 80 | 469 | 0 | running |
| fall_of_constantinople | 80 | 452 | 0 | running |
| early_modern | 200 | 492 | 0 | running |
| age_of_revolutions | 200 | 136 | 0 | AI economic victory at turn 76 |
| industrial_era | 200 | 546 | 0 | score at campaign end (turn 192) |
| world_conquest | 200 | 525 | 0 | running |
State validation every 10 turns found no problems. Some countries end a run in debt (>2000 gold) — AI financial management is imperfect and not tuned further.

Defects found and fixed through these runs (kept for honesty): late scenarios started with every technology line at maximum (tech tree useless) → start levels capped at 3; AI "technological" and "economic" victories fired within ~25 turns → minimum victory turn (60 / ¼ of campaign), hold counter starts only after it, tech victory needs a 0.5-level lead; economy blow-ups (gold in the hundreds of thousands) → rescaled constants, sinks; aliasing bug making saves diverge from live play → deep copies.

## 3. UI verification
Xvfb screenshots (`tests/ui_shots.tscn`) in EN and TR of menu, scenario/country select, campaign HUD, province panel (info/build/army), all sheets, map modes, editor, credits were reviewed by eye. Bugs found and fixed: raw modifier keys shown instead of labels, province panel overflowing the right edge in Turkish, wrong flag bands, label overlap, research points showing 0. **Not covered:** automated UI interaction tests; phone aspect ratios (only 16:9 reviewed); touch input on a real device.

## 4. Content & packaging checks
* `tools/validate_content.py`: all scenarios + events validate (`OK`).
* Godot `--export-pack` for the Android preset succeeded (25.9 MB) and the packed project boots headless for 200 frames without script errors; a negative control with the non-resource include filter removed produced a broken boot — the filter matters and is configured.
* AdMob binding exercised on desktop with the plugin's GDScript installed (consent → init → AdView creation → listener callbacks → hide); no errors from our code. Native calls are no-ops on desktop.

## 5. NOT tested / not possible here
* **APK/AAB were not built** (no Android SDK, JDK-gradle toolchain or export templates in the container). `.github/workflows/build.yml` is untested until it runs.
* **No test on a real Android device or emulator**: banner display, adaptive size, UMP form, safe areas, touch gestures, performance, battery.
* No human play-testing: balance, difficulty curves and fun factor are unvalidated beyond simulations.
* Godot reports "ObjectDB instances leaked at exit / resources still in use" at shutdown of headless runs (also in the packed boot); gameplay is unaffected, cause not investigated.
