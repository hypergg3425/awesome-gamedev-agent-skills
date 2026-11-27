# CLAUDE.md — working notes for AI/human contributors

IMPERIUM: Age of Crowns — original turn-based grand strategy game, Godot **4.7.2** (GDScript), GL Compatibility, Android-first (landscape), EN + TR.

## Commands
```bash
godot --headless --path . --import                                  # required after adding a class_name script
godot --headless --path . res://tests/test_runner.tscn              # all suites (~7 min); append `-- save loc` to filter
godot --headless --path . res://tests/sim.tscn -- <scenario> <turns> <seed> [difficulty]   # AI-vs-AI soak run
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 res://tests/ui_shots.tscn -- /tmp/ui <en|tr>
# UI tests (need a display): layout assertions, real-input interaction tests, screenshot regression
xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 res://tests/ui_layout_check.tscn -- sizes=800x360,1280x720 [touch=1 notch=1 lang=tr scale=1.3]
xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 --resolution 854x393 res://tests/ui_interaction.tscn
xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 res://tests/ui_regress.tscn [-- update=1]   # refs: tests/ui_refs/
python3 tools/validate_content.py                                   # scenario/event schema validation
python3 tools/scan_keys.py && python3 tools/strings/build_strings.py # localisation key scan / regenerate strings.json
```
Autoloads do not resolve inside `-s` scripts: tests run from a *scene* (`tests/test_runner.tscn`).

## Architecture rules (see docs/TECHNICAL_ARCHITECTURE.md)
1. **Game state is one JSON-serialisable Dictionary** (`GS` helpers). No Node/Object/Callable inside it. Derived caches live in `state["_c"]` and are rebuilt by `GS.rebuild_caches`.
2. Simulation systems (`scripts/systems/*`, `scripts/ai/*`) are **static classes with no node dependencies**; they take the state and mutate it. UI never mutates state directly — it calls `Game.cmd_*`.
3. Determinism: all randomness through the seeded `GameRng` stored in the state; floats are `GS.quantize()`d after every turn and after load so save→load→continue is bit-identical (tested).
4. AI never cheats economically. Difficulty only changes decision quality (see `AI DIFF` table). `expert` additionally reads enemy army sizes (documented).
5. Every user-visible string goes through `Loc` (`data/localization/strings.json`, EN+TR); `t_loc` fails on a missing key or a placeholder mismatch.
6. Ads: **banner only** (owner decision for v2.0), only through `scripts/ads/ad_manager.gd`; unit ids only in `scripts/ads/ad_config.gd`. Debug/editor builds always use Google's test unit; only release exports use the production unit. Never add interstitial/rewarded/app-open code (`t_ads` fails if it appears). Never commit keystores or passwords.
7. Content is data: `data/*.json`, `data/scenarios`, `data/events`. Historical events must carry `kind: historical` + `source`; random ones `kind: random`.

## Style
Typed GDScript, tabs, `:=` only when the type is certain (not for `Dictionary.get()`/Variant). New `class_name` ⇒ re-import. Keep turn time < ~0.6 s on desktop for the largest scenario.
