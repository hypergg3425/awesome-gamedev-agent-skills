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
  "native_fallback": true                                 // unclaimed provinces become native/tribal countries
}
```

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
