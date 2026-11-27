# Military and naval overhaul (workstream E)

Data formats other workstreams may supply:
* `<map dir>/features.json` (read by `GeoFeatures`; `features.sample.json` is used when absent): `{"rivers": [[pidA, pidB, {"name", "width": 1-3}]], "passes": [[pidA, pidB, {"name"}]]}`. Rivers: attacker penalty in battle, extra movement, thinner supply line, retreat stragglers. Passes: defender protection, narrower front, slower and costlier for armies over 8 regiments, thinner supply line. The sample file is test data on 20 rivers / 11 passes of the 410-province map, widths approximate.
* `<map dir>/sea_zones.json` (optional, read by `SeaZones`): `{"zones": {"<id>": {"name": {"en","tr"}, "provinces": [pid, ...]}}}`. Without it every coastal province joins the nearest sea of `seas.json` (zone id `sea_<index>`); this is an approximation (e.g. the western Mediterranean has no sea of its own in the 410-province data).
* `NavalSystem.sea_control(state, sea_id) -> {country: score}` (ships present / 10 plus 1.5 per port level and 0.4 per fort level in the zone); `SeaZones.zone_ids()`, `zone_name()`, `members()`, `neighbors()` for map modes.

Battle model: `BattleFactors` (rivers, passes, weather/mud, terrain, fort, commanders, discipline, experience, supply, composition counters, amphibious, seeded luck; technology and doctrine are shown as "included" factors) and `NavalCombat` (wind and sea state, weather gauge, ship-role matchups, crews, admiral, shore batteries). Every report has `modifiers` (kind power / protect / inc / info; contribution = multiplier - 1) plus the old `factors` table. All balance figures are game abstractions; unit and doctrine stats are approximate.

State added (guarded by `NavalSystem.ensure_fields`, called on load and in `ScenarioLoader.build`; no save-version bump): `state["naval"]` (control, blockades, raids, convoys, stats), army fields `discipline`, `mission`, `at_sea`, `flagship`, commanders with `traits`/`level`, country field `doctrine`.
