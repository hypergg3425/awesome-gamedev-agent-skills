extends Node
## Save / load (autoload "Saves"). Atomic writes, backup recovery, checksums, versioned migrations
## and structural validation. Corrupt files are never silently deleted: they are kept as *.corrupt.

const DIR := "user://saves"
const AUTOSLOTS := 3

signal saved(slot: String)
signal load_failed(slot: String, reason: String)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

static func slot_path(slot: String) -> String:
	return "%s/%s.json" % [DIR, slot]

## Strip derived caches so the saved dictionary is pure data.
static func export_state(state: Dictionary) -> Dictionary:
	GS.save_rng(state)
	var copy := state.duplicate(false)
	copy.erase("_c")
	return copy

static func meta_of(state: Dictionary) -> Dictionary:
	return {"scenario": state.get("scenario", ""), "scenario_name": state.get("scenario_name", {}), "player": state.get("player", ""),
		"turn": state.get("turn", 0), "date": "%d-%02d" % [int(GS.date_of(state)["year"]), int(GS.date_of(state)["month"])],
		"difficulty": state.get("difficulty", "normal"), "ts": Time.get_unix_time_from_system(), "version": Const.VERSION,
		"player_name": state.get("countries", {}).get(state.get("player", ""), {}).get("name", {}), "players": state.get("players", [])}

## Test hook: "write" fails opening the temp file, "rename" fails the final move, "truncate" writes half a file.
var test_fail := ""

## Atomic save: write <slot>.json.tmp, read it back and verify, move the previous file to .bak and only then
## move the verified temp file into place. A failure at any stage leaves the previous save untouched.
func save_slot(slot: String, state: Dictionary) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(DIR)
	# full precision + insertion order: a loaded campaign must continue exactly like the original
	var body := JSON.stringify(export_state(state), "", false, true)
	var doc := JSON.stringify({"format": "imperium-save", "version": Const.SAVE_VERSION, "meta": meta_of(state), "crc": body.hash(), "len": body.length(), "state_json": body})
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE) if test_fail != "write" else null
	if f == null:
		return {"ok": false, "reason": "SAVE_ERR_WRITE"}
	f.store_string(doc.substr(0, doc.length() / 2) if test_fail == "truncate" else doc)
	f.close()
	if FileAccess.get_file_as_string(tmp) != doc:
		DirAccess.remove_absolute(tmp)
		return {"ok": false, "reason": "SAVE_ERR_WRITE"}
	var da := DirAccess.open(DIR)
	if da == null or test_fail == "rename":
		DirAccess.remove_absolute(tmp)
		return {"ok": false, "reason": "SAVE_ERR_WRITE"}
	var had_old := FileAccess.file_exists(path)
	if had_old:
		# the old file is only a verified save (it was verified when written), so it becomes the backup
		DirAccess.copy_absolute(path, path + ".bak")
	if da.rename(slot + ".json.tmp", slot + ".json") != OK:
		DirAccess.remove_absolute(tmp)
		return {"ok": false, "reason": "SAVE_ERR_WRITE"}
	saved.emit(slot)
	return {"ok": true}

func autosave(state: Dictionary) -> void:
	var idx := int(state.get("turn", 0)) % AUTOSLOTS + 1
	save_slot("auto_%d" % idx, state)
	save_slot("last", state)

## Cheap safety save used when the app is backgrounded or closed.
func autosave_quick(state: Dictionary) -> Dictionary:
	return save_slot("last", state)

func list_saves() -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var slot := f.get_basename()
		var m := read_meta(slot)
		if not m.is_empty():
			m["slot"] = slot
			out.append(m)
	out.sort_custom(func(a, b): return float(a.get("ts", 0)) > float(b.get("ts", 0)))
	return out

func read_meta(slot: String) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var jp := JSON.new()
	if jp.parse(txt) == OK and jp.data is Dictionary and (jp.data as Dictionary).has("meta"):
		var m: Dictionary = (jp.data as Dictionary)["meta"]
		m["corrupt"] = false
		return m
	return {"corrupt": true, "turn": 0, "ts": 0}

func has_save(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))

func delete_slot(slot: String) -> void:
	var p := slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)
	if FileAccess.file_exists(p + ".bak"):
		DirAccess.remove_absolute(p + ".bak")

## Load with automatic fallback to the backup. Returns {ok, state, recovered, reason}
func load_slot(slot: String) -> Dictionary:
	var res := _load_file(slot_path(slot))
	if res["ok"]:
		res["recovered"] = false
		return res
	var first_reason: String = res.get("reason", "SAVE_ERR_CORRUPT")
	var main := slot_path(slot)
	var bak := _load_file(main + ".bak")
	# keep the broken file for inspection instead of deleting it
	if FileAccess.file_exists(main) and first_reason != "SAVE_ERR_NEWER":
		DirAccess.copy_absolute(main, main + ".corrupt")
		if bak["ok"]:
			# heal the slot so the next load does not need the fallback
			DirAccess.copy_absolute(main + ".bak", main)
	if bak["ok"]:
		bak["recovered"] = true
		return bak
	load_failed.emit(slot, first_reason)
	return {"ok": false, "reason": first_reason}

