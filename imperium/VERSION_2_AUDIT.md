# Version 2.0 audit

> **Status update (2026-11-28):** the initial audit below describes the starting point. Sections 4 ("Missing / incomplete") and the scenario-coverage table are largely resolved by the v2 workstreams — see IMPLEMENTATION_STATUS.md and VERSION_2_CHANGELOG.md for the current state, and the 'Still not done' list at the end of this file.

Method: every claim in the older documents was compared with the source, data and a real build. Findings are tagged **CONFIRMED**, **WRONG** (documentation said otherwise) or **FIXED** with evidence. Backup: git tag `v1.0-backup`; v2 work is on branch `v2-dev`. Date: 2026-11-23.

## 1. The 17 findings from the brief
| # | Finding | Result |
|---|---|---|
| 1 | Docs said 9 AI personalities, code had 7 | **CONFIRMED → FIXED.** `Const.PERSONALITIES` and `PERS_W` now hold 9 (`naval_trade`, `coalition_builder` added) with behaviour hooks (port/trade building weight, fleet appetite, trade-deal and alliance proposal rates, earlier/lower-threshold coalition forming, war-need ratio, acceptance bonus). `t_ai_personalities` runs each personality 24 turns and asserts naval_trade out-builds aggressive in ports/trade centres and coalition_builder forms more alliances than isolationist. |
| 2 | `tutorial_done` setting without a tutorial | **CONFIRMED → FIXED.** `scripts/ui/campaign/tutorial.gd`: 12 steps (EN+TR), highlight ring, auto-advance from real game state, skip, replay (Settings and pause menu). `t_tutorial` (37 checks). Only desktop screenshots were reviewed; touch behaviour is unverified. |
| 3 | All 7 scenarios use approximate map data | **CONFIRMED.** `approximate: true` in all seven (world_conquest is explicitly fictional). Not changed in this iteration. |
| 4 | Map = modern administrative regions | **CONFIRMED.** Natural Earth admin-1/regions grouped into 410 provinces. Not changed. |
| 5 | Very different explicit ownership coverage | **CONFIRMED** (table below). |
| 6 | Loader invents generic native states for unclaimed regions | **CONFIRMED** (table below). `ScenarioLoader` builds `NAT_*` "<Region> Peoples" tribal confederations. |
| 7 | Naval combat simplified | **CONFIRMED.** Not changed. |
| 8 | Editor cannot import map geometry | **CONFIRMED** (`scenario_editor.gd` header says imports are future work). |
| 9 | Hotseat has limited automated coverage | **WRONG — it had none.** No test referenced hotseat. Now `t_hotseat` (19 checks: device-pass order, one turn resolution, per-player commands, save/load of the player list). The old limitation (a load restarted at the first player) is fixed: the seat is saved as `hotseat_index` (`t_save2`). |
| 10 | No online multiplayer | **CONFIRMED.** Future work; not claimed. |
| 11 | Real-device UX unverified | **CONFIRMED, still unverified.** |
| 12 | APK/AAB unverified | **PARTLY FIXED.** Android SDK/NDK/templates installed in the authoring environment; a debug APK (114.8 MB) and a release AAB (59.5 MB, signed with a throw-away key) were really exported and statically inspected (see MOBILE_DEVICE_TEST_REPORT.md). Never installed or run. |
| 13 | AdMob never tested on a device | **CONFIRMED, still untested on a device.** Plugin binding was verified against the pinned plugin source and exercised on desktop. |
| 14 | AI balance never human-tested | **CONFIRMED.** Only simulations (AI_BALANCE_REPORT.md). |
| 15 | ObjectDB / resource leak warnings | **FIXED.** Root cause: `AudioManager` kept playing streams and a stream cache at exit (`AudioStreamPlaybackOggVorbis`, `OggPacketSequence` leaked, 2 resources in use). Players are now stopped, streams released, cache cleared in `_exit_tree`. Verified: boot, test runner and the screenshot tool exit with no leak warning. |
| 16 | Android CI workflow unverified | **PARTLY.** Every command was run by hand here with the same versions; the YAML itself has not run on GitHub Actions. |
| 17 | CI plugin tag vs source-verified version mismatch | **FIXED.** Pinned to **v5.1.0**; its banner/UMP/MobileAds/AdSize/RequestConfiguration scripts are byte-identical (comments stripped) to the nightly source checked earlier; the release asset `android-template-v4.7.2.zip` exists and was used in the real export. |

## 2. Scenario coverage (computed from data, fnmatch of each country's province patterns)
| Scenario | Countries | Explicitly owned | Generic native fill |
|---|---:|---:|---:|
| medieval_europe (1066) | 38 | 150 / 410 | 260 |
| hundred_years_war (1337) | 37 | 145 / 410 | 265 |
| fall_of_constantinople (1453) | 37 | 151 / 410 | 259 |
| early_modern (1519) | 54 | 224 / 410 | 186 |
| age_of_revolutions (1789) | 44 | 302 / 410 | 108 |
| industrial_era (1871) | 60 | 359 / 410 | 51 |
| world_conquest (1900, fictional) | 53 | 410 / 410 | 0 |

