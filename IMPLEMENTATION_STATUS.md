# Implementation status

Legend: ✅ implemented and covered by automated tests · 🟢 implemented, verified by screenshots/manual desktop run only · 🟡 implemented but simplified · ⛔ not done · ❓ cannot be verified in the authoring environment

| Area | Status | Notes |
|---|---|---|
| Interactive world map, 410 provinces + 34 sea zones, 8 map modes, pan/pinch/tap | 🟢 | Desktop (Xvfb) rendering + headless geometry tests; **touch feel on a real phone ❓** |
| Countries, 9 government types, 17 reforms, transitions, legitimacy/stability | ✅ | `t_core`, `t_population`, `t_diplomacy` |
| Economy (tax/production/commerce/food/manpower, budget, inflation, debt) | ✅ | `t_economy`; calibrated by AI-vs-AI soak runs |
| Trade (graph, hubs, embargo/blockade, tariffs) | ✅ | `t_economy`, `t_core` |
| Population & 6 classes, unrest, rebellion, religion/culture | ✅ | `t_population` |
| Buildings (23), construction queue, development, buy-missing-materials | ✅ | `t_construction` |
| Technology (23 lines × 4 levels = 92) with 4 branches and research allocation | ✅ | `t_tech` |
| Military: 43 units, generals, supply/attrition, sieges, retreat, battle reports | ✅ | `t_military` |
| Naval warfare | 🟡 | Fleets, naval transport, blockade, naval combat exist but are simplified (no tactical manoeuvre) |
| Diplomacy: alliances, guarantees, NAP, vassals, trade deals, embargo, coalitions, war goals, peace terms with explained acceptance | ✅ | `t_diplomacy` |
| AI: 9 personalities (v2.0: previously only 7 were implemented), 4 difficulties, no economic cheating | ✅ | `t_ai`, `t_ai_personalities` + soak sims; **balance tuned by simulation only, never by human play-testing** |
| Events: 129 data-driven (historical labelled with sources, random labelled) | ✅ | `t_events`, `validate_content.py` |
| 7 scenarios (1066, 1337, 1453, 1519, 1789, 1871, 1900) | ✅ | load/validate/step tests; historical data approximate (labelled) |
| Victory conditions (territory, economic, diplomatic, technological), objectives, score, statistics, timeline | ✅ | `t_victory` |
| Save/load, versioning, migration, backup, corruption handling, deterministic continuation | ✅ | `t_save` |
| Scenario editor (countries, provinces, relations, validate, save, test play) | 🟢 | Screenshot-reviewed; limited automated coverage. **Custom map import ⛔** |
| Hotseat | ✅ | `t_hotseat` (v2.0). Loading a save restarts with player 1 |
| Settings / accessibility (text scale, colour-blind palette, animations toggle, volumes/mute, language, confirm-actions, graphics quality, FPS cap) | 🟢 | |
| Localisation EN/TR (971 keys, Turkish glyphs verified) | ✅ | `t_loc` (4,216 checks) |
| Achievements (8) + lifetime stats | ✅ | toast wired to `Game.achievement_unlocked` |
| Audio (27 original files) | 🟢 | Plays in desktop runs; mix not reviewed on phone speakers |
| AdMob banner + UMP consent | 🟡❓ | Banner-only; real app id + production banner unit configured (release only; debug uses Google test unit); plugin pinned v5.1.0; exercised on desktop; APK manifest verified; **never run on Android** |
| Android export presets, CI workflow | 🟡 | Debug APK and release AAB really built here (v2.0) and statically inspected; never installed/run; workflow YAML never run on Actions |
| Online multiplayer | ⛔ | Future work |
| Interactive tutorial (12 steps) | 🟢✅ | v2.0, `t_tutorial` + screenshot; touch behaviour unverified |
| Real-device performance | ❓ | Desktop: 0.14–0.55 s/turn on the largest scenarios; mid-range phone not measured |
| v2.0 brief items not yet implemented | ⛔ | Historical map rebuild, scenario-specific names/geometry, new scenarios, visual redesign, espionage, dynasties, factions, naval overhaul, extra map modes — see VERSION_2_AUDIT.md §4 |
