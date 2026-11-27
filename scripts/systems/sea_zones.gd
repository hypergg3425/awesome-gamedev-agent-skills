class_name SeaZones
extends RefCounted
## Sea zones: every coastal province belongs to one named sea (a zone) and every sea passage (lane / strait link)
## joins two zones. Fleets stay on the province graph (they move along the sea links between coastal provinces, one
## hop per transit, never teleporting); zones give the regional view used for sea control, raiding and convoys.
## Zone ids are "sea_<index>" into Defs.seas. A map set may ship <map dir>/sea_zones.json
## {"zones": {"<id>": {"name": {"en","tr"}, "provinces": [pid, ...]}}} to override the nearest-sea assignment.

static var _key := ""
static var _zone: Dictionary = {}       # pid -> zone id
static var _members: Dictionary = {}    # zone id -> Array of pids
static var _adj: Dictionary = {}        # zone id -> Array of neighbouring zone ids
static var _names: Dictionary = {}      # zone id -> {"en","tr"}

static func reset() -> void:
	_key = ""

static func _ensure() -> void:
	var key := GeoFeatures.map_dir() + ":" + str(Defs.province_ids.size()) + ":" + str(Defs.seas.size())
	if key == _key:
		return
	_key = key
	_zone = {}
	_members = {}
	_adj = {}
	_names = {}
	var override := _load_override()
	if override.is_empty():
		for i in Defs.seas.size():
			_names["sea_%d" % i] = {"en": str(Defs.seas[i].get("name", "")), "tr": str(Defs.seas[i].get("name_tr", Defs.seas[i].get("name", "")))}
		for pid in Defs.province_ids:
			if bool(Defs.provinces[pid]["coastal"]):
				_assign(pid, _nearest(Defs.provinces[pid]["centroid"]))
	else:
		for zid in override:
			_names[zid] = override[zid].get("name", {"en": zid, "tr": zid})
			for pid in override[zid].get("provinces", []):
				if Defs.provinces.has(pid):
					_assign(str(pid), str(zid))
		for pid in Defs.province_ids:
			if bool(Defs.provinces[pid]["coastal"]) and not _zone.has(pid) and not _names.is_empty():
				_assign(pid, str(_names.keys()[0]))
	for zid in _names:
		if not _members.has(zid):
			_members[zid] = []
		_adj[zid] = []
	for pid in _zone:
		for sl in Defs.sea_links(pid):
			var z2 := lane_zone(pid, str(sl[0]))
			if z2 != "" and z2 != _zone[pid] and z2 not in _adj[_zone[pid]]:
				(_adj[_zone[pid]] as Array).append(z2)
			var zo: String = _zone.get(str(sl[0]), "")
			if zo != "" and zo != _zone[pid] and zo not in _adj[_zone[pid]]:
				(_adj[_zone[pid]] as Array).append(zo)

static func _load_override() -> Dictionary:
	var path := GeoFeatures.map_dir() + "/sea_zones.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and (parsed as Dictionary).get("zones") is Dictionary:
		return parsed["zones"]
	return {}

static func _assign(pid: String, zid: String) -> void:
	_zone[pid] = zid
	if not _members.has(zid):
		_members[zid] = []
	(_members[zid] as Array).append(pid)

static func _nearest(pt: Array) -> String:
	var best := 0
	var bd := 1e18
	for i in Defs.seas.size():
		var sp: Array = Defs.seas[i]["pos"]
		var d := Vector2(float(pt[0]) - float(sp[0]), float(pt[1]) - float(sp[1])).length() / pow(maxf(float(Defs.seas[i].get("size", 5.0)), 1.0), 0.5)
		if d < bd:
			bd = d
			best = i
	return "sea_%d" % best

static func zone_of(pid: String) -> String:
	_ensure()
	return str(_zone.get(pid, ""))

## Zone of the open water between two linked provinces (the nearer end decides, the first on ties).
static func lane_zone(a: String, b: String) -> String:
	_ensure()
	var za: String = _zone.get(a, "")
	var zb: String = _zone.get(b, "")
	if za == "" or za == zb:
		return za if za != "" else zb
	if zb == "":
		return za
	# open water: the sea whose centre is closest to the midpoint of the passage
	var ca: Array = Defs.provinces[a]["centroid"]
	var cb: Array = Defs.provinces[b]["centroid"]
	var mid := [(float(ca[0]) + float(cb[0])) * 0.5, (float(ca[1]) + float(cb[1])) * 0.5]
	var zm := _nearest(mid) if _names.has(_nearest(mid)) else za
	return zm

static func zone_ids() -> Array:
	_ensure()
	var out: Array = _names.keys()
	out.sort()
	return out

static func members(zid: String) -> Array:
	_ensure()
	return _members.get(zid, [])

static func neighbors(zid: String) -> Array:
	_ensure()
	return _adj.get(zid, [])

static func connected(a: String, b: String) -> bool:
	return a == b or b in neighbors(a)

static func zone_name(zid: String) -> String:
	_ensure()
	return Loc.tx(_names.get(zid, {"en": zid, "tr": zid}))

## Zone a fleet currently occupies: its port's zone, or the lane it is sailing on.
static func zone_of_fleet(a: Dictionary) -> String:
	if str(a.get("loc", "")) != "":
		return zone_of(a["loc"])
	var tr: Variant = a.get("transit")
	if tr is Dictionary:
		return lane_zone(str(tr.get("from", "")), str(tr.get("to", "")))
	return ""
