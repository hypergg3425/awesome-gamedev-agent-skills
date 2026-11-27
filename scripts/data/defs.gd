extends Node
## Static game definitions (autoload "Defs"). Everything here is read-only after load.
## Mutable campaign state lives in the Game state dictionary, never here.

var provinces: Dictionary = {}          # id -> static province dict
var province_ids: Array[String] = []     # ordered like geometry.bin
var province_index: Dictionary = {}      # id -> int
var units: Dictionary = {}
var buildings: Dictionary = {}
var techs: Dictionary = {}
var tech_lines: Dictionary = {}
var governments: Dictionary = {}
var reforms: Dictionary = {}
var gov_transitions: Dictionary = {}
var countries: Dictionary = {}           # country identity definitions
var events: Dictionary = {}              # id -> event def
var scenarios: Dictionary = {}           # id -> scenario def (built-in)
var seas: Array = []
var map_meta: Dictionary = {}
var geometry: MapGeometry = null
var features: Dictionary = {}            # rivers / passes / straits / lakes of the active map set (features.json)
var parents: Dictionary = {}             # extended map only: classic id -> [child ids]; first child = core
var province_scale := 1.0                # provinces per classic province (1.0 classic, ~2.6 extended): normalises per-province counts
var map_set := "classic"                 # active map set: "classic" (data/map) or "extended" (data/map600)
## Default set for scenarios that do not name one. "classic" until every suite passes on "extended";
## override per run with the environment variable IMPERIUM_MAP_SET=extended.
const DEFAULT_MAP_SET := "classic"
const MAP_DIRS := {"classic": "res://data/map", "extended": "res://data/map600"}
var default_map_set := DEFAULT_MAP_SET
signal map_set_changed(set_id: String)
var load_errors: Array[String] = []
var loaded := false
var _game: Node = null                   # cached autoload ref for province_name()

func _ready() -> void:
	var env := OS.get_environment("IMPERIUM_MAP_SET")
	if MAP_DIRS.has(env):
		default_map_set = env
	map_set = default_map_set
	load_all()

func map_dir() -> String:
	return MAP_DIRS[map_set]

## Switches the active map set (provinces, geometry, seas, features). Scenario state built on another set
## must not be used afterwards: ScenarioLoader/SaveManager call this before touching province ids.
func use_map_set(set_id: String) -> void:
	if not MAP_DIRS.has(set_id):
		load_errors.append("unknown map set: " + set_id)
		return
	if set_id == map_set and not provinces.is_empty():
		return
	map_set = set_id
	_load_map()
	map_set_changed.emit(set_id)

func _load_map() -> void:
	provinces = {}
	province_ids.clear()
	province_index = {}
	geometry = null
	var dir := map_dir()
	var plist: Variant = _read_json(dir + "/provinces.json")
	if plist is Array:
		var i := 0
		for p in plist:
			var d: Dictionary = p
			provinces[d["id"]] = d
			province_ids.append(d["id"])
			province_index[d["id"]] = i
			i += 1
	map_meta = _read_dict(dir + "/map_meta.json")
	var sl: Variant = _read_json(dir + "/seas.json")
	seas = sl if sl is Array else []
	features = _read_dict(dir + "/features.json") if FileAccess.file_exists(dir + "/features.json") else {}
	parents = _read_dict(dir + "/parents.json") if FileAccess.file_exists(dir + "/parents.json") else {}
	province_scale = float(province_ids.size()) / float(parents.size()) if not parents.is_empty() else 1.0

func load_all() -> void:
	if loaded:
		return
	load_errors.clear()
	_load_map()
	units = _read_dict("res://data/units.json")
	buildings = _read_dict("res://data/buildings.json")
	var t := _read_dict("res://data/technologies.json")
	techs = t.get("techs", {})
	tech_lines = t.get("lines", {})
	governments = _read_dict("res://data/governments.json")
	reforms = _read_dict("res://data/reforms.json")
	gov_transitions = _read_dict("res://data/government_transitions.json")
	_load_dir_json("res://data/events", events, true)
	_load_dir_json("res://data/scenarios", scenarios, false)
	loaded = true

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		load_errors.append("missing: " + path)
		return null
	var txt := FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	if parser.parse(txt) != OK:
		load_errors.append("parse error %s line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return null
	return parser.data

func _read_dict(path: String) -> Dictionary:
	var v: Variant = _read_json(path)
	return v if v is Dictionary else {}

## Event files contain arrays of events; scenario files one dict each.
func _load_dir_json(dir_path: String, into: Dictionary, as_array: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var v: Variant = _read_json(dir_path + "/" + f)
		if v == null:
			continue
		if as_array:
			if v is Array:
				for e in v:
					into[e["id"]] = e
			else:
				load_errors.append("expected array: " + f)
		elif v is Dictionary:
			into[v.get("id", f.get_basename())] = v

func load_geometry() -> MapGeometry:
	if geometry == null:
		geometry = MapGeometry.new()
		geometry.load_file(map_dir() + "/geometry.bin", province_ids.size())
	return geometry

## --- accessors -----------------------------------------------------------------------------
func province(pid: String) -> Dictionary:
	return provinces.get(pid, {})

func country_def(cid: String) -> Dictionary:
	return countries.get(cid, {})

## Display name of a province. Consults the active campaign's scenario names layer (state["names"],
## historical names for the scenario date) before the modern-geometry name from provinces.json.
func province_name(pid: String) -> String:
	if _game == null:
		_game = get_node_or_null("/root/Game")
	if _game != null and not (_game.state as Dictionary).is_empty():
		return province_name_in(_game.state, pid)
	return _static_province_name(pid)

## Same as province_name but for an explicit state (simulation code, tests, battle reports).
func province_name_in(state: Dictionary, pid: String) -> String:
	var names: Dictionary = state.get("names", {})
	var nd: Variant = names.get(pid)
	if nd is Dictionary:
		var txt := str(nd.get(Loc.lang, ""))
		if txt == "":
			txt = str(nd.get("en", ""))
		if txt != "":
			return txt
	return _static_province_name(pid)

func _static_province_name(pid: String) -> String:
	var p: Dictionary = provinces.get(pid, {})
	if p.is_empty():
		return pid
	return str(p.get("name_tr", p["name"])) if Loc.lang == "tr" and str(p.get("name_tr", "")) != "" else str(p["name"])

func unit_name(uid: String) -> String:
	return Loc.tx(units.get(uid, {}).get("name"))

func building_name(bid: String) -> String:
	return Loc.tx(buildings.get(bid, {}).get("name"))

func tech_name(tid: String) -> String:
	return Loc.tx(techs.get(tid, {}).get("name"))

func gov_name(gid: String) -> String:
	return Loc.tx(governments.get(gid, {}).get("name"))

func neighbors(pid: String) -> Array:
	return provinces.get(pid, {}).get("adj", [])

func sea_links(pid: String) -> Array:
	return provinces.get(pid, {}).get("sea", [])

## All scenario definitions including user-created ones.
func all_scenarios() -> Dictionary:
	var out := scenarios.duplicate()
	var dir := DirAccess.open("user://custom_scenarios")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".json"):
				var v: Variant = _read_json("user://custom_scenarios/" + f)
				if v is Dictionary and v.has("id"):
					v["custom"] = true
					out[v["id"]] = v
	return out
