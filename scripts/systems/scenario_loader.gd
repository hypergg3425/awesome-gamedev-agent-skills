class_name ScenarioLoader
extends RefCounted
## Builds a playable campaign state from a scenario definition (see docs/TECHNICAL_ARCHITECTURE.md).
## All population/density/building numbers produced here are MODELLED approximations, not
## historical statistics, and are labelled as such in the UI.

const ERA_YEARS: Array[int] = [1066, 1337, 1453, 1519, 1789, 1871, 1900]
# people per km2 by region class at ERA_YEARS (modelled)
const DENSITY := {
	"europe": [9.0, 24.0, 15.0, 19.0, 36.0, 52.0, 60.0],
	"mena": [5.0, 6.0, 5.0, 6.0, 8.0, 10.0, 12.0],
	"south_asia": [8.0, 10.0, 10.0, 11.0, 20.0, 28.0, 34.0],
	"east_asia": [10.0, 14.0, 14.0, 17.0, 35.0, 40.0, 45.0],
	"se_asia": [4.0, 5.0, 5.0, 6.0, 10.0, 14.0, 18.0],
	"central_asia": [0.8, 0.9, 0.9, 1.0, 1.4, 2.0, 3.0],
	"africa": [2.0, 2.5, 2.5, 3.0, 4.0, 5.0, 7.0],
	"americas": [1.6, 1.8, 1.8, 1.7, 1.6, 4.0, 9.0],
	"oceania": [0.5, 0.5, 0.5, 0.5, 0.5, 1.0, 2.0],
}
const TERRAIN_POP := {"plains": 1.1, "steppe": 0.5, "forest": 0.7, "hills": 0.75, "marsh": 0.6, "mountains": 0.35,
	"desert": 0.12, "jungle": 0.6, "arctic": 0.06}
const NATIVE_NAMES := {
	"Northern America": ["Peoples of Northern America", "Kuzey Amerika Halkları"],
	"Central America": ["Peoples of Central America", "Orta Amerika Halkları"],
	"Caribbean": ["Caribbean Peoples", "Karayip Halkları"],
	"South America": ["Peoples of South America", "Güney Amerika Halkları"],
	"Northern Africa": ["Saharan Tribes", "Sahra Kabileleri"],
	"Western Africa": ["West African Peoples", "Batı Afrika Halkları"],
	"Middle Africa": ["Central African Peoples", "Orta Afrika Halkları"],
	"Eastern Africa": ["East African Peoples", "Doğu Afrika Halkları"],
	"Southern Africa": ["Southern African Peoples", "Güney Afrika Halkları"],
	"Western Asia": ["Tribes of Western Asia", "Batı Asya Kabileleri"],
	"Central Asia": ["Steppe Tribes", "Bozkır Kabileleri"],
	"Southern Asia": ["Principalities of South Asia", "Güney Asya Beylikleri"],
	"South-Eastern Asia": ["Kingdoms of Southeast Asia", "Güneydoğu Asya Krallıkları"],
	"Eastern Asia": ["Realms of East Asia", "Doğu Asya Devletleri"],
	"Northern Europe": ["Northern Tribes", "Kuzey Kabileleri"],
	"Southern Europe": ["Southern European Lords", "Güney Avrupa Beyleri"],
	"Western Europe": ["Western European Lords", "Batı Avrupa Beyleri"],
	"Eastern Europe": ["Eastern European Lords", "Doğu Avrupa Beyleri"],
	"Australia and New Zealand": ["Peoples of Australasia", "Avustralasya Halkları"],
	"Melanesia": ["Melanesian Peoples", "Melanezya Halkları"],
	"Polynesia": ["Polynesian Peoples", "Polinezya Halkları"],
	"Micronesia": ["Micronesian Peoples", "Mikronezya Halkları"],
	"Pool": ["Island Peoples", "Ada Halkları"],
}
const NAT_COLORS := ["#8a7f5f", "#7a8c6a", "#8c6f6a", "#6f7f8c", "#8c866a", "#7d6a8c", "#6a8c82", "#8c7a6a"]

static func region_class(p: Dictionary) -> String:
	var lon := float(p["lon"])
	var lat := float(p["lat"])
	var cont: String = p["continent"]
	var cult: String = p["culture"]
	if cont == "Europe":
		return "europe" if lon < 50 else "central_asia"
	if cont == "Africa":
		return "mena" if (lat > 17.0 or (lat > 8.0 and lon > 25.0 and lon < 45.0 and lat > 22.0)) else "africa"
	if cont in ["North America", "South America"]:
		return "americas"
	if cont == "Oceania":
		return "oceania"
	# Asia
	if lon < 62.0 and lat < 45.0:
		return "mena"
	if lon < 75.0 and lat >= 45.0:
		return "central_asia"
	if lat > 48.0 and lon > 75.0:
		return "central_asia"
	if cult == "indic" or (lon < 92.0 and lat < 36.0):
		return "south_asia"
	if cult == "southeast_asian" or (lat < 22.0 and lon > 92.0):
		return "se_asia"
	if lon >= 92.0 and lat >= 22.0 and lon < 150:
		return "east_asia"
	return "central_asia" if lon < 100 and lat > 38 else "east_asia"

