class_name NoteFmt
extends RefCounted
## Turns notification / history records into localized, human-readable strings.

static func resolve_params(s: Dictionary, params: Dictionary) -> Dictionary:
	var out := {}
	for k in params:
		var v: Variant = params[k]
		match str(k):
			"province":
				out[k] = Defs.province_name(str(v))
			"country", "other", "by", "cid", "winner":
				out[k] = GS.country_name(s, str(v)) if s["countries"].has(str(v)) else str(v)
			"tech":
				out[k] = Defs.tech_name(str(v))
			"b":
				out[k] = Defs.building_name(str(v))
			"reform":
				out[k] = Loc.tx(Defs.reforms.get(str(v), {}).get("name", str(v)))
			"gov":
				out[k] = Defs.gov_name(str(v))
			"event":
				out[k] = Loc.tx(Defs.events.get(str(v), {}).get("title", str(v)))
			"obj":
				out[k] = _obj_name(s, str(v))
			"action":
				out[k] = Loc.t("ACT_" + str(v).to_upper())
			"cb":
				out[k] = Loc.t("CB_" + str(v).to_upper())
			"won":
				out[k] = Loc.t("UI_VICTORY") if bool(v) else Loc.t("UI_DEFEAT")
			_:
				out[k] = v
	return out

static func _obj_name(s: Dictionary, id: String) -> String:
	for o in s["objectives"]:
		if o.get("id", "") == id:
			return Loc.tx(o.get("name", id))
	return id

static func text(s: Dictionary, note: Dictionary) -> String:
	return Loc.tf(str(note["key"]), resolve_params(s, note.get("params", {})))

static func history_text(s: Dictionary, h: Dictionary) -> String:
	var p: Dictionary = (h.get("params", {}) as Dictionary).duplicate()
	if h["key"] == "HIST_EVENT":
		var ev: Dictionary = Defs.events.get(str(p.get("event", "")), {})
		var opt := ""
		for o in ev.get("options", []):
			if o["id"] == p.get("option", ""):
				opt = Loc.tx(o["name"])
		return Loc.tf("HIST_EVENT", {"event": Loc.tx(ev.get("title", "")), "option": opt})
	return Loc.tf(str(h["key"]), resolve_params(s, p))

static func category_icon(cat: String) -> String:
	return {"economy": "economy", "construction": "construction", "tech": "technology", "battle": "battle", "military": "military", "diplomacy": "diplomacy",
		"war": "war", "politics": "politics", "uprising": "warning", "disaster": "warning", "event": "events", "objective": "objectives", "world": "map", "game": "crown"}.get(cat, "info")

static func error_text(reason: String, params: Dictionary = {}) -> String:
	if Loc.has_key(reason):
		return Loc.tf(reason, params)
	return Loc.t("ERR_GENERIC") + " (" + reason + ")"
