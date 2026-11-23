# Development plan

| Phase | Scope | Status |
|---|---|---|
| A. Design | Architecture, data schemas, art direction, scenario/event schemas | done (docs/*SCHEMA.md, ART_DIRECTION.md) |
| B. Foundation | Godot project, map pipeline (Natural Earth → 410 provinces + 34 sea zones, geometry.bin), map renderer (single ArrayMesh, data-texture colouring), input (pan/pinch/tap) | done |
| C. Simulation | Economy, trade graph, population/classes, construction, technology (92), politics (9 governments, 17 reforms), military/combat/sieges/supply, diplomacy, events, victory, AI, save system | done, unit-tested |
| D. Content | 7 scenarios, 129 events (historical + random), 43 units, 23 buildings, localisation EN/TR (≈950 keys) | done (approximate history — see scenario `note` fields) |
| E. UI | HUD, sheets (country, economy, military, diplomacy, tech, politics, objectives, events), province panel, battle reports, menus, settings/accessibility, scenario editor, hotseat | done, screenshot-reviewed on desktop |
| F. Assets | 163 icons, 27 audio files, illustrations, fonts — all original or OFL, documented | done |
| G. Release engineering | AdMob banner, export presets, CI, docs, privacy template | written; **Android build and on-device test not executed here** |
| H. Future | naval combat depth, custom-map import, online multiplayer, more scenarios, balance with real players | not started |