static func era_index(year: int) -> float:
	if year <= ERA_YEARS[0]:
		return 0.0
	for i in range(1, ERA_YEARS.size()):
		if year <= ERA_YEARS[i]:
			var a := float(ERA_YEARS[i - 1])
			var b := float(ERA_YEARS[i])
			return float(i - 1) + (float(year) - a) / (b - a)
	return float(ERA_YEARS.size() - 1)

static func density_at(rc: String, year: int) -> float:
	var arr: Array = DENSITY[rc]
	var ei := era_index(year)
	var i := int(floor(ei))
	if i >= arr.size() - 1:
		return float(arr[arr.size() - 1])
	var f := ei - float(i)
	return lerpf(float(arr[i]), float(arr[i + 1]), f)

static func default_religion(p: Dictionary, year: int, country_religion: String) -> String:
	var cult: String = p["culture"]
	var lat := float(p["lat"])
	var lon := float(p["lon"])
	match cult:
		"latin":
			return "catholic"
		"germanic":
			if year >= 1560 and lat > 49.5 and lon < 20 and p["adm0"] not in ["AUT", "IRL"]:
				return "protestant"
			return "catholic"
		"slavic":
			if p["adm0"] in ["RUS", "UKR", "BLR", "SRB", "BGR", "MKD", "MNE", "BIH"]:
				return "orthodox" if p["adm0"] != "BIH" else "catholic"
			if p["adm0"] in ["LTU", "LVA", "EST"] and year < 1400:
				return "pagan"
			return "catholic"
		"hellenic":
			return "orthodox"
		"magyar_finnic":
			return "pagan" if (p["adm0"] == "FIN" and year < 1200) else "catholic"
		"turkic":
			return "sunni"
		"arabic":
			return "sunni"
		"iranian":
			return "shia" if (year >= 1501 and p["adm0"] == "IRN") else "sunni"
		"caucasian":
			return "orthodox"
		"indic":
			return "hindu"
		"sinic":
			return "eastern_faiths" if p["adm0"] in ["CHN", "TWN", "KOR", "PRK"] else "tengri"
		"japonic":
			return "shinto"
		"southeast_asian":
			return "sunni" if (p["adm0"] in ["IDN", "MYS", "BRN"] and year >= 1400) else "buddhist"
		"latin_american":
			return "catholic" if year >= 1550 else "animist"
		"african":
			return "orthodox" if p["adm0"] == "ETH" else "animist"
		_:
			return "animist"

