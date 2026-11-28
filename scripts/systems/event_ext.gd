class_name EventExt
extends RefCounted
## Extended event conditions and effects (territory, vassals, commanders, dynasty, espionage, economy cycle,
## government). EventSystem delegates here for every type it does not know. Also renders the plain-text
## consequence list shown in the event dialog (`describe`).

const NEW_COND_TYPES := ["spy_levels_at_least", "ci_level_at_least", "eco_phase_is", "heir_exists", "royals_below", "has_general", "vassals_at_least",
	"is_hereditary", "naval_regiments_at_least", "faction_loyalty_between"]
const NEW_EFFECT_TYPES := ["transfer_province", "create_vassal", "vassalize", "spawn_general", "spawn_army", "spawn_fleet", "ruler_health", "add_royal",
	"heir_skill", "ci_level", "spy_network", "eco_phase", "force_government", "civil_war", "alliance", "add_core", "set_opinion_all"]

static func cond(s: Dictionary, cid: String, t: String, c: Dictionary) -> bool:
	var cc: Dictionary = s["countries"][cid]
	var v := float(c.get("value", 0))
	match t:
		"spy_levels_at_least": return EspionageSystem.total_levels(s, cid) >= int(v)
		"ci_level_at_least": return EspionageSystem.ci_level(s, cid) >= int(v)
		"eco_phase_is": return str(EconomyDepth.st(cc).get("phase", "normal")) == str(c.get("phase", c.get("value", "")))
		"heir_exists": return cc.get("heir") != null
		"royals_below": return (DynastySystem.st(cc)["royals"] as Array).size() < int(v)
		"has_general":
			for aid in GS.armies_of(s, cid):
				if s["armies"][aid].get("general") != null:
					return true
			return false
		"vassals_at_least": return GS.vassals_of(s, cid).size() >= int(v)
		"is_hereditary": return DynastySystem.is_hereditary(cc)
		"naval_regiments_at_least": return UnitUtil.country_regiments(s, cid, true) >= v
		"faction_loyalty_between":
			var fid := str(c.get("faction", "nobility"))
			return fid in FactionsSystem.FACTIONS and FactionsSystem.loyalty(cc, fid) >= float(c.get("min", 0)) and FactionsSystem.loyalty(cc, fid) <= float(c.get("max", 100))
	return false

