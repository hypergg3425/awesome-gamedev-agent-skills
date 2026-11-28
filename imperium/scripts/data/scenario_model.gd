class_name ScenarioModel
extends RefCounted
## Headless model of a scenario under construction (used by the scenario editor UI and by tests). Holds the scenario
## definition (docs/SCENARIO_SCHEMA.md) plus an explicit province -> owner table; patterns are expanded on load and
## written back as explicit province lists on export. Province ids are those of the active map set (`Defs.map_set`),
## which is written to the `map_set` field on export.

const CUSTOM_DIR := "user://custom_scenarios"

var def: Dictionary = {}
var owners: Dictionary = {}     # province id -> country tag

static func blank() -> ScenarioModel:
	var m := ScenarioModel.new()
	m.def = {"id": "custom_%d" % (int(Time.get_unix_time_from_system()) % 100000), "name": {"en": "My Scenario", "tr": "Senaryom"}, "desc": {"en": "A custom scenario.", "tr": "Özel bir senaryo."},
		"note": {"en": "Custom scenario created in the editor.", "tr": "Düzenleyicide oluşturulmuş özel senaryo."}, "start": {"year": 1500, "month": 1}, "turn_limit": 200,
		"era": 2, "approximate": true, "native_fallback": true, "countries": {}, "relations": {}, "objectives": [], "events": [], "default_player": "", "custom": true}
	var ids: Array = Defs.province_ids
	var a: Array = []
	var b: Array = []
	for pid in ["fra_ile_de_france", "fra_normandy", "fra_picardy", "fra_champagne"]:
		if Defs.provinces.has(pid):
			a.append(pid)
	for pid in ["deu_rhineland", "deu_lower_saxony", "deu_hesse_thuringia"]:
		if Defs.provinces.has(pid):
			b.append(pid)
	if a.is_empty() or b.is_empty():
		a = ids.slice(0, 4)
		b = ids.slice(4, 7)
	m.add_country("Kingdom A", "A Krallığı", Color("b8242b"), a, a[0])
	m.add_country("Kingdom B", "B Krallığı", Color("2b5fb8"), b, b[0])
	m.def["default_player"] = m.def["countries"].keys()[0]
	return m

static func from_def(d: Dictionary) -> ScenarioModel:
	var m := ScenarioModel.new()
	m.def = d.duplicate(true)
	m.def["custom"] = true
	for k in ["relations", "countries"]:
		if not m.def.has(k):
			m.def[k] = {}
	for k in ["objectives", "events"]:
		if not m.def.has(k):
			m.def[k] = []
	# expand glob patterns into the explicit ownership table
	for cid in m.def["countries"]:
		for pat in m.def["countries"][cid].get("provinces", []):
			var ps := str(pat)
			var neg := ps.begins_with("-")
			if neg:
				ps = ps.substr(1)
			for pid in Defs.province_ids:
				if Util.glob_match(ps, pid):
					if neg:
						if m.owners.get(pid, "") == cid:
							m.owners.erase(pid)
					else:
						m.owners[pid] = cid
	return m

func default_brush() -> String:
	var b := str(def.get("default_player", ""))
	if b == "" and not def["countries"].is_empty():
		b = def["countries"].keys()[0]
	return b

## --- countries -----------------------------------------------------------------------------------------------
func add_country(en: String, tr: String, col: Color, provs: Array, capital: String) -> String:
	var n: int = (def["countries"] as Dictionary).size() + 1
	var tag := "C%02d" % n
	while def["countries"].has(tag):
		n += 1
		tag = "C%02d" % n
	var hex := "#" + col.to_html(false)
	def["countries"][tag] = {"name": {"en": en, "tr": tr}, "short": {"en": en, "tr": tr}, "color": hex, "flag": {"p": "hstripes", "c": [hex, "#f2f2f2"], "charge": "star"},
		"culture": "latin", "religion": "catholic", "gov": "feudal_kingdom", "ruler": {"name": "Ruler", "adm": 5, "dip": 5, "mil": 5, "age": 35, "dynasty": ""},
		"capital": capital, "provinces": provs.duplicate(), "civ": "average", "military": "medium", "ai": "opportunistic", "playable": true}
	for p in provs:
		owners[p] = tag
	return tag

func remove_country(tag: String) -> void:
	for pid in owners.keys():
		if owners[pid] == tag:
			owners.erase(pid)
	def["countries"].erase(tag)
	drop_relations(tag)
	if def.get("default_player", "") == tag:
		def["default_player"] = default_brush()

func set_field(tag: String, field: String, value: Variant) -> void:
	def["countries"][tag][field] = value

func set_name(tag: String, en: String, tr: String) -> void:
	var c: Dictionary = def["countries"][tag]
	c["name"] = {"en": en, "tr": tr}
	c["short"] = {"en": en, "tr": tr}

func set_color(tag: String, col: Color) -> void:
	var c: Dictionary = def["countries"][tag]
	c["color"] = "#" + col.to_html(false)
	if c["flag"].get("c") is Array and (c["flag"]["c"] as Array).size() > 0:
		c["flag"]["c"][0] = c["color"]

func set_ruler(tag: String, name: String, adm: int, dip: int, mil: int) -> void:
	var r: Dictionary = def["countries"][tag]["ruler"]
	r["name"] = name
	r["adm"] = clampi(adm, 1, 9)
	r["dip"] = clampi(dip, 1, 9)
	r["mil"] = clampi(mil, 1, 9)

func set_treasury(tag: String, gold: float) -> void:
	def["countries"][tag]["treasury"] = maxf(0.0, gold)

func set_stability(tag: String, v: float) -> void:
	def["countries"][tag]["stability"] = clampf(v, 0.0, 100.0)

