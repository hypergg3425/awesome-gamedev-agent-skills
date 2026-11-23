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
var load_errors: Array[String] = []
var loaded := false

func _ready() -> void:
	load_all()

func load_all() -> void:
	if loaded:
		return
	load_errors.clear()
	var plist: Variant = _read_json("res://data/map/provinces.json")
	if plist is Array:
		var i := 0
		for p in plist:
			var d: Dictionary = p
			provinces[d["id"]] = d
			province_ids.append(d["id"])
			province_index[d["id"]] = i
			i += 1
	units = _read_dict("res://data/units.json")
	buildings = _read_dict("res://data/buildings.json")
	var t := _read_dict("res://data/technologies.json")
	techs = t.get("techs", {})
	tech_lines = t.get("lines", {})
	governments = _read_dict("res://data/governments.json")
	reforms = _read_dict("res://data/reforms.json")
	gov_transitions = _read_dict("res://data/government_transitions.json")
	map_meta = _read_dict("res://data/map/map_meta.json")
	var sl: Variant = _read_json("res://data/map/seas.json")
	if sl is Array:
		seas = sl
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
		geometry.load_file("res://data/map/geometry.bin", province_ids.size())
	return geometry

## --- accessors -----------------------------------------------------------------------------
func province(pid: String) -> Dictionary:
	return provinces.get(pid, {})

func country_def(cid: String) -> Dictionary:
	return countries.get(cid, {})

func province_name(pid: String) -> String:
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
