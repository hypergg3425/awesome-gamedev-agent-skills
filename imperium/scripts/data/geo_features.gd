class_name GeoFeatures
extends RefCounted
## Rivers and mountain passes between neighbouring provinces. Static, read-only content.
## File: <map dir>/features.json (written by the map workstream); if it is absent the small
## <map dir>/features.sample.json is used so tests and early builds still have data.
## Format: {"rivers": [[pidA, pidB, {"name": "Rhine", "width": 2}], ...], "passes": [[pidA, pidB, {"name": "Brenner"}], ...]}
## River width: 1 stream, 2 large river, 3 great river. Order of the two province ids is irrelevant.

static var _rivers: Dictionary = {}   # pair key -> {"name": String, "width": int}
static var _passes: Dictionary = {}   # pair key -> {"name": String}
static var _loaded_dir := ""
static var _sample := false
static var _river_adj: Dictionary = {}   # pid -> Array of pids across a river

static func map_dir() -> String:
	var d: String = str(Defs.map_dir())
	return d if d != "" else "res://data/map"

## Load (or reload) the data of the active map set. Cheap when already loaded.
static func ensure_loaded() -> void:
	var dir := map_dir()
	if _loaded_dir == dir:
		return
	load_dir(dir)

static func load_dir(dir: String) -> void:
	_rivers = {}
	_passes = {}
	_river_adj = {}
	_sample = false
	_loaded_dir = dir
	var path := dir + "/features.json"
	if not FileAccess.file_exists(path):
		path = dir + "/features.sample.json"
		_sample = true
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		set_data(parsed as Dictionary)

## Replace the data (tests and loaders). Marks the cache as loaded for the active dir.
static func set_data(d: Dictionary) -> void:
	_rivers = {}
	_passes = {}
	_river_adj = {}
	_loaded_dir = map_dir()
	for r in d.get("rivers", []):
		var arr: Array = r
		if arr.size() < 2:
			continue
		var meta: Dictionary = arr[2] if arr.size() > 2 and arr[2] is Dictionary else {}
		var a := str(arr[0])
		var b := str(arr[1])
		_rivers[Util.pair_key(a, b)] = {"name": str(meta.get("name", "")), "width": clampi(int(meta.get("width", 1)), 1, 3)}
		_add_adj(a, b)
		_add_adj(b, a)
	for p in d.get("passes", []):
		var arr2: Array = p
		if arr2.size() < 2:
			continue
		var meta2: Dictionary = arr2[2] if arr2.size() > 2 and arr2[2] is Dictionary else {}
		_passes[Util.pair_key(str(arr2[0]), str(arr2[1]))] = {"name": str(meta2.get("name", ""))}

static func _add_adj(a: String, b: String) -> void:
	if not _river_adj.has(a):
		_river_adj[a] = []
	(_river_adj[a] as Array).append(b)

static func is_sample() -> bool:
	ensure_loaded()
	return _sample

static func river_between(a: String, b: String) -> bool:
	ensure_loaded()
	return _rivers.has(Util.pair_key(a, b))

static func river_width(a: String, b: String) -> int:
	ensure_loaded()
	return int(_rivers.get(Util.pair_key(a, b), {}).get("width", 0))

static func river_name(a: String, b: String) -> String:
	ensure_loaded()
	return str(_rivers.get(Util.pair_key(a, b), {}).get("name", ""))

static func pass_between(a: String, b: String) -> bool:
	ensure_loaded()
	return _passes.has(Util.pair_key(a, b))

static func pass_name(a: String, b: String) -> String:
	ensure_loaded()
	return str(_passes.get(Util.pair_key(a, b), {}).get("name", ""))

## Provinces reachable from pid across a river.
static func river_neighbors(pid: String) -> Array:
	ensure_loaded()
	return _river_adj.get(pid, [])

static func river_count() -> int:
	ensure_loaded()
	return _rivers.size()

static func pass_count() -> int:
	ensure_loaded()
	return _passes.size()
