# IMPERIUM icon set

All icons are **original**, generated procedurally by `tools/assets/gen_icons.py`; no third-party artwork is used.
License: the project's own (same as the rest of IMPERIUM).

## Format

* `assets/icons/<id>.svg`, viewBox `0 0 64 64`, pure white `#ffffff` strokes/fills on transparent (tint in-engine).
* 4px stroke, round joins and caps, about 6px padding, one concept per icon (see `docs/ART_DIRECTION.md`).
* Religion icons are generic symbols (crosses, crescent, star, wheel, lotus, sun, gate); no people or sacred figures.

## Regenerating

```
python3 tools/assets/gen_icons.py
```

Edit the per-icon functions in the script and re-run; it rewrites every SVG listed below.

## Ids (163 unique icons)

### Resources / stats

`gold`, `food`, `manpower`, `iron`, `wood`, `stone`, `coal`, `luxury`, `prestige`, `admin`, `stability`, `legitimacy`, `inflation`, `debt`, `trade`, `research`, `population`, `income`, `expense`

### UI

`end_turn`, `menu`, `settings`, `save`, `load`, `close`, `back`, `next`, `plus`, `minus`, `check`, `cross`, `info`, `warning`, `lock`, `search`, `filter`, `map`, `zoom_in`, `zoom_out`, `mode_political`, `mode_terrain`, `mode_economic`, `mode_diplomatic`, `mode_military`, `mode_population`, `mode_supply`, `mode_trade`

### Panels

`country`, `economy`, `military`, `diplomacy`, `technology`, `construction`, `population`, `events`, `objectives`, `politics`, `history`, `statistics`, `achievements`, `editor`, `credits`, `language`, `sound`, `music`, `video`

### Military

`unit_infantry`, `unit_heavy_infantry`, `unit_archers`, `unit_cavalry`, `unit_heavy_cavalry`, `unit_artillery`, `unit_engineer`, `unit_naval`, `general`, `siege`, `battle`, `move`, `recruit`, `disband`, `merge`, `split`, `fort`

### Diplomacy

`war`, `peace`, `alliance`, `nap`, `defensive`, `access`, `trade_agreement`, `vassal`, `guarantee`, `gift`, `relations`, `sanction`, `coalition`, `embargo`, `transfer`, `assist`

### Terrain

`terrain_plains`, `terrain_hills`, `terrain_mountains`, `terrain_forest`, `terrain_desert`, `terrain_jungle`, `terrain_marsh`, `terrain_steppe`, `terrain_arctic`

### Buildings

`b_farm`, `b_market`, `b_workshop`, `b_mine`, `b_sawmill`, `b_port`, `b_trading_center`, `b_barracks`, `b_fort`, `b_arsenal`, `b_military_academy`, `b_government_office`, `b_court`, `b_tax_office`, `b_admin_center`, `b_road`, `b_bridge`, `b_canal`, `b_railway`, `b_university`, `b_hospital`, `b_cultural_institution`, `b_religious_building`

### Tech branches

`t_military`, `t_economic`, `t_administration`, `t_society`

### Governments

`g_absolute_monarchy`, `g_constitutional_monarchy`, `g_republic`, `g_merchant_republic`, `g_empire`, `g_tribal_confederation`, `g_theocracy`, `g_feudal_kingdom`, `g_military_government`

### Religions (abstract symbols only)

`r_catholic`, `r_orthodox`, `r_protestant`, `r_sunni`, `r_shia`, `r_jewish`, `r_buddhist`, `r_hindu`, `r_eastern_faiths`, `r_pagan`, `r_animist`, `r_tengri`, `r_shinto`, `r_secular`

### Classes

`c_nobility`, `c_merchants`, `c_peasants`, `c_clergy`, `c_artisans`, `c_military`