In the three medieval scenarios roughly two thirds of the map is generic tribal filler, i.e. **not historically accurate**; it is labelled approximate, not reconstructed.

## 3. Existing functional features (verified by tests/builds)
Economy, trade graph, population/classes, construction, 92 technologies, 43 units, supply/siege/combat, diplomacy with explained acceptance, events (129; 68 flagged historical with a recorded `source`), victory/objectives/score, save/load with deterministic continuation, localisation EN/TR, map rendering of 410 provinces with 8 modes, editor, hotseat, banner integration.

## 4. Missing / incomplete (relative to the v2.0 brief) — NOT done in this iteration
* Historical map: no scenario-specific geometry, names, ownership reconstruction, rivers/passes/straits data, ≥600 provinces, extra map modes (religion/culture/…), new zoom-dependent detail layers.
* Researched bibliography per scenario and ≥3 new scenarios.
* Visual redesign (menu, HUD, panels, original art upgrade), animations.
* Gameplay: espionage, dynasties/marriage/regency, factions/civil wars/coups, extended tech tree (era gating exists only through the start-level cap), building era restrictions, credit/crisis expansion, doctrines, naval overhaul (fleet organisation, convoys, sea control, amphibious ops), richer battle report factors (weather, rivers).
* Long-press context info, UI interaction tests, screenshot regression tests across aspect ratios (only manual screenshot review at 800×360, 1024×768, 1280×720, 2400×1080).
* Real-device profiling, 30–60 FPS verification, memory-growth tests.
* Privacy/Data-Safety documentation is a template, not a final legal text.

## 5. Architecture weaknesses (observed)
* `diplomacy_system.gd` (1,064 lines), `ai_system.gd` (944), `military_system.gd` (853) are large; no splitting done.
* 24 hard-coded `Vector2(≥100, …)` sizes remain in UI scripts. Layout survives all tested aspect ratios because the project uses `canvas_items` stretch with `expand` (virtual 1280×720 scaled uniformly), not because panels are fully fluid; very small physical screens get small text.
* `AudioManager._stream` mutates the `loop` flag on a shared cached resource (name|loop keys share one Resource) — harmless today (music loops, SFX do not) but fragile.
* AI "force" difficulty knob scales how large an army the AI *wants* (still limited by its real manpower/gold); not an economic bonus, but it is a behavioural multiplier worth knowing about.

## 6. Performance risks
Desktop turn times 0.14–0.55 s (headless, shared CPU) on the largest scenarios; mobile unmeasured. Map is one ArrayMesh + data texture (cheap), but label/marker overlay is rebuilt in GDScript. APK 114.8 MB (debug), AAB 59.5 MB: audio, illustrations and the AdMob plugin's own 26 API scripts are included.

## 7. Android release blockers
Package id still the placeholder `com.imperium.agecrowns`; no real upload keystore; Play listing/privacy policy/Data Safety/content rating unfinished; nothing run on a device/emulator; adaptive-banner placement and UMP flow unverified at runtime.

## 8. Advertising risks
Banner-only is enforced by `t_ads` (no forbidden class references in `scripts/ads`). The plugin library itself still ships its other ad-format scripts (unused). Misplaced banner could cause accidental clicks — verify the bottom reserve on real devices. The developer's interstitial unit exists in AdMob but is deliberately unused.

## 9. Test coverage gaps
No UI interaction tests; no automated layout assertions; naval, siege and battle-report content have only light unit tests; scenario editor save/load has no automated test; tutorial UI placement only reviewed visually.

## 10. Still not done after the v2 integration (honest list)
* **Real device/emulator testing** of anything (touch, banner, UMP, performance, battery). No device was available.
* **Google Play readiness:** placeholder package id, no real upload key, no store listing/privacy URL, policies not re-verified online.
* **Historical verification:** web sources were unreachable for the research agents; scenario rulers/borders/events are from general knowledge and flagged approximate. No independent re-verification, no per-line bibliography with URLs.
* **Map:** Americas, sub-Saharan Africa, Oceania, most of Siberia not refined on the 1062-province set; some passes unmatched (15 extended, 35 classic); capitals like Delhi/Beijing sit in approximate regions; scenarios remain authored on 410 regions and are upgraded through parents (children inherit ownership).
* **Performance target:** extended map ~0.5–0.8 s/turn on a shared desktop (goal <0.6 s); mobile unmeasured.
* **Art:** unit illustrations, historical portraits, loading screens, new store graphics, terrain/building/resource icon redesign.
* **UI:** editor still uses MapView's own input (not the gesture layer); `ui_layout_check touch=1` fails mode-strip checks at small sizes (122 failures on the base commit, not fixed); Turkish layout checked only for a subset of sizes.
* **Gameplay depth gaps:** multi-hop amphibious transport, 4th new scenario (1914), unused military modifier keys (xp_gain, naval_slots, siege_def, mercenary_cost, prod_military, legit_conquest).
* **Fourth-order checks not run:** CI YAML never executed on GitHub Actions; ads/UMP flows.
