class_name GS
extends RefCounted
## Game-state helpers. The state is a plain Dictionary (JSON-serialisable) so saving, AI cloning
## and tests are trivial. Derived caches live under state["_c"] and are never saved.

static func new_state() -> Dictionary:
	return {
		"version": Const.SAVE_VERSION, "scenario": "", "turn": 0, "start_year": 1066, "start_month": 1,
		"turn_limit": 0, "player": "", "players": [], "difficulty": "normal", "seed": 1, "rng": {},
		"countries": {}, "provinces": {}, "armies": {}, "next_army_id": 1, "wars": {}, "next_war_id": 1,
		"relations": {}, "coalitions": {}, "next_coalition_id": 1, "market": {}, "events": {"pending": [], "fired": {}, "queue": []},
		"history": [], "notes": [], "objectives": [], "winner": "", "victory_type": "", "game_over": false, "stats": {},
		"flags": {}, "ai": {}, "custom": false, "approximate": true, "pending_requests": [], "battle_log": [], "_c": {},
	}

static func country(s: Dictionary, cid: String) -> Dictionary:
	return s["countries"].get(cid, {})

static func prov(s: Dictionary, pid: String) -> Dictionary:
	return s["provinces"].get(pid, {})

static func alive_countries(s: Dictionary) -> Array:
	var out: Array = []
	for cid in s["countries"]:
		if s["countries"][cid].get("alive", false) and cid != "REB":
			out.append(cid)
	out.sort()
	return out

## --- derived caches ------------------------------------------------------------------------
static func rebuild_caches(s: Dictionary) -> void:
	var owned := {}
	var ctrl := {}
	for cid in s["countries"]:
		owned[cid] = []
		ctrl[cid] = []
	for pid in s["provinces"]:
		var p: Dictionary = s["provinces"][pid]
		var o: String = p.get("owner", "")
		if o != "" and owned.has(o):
			owned[o].append(pid)
		var c: String = p.get("controller", o)
		if c != "" and ctrl.has(c):
			ctrl[c].append(pid)
	for cid in owned:
		(owned[cid] as Array).sort()
		(ctrl[cid] as Array).sort()
	var armies_at := {}
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		var loc: String = a.get("loc", "")
		if not armies_at.has(loc):
			armies_at[loc] = []
		armies_at[loc].append(aid)
	var old_rng: Variant = s["_c"].get("rng") if s.has("_c") else null
	s["_c"] = {"owned": owned, "controlled": ctrl, "armies_at": armies_at, "mods": {}, "mods_turn": -1}
	if old_rng != null:
		s["_c"]["rng"] = old_rng

static func owned(s: Dictionary, cid: String) -> Array:
	var c: Dictionary = s["_c"]
	if c.is_empty():
		rebuild_caches(s)
		c = s["_c"]
	return c["owned"].get(cid, [])

static func controlled(s: Dictionary, cid: String) -> Array:
	if s["_c"].is_empty():
		rebuild_caches(s)
	return s["_c"]["controlled"].get(cid, [])

static func armies_at(s: Dictionary, pid: String) -> Array:
	if s["_c"].is_empty():
		rebuild_caches(s)
	return s["_c"]["armies_at"].get(pid, [])

static func armies_of(s: Dictionary, cid: String) -> Array:
	var out: Array = []
	for aid in s["armies"]:
		if s["armies"][aid]["owner"] == cid:
			out.append(aid)
	out.sort()
	return out

static func invalidate_mods(s: Dictionary) -> void:
	if not s["_c"].is_empty():
		s["_c"]["mods"] = {}
		s["_c"].erase("pcalc")
		s["_c"].erase("admin_cap")

static func set_owner(s: Dictionary, pid: String, cid: String, also_controller: bool = true) -> void:
	var p: Dictionary = s["provinces"][pid]
	p["owner"] = cid
	if also_controller:
		p["controller"] = cid
	p["siege"] = null
	rebuild_caches(s)

static func move_army_cache(s: Dictionary, aid: String, from: String, to: String) -> void:
	var c: Dictionary = s["_c"]
	if c.is_empty():
		return
	var at: Dictionary = c["armies_at"]
	if at.has(from):
		(at[from] as Array).erase(aid)
	if not at.has(to):
		at[to] = []
	if not (at[to] as Array).has(aid):
		at[to].append(aid)

## --- date ----------------------------------------------------------------------------------
static func date_of(s: Dictionary, turn: int = -1) -> Dictionary:
	var t := int(s["turn"]) if turn < 0 else turn
	var months := (int(s["start_month"]) - 1) + t * Const.MONTHS_PER_TURN
	var year := int(s["start_year"]) + months / 12
	var m := months % 12 + 1
	return {"year": year, "month": m, "season": ((m % 12) / 3)}  # 0 spring? see season_idx()

## 0=spring,1=summer,2=autumn,3=winter for northern hemisphere month m (1..12)
static func season_idx(month: int) -> int:
	if month in [3, 4, 5]:
		return 0
	if month in [6, 7, 8]:
		return 1
	if month in [9, 10, 11]:
		return 2
	return 3

static func date_string(s: Dictionary) -> String:
	var d := date_of(s)
	var months: Array = Loc.t("MONTHS").split(",")
	var mi: int = int(d["month"]) - 1
	var mname: String = months[mi] if months.size() == 12 else str(d["month"])
	var yr := int(d["year"])
	var yrs := str(yr) if yr > 0 else str(-yr) + " BC"
	return "%s %s" % [mname, yrs]

