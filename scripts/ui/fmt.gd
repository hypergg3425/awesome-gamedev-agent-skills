class_name Fmt
extends RefCounted
## Formatting helpers shared by panels.

const FLAT_KEYS := ["stability", "admin_cap_flat", "stability_local", "fort_level", "infra", "trade_power", "naval_slots", "research_pts", "happiness",
	"happiness_local", "general_skill", "legit", "legit_conquest", "move_bonus"]
const RES_ICON := {"gold": "gold", "food": "food", "manpower": "manpower", "iron": "iron", "wood": "wood", "stone": "stone", "coal": "coal", "lux": "luxury",
	"admin": "admin", "prestige": "prestige"}
const RES_COLOR := {"gold": Color("f0cf6a"), "food": Color("b7d98a"), "manpower": Color("f4ecd6"), "iron": Color("b8c4d6"), "wood": Color("c9a070"),
	"stone": Color("c9c9c9"), "coal": Color("8a8a96"), "lux": Color("e8b6e8"), "admin": Color("9ec5ee")}

static func mod_line(key: String, v: float) -> String:
	var mk := "MOD_" + key.to_upper()
	var name := Loc.t(mk) if Loc.has_key(mk) else key
	if key in FLAT_KEYS or absf(v) > 3.0:
		return "%s %s" % [UI.signed(v, 1 if absf(v) < 10.0 else 0), name]
	return "%s%% %s" % [UI.signed(v * 100.0, 0), name]

static func effects_list(effects: Dictionary) -> Array:
	var out: Array = []
	for k in effects:
		if effects[k] is float or effects[k] is int:
			out.append(mod_line(str(k), float(effects[k])))
	return out

static func effects_text(effects: Dictionary) -> String:
	return ", ".join(effects_list(effects))

static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost:
		if k == "manpower":
			parts.append("%s %s" % [UI.fmt(float(cost[k])), Loc.t("RES_MANPOWER")])
		else:
			parts.append("%s %s" % [UI.fmt(float(cost[k])), Loc.t("RES_" + str(k).to_upper())])
	return ", ".join(parts)

static func cost_row(cost: Dictionary, have: Dictionary = {}) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	for k in cost:
		var ic: String = RES_ICON.get(k, "gold")
		var enough := true
		if have.has(k):
			enough = float(have[k]) >= float(cost[k])
		var st := UI.stat(ic, UI.fmt(float(cost[k])), (RES_COLOR.get(k, Color.WHITE) if enough else UI.BAD), Loc.t("RES_" + str(k).to_upper()), "Small")
		h.add_child(st)
	return h

static func terrain_name(t: String) -> String:
	return Loc.t("TERRAIN_" + t.to_upper())

static func religion_name(r: String) -> String:
	return Loc.t("REL_" + r.to_upper())

static func culture_name(c: String) -> String:
	return Loc.t("CULT_" + c.to_upper())

static func opinion_color(v: float) -> Color:
	if v > 40.0:
		return UI.GOOD
	if v < -40.0:
		return UI.BAD
	return Color("d8d0b8")

static func pct(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))

static func war_name(s: Dictionary, w: Dictionary) -> String:
	return "%s – %s" % [GS.country_name(s, w["leader_a"]), GS.country_name(s, w["leader_d"])]

static func general_text(g: Variant) -> String:
	if g == null:
		return Loc.t("MIL_NO_GENERAL")
	return "%s  (%d/%d/%d)" % [str(g["name"]), int(g["tac"]), int(g["log"]), int(g["siege"])]

static func unit_comp(a: Dictionary) -> String:
	var parts: Array = []
	var keys: Array = a["units"].keys()
	keys.sort()
	for uid in keys:
		parts.append("%s %s" % [str(snappedf(float(a["units"][uid]), 0.1)), Defs.unit_name(uid)])
	return ", ".join(parts)

static func roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][clampi(n, 0, 10)]