## Returns true when `t` is an extended effect (it has been applied, or skipped because it does not apply).
static func effect(s: Dictionary, entry: Dictionary, t: String, fx: Dictionary) -> bool:
	if t not in NEW_EFFECT_TYPES:
		return false
	var cid: String = entry["cid"]
	var c: Dictionary = s["countries"][cid]
	var v := float(fx.get("value", 0))
	var other := _other(s, entry, fx)
	match t:
		"transfer_province": _transfer(s, entry, fx, other)
		"create_vassal": _create_vassal(s, entry, fx)
		"vassalize":
			if other != "" and GS.overlord_of(s, other) == "" and GS.vassals_of(s, other).is_empty() and not GS.at_war(s, cid, other) and GS.overlord_of(s, cid) == "":
				DiplomacySystem.make_vassal(s, cid, other)
		"spawn_general": _spawn_general(s, cid, fx)
		"spawn_army": _spawn_army(s, entry, str(fx.get("class", "infantry")), maxf(1.0, float(fx.get("n", 3))))
		"spawn_fleet": _spawn_army(s, entry, "naval", maxf(1.0, float(fx.get("n", 2))))
		"ruler_health":
			c["ruler"]["health"] = clampf(float(c["ruler"].get("health", 80.0)) + v, 5.0, 100.0)
		"add_royal": _add_royal(s, cid, fx)
		"heir_skill":
			var h: Variant = c.get("heir")
			if h is Dictionary:
				var r := DynastySystem.royal_by_id(c, int((h as Dictionary).get("id", -1)))
				var sk := str(fx.get("skill", "adm"))
				if not r.is_empty() and sk in ["adm", "dip", "mil"]:
					r[sk] = clampi(int(r[sk]) + int(v), 1, 9)
					DynastySystem.refresh_heir(c)
		"ci_level":
			var e := EspionageSystem.st(s, cid)
			e["ci"] = clampi(int(e.get("ci", 0)) + int(v), 0, EspionageSystem.MAX_LEVEL)
		"spy_network":
			if other != "" and other != cid:
				var e2 := EspionageSystem.st(s, cid)
				var net: Dictionary = e2["net"].get(other, {"lvl": 0, "since": int(s["turn"])})
				net["lvl"] = clampi(int(net["lvl"]) + int(v), 0, EspionageSystem.MAX_LEVEL)
				if int(net["lvl"]) > 0:
					e2["net"][other] = net
				else:
					e2["net"].erase(other)
		"eco_phase":
			var ph := str(fx.get("phase", "boom"))
			if ph in EconomyDepth.PHASES:
				EconomyDepth._enter(s, cid, c, ph, "event", int(fx.get("turns", 6)))
		"force_government": _force_government(s, cid, str(fx.get("to", "")))
		"civil_war":
			var fac := str(fx.get("faction", "military"))
			CivilWar.start(s, cid, str(fx.get("reason", "event")), fac, "", GS.rng_of(s))
		"alliance":
			if other != "" and not GS.at_war(s, cid, other) and GS.overlord_of(s, cid) == "":
				var r2 := GS.rel(s, cid, other)
				r2["alliance"] = true
				r2["defensive"] = true
				GS.add_opinion(s, cid, other, 15.0)
				GS.add_opinion(s, other, cid, 15.0)
		"add_core":
			var pid := _province_of(s, entry, fx)
			if pid != "" and cid not in s["provinces"][pid]["cores"]:
				s["provinces"][pid]["cores"].append(cid)
		"set_opinion_all":
			for oid in GS.alive_countries(s):
				if oid != cid and oid != "REB" and not str(oid).begins_with("NAT_"):
					GS.add_opinion(s, oid, cid, v)
	return true

static func _other(s: Dictionary, entry: Dictionary, fx: Dictionary) -> String:
	var tg := str(fx.get("target", "other"))
	if s["countries"].has(tg):
		return tg
	var o := str(entry.get("other", ""))
	return o if o != "" and s["countries"].has(o) and bool(s["countries"][o].get("alive", false)) else ""

static func _province_of(s: Dictionary, entry: Dictionary, fx: Dictionary) -> String:
	var pid := str(fx.get("province", ""))
	if pid != "" and s["provinces"].has(pid):
		return pid
	var ep := str(entry.get("pid", ""))
	return ep if ep != "" and s["provinces"].has(ep) else ""

## weakest-held non-capital province of `cid`: the natural one to lose, break away or hand over
static func _marginal_province(s: Dictionary, cid: String) -> String:
	var best := ""
	var bu := -1.0
	var cap := str(s["countries"][cid]["capital"])
	for pid in GS.owned(s, cid):
		if pid == cap:
			continue
		var u := float(s["provinces"][pid]["unrest"]) + (100.0 - float(s["provinces"][pid]["pop"])) * 0.0001
		if u > bu:
			bu = u
			best = pid
	return best

static func _transfer(s: Dictionary, entry: Dictionary, fx: Dictionary, other: String) -> void:
	var cid: String = entry["cid"]
	var give := str(fx.get("direction", "give")) == "give"
	if other == "":
		return
	var from := cid if give else other
	var to := other if give else cid
	var pid := str(fx.get("province", ""))
	if pid == "" or not s["provinces"].has(pid) or s["provinces"][pid]["owner"] != from:
		pid = ""
		var ep := str(entry.get("pid", ""))
		if give and ep != "" and s["provinces"][ep]["owner"] == cid:
			pid = ep
		elif give:
			pid = _marginal_province(s, cid)
		else:
			# a province of the other country that touches our land
			for p2 in GS.owned(s, other):
				if p2 == str(s["countries"][other]["capital"]):
					continue
				for nb in Defs.neighbors(p2):
					if s["provinces"][nb]["owner"] == cid:
						pid = p2
						break
				if pid != "":
					break
	if pid == "" or pid == str(s["countries"][from]["capital"]) or GS.owned(s, from).size() < 2:
		return
	DiplomacySystem.transfer_province(s, pid, from, to)
	var cp: Array = s["provinces"][pid]["cores"]
	if to not in cp and bool(fx.get("core", false)):
		cp.append(to)