func _load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "SAVE_ERR_MISSING"}
	var txt := FileAccess.get_file_as_string(path)
	var jp := JSON.new()
	if jp.parse(txt) != OK or not (jp.data is Dictionary) or not (jp.data as Dictionary).has("state_json"):
		return {"ok": false, "reason": "SAVE_ERR_CORRUPT"}
	var parsed: Dictionary = jp.data
	var body: String = parsed["state_json"]
	if int(parsed.get("crc", 0)) != body.hash() or int(parsed.get("len", -1)) != body.length():
		return {"ok": false, "reason": "SAVE_ERR_CHECKSUM"}
	var jp2 := JSON.new()
	if jp2.parse(body) != OK or not (jp2.data is Dictionary):
		return {"ok": false, "reason": "SAVE_ERR_CORRUPT"}
	var st: Variant = jp2.data
	var ver := int(parsed.get("version", int((st as Dictionary).get("version", 1))))
	if ver > Const.SAVE_VERSION:
		return {"ok": false, "reason": "SAVE_ERR_NEWER"}
	var state: Dictionary = st
	state["version"] = ver
	state = migrate(state)
	Defs.use_map_set(str(state.get("map_set", "classic")))
	var errs := validate_state(state)
	if not errs.is_empty():
		return {"ok": false, "reason": "SAVE_ERR_INVALID", "errors": errs}
	NavalSystem.ensure_fields(state)
	GS.quantize(state)
	GS.rebuild_caches(state)
	return {"ok": true, "state": state, "meta": parsed.get("meta", {})}

## --- migrations ----------------------------------------------------------------------------------------
static func migrate(state: Dictionary) -> Dictionary:
	var v := int(state.get("version", 1))
	while v < Const.SAVE_VERSION:
		match v:
			1:
				# v1 -> v2: diplomacy requests, infamy, battle log, truce bookkeeping
				state["pending_requests"] = state.get("pending_requests", [])
				state["battle_log"] = state.get("battle_log", [])
				for cid in state.get("countries", {}):
					var c: Dictionary = state["countries"][cid]
					c["infamy"] = c.get("infamy", 0.0)
					c["war_exhaustion"] = c.get("war_exhaustion", 0.0)
			2:
				# v2 -> v3: coalitions, flags, research bank, class offsets, vassal timing
				state["coalitions"] = state.get("coalitions", {})
				state["next_coalition_id"] = state.get("next_coalition_id", 1)
				state["flags"] = state.get("flags", {})
				for cid in state.get("countries", {}):
					var c2: Dictionary = state["countries"][cid]
					if c2.get("research") is Dictionary:
						c2["research"]["bank"] = c2["research"].get("bank", 0.0)
					c2["class_offsets"] = c2.get("class_offsets", {})
					c2["victory_hold"] = c2.get("victory_hold", {})
			3:
				# v3 -> v4: espionage, dynasties, factions, economy depth
				SimExt.migrate_v4(state)
		v += 1
		state["version"] = v
	return state

## --- structural validation -------------------------------------------------------------------------------
static func validate_state(s: Dictionary) -> Array:
	var errs: Array = []
	for key in ["countries", "provinces", "armies", "wars", "relations", "turn", "player", "market", "events"]:
		if not s.has(key):
			errs.append("missing key " + key)
	if not errs.is_empty():
		return errs
	for pid in Defs.province_ids:
		if not s["provinces"].has(pid):
			errs.append("province missing " + pid)
			continue
		var p: Dictionary = s["provinces"][pid]
		var o: String = p.get("owner", "")
		if o != "" and not s["countries"].has(o):
			errs.append("province %s owner %s unknown" % [pid, o])
		var c: String = p.get("controller", "")
		if c != "" and not s["countries"].has(c):
			errs.append("province %s controller %s unknown" % [pid, c])
		if o != "" and s["countries"].has(o) and not s["countries"][o].get("alive", false) and o != "REB":
			errs.append("province %s owned by dead country %s" % [pid, o])
		if float(p.get("pop", 0)) <= 0.0:
			errs.append("province %s non-positive pop" % pid)
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		if not s["countries"].has(a.get("owner", "")):
			errs.append("army %s bad owner" % aid)
		if a.get("loc", "") != "" and not s["provinces"].has(a["loc"]):
			errs.append("army %s bad loc" % aid)
		for uid in a.get("units", {}):
			if not Defs.units.has(uid):
				errs.append("army %s unknown unit %s" % [aid, uid])
	if not s["countries"].has(s["player"]):
		errs.append("player missing")
	errs.append_array(SimExt.validate(s))
	for cid in s["countries"]:
		var cc: Dictionary = s["countries"][cid]
		if cc.get("alive", false) and cid != "REB":
			if str(cc.get("gov", "")) not in Defs.governments:
				errs.append("country %s bad gov" % cid)
			if is_nan(float(cc.get("gold", 0.0))) or is_inf(float(cc.get("gold", 0.0))):
				errs.append("country %s gold not finite" % cid)
			if cc.get("capital", "") != "" and not s["provinces"].has(cc["capital"]):
				errs.append("country %s bad capital" % cid)
	return errs
