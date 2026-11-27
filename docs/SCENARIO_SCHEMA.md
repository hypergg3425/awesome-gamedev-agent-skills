# Scenario schema (data/scenarios/<id>.json)

One JSON file per scenario. Loaded by `ScenarioLoader.build()`. Province ids are the stable ids in
`data/map/provinces.json` (e.g. `fra_normandy`). Everything in a scenario that is not a documented
fact must be marked approximate (`"approximate": true`, which is the default) — the UI shows a notice.

```jsonc
{
  "id": "hundred_years_war",
  "name": {"en": "...", "tr": "..."},
  "desc": {"en": "...", "tr": "..."},            // 2-4 sentences, shown on the scenario card
  "note": {"en": "...", "tr": "..."},            // honesty note: which parts are approximated
  "start": {"year": 1337, "month": 5},           // turns are 3 months long
  "turn_limit": 240,
  "era": 1,                                       // 0..4 baseline technology level for the era
  "approximate": true,
  "default_player": "ENG",
  "countries": {
    "ENG": {
      "name": {"en": "Kingdom of England", "tr": "İngiltere Krallığı"},
      "short": {"en": "England", "tr": "İngiltere"},
      "color": "#b8242b",                         // political-map colour; keep neighbours distinguishable
      "flag": {"p": "cross", "c": ["#ffffff", "#cc1f2e", "#ffffff"], "charge": "none"},   // see FLAGS below
      "culture": "germanic",                      // culture group (see list), default = capital culture
      "religion": "catholic",                     // see list
      "gov": "feudal_kingdom",                    // governments.json id
      "ruler": {"name": "Edward III", "adm": 6, "dip": 6, "mil": 8, "age": 24, "dynasty": "Plantagenet"},
      "heir": {"name": "Edward of Woodstock", "age": 6, "adm": 6, "dip": 5, "mil": 8},   // optional
      "capital": "gbr_home_counties",
      "provinces": ["gbr_*", "-gbr_ulster", "fra_aquitaine"],   // glob patterns, "-" removes; later entries override earlier countries
      "civ": "average",                           // advanced | average | backward  (tech/dev modifier)
      "tech_mod": 0,                              // extra tech levels (-1..1)
      "treasury": 120,                            // optional, otherwise computed from income
      "military": "medium",                       // low | medium | high   (auto-composed armies) — or give explicit "armies"
      "armies": [{"loc": "gbr_wessex", "units": {"longbowmen": 3, "men_at_arms": 2}, "general": {"name": "Henry of Grosmont", "tac": 6, "log": 5, "siege": 5}}],
      "special_units": ["longbowmen"],            // regional units unlocked for this country (see units.json "countries")
      "ai": "aggressive",                         // aggressive | defensive | expansionist | diplomatic | economic | opportunistic | isolationist
      "playable": true,
      "traditions": [{"en": "Yeoman archers", "tr": "Yeoman okçuları"}],   // flavour only
      "mods": {"morale": 0.05},                   // optional permanent modifiers (keys: see MODS below)
      "stability": 55
    }
  },
  "religion_overrides": {"sunni": ["esp_andalusia"]},     // province patterns -> religion
  "culture_overrides": {"latin": ["gbr_wessex"]},
  "province_dev": {"fra_ile_de_france": 1.0},             // optional +dev tweaks
  "claims": {"ENG": ["fra_normandy", "fra_aquitaine"]},   // claims (war goals / casus belli)
  "relations": {
    "alliances": [["ENG", "POR"]], "defensive": [], "nap": [], "access": [], "trade": [],
    "guarantees": [["A", "B"]],                           // A guarantees B
    "vassals": [["OTT", "WAL"]],                          // [overlord, vassal]
    "opinions": [["ENG", "FRA", -100]],                   // directional, -200..200
    "wars": [{"attackers": ["ENG"], "defenders": ["SCO"], "cb": "conquest", "goals": []}],
    "truces": [["ENG", "FRA", 4]]                         // [a,b,until_turn]
  },
  "objectives": [ { "id": "win_france", "type": "own_provinces", "provinces": ["fra_*"], "count": 8,
                    "by_turn": 120, "score": 300, "name": {"en": "...", "tr": "..."}, "desc": {"en": "...", "tr": "..."} } ],
  "victory": {"territory_pct": 0.25},                     // optional overrides
  "events": ["hyw_crecy"],                                // ids of historical events active in this scenario (events live in data/events)
  "native_fallback": true,                                // unclaimed provinces become generic native/tribal countries (v2.0 scenarios leave none)
  "province_names": {"tur_constantinople": {"en": "Constantinople (besieged)", "tr": "Konstantiniyye (kuşatma altında)"}},   // v2.0: names for the scenario date
  "geo_layer": [{"id": "bosporus", "kind": "strait", "name": {"en": "...", "tr": "..."}, "provinces": ["tur_constantinople"], "note": {"en": "...", "tr": "..."}}]
}
```

