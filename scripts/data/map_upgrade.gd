class_name MapUpgrade
extends RefCounted
## Map-set selection and automatic upgrade of scenarios authored on the classic 410-province map.
## A scenario without a "map_set" field is authored on classic ids and runs on Defs.default_map_set; when that
## is "extended" every province reference (ownership patterns, capitals, armies, claims, overrides,
## objectives) is expanded through data/map600/parents.json: all children of a parent inherit its owner,
## claims, religion/culture overrides and dev tweaks; single-province references (capital, army location)
## go to the parent's core child (first entry). A scenario with "map_set": "extended" is used verbatim.

const MAP_SET_FIELD := "map_set"
const MARK := "_map_upgraded"

static var _cache: Dictionary = {}

## Returns the scenario def to use. Switches Defs to the scenario's map set first. Idempotent.
static func prepare(def: Dictionary) -> Dictionary:
	if def.has(MARK):
		Defs.use_map_set(str(def[MARK]))
		return def
	var target := str(def.get(MAP_SET_FIELD, Defs.default_map_set))
	if not Defs.MAP_DIRS.has(target):
		target = Defs.default_map_set
	Defs.use_map_set(target)
	var authored := str(def.get(MAP_SET_FIELD, "classic"))
	if authored == target:
		return def
	if authored == "classic" and target == "extended":
		var key := "%s|%d" % [str(def.get("id", "")), hash(JSON.stringify(def))]
		if not _cache.has(key):
			_cache[key] = upgrade_def(def)
		return _cache[key]
	return def

## Children of a classic id on the extended map ([] when the id is unknown).
static func children_of(pid: String) -> Array:
	return Defs.parents.get(pid, [])

static func core_of(pid: String) -> String:
	var kids: Array = Defs.parents.get(pid, [])
	return str(kids[0]) if not kids.is_empty() else pid

## Expands one classic pattern ("fra_*", "-gbr_ulster", "tur_bithynia") into extended ids (keeps a leading "-").
static func expand_pattern(pat: String) -> Array:
	var neg := pat.begins_with("-")
	var body := pat.substr(1) if neg else pat
	var out: Array = []
	for parent in Defs.parents:
		if Util.glob_match(body, str(parent)):
			for kid in Defs.parents[parent]:
				out.append(("-" if neg else "") + str(kid))
	return out

## Number of classic provinces matched by the patterns minus negations, and of extended ones (objective scaling).
static func _scale_of(pats: Array) -> float:
	var classic := {}
	var extended := {}
	for p in pats:
		var pstr := str(p)
		var neg := pstr.begins_with("-")
		var body := pstr.substr(1) if neg else pstr
		for parent in Defs.parents:
			if Util.glob_match(body, str(parent)):
				if neg:
					classic.erase(parent)
					for kid in Defs.parents[parent]:
						extended.erase(kid)
				else:
					classic[parent] = true
					for kid in Defs.parents[parent]:
						extended[kid] = true
	return float(extended.size()) / float(maxi(classic.size(), 1))

static func _expand_list(pats: Array) -> Array:
	var out: Array = []
	for p in pats:
		var e := expand_pattern(str(p))
		out.append_array(e if not e.is_empty() else [p])
	return out

static func upgrade_def(def: Dictionary) -> Dictionary:
	var d: Dictionary = def.duplicate(true)
	d[MARK] = "extended"
	d[MAP_SET_FIELD] = "extended"
	var cds: Dictionary = d.get("countries", {})
	for cid in cds:
		var c: Dictionary = cds[cid]
		if c.has("provinces"):
			c["provinces"] = _expand_list(c["provinces"])
		if str(c.get("capital", "")) != "":
			c["capital"] = core_of(str(c["capital"]))
		for ad in c.get("armies", []):
			ad["loc"] = core_of(str(ad.get("loc", "")))
	for key in ["religion_overrides", "culture_overrides"]:
		var ov: Dictionary = d.get(key, {})
		for k in ov:
			ov[k] = _expand_list(ov[k])
	if d.has("province_dev"):
		var nd := {}
		for pat in d["province_dev"]:
			for kid in expand_pattern(str(pat)):
				nd[kid] = d["province_dev"][pat]
			if expand_pattern(str(pat)).is_empty():
				nd[pat] = d["province_dev"][pat]
		d["province_dev"] = nd
	var cl: Dictionary = d.get("claims", {})
	for cid in cl:
		cl[cid] = _expand_list(cl[cid])
	for ob in d.get("objectives", []):
		var o: Dictionary = ob
		if o.has("provinces") and o["provinces"] is Array:
			var pats: Array = o["provinces"]
			var ratio := _scale_of(pats)
			o["provinces"] = _expand_list(pats)
			if o.has("count"):
				o["count"] = maxi(1, int(ceil(float(o["count"]) * ratio)))
		elif str(o.get("type", "")) == "provinces_count" and o.has("count"):
			o["count"] = int(ceil(float(o["count"]) * float(Defs.province_ids.size()) / float(maxi(Defs.parents.size(), 1))))
		if str(o.get("province", "")) != "":
			o["province"] = core_of(str(o["province"]))
	return d
