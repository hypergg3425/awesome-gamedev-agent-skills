# Event schema (data/events/*.json — each file is an array of events)

```jsonc
{
  "id": "famine_harvest_failure",
  "category": "food",          // political | succession | economic | food | diplomatic | religious | military | uprising | disaster | tech | historical
  "historical": false,         // true => tied to a real dated event; false => randomly generated (the UI labels these differently)
  "source": "",                // REQUIRED for historical events: short citation (e.g. "Battle of Hastings, 14 Oct 1066")
  "title": {"en": "...", "tr": "..."},
  "text":  {"en": "...", "tr": "..."},     // placeholders: {country} {ruler} {province} {other}
  "image": "famine",           // illustration key (see list)
  "trigger": {
    "date_from": {"year": 1347, "month": 1}, "date_to": {"year": 1352, "month": 12},   // optional window
    "scenarios": ["hundred_years_war"],      // optional whitelist; omit = any scenario
    "countries": ["ENG"],                    // optional tag whitelist; omit = any country
    "min_turn": 4,
    "conds": [ {"type": "stability_below", "value": 40} ]    // ALL must hold (country scope)
  },
  "mtth": 60,                  // mean turns until it fires while the trigger holds (random events). Use 1 for dated historical events.
  "once": true,                // fire at most once per country (default false)
  "cooldown": 20,              // turns before it may fire again for the same country
  "scope": "country",          // country | province  (province: picks a random owned province matching pconds; {province} available)
  "pconds": [ {"type": "terrain_is", "value": "plains"} ],
  "options": [
    { "id": "import", "name": {"en": "...", "tr": "..."}, "tip": {"en": "...", "tr": "..."},      // tip = one line consequence summary
      "requires": [ {"type": "treasury_above", "value": 60} ],       // option only available when true
      "effects": [ {"type": "gold", "value": -60}, {"type": "stability", "value": 3} ],
      "ai_weight": 2 }
  ]
}
```
Every event needs 2-4 options with *different* consequences (a real trade-off). Historical events must still offer
choices; the date is real, the consequences are game consequences. Never present invented events as historical.

## Country-scope conditions
`stability_below|above` value · `legitimacy_below|above` · `treasury_below|above` · `debt_above` · `income_below|above` ·
`at_war` · `not_at_war` · `at_war_with` {tag} · `gov_is` {value} · `gov_in` {values[]} · `has_tech` {line, level} ·
`tech_avg_above` {value} · `provinces_above|below` {value} · `food_ratio_below` {value} · `food_stock_below` {value} ·
`religion_is` {value} · `culture_is` {value} · `flag_set` {flag} · `flag_not_set` {flag} · `year_at_least|year_before` {value} ·
`is_player` · `is_ai` · `ruler_age_above` {value} · `ruler_skill_below|above` {skill: adm|dip|mil, value} ·
`prestige_above|below` · `manpower_below` · `has_reform` {value} · `war_exhaustion_above` {value} ·
`season_is` {value: spring|summer|autumn|winter} · `class_sat_below` {class, value} · `is_vassal` · `has_vassals` ·
`alliances_at_least` {value} · `owns_province` {value: province id} · `neighbors_tag` {value: tag} · `armies_at_least` {value} ·
`inflation_above` {value} · `bankrupt_recently` · `heir_missing` · `capital_coastal`
## Province-scope conditions (pconds)
`unrest_above|below` · `pop_above|below` (thousands) · `terrain_is` · `coastal` · `culture_is` · `religion_is` ·
`religion_differs` · `has_building` {value} · `dev_below|above` · `devastation_above` · `occupied`

## Effects
Country: `gold` `manpower` `stability` `legitimacy` `prestige` `admin` `inflation` `debt` (all `value`, +/-) ·
`stock` {res: food|iron|wood|stone|coal|lux, value} · `set_flag` {flag, turns?} · `clear_flag` {flag} ·
`temp_mod` {mods: {key: value,...}, turns} (keys: tax, trade, prod, food, morale, research, manpower, army_upkeep, unrest, stability, build_cost, diplo, pop_growth, legit) ·
`class_sat` {class, value} · `pop_pct` {value} (percent change of all provinces, e.g. -8) · `province_unrest` {value} (event province, or all) ·
`province_pop_pct` {value} · `province_devastation` {value 0..1} · `province_dev` {value} · `add_building` {bid} · `destroy_building` {bid?} ·
`ruler_skill` {skill, value} · `kill_ruler` · `spawn_rebels` {size} · `relation` {target: random_neighbor|enemy|tag id, value} ·
`research_points` {value} · `add_claim` {target: tag, province?} · `trigger_event` {id} · `disband_pct` {value} · `add_regiments` {unit, n} ·
`change_religion_province` {value} · `war_exhaustion` {value} · `reform_cost_free` (grants +60 admin)
