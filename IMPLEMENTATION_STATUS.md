# Implementation status (v2.0 integration, 2026-11-28)

Legend: ✅ implemented + automated tests · 🟢 implemented, verified by headless/Xvfb screenshots or UI tests only · 🟡 implemented but simplified/partial · ❓ cannot be verified here (needs a real device) · ⛔ not done

| Area | Status | Notes |
|---|---|---|
| Map: classic 410 provinces (fallback) and **extended 1062 provinces (default)** with parents mapping, rivers (337), passes (74), straits, lakes | ✅ | `t_map600` 3,565 checks; Americas, sub-Saharan Africa, Oceania, Siberia are *not* refined on the extended set; river/pass/strait data is partly hand-entered and approximate |
| Map rendering: relief shading, coasts, water shimmer, rivers/passes, markers, zoom tiers, 15 map modes with legends | ✅🟢 | `t_maprender` 2,529 checks; visually reviewed on both sets (EN, 1280×720); only some modes were opened by eye |
| Scenarios: 7 rebuilt (generic native filler replaced by named polities/cultural groups), + 3 new (Third Crusade 1187, Westphalia 1648, Austerlitz 1805) | ✅ | `t_scenarios_v2` 7,357, `t_scenarios_new` 3,746. **History is from general knowledge, flagged approximate; not line-by-line verified (no web access)** |
| Scenario-specific historical province names, per-country approximate flag, geo notes | ✅ | names layer in state; short names on map labels |
| Economy/trade/credit/crises/employment/specialisation; trade conserves money | ✅ | `t_economy2`, invariant enforced in `TradeSystem.compute` |
| Technology 138 (era-gated), buildings 31 (all effects wired except 6 unused military keys) | ✅ | `t_tech2`, `t_buildings2` |
| Espionage, dynasties/marriage/regency/succession disputes, factions/coups/civil wars/independence, 9 distinct government mechanics | ✅ | `t_espionage`, `t_dynasty`, `t_factions`, `sim_ext` |
| Military: factor-based battles with numeric report, commanders (traits/death/capture), 14 doctrines, 61 units | ✅ | `t_battle2`, `t_doctrine`, `t_military` |
| Naval: fleets/squadrons, supply, blockades, commerce raiding/convoys, sea control, naval battles, single-hop amphibious landings | ✅🟡 | `t_naval` 1,262; sea zones derived from nearest sea (some coastal assignments approximate); no multi-hop amphibious transport |
| AI: 9 personalities, no economic cheating, naval/espionage/marriage logic, food-import guard | ✅ | `t_ai`, `t_ai_personalities`; balance by simulation only |
| UI: responsive layout, new HUD/menu/theme, gestures (pan/pinch/tap/long-press), animations, back button, tutorial (12 steps) | ✅🟢 | `ui_layout_check` (0 failures at 800×360, 854×393, 1280×720, 1920×1080; EN and TR subsets), `ui_interaction` 59 assertions, `ui_regress` 15 refs; **no real touch device** |
| Art: new menu art, flags (20 charges, 6 patterns), +13 icons | 🟡 | unit illustrations, historical portraits, loading screens, store-graphics refresh **not done** |
| Events: 237 (136 historical with sources), 17 new effect types, 10 conditions, consequence preview | ✅ | `t_events`, `t_events2` (references from author knowledge, not verified) |
| Save: atomic writes, verified .bak healing, `.corrupt` retention, v1→v4 migration, lifecycle autosave, hotseat seat persisted | ✅ | `t_save`, `t_save2` |
| Scenario editor model API (+ names, objectives, events, map_set) | ✅🟢 | `t_editor2`; custom map geometry import = documented stub interface only |
| Hotseat | ✅ | `t_hotseat` |
| Advertising: banner only (developer app id + production banner unit in release builds; test unit in debug) | 🟡❓ | `t_ads`; plugin v5.1.0; never run on a device |
| Android: debug APK (119.6 MB) + release AAB (64.1 MB, **throw-away key**) built with the real toolchain | 🟡❓ | statically inspected; never installed or run |
| Online multiplayer | ⛔ | future work; not claimed |
| Performance on a phone | ❓ | desktop only; see PERFORMANCE_REPORT.md |