static func _create_vassal(s: Dictionary, entry: Dictionary, fx: Dictionary) -> void:
	var cid: String = entry["cid"]
	if GS.owned(s, cid).size() < 4 or GS.overlord_of(s, cid) != "":
		return
	var pid := _province_of(s, entry, fx)
	if pid == "" or s["provinces"][pid]["owner"] != cid or pid == str(s["countries"][cid]["capital"]):
		pid = _marginal_province(s, cid)
	if pid == "":
		return
	var base: String = Defs.province_name_in(s, pid)
	var nm: Dictionary = fx.get("name", {"en": "Duchy of " + base, "tr": base + " Dukalığı"})
	var tag := CivilWar.spawn_country(s, cid, [pid], str(s["countries"][cid]["gov"]), str(nm.get("en", base)), str(nm.get("tr", base)), "", GS.rng_of(s), "V")
	DiplomacySystem.make_vassal(s, cid, tag)
	s["countries"][tag]["stability"] = 55.0
	s["provinces"][pid]["unrest"] = 5.0

static func _spawn_general(s: Dictionary, cid: String, fx: Dictionary) -> void:
	var mil := clampi(int(fx.get("mil", int(s["countries"][cid]["ruler"]["mil"]) + 1)), 3, 9)
	var naval := bool(fx.get("naval", false))
	var g := Commanders.make(s, cid, mil, naval)
	var tr: Variant = fx.get("trait", "")
	if str(tr) in Commanders.TRAITS and str(tr) not in g["traits"] and (g["traits"] as Array).size() < Commanders.MAX_TRAITS:
		(g["traits"] as Array).append(str(tr))
	g["tac"] = clampi(maxi(int(g["tac"]), mil), 1, 9)
	var best := ""
	var worst := 99.0
	for aid in GS.armies_of(s, cid):
		var a: Dictionary = s["armies"][aid]
		if bool(a.get("naval", false)) != naval:
			continue
		var cur := float(a["general"]["tac"]) if a.get("general") != null else 0.0
		if cur < worst:
			worst = cur
			best = aid
	if best != "" and worst < float(g["tac"]):
		s["armies"][best]["general"] = g

static func _spawn_army(s: Dictionary, entry: Dictionary, cls: String, n: float) -> void:
	var cid: String = entry["cid"]
	var c: Dictionary = s["countries"][cid]
	var uid := UnitUtil.best_of(s, cid, cls)
	if uid == "":
		return
	var loc := str(entry.get("pid", ""))
	if loc == "" or s["provinces"][loc]["owner"] != cid:
		loc = str(c["capital"])
	if cls == "naval":
		if not bool(Defs.provinces.get(loc, {}).get("coastal", false)):
			loc = ""
			for pid in GS.owned(s, cid):
				if bool(Defs.provinces[pid].get("coastal", false)):
					loc = pid
					break
		if loc == "":
			return
	MilitarySystem.create_army(s, cid, loc, {uid: n}, Commanders.make(s, cid, int(c["ruler"]["mil"]), cls == "naval"))

static func _add_royal(s: Dictionary, cid: String, fx: Dictionary) -> void:
	var c: Dictionary = s["countries"][cid]
	if not DynastySystem.is_hereditary(c):
		return
	var d := DynastySystem.st(c)
	if (d["royals"] as Array).size() >= DynastySystem.MAX_ROYALS:
		return
	var ru: Dictionary = c["ruler"]
	var mean := (float(ru.get("adm", 5)) + float(ru.get("dip", 5)) + float(ru.get("mil", 5))) / 3.0
	var r := DynastySystem._new_royal(s, cid, d, GS.rng_of(s), 0.0, str(fx.get("rel", "child")), mean, str(fx.get("sex", "")))
	(d["royals"] as Array).append(r)
	DynastySystem.refresh_heir(c)

