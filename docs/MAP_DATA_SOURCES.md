# Map data: sources, derivation and formats

## Map sets
| set | directory | provinces | status |
|---|---|---|---|
| `classic` | `data/map/` | 410 | validated fallback, unchanged geometry/ids |
| `extended` | `data/map600/` | 1062 | partition of the 410 classic provinces; selected per scenario or by default (`Defs.default_map_set`) |

Selection: `Defs.use_map_set("classic"|"extended")`. A scenario may carry `"map_set": "classic"|"extended"`; without the field it is
authored on classic ids and runs on `Defs.default_map_set` (constant `Defs.DEFAULT_MAP_SET`, or the environment variable
`IMPERIUM_MAP_SET=extended` for a run). `ScenarioLoader.build/validate` call `MapUpgrade.prepare(def)`
(`scripts/data/map_upgrade.gd`) which switches the set and, for classic-authored scenarios on the extended set, rewrites every province
reference through `data/map600/parents.json`. Saves record `state["map_set"]`; `SaveManager` switches the set before validating a load.

## Sources (all public domain / CC0)
| data | file | URL | accessed | licence |
|---|---|---|---|---|
| Admin-0 countries 1:50m | ne_50m_admin_0_countries | https://naturalearth.s3.amazonaws.com/50m_cultural/ | 2026-11-23 | Natural Earth, public domain |
| Admin-1 states/provinces 1:10m | ne_10m_admin_1_states_provinces | https://naturalearth.s3.amazonaws.com/10m_cultural/ | 2026-11-23 | public domain |
| Geography regions (polys) 1:10m | ne_10m_geography_regions_polys | https://naturalearth.s3.amazonaws.com/10m_physical/ | 2026-11-23 | public domain |
| Marine polys 1:10m, land 1:50m, lakes 1:50m | ne_10m_geography_marine_polys, ne_50m_land, ne_50m_lakes | .../10m_physical/, .../50m_physical/ | 2026-11-23 | public domain |
| Rivers + lake centrelines 1:10m, Europe rivers | ne_10m_rivers_lake_centerlines, ne_10m_rivers_europe | https://naturalearth.s3.amazonaws.com/10m_physical/ | 2026-11-23 | public domain |
| Lakes 1:10m | ne_10m_lakes | .../10m_physical/ | 2026-11-23 | public domain |
| Populated places 1:10m | ne_10m_populated_places | https://naturalearth.s3.amazonaws.com/10m_cultural/ | 2026-11-23 | public domain |

Hand-entered, **approximate** tables (own knowledge, no proprietary map copied) live in `tools/map600_data.py`: historic trade hubs,
coal / iron / luxury districts (point + radius), great-desert boxes, named strait coordinates, mountain-pass coordinates, extra sea
label translations. The split table `tools/map600_splits.py` names every extended province (historical-regional names, English + Turkish).
Turkish names are authored or taken from Natural Earth `name_tr`; they are neutral regional names, not claims.

## Pipeline (reproducible)
```
python3 tools/gen_map_step1.py           # classic step 1 (unchanged) -> /tmp/claude-0/provinces_step1.pkl
python3 tools/gen_map_step2.py           # classic step 2 (unchanged)
python3 tools/gen_map600_step1.py        # split 410 -> 1062 (+ data/map600/parents.json)   [needs /tmp/claude-0/units600.pkl, see below]
python3 tools/gen_map600_step2.py        # topology, derived data, sea links, features, geometry.bin -> data/map600/
python3 tools/gen_map_features_classic.py# data/map/features.json
python3 tools/gen_map600_docs.py         # docs/province_list_extended.txt
python3 tools/validate_map.py data/map600 ; python3 tools/validate_map.py data/map
```
`units600.pkl` is the cached Natural Earth admin-1 unit list (see the loader snippet in `tools/map600_common.py` paths; regenerate by reading
the admin-1 shapefile with `MERGE` from `map_seeds.py`). Inputs are expected under `/tmp/claude-0/ne` (admin/regions/marine/land/lakes) and
`/tmp/claude-0/ne2` (rivers, lakes 10m, populated places).

## How the 1062 provinces were made
Each child is a union of real admin-1 units, of the separate polygons of a multi-part unit (European / Asian Istanbul, Gallipoli, islands)
or, where a modern unit is far too big to be one region (e.g. Xinjiang, Ar Riyad, Inner Mongolia), a Voronoi cut between authored
historical-region seeds (frontier approximate). Children partition their parent exactly (validated by area and by `parents.json`).
Priority regions (Europe, Anatolia, Balkans, Caucasus, North Africa, Levant/Iraq, Arabia, Persia, Central Asia, India, China, Japan, Korea,
Southeast Asia) are split; Americas, sub-Saharan Africa, Oceania and Siberia keep (or only partly refine) the classic provinces.
Every province has a `reason` (strategic justification: authored tag + data tags such as island, mountain, river valley (name), delta,
city hinterland (city), coast, steppe).

