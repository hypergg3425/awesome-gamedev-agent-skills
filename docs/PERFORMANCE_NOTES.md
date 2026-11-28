# Performance notes (workstream G)

Measured headless on a shared 4-core Linux VM (other agents running), desktop CPU, GDScript, `tests/perf.tscn` (mean over 12 AI-vs-AI turns from the
scenario start, no player; `IMPERIUM_MAP_SET=extended` selects the 600-province map). Phase names are those of `TurnManager` (ms per turn).
Numbers are noisy by +-10%. Mobile was not measured.

| scenario / map | countries | before (mean, worst) | after (mean, worst) | after: ai / military / economy / population / end | save / load |
|---|---:|---|---|---|---|
| world_conquest / classic | 53 | 590 / 840 | 491 / 584 | 192 / 36 / 127 / 81 / 32 | 64 / 94 ms |
| medieval_europe / classic | 136 | 543 / 646 | 551 / 709 | 190 / 33 / 150 / 73 / 62 | 138 / 211 ms |
| world_conquest / extended | 53 | 806 / 919 | 771 / 847 | 235 / 51 / 234 / 171 / 47 | 76 / 96 ms |
| medieval_europe / extended | 136 | 932 / 1124 | 780 / 873 | 219 / 46 / 200 / 109 / 138 | 204 / 366 ms |

**Target (<0.6 s) is met on the classic map for world_conquest (0.49 s) and just on medieval_europe (0.55 s, worst turn 0.71 s). It is NOT met on the
600-province extended map (0.77-0.78 s).** The extended map has about 1.5x the provinces, and every per-province phase scales with it.

## Per-subsystem profile (`tests/perf_detail.tscn`, medieval_europe, extended map, ms per turn, before the changes)
ai.run 211 · trade.compute 124 · diplomacy 87 · GS.quantize 77 · population 70 · economy (process_turn) 55 · politics 48 · victory 43 · military 42 ·
SimExt.economy_phase 32 · events 17 · tech 9. The AI (one decision pass per country) is the largest single block; trade routing and diplomacy follow.

## Changes made (results unchanged; `t_save`, `t_save2` (150-turn identical hash), `sim_ext`, `economy`, `economy2`, `events` all pass)
* `GS.quantize`: iterates dictionaries without copying the key list and writes a value back only when snapping changed it (was ~77 -> ~70 ms).
* `TradeSystem`: the static neighbour/sea-link edge lists used by the route search are cached per map set instead of rebuilt for every heap pop, and
  `edge_ok` short-circuits provinces of one country (no war/embargo/blockade can apply inside a country). Gain is within measurement noise on the
  profile above (~5 ms); the real cost of `trade.compute` is the payout loop (province_calc, path walk).

## Remaining hot spots (not done)
* `GS.at_war` scans every war dictionary on each call and is used inside the AI, trade and diplomacy loops; a per-turn cache keyed on the war list
  would help but needs invalidation at every war start/end/join, so it was left alone.
* AI evaluation per country (`AISystem.run`) re-derives neighbour sets and threat estimates; sharing them per turn in `state["_c"]` is the best next step.
* `DiplomacySystem.process_turn` (87 ms) and `VictorySystem.snapshot` (43 ms) could run on alternating halves of the countries; not done because
  that changes behaviour and needs new balance runs.
* Save size: ~1.5 MB JSON for 136 countries on the classic map; load 0.2-0.37 s.