static func _force_government(s: Dictionary, cid: String, to: String) -> void:
	var c: Dictionary = s["countries"][cid]
	var tr: Dictionary = Defs.gov_transitions.get(str(c["gov"]), {})
	if not Defs.governments.has(to) or str(c["gov"]) == to or not tr.has(to) or FactionsSystem.in_transition(c):
		return
	# the event imposes the change: no tech / admin requirement, the stability cost still applies
	PoliticsSystem.apply_government_change(s, cid, to, 0.0, float(tr[to]["stability_hit"]) * 0.6)

## --- plain-text consequence list -----------------------------------------------------------------------------------
static func signed(v: float) -> String:
	var r := roundf(v * 10.0) / 10.0
	return ("+%s" % str(r).trim_suffix(".0")) if r > 0.0 else str(r).trim_suffix(".0")

static func describe(fx: Dictionary) -> String:
	var t := str(fx.get("type", ""))
	var key := "EVFX_" + t
	if Loc.strings.get(key) == null:
		return ""
	var p := {"v": signed(float(fx.get("value", 0))), "n": str(fx.get("n", 1)), "turns": str(fx.get("turns", 8))}
	match t:
		"stock": p["x"] = Loc.t("RES_" + str(fx.get("res", "food")).to_upper())
		"class_sat": p["x"] = Loc.t("CLASS_" + str(fx.get("class", "peasants")).to_upper())
		"faction_loyalty": p["x"] = Loc.t("FACTION_" + str(fx.get("faction", "nobility")).to_upper())
		"force_government": p["x"] = Loc.tx(Defs.governments.get(str(fx.get("to", "")), {}).get("name", str(fx.get("to", ""))))
		"temp_mod":
			var parts: Array = []
			for k in (fx.get("mods", {}) as Dictionary):
				var mk := "MOD_" + str(k).to_upper()
				parts.append("%s %s" % [Loc.t(mk) if Loc.strings.get(mk) != null else str(k), signed(float(fx["mods"][k]) * (100.0 if absf(float(fx["mods"][k])) < 1.0 else 1.0)) + ("%" if absf(float(fx["mods"][k])) < 1.0 else "")])
			p["x"] = ", ".join(parts)
		"add_regiments": p["x"] = Loc.tx(Defs.units.get(str(fx.get("unit", "")), {}).get("name", str(fx.get("unit", ""))))
	return Loc.tf(key, p)

## All effect lines of an option (empty effects such as flags are skipped).
static func describe_option(o: Dictionary) -> Array:
	var out: Array = []
	for fx in o.get("effects", []):
		var line := describe(fx)
		if line != "":
			out.append(line)
	return out

const BAD_WHEN_POSITIVE := ["inflation", "debt", "province_unrest", "province_devastation", "war_exhaustion", "corruption", "disband_pct", "kill_ruler",
	"spawn_rebels", "destroy_building", "civil_war"]

## +1 good, -1 bad, 0 neutral/unknown for the player (used to colour the consequence lines).
static func tone(fx: Dictionary) -> int:
	var t := str(fx.get("type", ""))
	if t in ["set_flag", "clear_flag", "trigger_event"]:
		return 0
	var v := float(fx.get("value", 1.0))
	if t in ["kill_ruler", "spawn_rebels", "destroy_building", "civil_war"]:
		return -1
	if t in ["add_regiments", "spawn_army", "spawn_fleet", "spawn_general", "add_royal", "add_building", "add_claim", "add_core", "alliance", "vassalize", "create_vassal", "research_points"]:
		return 1
	if t == "transfer_province":
		return -1 if str(fx.get("direction", "give")) == "give" else 1
	if t == "eco_phase":
		return 1 if str(fx.get("phase", "boom")) == "boom" else -1
	if t == "temp_mod":
		var sum := 0.0
		for k in (fx.get("mods", {}) as Dictionary):
			var mv := float(fx["mods"][k])
			sum += -mv if k in ["unrest", "army_upkeep", "build_cost"] else mv
		return 1 if sum > 0.0 else -1
	if v == 0.0:
		return 0
	return (-1 if v > 0.0 else 1) if t in BAD_WHEN_POSITIVE else (1 if v > 0.0 else -1)
