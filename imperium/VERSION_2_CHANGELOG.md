# Version 2.0 changelog (work completed so far — see VERSION_2_AUDIT.md §4 for what is NOT done)

## Added
* Interactive 12-step tutorial (EN/TR), skippable, replayable from Settings and the pause menu; `tutorial_done` is now a real setting.
* AI personalities `naval_trade` and `coalition_builder` (now 9 total, as documented) with distinct behaviour.
* Hotseat test suite; tutorial, AI-personality and ads-policy test suites.
* Real Android export pipeline run end to end: debug APK and release AAB (throw-away key) produced and statically inspected.
* AdMob: developer's app id in `project.godot`; production banner unit `ca-app-pub-1178249482215901/8669329404` used by release exports only; debug/editor builds always use Google's test unit; plugin pinned to v5.1.0.
* New documents: VERSION_2_AUDIT, HISTORICAL_SOURCES, MOBILE_DEVICE_TEST_REPORT, AI_BALANCE_REPORT, PERFORMANCE_REPORT.

## Changed
* Technology start levels capped at 3 (late scenarios started with every line maxed).
* Victory pacing: minimum turn 60 / ¼ of the campaign, hold counter starts after it, technological victory needs a 0.5-level lead, economic share 40 %.
* Android back button: closes panels / opens pause menu in a campaign, returns to the menu elsewhere, never quits mid-campaign.
* Province panel and sheets shrink instead of overflowing in Turkish; raw modifier keys replaced by labels; achievement toast wired; `crown` icon added.
* Export presets exclude plugin samples/docs.

## Fixed
* Audio shutdown leak (see audit #15). Stale victory test. Missing `victory_type` default. Missing `crown` icon.

## Reverted / not done
* An interstitial-ad implementation was started and **reverted** because the v2.0 brief requires banner-only advertising; the interstitial unit id is intentionally not used.


## v2 integration (2026-11-28) — merged workstreams
* **Map:** extended 1062-province dataset (default), parents mapping, 337 rivers / 74 passes / 22 straits, 926 sea links; 15 map modes with legends; relief/coast/water shaders; markers; zoom tiers.
* **Scenarios:** 7 rebuilt with named polities (136 countries in the medieval ones), historical names layer, 3 new scenarios (1187, 1648, 1805), per-scenario source docs (docs/scenarios/*.md).
* **Simulation:** espionage, dynasties, factions/coups/civil wars, government mechanics, economy depth, 138 techs with era gating, 31 buildings.
* **Military/naval:** factor-based battle reports, commanders, 14 doctrines, 61 units, rivers/passes/weather, full naval layer.
* **UI:** responsive layout engine, HUD, menu, theme, gestures + long-press, animations, back-button chain, tutorial improvements, layout/interaction/regression tests.
* **Systems:** event effects/conditions extension, editor model API, atomic saves with healing, lifecycle autosave, hotseat seat persistence.
* **Integration fixes found by the merged test run:** trade payouts exceeded commerce (merchant-fleet bonus) → capped; AI bankrupted by food imports → guard; runtime-created countries lacked naval/doctrine fields → save/load divergence; corruption formula ignored province scale; override exclusions ("-id") now supported; GeoFeatures read the classic dir on the extended set; several test fixtures that depended on the old scenario layout were made robust.