## --- main entry ----------------------------------------------------------------------------
static func build(def_in: Dictionary, player: String, difficulty: String = "normal", seed_value: int = 12345) -> Dictionary:
	var def := MapUpgrade.prepare(def_in)  # selects the map set; upgrades classic-authored scenarios (scripts/data/map_upgrade.gd)
	var s := GS.new_state()
	s["map_set"] = Defs.map_set
	s["scenario"] = def.get("id", "custom")
	s["scenario_name"] = def.get("name", {})
	s["custom"] = bool(def.get("custom", false))
	s["approximate"] = bool(def.get("approximate", true))
	s["names"] = _scenario_names(def.get("province_names", {}))
	s["geo_layer"] = (def.get("geo_layer", []) as Array).duplicate(true)
	var start: Dictionary = def.get("start", {"year": 1066, "month": 1})
	s["start_year"] = int(start.get("year", 1066))
	s["start_month"] = int(start.get("month", 1))
	s["turn_limit"] = int(def.get("turn_limit", 200))
	s["difficulty"] = difficulty
	s["seed"] = seed_value
	s["player"] = player
	s["players"] = [player]
	s["era"] = int(def.get("era", 1))
	var year := int(s["start_year"])

	# 1. province ownership -------------------------------------------------------------------
	var owner_of := {}
	var cdefs: Dictionary = def.get("countries", {})
	for cid in cdefs:
		for pat in cdefs[cid].get("provinces", []):
			var pstr := str(pat)
			var remove := pstr.begins_with("-")
			if remove:
				pstr = pstr.substr(1)
			for pid in Defs.province_ids:
				if Util.glob_match(pstr, pid):
					if remove:
						if owner_of.get(pid, "") == cid:
							owner_of.erase(pid)
					else:
						owner_of[pid] = cid
	# 2. country states -------------------------------------------------------------------------
	for cid in cdefs:
		s["countries"][cid] = _make_country(s, cid, cdefs[cid])
	# natives for unclaimed provinces
	if bool(def.get("native_fallback", true)):
		var groups := {}
		for pid in Defs.province_ids:
			if not owner_of.has(pid):
				var pd: Dictionary = Defs.provinces[pid]
				var key: String = str(pd["subregion"])
				if pd["adm0"] == "ISL_POOL":
					key = "Pool"
				if not groups.has(key):
					groups[key] = []
				groups[key].append(pid)
		var ci := 0
		for key in Util.sorted_keys(groups):
			var nid := "NAT_" + str(key).replace(" ", "_").replace("-", "_").to_upper()
			var names: Array = NATIVE_NAMES.get(key, [str(key) + " Peoples", str(key) + " Halkları"])
			var cd := {"name": {"en": names[0], "tr": names[1]}, "color": NAT_COLORS[ci % NAT_COLORS.size()],
				"gov": "tribal_confederation", "ai": "isolationist", "native": true, "playable": false,
				"culture": "native", "civ": "backward"}
			ci += 1
			# capital = biggest province
			var best := ""
			var barea := -1
			for pid in groups[key]:
				if int(Defs.provinces[pid]["area_km2"]) > barea:
					barea = int(Defs.provinces[pid]["area_km2"])
					best = pid
			cd["capital"] = best
			var cs := _make_country(s, nid, cd)
			cs["native"] = true
			s["countries"][nid] = cs
			for pid in groups[key]:
				owner_of[pid] = nid
	# rebel pseudo-country
	var reb := _make_country(s, "REB", {"name": {"en": "Rebels", "tr": "İsyancılar"}, "color": "#444444", "gov": "military_government", "playable": false})
	reb["rebel"] = true
	s["countries"]["REB"] = reb
	# 3. provinces ------------------------------------------------------------------------------
	var rel_over: Dictionary = def.get("religion_overrides", {})
	var cul_over: Dictionary = def.get("culture_overrides", {})
	var dev_over: Dictionary = def.get("province_dev", {})
	for pid in Defs.province_ids:
		var owner: String = owner_of.get(pid, "")
		var pd: Dictionary = Defs.provinces[pid]
		var cstate: Dictionary = s["countries"].get(owner, {})
		var rc := region_class(pd)
		var dens := density_at(rc, year)
		# western/central Europe is denser than the north-east; north & arctic are sparser
		if rc == "europe":
			if float(pd["lon"]) > 24.0 or float(pd["lat"]) > 58.0:
				dens *= 0.55
			elif float(pd["lat"]) < 50.0 and float(pd["lon"]) < 16.0:
				dens *= 1.15
		var fert := float(pd["fert"])
		var pop: float = float(pd["area_km2"]) * dens * TERRAIN_POP.get(pd["terrain"], 0.7) * (0.55 + 0.9 * fert) / 1000.0
		pop = maxf(pop, 6.0)
		var civ: String = str(cstate.get("civ", "average"))
		var dev := clampf(log(maxf(pop, 20.0) / 25.0) / log(2.1), 0.0, 9.0)
		dev += {"advanced": 0.8, "average": 0.0, "backward": -0.7}.get(civ, 0.0)
		dev += float(dev_over.get(pid, 0.0))
		if cstate.get("capital", "") == pid:
			dev += 1.0
			pop *= 1.25
		dev = clampf(dev, 0.2, 10.0)
		var religion := _override_for(rel_over, pid)
		if religion == "":
			religion = default_religion(pd, year, str(cstate.get("religion", "")))
			if religion == "animist" or religion == "":
				religion = str(cstate.get("religion", "animist")) if str(cstate.get("native", "")) == "" else religion
			# the owning country's faith applies to provinces of its own culture
			if cstate.get("culture", "") == pd["culture"] and cstate.get("religion", "") != "":
				religion = str(cstate["religion"])
		var culture: String = _override_for(cul_over, pid)
		if culture == "":
			culture = pd["culture"]
		var rs: Dictionary = {"owner": owner, "controller": owner, "pop": snappedf(pop, 0.1), "dev": snappedf(dev, 0.1),
			"buildings": {}, "queue": [], "stab": 60.0, "unrest": 0.0, "culture": culture, "religion": religion,
			"classes": _default_classes(pd, dev), "literacy": 0.02 + 0.01 * dev, "urban": clampf(0.04 + 0.025 * dev, 0.03, 0.5),
			"disease": 0.0, "devastation": 0.0, "siege": null, "claims": [], "cores": [owner] if owner != "" else [],
			"last": {}, "recruit_pool": 0.0}
		s["provinces"][pid] = rs
	# claims declared in scenario ("claims": {"ENG": ["fra_*"]})
	# a pattern starting with "-" removes earlier matches; provinces a country already owns are skipped
	for cid in def.get("claims", {}):
		if not s["countries"].has(cid):
			continue
		for pat in def["claims"][cid]:
			var cpat := str(pat)
			var cneg := cpat.begins_with("-")
			if cneg:
				cpat = cpat.substr(1)
			for pid in Defs.province_ids:
				if not Util.glob_match(cpat, pid):
					continue
				var pcl: Array = s["provinces"][pid]["claims"]
				if cneg:
					pcl.erase(cid)
				elif cid not in pcl and s["provinces"][pid]["owner"] != cid:
					pcl.append(cid)
	GS.rebuild_caches(s)
	# 4. country completion ----------------------------------------------------------------------
	for cid in s["countries"]:
		if cid == "REB":
			continue
		_finish_country(s, cid, cdefs.get(cid, {}))
	# 5. relations --------------------------------------------------------------------------------
	_apply_relations(s, def.get("relations", {}))
	# 6. objectives ---------------------------------------------------------------------------------
	for o in def.get("objectives", []):
		var ob: Dictionary = (o as Dictionary).duplicate(true)
		ob["done"] = false
		s["objectives"].append(ob)
	s["victory_cfg"] = def.get("victory", {})
	s["scenario_events"] = def.get("events", [])
	# market ------------------------------------------------------------------------------------------
	for res in ["food", "iron", "wood", "stone", "coal", "lux"]:
		s["market"][res] = {"price": float(BASE_PRICE[res]), "supply": 0.0, "demand": 0.0}
	GS.rebuild_caches(s)
	GS.rng_of(s)
	# starting armies --------------------------------------------------------------------------------
	for cid in s["countries"]:
		if cid == "REB":
			continue
		_make_armies(s, cid, cdefs.get(cid, {}))
	GS.rebuild_caches(s)
	# AI init + player flag
	for cid in s["countries"]:
		if cid == "REB":
			continue
		s["countries"][cid]["is_player"] = cid == player
		s["ai"][cid] = AISystem.new_ai_state(s, cid, str(cdefs.get(cid, {}).get("ai", "")))
	# statistics bookkeeping + first economy snapshot
	GS.save_rng(s)
	return s