func set_regiments(tag: String, n: int, unit: String = "spearmen") -> void:
	var c: Dictionary = def["countries"][tag]
	var loc := str(c.get("capital", ""))
	c["armies"] = [] if n <= 0 or loc == "" else [{"loc": loc, "units": {unit: float(n)}}]

func add_army(tag: String, loc: String, units: Dictionary) -> void:
	var c: Dictionary = def["countries"][tag]
	if not c.has("armies"):
		c["armies"] = []
	(c["armies"] as Array).append({"loc": loc, "units": units.duplicate()})

func regiments(tag: String) -> int:
	var c: Dictionary = def["countries"][tag]
	var n := 0
	for a in c.get("armies", []):
		for u in a["units"]:
			n += int(a["units"][u])
	return n if c.has("armies") else int({"low": 6, "medium": 10, "high": 18}.get(str(c.get("military", "medium")), 10))

## --- provinces -----------------------------------------------------------------------------------------------
func assign(pid: String, tag: String) -> void:
	var prev: String = owners.get(pid, "")
	if prev == tag:
		return
	if tag == "":
		owners.erase(pid)
	else:
		owners[pid] = tag
	if prev != "" and def["countries"].has(prev) and def["countries"][prev].get("capital", "") == pid:
		def["countries"][prev]["capital"] = ""
		for p2 in owners:
			if owners[p2] == prev:
				def["countries"][prev]["capital"] = p2
				break
	if tag != "" and def["countries"][tag].get("capital", "") == "":
		def["countries"][tag]["capital"] = pid

func provinces_of(tag: String) -> Array:
	var out: Array = []
	for pid in owners:
		if owners[pid] == tag:
			out.append(pid)
	out.sort()
	return out

## Historical / regional name valid at the scenario date (province_names layer).
func set_province_name(pid: String, en: String, tr: String) -> void:
	if not def.has("province_names"):
		def["province_names"] = {}
	if en == "" and tr == "":
		(def["province_names"] as Dictionary).erase(pid)
	else:
		def["province_names"][pid] = {"en": en if en != "" else tr, "tr": tr if tr != "" else en}

## --- diplomacy, dates, objectives, events ------------------------------------------------------------------------
func add_relation(kind: String, a: String, b: String) -> void:
	var rd: Dictionary = def["relations"]
	if kind == "wars":
		if not rd.has("wars"):
			rd["wars"] = []
		rd["wars"].append({"attackers": [a], "defenders": [b], "cb": "conquest", "goals": []})
		return
	if not rd.has(kind):
		rd[kind] = []
	rd[kind].append([a, b])

func set_opinion(a: String, b: String, v: int) -> void:
	if not def["relations"].has("opinions"):
		def["relations"]["opinions"] = []
	def["relations"]["opinions"].append([a, b, clampi(v, -200, 200)])

func drop_relations(tag: String) -> void:
	var rd: Dictionary = def["relations"]
	for key in rd.keys():
		var arr: Array = rd[key]
		for i in range(arr.size() - 1, -1, -1):
			var e: Variant = arr[i]
			if e is Dictionary:
				if tag in e.get("attackers", []) or tag in e.get("defenders", []):
					arr.remove_at(i)
			elif tag in e:
				arr.remove_at(i)

func set_dates(year: int, month: int, turn_limit: int) -> void:
	def["start"] = {"year": year, "month": clampi(month, 1, 12)}
	def["turn_limit"] = turn_limit

func add_objective(o: Dictionary) -> void:
	(def["objectives"] as Array).append(o)

func set_events(ids: Array) -> void:
	def["events"] = ids.duplicate()

## --- validation / persistence --------------------------------------------------------------------------------------
func sync() -> void:
	for tag in def["countries"]:
		var c: Dictionary = def["countries"][tag]
		c["provinces"] = provinces_of(tag)
		if c.get("capital", "") != "" and c["capital"] not in c["provinces"]:
			c["capital"] = c["provinces"][0] if not (c["provinces"] as Array).is_empty() else ""
		for a in c.get("armies", []):
			a["loc"] = c.get("capital", a["loc"])

func validate() -> Array:
	sync()
	var errs: Array = ScenarioLoader.validate(export())
	if def["countries"].size() < 2:
		errs.append("ED_ERR_TWO_COUNTRIES")
	if str(def.get("default_player", "")) not in def["countries"]:
		errs.append("ED_ERR_NO_PLAYER")
	var seen := {}
	for t in def["countries"]:
		var nm := str(def["countries"][t]["name"]["en"])
		if nm.strip_edges() == "":
			errs.append("ED_ERR_EMPTY_NAME:" + t)
		if seen.has(nm):
			errs.append("ED_ERR_DUP_NAME:" + nm)
		seen[nm] = true
	for pid in def.get("province_names", {}):
		if not Defs.provinces.has(pid):
			errs.append("ED_ERR_BAD_PROVINCE_NAME:" + str(pid))
	return errs

## The scenario dictionary as written to disk (explicit province lists, map_set recorded).
func export() -> Dictionary:
	sync()
	var out := def.duplicate(true)
	out.erase("custom")
	out["id"] = str(out["id"]).replace(" ", "_")
	out["map_set"] = Defs.map_set
	return out

func save(dir: String = CUSTOM_DIR) -> Dictionary:
	var errs := validate()
	if not errs.is_empty():
		return {"ok": false, "errors": errs}
	DirAccess.make_dir_recursive_absolute(dir)
	var out := export()
	var path := "%s/%s.json" % [dir, out["id"]]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "errors": ["SAVE_ERR_WRITE"]}
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	return {"ok": true, "path": path, "id": out["id"]}

static func load_file(path: String) -> ScenarioModel:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		return null
	var ms := str((d as Dictionary).get("map_set", "classic"))
	Defs.use_map_set(ms)
	return from_def(d)