## --- logging -------------------------------------------------------------------------------
static func note(s: Dictionary, cid: String, cat: String, key: String, params: Dictionary = {}, pid: String = "") -> void:
	## Notifications are kept for every country but only trimmed; UI shows the player's.
	var arr: Array = s["notes"]
	arr.append({"turn": s["turn"], "cid": cid, "cat": cat, "key": key, "params": params, "pid": pid})
	if arr.size() > 400:
		arr.pop_front()

static func history(s: Dictionary, cid: String, type: String, key: String, params: Dictionary = {}) -> void:
	var arr: Array = s["history"]
	arr.append({"turn": s["turn"], "cid": cid, "type": type, "key": key, "params": params})
	if arr.size() > 1500:
		arr.pop_front()

static func stat_add(s: Dictionary, cid: String, key: String, v: float = 1.0) -> void:
	var c: Dictionary = s["countries"].get(cid, {})
	if c.is_empty():
		return
	var st: Dictionary = c["stats"]
	st[key] = float(st.get(key, 0.0)) + v

## --- naming helpers ------------------------------------------------------------------------
static func country_name(s: Dictionary, cid: String) -> String:
	var c: Dictionary = s["countries"].get(cid, {})
	if c.is_empty():
		return cid
	var nm: Variant = c.get("name", null)
	if nm != null:
		return Loc.tx(nm)
	return cid

static func rng_of(s: Dictionary) -> GameRng:
	if not s["_c"].has("rng"):
		var r := GameRng.new(int(s["seed"]))
		if not (s["rng"] as Dictionary).is_empty():
			r.set_state(s["rng"])
		s["_c"]["rng"] = r
	return s["_c"]["rng"]

static func save_rng(s: Dictionary) -> void:
	if s["_c"].has("rng"):
		s["rng"] = (s["_c"]["rng"] as GameRng).get_state()

## War helpers ------------------------------------------------------------------------------
static func at_war(s: Dictionary, a: String, b: String) -> bool:
	if a == b:
		return false
	if a == "REB" or b == "REB":
		return true
	for wid in s["wars"]:
		var w: Dictionary = s["wars"][wid]
		if w.get("ended", false):
			continue
		if (a in w["attackers"] and b in w["defenders"]) or (b in w["attackers"] and a in w["defenders"]):
			return true
	return false

static func wars_of(s: Dictionary, cid: String) -> Array:
	var out: Array = []
	for wid in s["wars"]:
		var w: Dictionary = s["wars"][wid]
		if not w.get("ended", false) and (cid in w["attackers"] or cid in w["defenders"]):
			out.append(wid)
	return out

static func enemies_of(s: Dictionary, cid: String) -> Array:
	var out: Array = []
	for wid in wars_of(s, cid):
		var w: Dictionary = s["wars"][wid]
		var foes: Array = w["defenders"] if cid in w["attackers"] else w["attackers"]
		for f in foes:
			if f not in out and s["countries"].get(f, {}).get("alive", false):
				out.append(f)
	return out

static func rel_key(a: String, b: String) -> String:
	return Util.pair_key(a, b)

static func rel(s: Dictionary, a: String, b: String) -> Dictionary:
	var k := Util.pair_key(a, b)
	var rels: Dictionary = s["relations"]
	if not rels.has(k):
		rels[k] = {"op": {a: 0.0, b: 0.0}, "trust": 50.0, "alliance": false, "defensive": false, "nap_until": -1,
			"access": {a: false, b: false}, "trade": false, "guarantee": {a: false, b: false}, "overlord": "",
			"truce_until": -1, "sanction": {a: false, b: false}, "improving": {a: 0, b: 0}, "wars_fought": 0, "gifted": 0.0,
			"embargo": {a: false, b: false}, "last_action": {}}
	return rels[k]

static func opinion(s: Dictionary, from: String, to: String) -> float:
	return float(rel(s, from, to)["op"].get(from, 0.0))

static func add_opinion(s: Dictionary, from: String, to: String, v: float) -> void:
	var r := rel(s, from, to)
	r["op"][from] = clampf(float(r["op"].get(from, 0.0)) + v, Const.OPINION_MIN, Const.OPINION_MAX)

static func allied(s: Dictionary, a: String, b: String) -> bool:
	return a != b and bool(rel(s, a, b)["alliance"])

static func overlord_of(s: Dictionary, cid: String) -> String:
	return str(s["countries"].get(cid, {}).get("overlord", ""))

static func vassals_of(s: Dictionary, cid: String) -> Array:
	var out: Array = []
	for oid in s["countries"]:
		var c: Dictionary = s["countries"][oid]
		if c.get("alive", false) and c.get("overlord", "") == cid:
			out.append(oid)
	return out

## Round every float in the state to a 1e-6 grid. Applied at the end of each turn and right after
## loading a save, so that JSON float round-trips (which can differ in the last bit) can never make
## a restored campaign diverge from an uninterrupted one.
static func quantize(v: Variant) -> Variant:
	if v is float:
		return snappedf(v, 0.000001)
	if v is Dictionary:
		var d: Dictionary = v
		for k in d:
			var x: Variant = d[k]
			if x is float:
				var q := snappedf(x, 0.000001)
				if q != x:
					d[k] = q
			elif x is Dictionary or x is Array:
				if k != "_c":
					quantize(x)
		return d
	if v is Array:
		var a: Array = v
		for i in a.size():
			var x: Variant = a[i]
			if x is float:
				var q := snappedf(x, 0.000001)
				if q != x:
					a[i] = q
			elif x is Dictionary or x is Array:
				quantize(x)
		return a
	return v