## Province fields (provinces.json)
Same as classic (`id,name,name_tr,adm0,continent,subregion,area_km2,pop_modern_m,centroid,label,bbox,lat,lon,terrain,coastal,landmass,
archipelago,culture,fert,iron,stone,coal,wood,lux,mountain_cover,adj,sea`) plus:
`parent` (classic id), `climate`, `port`, `coast_km`, `hub` (0-3 historic trade hub score), `urban_k` (modern city population in thousands),
`cities` (top 3 modern cities, ascii), `dev_hint` (0..1), `pop_share` (share of the parent's population), `tags`, `reason`.

Derivations (deterministic, no random numbers):
* `terrain`: unchanged rule of `gen_map_step2.terrain_for` on Natural Earth region cover (+ desert boxes).
* `climate`: Köppen-like heuristic from latitude/longitude, desert and mountain cover, coastline. **Not measured climate.**
* `fert` = terrain base x climate multiplier + river density + delta/wetland + valley/lowland cover (+ river-oasis bonus in deserts).
* `iron`/`stone`: mountain + foothill cover, hills bonus, plus proximity to curated ore districts. `coal`: curated coal districts only.
* `wood`: terrain base x climate humidity. `lux`: climate + coast + curated luxury districts.
* `pop_modern_m` = parent population x `pop_share`, `pop_share` = 0.5 area share + 0.5 modern-urban share within the parent.
* `dev_hint` = 0.22 log2(1 + urban_k/150), a weak proxy (modern cities, not medieval ones). Not used by the loader yet.
* `port` = coastal with >= 0.6 deg of coast (or island); `hub` from the curated hub list (province containing/near the city).
* Sea links: land-adjacent provinces never get links; different landmass: strait <= 150 km (max 4), else 2 nearest lanes (<= 2600 km);
  same landmass: strait <= 90 km when the land route is >= 5 hops, lane <= 900 km when >= 7 hops and the straight line crosses open sea;
  plus the curated named straits; finally lanes join any disconnected landmass. 926 links vs 548 on classic.

## parents.json
`{"fra_normandy": ["fra_normandy", "fra_upper_normandy"], ...}`: every classic id -> its children (partition). The first child is the *core*:
it keeps the parent's id when that id still names the region; single-province references (capitals, army locations, event province
ids) are mapped to the core. Ownership, claims, religion/culture overrides, `province_dev` of a parent apply to all children.
Objective counts are scaled by children-per-parent. Events that name a province (`add_claim`, `owns_province`) address the core child only.

## features.json (data/map/features.json and data/map600/features.json)
```
{"rivers":  [[idA, idB, {"name": "Rhine", "name_tr": "Ren", "width": 1..3}], ...],
 "passes":  [[idA, idB, {"name": "Brenner", "name_tr": "...", "approximate": true}], ...],
 "straits": [[idA, idB, {"name": "Bosporus", "name_tr": "...", "adjacent": true|false, "km": 8}], ...],
 "lakes":   [{"name","name_tr","lon","lat","pos":[x,y],"area_km2","provinces":[...]}], "meta": {...}}
```
* `rivers`: land-adjacent pair whose shared border follows a named Natural Earth river centre line (>= 25% of the border and >= 0.2 deg).
  `width` 3 = great river (scalerank <= 4), 2 = <= 6, 1 otherwise.
* `passes`: hand-entered pass coordinates matched to the adjacent pair whose shared border is nearest (<= 0.45 deg). **Approximate.** A pass
  not matched (15 on extended, 35 on classic) is listed in `meta.passes_unmatched`.
* `straits`: named narrow crossings; `adjacent: false` pairs are also `strait` sea links of the province data.
* The consuming class `GeoFeatures` (scripts/data/geo_features.gd) belongs to workstream E; `Defs.features` holds the active set's dictionary.

## Limitations (honest)
* Modern admin-1 geometry, not historical frontiers; splits inside single big units are Voronoi approximations.
* Americas, sub-Saharan Africa, Oceania and most of Siberia are not refined (extended provinces there equal classic ones).
* Resource/climate values are heuristics; coal/iron/luxury use curated approximate districts.
* Rivers only where a border follows a river; rivers crossing a province do not create a barrier.
* Several straits are land-adjacent in the simplified geometry (Bosporus, Gibraltar): they are features, not sea links.