### v2.0 additions
* **`province_names`** (optional): `{"<province_id>": {"en": "...", "tr": "..."}}`. Historical or regional names valid at the scenario date. `ScenarioLoader.build` stores the known ids in `state["names"]` (saved with the game; old saves without it simply fall back). All UI goes through `Defs.province_name(pid)`, which consults the active `Game.state`; simulation code and tests use `Defs.province_name_in(state, pid)`. Both fall back to the modern name from `provinces.json`.
* **`geo_layer`** (optional): notes about straits, rivers, passes, fortifications, regions or routes for the date (`kind`: strait | river | pass | fortification | region | route). Stored in `state["geo_layer"]`; documentation-grade data for map layers, no gameplay effect yet.
* **Per-country `approximate`** (bool, default = the scenario flag) and **`note`** (`{en, tr}`): `true` marks a reconstruction whose ruler, borders or polity form is uncertain; the country panel shows "Approximate reconstruction" plus the note. Stored as `country["approximate"]` / `country["note"]`.
* **`native: true` named groups**: a country with `native: true` is a cultural group or tribal polity (not playable, one tech level lower, low military). Use it, with `approximate: true`, for regions where no state can be drawn instead of relying on the generic filler.
* **`claims`** patterns may start with `-` to remove earlier matches; a country never claims a province it already owns.
* **`religion_overrides` / `culture_overrides`**: an exact province id now beats a glob such as `tur_*`, regardless of key order.
* Authored armies: a `general` needs only `name`, `tac`, `log`, `siege`; `xp` and missing skills are filled in by the loader.
* `tools/validate_content.py` checks ruler fields, heirs, `approximate`, `province_names`, `claims` (country and patterns), `geo_layer` and override patterns.

Provinces not listed for any country become small native/tribal states automatically, so a scenario only
needs to describe the powers that matter. Late entries in the `countries` object override earlier ones
for the same province, so list big countries first and breakaway/vassal states after.

**Objective types** (`type`): `own_provinces` {provinces, count}, `own_all` {provinces},
`provinces_count` {count}, `tech_avg` {level}, `treasury` {amount}, `survive_until` {turn},
`alliance_with` {target}, `vassalize` {target}, `destroy` {target}, `capital_of` {target, province},
`wars_won` {count}, `income` {amount}.

**Cultures**: latin, germanic, slavic, hellenic, magyar_finnic, turkic, arabic, iranian, caucasian, indic,
sinic, japonic, southeast_asian, african, native_american, latin_american, oceanian.
**Religions**: catholic, orthodox, protestant, sunni, shia, jewish, buddhist, hindu, eastern_faiths, pagan, animist, tengri, shinto, secular.
**Governments**: absolute_monarchy, constitutional_monarchy, republic, merchant_republic, empire,
tribal_confederation, theocracy, feudal_kingdom, military_government.

## FLAGS
Flags are drawn procedurally (original stylised banners, not copies). `{"p": pattern, "c": [colors...], "charge": symbol}`
patterns: `plain` (1 colour), `hstripes` (2-3), `vstripes` (2-3), `cross` (field, cross, [outline]), `nordic` (field, cross, [outline]),
`saltire` (field, cross), `canton` (field, canton colour), `bend` (field, band), `chevron` (field, chevron), `quartered` (c1,c2),
`disc` (field, disc), `border` (field, border), `pale` (3 vertical, centre wide). charges: `none`, `star`, `crescent`, `sun`,
`fleur`, `cross`, `crown`, `tower`, `eagle`, `lion`, `dragon`, `anchor`.

## MODS — modifier keys
Modifier dictionaries (government `mods`, tech `effects`, reform advantages, building `effects`, scenario/country `mods`, event `temp_mod`) use these keys; each has a localised label `MOD_<KEY>` in `strings.json`. Values are fractions (0.10 = +10 %) except flat keys (`trade_power`, `fort_level`, `*_slots`, …) which are shown unscaled.

admin_cap, army_upkeep, artisans_sat, artisan_share, art_atk, attrition, build_cost, build_speed, cav_atk, clergy_sat, clergy_share, corruption, cost_inflation, credit, diplo, disease, disease_resist, food, food_mult, fort_def, fort_level, general_skill, happiness, happiness_local, infra, inf_atk, inf_def, interest, legit, legit_conquest, literacy, manpower, manpower_mult, manpower_recovery, mercenary_cost, merchants_sat, merchant_share, mine, mine_mult, morale, move, move_bonus, naval_atk, naval_slots, naval_transport, nobility_sat, overextension, peasants_sat, pop_cap, pop_growth, prestige, prod, prod_military, prod_mult, recruit_cost, recruit_speed, reform_cost, religion_unity, research, research_pts, siege, siege_def, stability, stability_local, supply, tariff, tax, tax_mult, trade, trade_power, unrest, unrest_minority, war_exhaustion, wood_mult, xp_gain