const BASE_PRICE := {"food": 1.2, "iron": 4.0, "wood": 2.0, "stone": 3.0, "coal": 3.0, "lux": 8.0}

## Value (religion / culture id) whose pattern list matches pid; exact province ids beat globs so a
## precise entry always overrides a broad "tur_*" style one. "" when nothing matches.
static func _override_for(overrides: Dictionary, pid: String) -> String:
	var found := ""
	for key in overrides:
		for pat in overrides[key]:
			var ps := str(pat)
			if ps == pid:
				return str(key)
			if ps.contains("*") and Util.glob_match(ps, pid):
				found = str(key)
	return found

## Scenario-specific province names ({"<pid>": {"en": ..., "tr": ...}}) restricted to known provinces.
static func _scenario_names(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for pid in raw:
			var nd: Variant = raw[pid]
			if Defs.provinces.has(pid) and nd is Dictionary and str(nd.get("en", "")) != "":
				out[pid] = {"en": str(nd["en"]), "tr": str(nd.get("tr", nd["en"]))}
	return out

static func _default_classes(pd: Dictionary, dev: float) -> Dictionary:
	var urban := clampf(0.04 + 0.025 * dev, 0.03, 0.5)
	return {"nobility": 0.02, "merchants": 0.01 + urban * 0.15, "peasants": 0.80 - urban * 0.5, "clergy": 0.015 + 0.004 * dev,
		"artisans": 0.02 + urban * 0.35, "military": 0.01}

static func _make_country(s: Dictionary, cid: String, cd: Dictionary) -> Dictionary:
	var gov: String = str(cd.get("gov", "feudal_kingdom"))
	var c := {
		"id": cid, "alive": true, "name": (cd.get("name", {"en": cid, "tr": cid}) as Dictionary).duplicate(true), "short": (cd.get("short", cd.get("name", {"en": cid, "tr": cid})) as Dictionary).duplicate(true),
		"color": str(cd.get("color", "#888888")), "flag": (cd.get("flag", {}) as Dictionary).duplicate(true), "culture": str(cd.get("culture", "")),
		"religion": str(cd.get("religion", "")), "gov": gov, "civ": str(cd.get("civ", "average")),
		"capital": str(cd.get("capital", "")), "is_player": false, "native": bool(cd.get("native", false)),
		"playable": bool(cd.get("playable", true)) and not bool(cd.get("native", false)),
		"ruler": _make_ruler(cd.get("ruler", {}), gov), "heir": (cd["heir"] as Dictionary).duplicate(true) if cd.get("heir") is Dictionary else null, "dynasty": str(cd.get("ruler", {}).get("dynasty", "")),
		"gold": float(cd.get("treasury", 0.0)), "debt": 0.0, "inflation": 0.0, "stock": {"food": 30.0, "iron": 10.0, "wood": 20.0, "stone": 10.0, "coal": 0.0, "lux": 0.0},
		"manpower": 0.0, "manpower_max": 0.0, "stability": float(cd.get("stability", 55.0)), "legitimacy": 60.0, "prestige": float(cd.get("prestige", 0.0)),
		"admin": 50.0, "tax_rate": 0.25, "army_funding": 1.0, "import_food": true,
		"researched": {}, "tech_level": {}, "research": {"current": {}, "progress": {}, "alloc": {"military": 1.0, "economic": 1.0, "administration": 1.0, "society": 1.0}, "bank": 0.0, "last_points": 0.0},
		"reforms": [], "classes": {}, "mods": (cd.get("mods", {}) as Dictionary).duplicate(true), "temp_mods": [], "special_units": (cd.get("special_units", []) as Array).duplicate(true),
		"traditions": (cd.get("traditions", []) as Array).duplicate(true), "overlord": "", "stats": {}, "flags": {}, "recruit_queue": [], "budget": {}, "history_income": [],
		"unrest_streak": 0, "election_turn": 0, "bankrupt_turns": 0, "war_exhaustion": 0.0, "regency": 0,
	}
	c["tag_alias"] = str(cd.get("alias", cid))
	# per-country honesty flag: true = reconstruction is approximate (ruler, borders or polity form uncertain)
	c["approximate"] = bool(cd.get("approximate", s.get("approximate", true)))
	c["note"] = (cd.get("note", {}) as Dictionary).duplicate(true) if cd.get("note") is Dictionary else {}
	return c

static func _make_ruler(rd: Dictionary, gov: String) -> Dictionary:
	var title := "Ruler"
	return {"name": rd.get("name", "Unknown"), "adm": int(rd.get("adm", 5)), "dip": int(rd.get("dip", 5)), "mil": int(rd.get("mil", 5)),
		"age": int(rd.get("age", 35)), "dynasty": str(rd.get("dynasty", "")), "term_start": 0}

static func _finish_country(s: Dictionary, cid: String, cd: Dictionary) -> void:
	var c: Dictionary = s["countries"][cid]
	var owned := GS.owned(s, cid)
	if owned.is_empty():
		c["alive"] = false
		return
	if c["capital"] == "" or GS.prov(s, c["capital"]).get("owner", "") != cid:
		var best := ""
		var bp := -1.0
		for pid in owned:
			var pp: float = float(s["provinces"][pid]["pop"])
			if pp > bp:
				bp = pp
				best = pid
		c["capital"] = best
		# capital bonus was applied only to listed capitals; apply now
		s["provinces"][best]["dev"] = minf(10.0, float(s["provinces"][best]["dev"]) + 0.5)
	if c["culture"] == "":
		c["culture"] = str(Defs.provinces[c["capital"]]["culture"])
	if c["religion"] == "":
		c["religion"] = str(s["provinces"][c["capital"]]["religion"])
	# technology by era and civilisation level
	# Start levels are compressed (era 0..4 -> 0,1,2,2,3) so that level 4 of every line is
	# always left to research, even in the late scenarios (no instant technological victory).
	var era_base: int = [0, 1, 2, 2, 3][clampi(int(s["era"]), 0, 4)]
	var era := era_base + int(cd.get("tech_mod", 0))
	if bool(cd.get("native", false)):
		era -= 1
	else:
		era += {"advanced": 1, "average": 0, "backward": -1}.get(c["civ"], 0)
	for line in Defs.tech_lines:
		var lv := clampi(era, 0, Const.START_TECH_CAP)
		if cd.has("tech"):
			lv = clampi(int(cd["tech"].get(line, lv)), 0, Const.START_TECH_CAP)
		TechSystem.grant_line_to(s, cid, line, lv)
	# buildings
	var civlv := clampi(int(c["tech_level"].get("infrastructure", 0)), 0, 4)
	for pid in owned:
		_auto_buildings(s, cid, pid)
	# classes initial satisfaction
	for cls in Const.CLASSES:
		c["classes"][cls] = {"sat": 55.0 + (4.0 if Defs.governments.get(c["gov"], {}).get("class_favor", {}).get(cls, 0) > 0 else 0.0), "power": 0.0}
	# manpower and money
	var mp := EconomySystem.manpower_max(s, cid)
	c["manpower_max"] = mp
	c["manpower"] = mp * 0.7
	var inc := EconomySystem.budget(s, cid)
	if not cd.has("treasury"):
		c["gold"] = maxf(40.0, float(inc.get("income", 20.0)) * 5.0)
	c["admin"] = 50.0 + 20.0 * float(Defs.governments.get(c["gov"], {}).get("mods", {}).get("admin_cap", 0.0))
	c["legitimacy"] = float(Defs.governments.get(c["gov"], {}).get("legit_start", 60)) if float(Defs.governments.get(c["gov"], {}).get("legit_start", 60)) > 0 else 65.0
	if c["gov"] in ["republic", "merchant_republic", "tribal_confederation", "theocracy"]:
		c["legitimacy"] = 65.0
	c["stability"] = float(cd.get("stability", 55.0))
	c["stock"]["food"] = float(s["provinces"][c["capital"]]["pop"]) * 0.05 + 20.0
	c["stock"]["wood"] = 20.0 + owned.size() * 2.0
	c["stock"]["stone"] = 10.0 + owned.size()
	c["stock"]["iron"] = 8.0 + owned.size()
	c["election_turn"] = 0
	if cd.has("heir") == false and "succession_crisis" in Defs.governments.get(c["gov"], {}).get("features", []):
		c["heir"] = {"name": "Heir of " + str(c["ruler"]["name"]), "age": 12 + int(hash(cid) % 8), "adm": 4 + int(hash(cid + "a") % 4), "dip": 4 + int(hash(cid + "d") % 4), "mil": 4 + int(hash(cid + "m") % 4)}

static func _auto_buildings(s: Dictionary, cid: String, pid: String) -> void:
	var p: Dictionary = s["provinces"][pid]
	var pd: Dictionary = Defs.provinces[pid]
	var c: Dictionary = s["countries"][cid]
	var dev := float(p["dev"])
	var tl: Dictionary = c["tech_level"]
	var b: Dictionary = {}
	var cap: bool = c["capital"] == pid
	var native: bool = bool(c.get("native", false))
	var slots := Mods.building_slots(p)
	if dev >= 1.0 and float(pd["fert"]) > 0.35:
		b["farm"] = clampi(int(round(float(pd["fert"]) * 1.4 + float(tl.get("agriculture", 0)) * 0.4)), 1, 3)
	if dev >= 1.5 and not native:
		b["religious_building"] = clampi(int(dev / 3.0) + 1, 1, 3)
	if dev >= 2.5 and not native:
		b["market"] = clampi(int(dev / 3.5) + (1 if cap else 0), 1, 3)
	if cap:
		b["government_office"] = clampi(1 + int(tl.get("bureaucracy", 0)) / 2, 1, 3)
		b["fort"] = 1
		if dev >= 4.0:
			b["barracks"] = 1
	if pd["coastal"] and dev >= 3.0 and not native:
		b["port"] = 1
	if dev >= 3.5 and not native and int(tl.get("infrastructure", 0)) >= 1:
		b["road"] = clampi(int(tl.get("infrastructure", 0)), 1, 3)
	if dev >= 4.0 and (pd["terrain"] in ["hills", "mountains"]) and not native:
		b["mine"] = 1
	if dev >= 3.0 and not native and int(tl.get("industry", 0)) >= 1:
		b["workshop"] = clampi(int(tl.get("industry", 0)) / 2 + 1, 1, 3)
	if dev >= 3.5 and int(tl.get("education", 0)) >= 1 and not native:
		b["university"] = 1 if (cap or dev >= 5.0) else 0
		if b["university"] == 0:
			b.erase("university")
	if p.get("dev", 0) >= 2.0 and str(pd["terrain"]) in ["forest", "jungle"] and not native:
		b["sawmill"] = 1
	# frontier forts / barracks are placed later by AI; keep slots in range
	var keys := b.keys()
	keys.sort()
	while b.size() > slots:
		b.erase(keys.pop_back())
	p["buildings"] = b

static func _make_armies(s: Dictionary, cid: String, cd: Dictionary) -> void:
	var c: Dictionary = s["countries"][cid]
	if not c["alive"]:
		return
	if cd.has("armies"):
		for ad in cd["armies"]:
			var loc: String = str(ad.get("loc", c["capital"]))
			var units := {}
			for uid in ad.get("units", {}):
				if Defs.units.has(uid):
					units[uid] = float(ad["units"][uid])
			if units.is_empty():
				continue
			var gen: Variant = ad.get("general", null)
			if gen is Dictionary:
				gen = (gen as Dictionary).duplicate()
				for k in ["tac", "log", "siege"]:
					gen[k] = int(gen.get(k, 5))
				gen["xp"] = float(gen.get("xp", 0.0))
			MilitarySystem.create_army(s, cid, loc, units, gen)
		return
	var level: String = str(cd.get("military", "medium"))
	var factor: float = {"low": 0.6, "medium": 1.0, "high": 1.6}.get(level, 1.0)
	if bool(cd.get("native", false)):
		factor = 0.7
	var total_pop := 0.0
	for pid in GS.owned(s, cid):
		total_pop += float(s["provinces"][pid]["pop"])
	var mods := Mods.country(s, cid)
	var n: float = total_pop * 0.0021 * factor * (1.0 + float(mods.get("manpower", 0.0)))
	n = clampf(n, 2.0, 60.0)
	if n < 2.0:
		return
	# compose: infantry core, some ranged, cavalry, plus siege units when tech allows
	var comp := {}
	var inf := UnitUtil.best_of(s, cid, "infantry")
	var hv := UnitUtil.best_of(s, cid, "heavy_infantry")
	var arc := UnitUtil.best_of(s, cid, "archers")
	var cav := UnitUtil.best_of(s, cid, "cavalry")
	var hc := UnitUtil.best_of(s, cid, "heavy_cavalry")
	var art := UnitUtil.best_of(s, cid, "artillery")
	var spec := ""
	for u in c["special_units"]:
		if Defs.units.has(u) and UnitUtil.is_available(s, cid, u):
			spec = u
	var shares := {inf: 0.38, hv: 0.14, arc: 0.14, cav: 0.12, hc: 0.08}
	if art != "":
		shares[art] = 0.08
	if spec != "":
		shares[spec] = shares.get(spec, 0.0) + 0.1
	for uid in shares:
		if uid == "":
			continue
		var cnt := roundf(n * float(shares[uid]))
		if cnt >= 1.0:
			comp[uid] = comp.get(uid, 0.0) + cnt
	if comp.is_empty():
		comp[inf] = n
	# split: ~60% field army at capital or frontier, rest garrison near capital & frontier provinces
	var locs: Array = [c["capital"]]
	var border := _frontier_provinces(s, cid)
	for pid in border:
		if pid != c["capital"] and locs.size() < 3:
			locs.append(pid)
	var parts := locs.size()
	var rem := comp.duplicate()
	for i in parts:
		var part := {}
		for uid in rem.keys():
			var share: float = float(comp[uid]) / float(parts)
			var take := minf(float(rem[uid]), (floorf(share) if i < parts - 1 else float(rem[uid])))
			if i < parts - 1 and take <= 0.0 and float(rem[uid]) >= 1.0 and float(comp[uid]) >= 1.0 and (hash(uid + str(i)) % parts == 0):
				take = 1.0
			if take > 0.0:
				part[uid] = take
				rem[uid] = float(rem[uid]) - take
		if not part.is_empty():
			var gen: Variant = null
			if i == 0:
				gen = MilitarySystem.make_general(s, cid, int(c["ruler"]["mil"]))
			MilitarySystem.create_army(s, cid, locs[i], part, gen)
	# a small fleet for rich coastal states in naval-capable eras
	var cap_p: Dictionary = Defs.provinces[c["capital"]]
	if bool(cap_p["coastal"]) and not bool(c.get("native", false)) and int(s["countries"][cid]["tech_level"].get("naval_warfare", 0)) >= 0:
		var port := ""
		for pid in GS.owned(s, cid):
			if Defs.provinces[pid]["coastal"] and int(s["provinces"][pid]["buildings"].get("port", 0)) > 0:
				port = pid
				break
		if port != "" and n >= 8.0:
			var warship := UnitUtil.best_of(s, cid, "naval")
			var fleet := {warship: maxf(1.0, roundf(n / 10.0))}
			if "cog" in Defs.units and warship != "cog":
				fleet["cog"] = maxf(1.0, roundf(n / 14.0))
			MilitarySystem.create_army(s, cid, port, fleet, null)

static func _frontier_provinces(s: Dictionary, cid: String) -> Array:
	var out: Array = []
	for pid in GS.owned(s, cid):
		for nb in Defs.neighbors(pid):
			var o: String = s["provinces"][nb]["owner"]
			if o != cid and o != "":
				out.append(pid)
				break
	out.sort_custom(func(a, b): return float(s["provinces"][a]["pop"]) > float(s["provinces"][b]["pop"]))
	return out

static func _apply_relations(s: Dictionary, rd: Dictionary) -> void:
	for pair in rd.get("alliances", []):
		if _has2(s, pair):
			var r := GS.rel(s, pair[0], pair[1])
			r["alliance"] = true
			r["defensive"] = true
			r["trust"] = 75.0
			GS.add_opinion(s, pair[0], pair[1], 60.0)
			GS.add_opinion(s, pair[1], pair[0], 60.0)
	for pair in rd.get("defensive", []):
		if _has2(s, pair):
			GS.rel(s, pair[0], pair[1])["defensive"] = true
	for pair in rd.get("nap", []):
		if _has2(s, pair):
			GS.rel(s, pair[0], pair[1])["nap_until"] = 40
	for pair in rd.get("access", []):
		if _has2(s, pair):
			GS.rel(s, pair[0], pair[1])["access"][pair[0]] = true
			GS.rel(s, pair[0], pair[1])["access"][pair[1]] = true
	for pair in rd.get("trade", []):
		if _has2(s, pair):
			GS.rel(s, pair[0], pair[1])["trade"] = true
			GS.add_opinion(s, pair[0], pair[1], 15.0)
			GS.add_opinion(s, pair[1], pair[0], 15.0)
	for pair in rd.get("guarantees", []):
		if _has2(s, pair):
			GS.rel(s, pair[0], pair[1])["guarantee"][pair[1]] = true  # pair[0] guarantees pair[1]
	for pair in rd.get("vassals", []):
		if _has2(s, pair):
			DiplomacySystem.make_vassal(s, pair[0], pair[1], false)
	for o in rd.get("opinions", []):
		if o.size() >= 3 and _has2(s, o):
			GS.add_opinion(s, o[0], o[1], float(o[2]))
	for w in rd.get("wars", []):
		var atk: Array = []
		var dfn: Array = []
		for a in w.get("attackers", []):
			if s["countries"].has(a):
				atk.append(a)
		for d in w.get("defenders", []):
			if s["countries"].has(d):
				dfn.append(d)
		if not atk.is_empty() and not dfn.is_empty():
			DiplomacySystem.start_war(s, atk, dfn, str(w.get("cb", "conquest")), w.get("goals", []), true)
	for t in rd.get("truces", []):
		if _has2(s, t):
			GS.rel(s, t[0], t[1])["truce_until"] = int(t[2])

static func _has2(s: Dictionary, pair: Array) -> bool:
	return pair.size() >= 2 and s["countries"].has(pair[0]) and s["countries"].has(pair[1]) and pair[0] != pair[1]

## Returns a list of error strings (empty when the scenario is valid). Used by tests and the editor.
static func validate(def_in: Dictionary) -> Array:
	var def := MapUpgrade.prepare(def_in)
	var errs: Array = []
	if not def.has("id"):
		errs.append("ERR_SC_NO_ID")
	if not def.has("start"):
		errs.append("ERR_SC_NO_START")
	var cd: Dictionary = def.get("countries", {})
	if cd.is_empty():
		errs.append("ERR_SC_NO_COUNTRIES")
	var seen := {}
	for cid in cd:
		var c: Dictionary = cd[cid]
		if not Defs.governments.has(c.get("gov", "feudal_kingdom")):
			errs.append("ERR_SC_BAD_GOV:" + cid)
		if not c.has("name"):
			errs.append("ERR_SC_NO_NAME:" + cid)
		var n_own := 0
		for pat in c.get("provinces", []):
			var pstr := str(pat)
			if pstr.begins_with("-"):
				continue
			var hit := false
			for pid in Defs.province_ids:
				if Util.glob_match(pstr, pid):
					hit = true
					if seen.has(pid) and seen[pid] != cid:
						pass  # later entries override earlier ones; allowed
					seen[pid] = cid
					n_own += 1
			if not hit:
				errs.append("ERR_SC_BAD_PROVINCE:%s:%s" % [cid, pstr])
		if c.get("capital", "") != "" and not Defs.provinces.has(c["capital"]):
			errs.append("ERR_SC_BAD_CAPITAL:" + cid)
		for ad in c.get("armies", []):
			if not Defs.provinces.has(ad.get("loc", "")):
				errs.append("ERR_SC_BAD_ARMY_LOC:" + cid)
			for uid in ad.get("units", {}):
				if not Defs.units.has(uid):
					errs.append("ERR_SC_BAD_UNIT:%s:%s" % [cid, uid])
	# every country must own at least one province after overrides
	var owned_count := {}
	for pid in seen:
		owned_count[seen[pid]] = int(owned_count.get(seen[pid], 0)) + 1
	for cid in cd:
		if int(owned_count.get(cid, 0)) == 0:
			errs.append("ERR_SC_EMPTY_COUNTRY:" + cid)
		var cp: String = cd[cid].get("capital", "")
		if cp != "" and seen.get(cp, "") != cid:
			errs.append("ERR_SC_CAPITAL_NOT_OWNED:" + cid)
	for pid in def.get("province_names", {}):
		var nd: Variant = def["province_names"][pid]
		if not Defs.provinces.has(pid) or not (nd is Dictionary) or str(nd.get("en", "")) == "" or str(nd.get("tr", "")) == "":
			errs.append("ERR_SC_BAD_NAME:" + str(pid))
	for ccid in def.get("claims", {}):
		if not cd.has(ccid):
			errs.append("ERR_SC_CLAIM_UNKNOWN_COUNTRY:" + str(ccid))
		for pat in def["claims"][ccid]:
			var hit_claim := false
			for pid in Defs.province_ids:
				if Util.glob_match(str(pat).lstrip("-"), pid):
					hit_claim = true
					break
			if not hit_claim:
				errs.append("ERR_SC_BAD_CLAIM:%s:%s" % [ccid, str(pat)])
	var rd: Dictionary = def.get("relations", {})
	for key in ["alliances", "defensive", "nap", "access", "trade", "vassals", "guarantees"]:
		for pair in rd.get(key, []):
			for x in [pair[0], pair[1]]:
				if not cd.has(x):
					errs.append("ERR_SC_REL_UNKNOWN:%s:%s" % [key, x])
	for w in rd.get("wars", []):
		for x in w.get("attackers", []) + w.get("defenders", []):
			if not cd.has(x):
				errs.append("ERR_SC_REL_UNKNOWN:wars:" + str(x))
	return errs
