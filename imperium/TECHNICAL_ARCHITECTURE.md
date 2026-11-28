# Technical architecture

## Layers
```
UI (scripts/ui/*, scenes/*)  ──cmd_*──▶  Game (autoload GameManager)  ──▶  Systems (static, node-free)  ──▶  State (Dictionary)
        ▲                                   │ signals (state_changed, notes…)         ▲
        └───────────────────────────────────┘                                         └─ Saves (JSON, versioned)
Defs (autoload): immutable content tables from data/*.json      Loc: EN/TR      Settings: user://settings.json
Ads (autoload): banner only      Audio (autoload): buses, music/SFX
```
* **State** (`scripts/core/gs.gd`): `{meta, turn, date, countries, provinces, armies, wars, diplomacy, events, objectives, rng, _c(cache, never saved)}`. Pure JSON types. Armies/countries/provinces keyed by string ids.
* **Turn** (`turn_manager.gd`): 3 months per turn. Order (see `TurnManager.end_turn`): AI decisions and recruit queues → army movement → battles → sieges → supply → rebels → trade routing → per-country economy, construction, research → population → politics → market update → diplomacy upkeep → events/victory/statistics → quantize. Alternating-half updates (opinions, unrest) and caches keep a 410-province turn at ≈0.15–0.55 s on desktop.
* **Determinism**: single `GameRng` (wraps Godot's PCG32 `RandomNumberGenerator`; seed + state serialised as strings); `GS.quantize` rounds floats to 1e-6; save uses `JSON.stringify(state,"",false,true)`. Test `t_save` proves save→load→continue equals the uninterrupted run.
* **Economy** (`economy_system.gd`): per-province tax/production/commerce/food/manpower from pop, development, terrain, buildings, classes; national budget (income, upkeep, interest); stockpiles; inflation; debt/bankruptcy; admin capacity & corruption.
* **Trade** (`trade_system.gd`): multi-source Dijkstra (binary heap) from producers to trade hubs over a graph whose edges are cut by war/embargo/blockade; tariffs and hub fees.
* **Population** (`population_system.gd`): growth, migration, 6 classes with satisfaction/power, unrest, rebellion (pseudo-country `REB`), religion/culture minorities.
* **Military** (`military_system.gd`, `combat.gd`): regiments of 1000 men, 43 unit types, generals (skill/traits), morale, supply & attrition, sieges, retreat, naval transport via escorted fleets. Combat: fire → shock → shock phases, terrain/river/fort/general modifiers; reports list every factor.
* **Diplomacy** (`diplomacy_system.gd`): opinion, trust, alliances, guarantees, NAPs, vassals, trade agreements, embargo, coalitions, war goals/casus belli, peace terms with an acceptance score that exposes its reasons (`AI explanation` in the UI).
* **AI** (`ai_system.gd`): layers assessment → economy → research → military → diplomacy; 9 personalities; difficulty changes decision parameters only (`DIFF` table: skipped decisions, force-size appetite, planning, war prudence, construction appetite; `expert` also reads enemy army sizes). **No income, manpower or combat bonuses are ever applied to AI countries.** Natives (`native:true`) follow a passive isolationist routine.
* **Events** (`event_system.gd`): data-driven (`data/events/*.json`): triggers, weights, options with effects; `kind: historical` events carry a `source` string and are labelled in the UI; random events are labelled "random".
* **Map** (`scripts/map/*`): one `ArrayMesh` for all provinces (geometry.bin), colours from an N×2 RGBA8 data texture updated per map mode; borders as quantised-width strips; labels/markers in a screen-space overlay with zoom thresholds; grid hit-test for taps; pan/pinch/inertia.
* **Saves** (`save_manager.gd`): slots in `user://saves`, header (version, scenario, date, crc, length), `.bak` rotation, corrupt files renamed `.corrupt`, migrations v1→3, `validate_state`, autosave.
* **Localisation**: `Loc.t/tf/tx`; `strings.json {KEY:{en,tr}}` (971 keys), content uses inline `{en,tr}`.
* **Ads**: see docs/ADMOB_SETUP.md. Plugin bound dynamically through `ProjectSettings.get_global_class_list()`; project runs with or without it.

* **v2.1 systems (save v4)**: `sim_ext.gd` (init, migration, phases), `espionage_system.gd` (`country.esp`), `dynasty_system.gd` (`country.dyn`, ruler/heir stay in `ruler`/`heir`), `factions_system.gd` + `gov_mechanics.gd` + `civil_war.gd` (`country.fac`, rules in `governments.json -> politics`), `economy_depth.gd` (`country.eco`, `state.econ`). Building effects listed in `Mods.NATIONAL` also act nationally with a soft cap. Techs carry `era_year`; `TechSystem.era_check` allows a 50-year lead (up to 150 for countries far ahead of the world). Approximate era years: HISTORICAL_SOURCES.md.

## Directory map
`data/` content · `scripts/{core,data,systems,ai,map,ui,save,managers,ads,localization}` · `scenes/` thin wrappers · `tests/` · `tools/` generators/validators/CI helpers · `docs/` · `assets/`.

## Extension points
New scenario → JSON in `data/scenarios` (docs/SCENARIO_SCHEMA.md) + `python3 tools/validate_content.py`. New event → `data/events/*.json` (docs/EVENT_SCHEMA.md). New modifier key → add the effect in the relevant system and a `MOD_<KEY>` string. New map mode → `Const.MAP_MODES` + `map_overlay`/`campaign_map` colour function.
