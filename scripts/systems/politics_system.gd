class_name PoliticsSystem
extends RefCounted
## Classes & factions, stability, legitimacy, succession, elections, coups, revolts, reforms.

const NAMES := {
	"latin": ["Louis", "Charles", "Henri", "Philippe", "Alfonso", "Pedro", "Giovanni", "Carlo", "Ferdinand", "Jean", "Alberto", "Raimond"],
	"germanic": ["Henry", "Edward", "Frederick", "Otto", "William", "Harald", "Eric", "Wilhelm", "Konrad", "Richard", "Magnus", "Albrecht"],
	"slavic": ["Vladimir", "Boleslaw", "Casimir", "Ivan", "Mikhail", "Stefan", "Alexei", "Wladyslaw", "Jaroslav", "Milos"],
	"hellenic": ["Constantine", "Alexios", "Manuel", "Michael", "Andronikos", "Ioannis"],
	"magyar_finnic": ["Bela", "Stephen", "Matthias", "Lajos", "Tapio", "Eero"],
	"turkic": ["Mehmed", "Murad", "Selim", "Orhan", "Bayezid", "Suleiman", "Alp"],
	"arabic": ["Abdullah", "Yusuf", "Hasan", "Omar", "Khalid", "Salim", "Mansur"],
	"iranian": ["Shapur", "Abbas", "Ismail", "Tahmasp", "Kavus", "Darius"],
	"caucasian": ["David", "Tamar", "Giorgi", "Levan"],
	"indic": ["Rajendra", "Akbar", "Vikram", "Prithvi", "Shivaji", "Harsha"],
	"sinic": ["Taizong", "Hongwu", "Kangxi", "Wanli", "Chengzu", "Guangxu"],
	"japonic": ["Nobunaga", "Ieyasu", "Hideyoshi", "Takauji", "Yoritomo", "Mutsuhito"],
}
const SURN := ["the Bold", "the Wise", "the Just", "the Pious", "the Stern", "the Fair", "the Elder", "the Younger", "the Great", "the Builder"]

static func random_name(s: Dictionary, cid: String, rng: GameRng) -> String:
	var cult := str(s["countries"][cid]["culture"])
	var pool: Array = NAMES.get(cult, ["Aron", "Teku", "Mara", "Dagan", "Ilya", "Sato", "Nilo"])
	return str(rng.pick(pool))

static func random_skill(rng: GameRng, mean: float = 5.0) -> int:
	return clampi(int(round(rng.gauss(mean, 1.8))), 1, 9)

static func new_ruler(s: Dictionary, cid: String, age_lo: int, age_hi: int, bias: String = "") -> Dictionary:
	var rng := GS.rng_of(s)
	var c: Dictionary = s["countries"][cid]
	var r := {"name": random_name(s, cid, rng), "adm": random_skill(rng), "dip": random_skill(rng), "mil": random_skill(rng),
		"age": rng.randi_range(age_lo, age_hi), "dynasty": c["ruler"].get("dynasty", ""), "term_start": s["turn"], "health": clampf(rng.gauss(85.0, 8.0), 50.0, 100.0), "sex": "m", "ill": false}
	if bias != "":
		r[bias] = clampi(int(r[bias]) + 2, 1, 9)
	return r

## --- classes & stability --------------------------------------------------------------------
static func class_targets(s: Dictionary, cid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var m := Mods.country(s, cid)
	var gov: Dictionary = Defs.governments.get(c["gov"], {})
	var favor: Dictionary = gov.get("class_favor", {})
	var tax := float(c["tax_rate"])
	var hunger := (1.0 - float(c.get("food_ratio", 1.0)))
	var wx := float(c.get("war_exhaustion", 0.0))
	var off: Dictionary = c.get("class_offsets", {})
	var n_ports := 0
	var n_workshops := 0
	var n_rel := 0
	for pid in GS.owned(s, cid):
		var b: Dictionary = s["provinces"][pid]["buildings"]
		n_ports += 1 if b.has("port") else 0
		n_workshops += int(b.get("workshop", 0))
		n_rel += int(b.get("religious_building", 0))
	var np := float(maxi(1, GS.owned(s, cid).size()))
	var t := {}
	t["peasants"] = 58.0 - (tax - 0.2) * 110.0 - hunger * 70.0 - wx * 0.2 + float(favor.get("peasants", 0)) * 5.0
	t["merchants"] = 52.0 - (tax - 0.2) * 55.0 + float(m.get("trade", 0.0)) * 60.0 + float(favor.get("merchants", 0)) * 6.0 + minf(n_ports, 6) * 1.2 - wx * 0.25
	t["nobility"] = 52.0 + float(favor.get("nobility", 0)) * 7.0 - float(m.get("tax", 0.0)) * 10.0 + (float(c["legitimacy"]) - 50.0) * 0.1 - maxf(0.0, float(m.get("legit", 0.0))) * 2.0
	t["clergy"] = 52.0 + float(favor.get("clergy", 0)) * 6.0 + minf(n_rel / np, 3.0) * 4.0 + float(c.get("lux_ok", true) as bool) * 2.0
	t["artisans"] = 52.0 + float(favor.get("artisans", 0)) * 6.0 + minf(n_workshops / np, 2.0) * 5.0 - (tax - 0.2) * 40.0
	t["military"] = 50.0 + float(favor.get("military", 0)) * 7.0 + (float(c["army_funding"]) - 0.8) * 40.0 + float(int(c["stats"].get("battles_won", 0)) > 0) * 3.0 - wx * 0.15
	for k in t:
		t[k] = clampf(float(t[k]) + float(off.get(k, 0.0)), 5.0, 95.0)
	return t

static func class_power(s: Dictionary, cid: String) -> Dictionary:
	var shares := {}
	var tot := 0.0
	var pops := 0.0
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		pops += float(p["pop"])
		for cls in Const.CLASSES:
			shares[cls] = float(shares.get(cls, 0.0)) + float(p["classes"].get(cls, 0.0)) * float(p["pop"])
	var pw := {}
	var wtot := 0.0
	for cls in Const.CLASSES:
		var sh := float(shares.get(cls, 0.0)) / maxf(pops, 1.0)
		var w := sh * PopulationSystem._class_weight(cls) * (1.0 + (0.4 if float(Defs.governments.get(s["countries"][cid]["gov"], {}).get("class_favor", {}).get(cls, 0)) > 0.0 else 0.0))
		pw[cls] = w
		wtot += w
	for cls in Const.CLASSES:
		pw[cls] = float(pw[cls]) / maxf(wtot, 0.0001)
		s["countries"][cid]["classes"][cls]["share"] = float(shares.get(cls, 0.0)) / maxf(pops, 1.0)
	return pw

static func process_turn(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	if not c["alive"]:
		return
	var m := Mods.country(s, cid)
	var gov: Dictionary = Defs.governments.get(c["gov"], {})
	var rng := GS.rng_of(s)
	# war exhaustion
	var at_war := not GS.wars_of(s, cid).is_empty()
	if at_war:
		c["war_exhaustion"] = minf(100.0, float(c["war_exhaustion"]) + 0.7 * (1.0 + float(m.get("war_exhaustion", 0.0))))
	else:
		c["war_exhaustion"] = maxf(0.0, float(c["war_exhaustion"]) - 2.5)
	# class satisfaction
	var targets := class_targets(s, cid)
	var power := class_power(s, cid)
	var weighted := 0.0
	for cls in Const.CLASSES:
		var cd: Dictionary = c["classes"][cls]
		cd["sat"] = lerpf(float(cd["sat"]), float(targets[cls]), 0.2)
		cd["power"] = power[cls]
		weighted += float(cd["sat"]) * float(power[cls])
	c["faction_sat"] = weighted
	# stability
	var tgt := 50.0 + (weighted - 50.0) * 0.8
	tgt += float(m.get("stability", 0.0)) * 3.0
	tgt -= float(c["war_exhaustion"]) * 0.2
	tgt -= float(c["bankrupt_turns"]) * 2.0 if float(c["gold"]) <= 0.0 else 0.0
	tgt -= float(EconomySystem.admin_capacity(s, cid)["overextension"]) * 18.0
	tgt += clampf(float(c["prestige"]) / 60.0, -5.0, 8.0)
	tgt += float(m.get("happiness", 0.0))
	tgt += (float(c["legitimacy"]) - 50.0) * 0.12
	if not c.get("lux_ok", true):
		tgt -= 2.0
	if float(c.get("food_ratio", 1.0)) < 1.0:
		tgt -= (1.0 - float(c["food_ratio"])) * 25.0
	var step := clampf((tgt - float(c["stability"])) * 0.12, -3.0, 3.0)
	c["stability"] = clampf(float(c["stability"]) + step, 0.0, 100.0)
	if float(c["gold"]) > 0.0:
		c["bankrupt_turns"] = maxi(0, int(c["bankrupt_turns"]) - 1)
	# legitimacy by government
	var leg := float(c["legitimacy"])
	var ru: Dictionary = c["ruler"]
	var base_leg := 55.0
	if "ruler_skill_matters" in gov.get("features", []):
		base_leg = 40.0 + (float(ru["adm"]) + float(ru["dip"]) + float(ru["mil"])) * 2.5
	elif "elections" in gov.get("features", []):
		base_leg = 60.0
	elif "religious_unity_matters" in gov.get("features", []):
		base_leg = 50.0 + _religious_unity(s, cid) * 40.0
	if "prestige_legit" in gov.get("features", []):
		base_leg += clampf(float(c["prestige"]) / 25.0, -15.0, 20.0)
	base_leg += float(m.get("legit", 0.0)) * 5.0
	if "coup_risk" in gov.get("features", []):
		base_leg = 40.0 + float(c["stats"].get("battles_won", 0.0)) * 0.3 - float(c["stats"].get("battles_lost", 0.0)) * 0.6 + 20.0
	c["legitimacy"] = clampf(lerpf(leg, clampf(base_leg, 5.0, 100.0), 0.08), 0.0, 100.0)
	# prestige relaxes towards zero
	c["prestige"] = float(c["prestige"]) * 0.992
	# temp mods expire
	var keep: Array = []
	for tm in c["temp_mods"]:
		if int(tm["until"]) >= int(s["turn"]):
			keep.append(tm)
	c["temp_mods"] = keep
	# factions, corruption, independence movements
	FactionsSystem.process_turn(s, cid, rng)
	CivilWar.process_turn(s, cid, rng)
	# ruler ageing, health, family and succession
	DynastySystem.process_turn(s, cid, rng)
	# elections
	var term := int(gov.get("term_turns", 0))
	if term > 0 and "elections" in gov.get("features", []):
		if int(s["turn"]) - int(c.get("election_turn", 0)) >= term:
			_election(s, cid, rng)
	if "religious_unity_matters" in gov.get("features", []) and term > 0 and int(s["turn"]) - int(c.get("election_turn", 0)) >= term * 2:
		_new_leader(s, cid, rng, 45, 70, "")
		c["election_turn"] = s["turn"]
	# revolts in provinces
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		var u := float(p["unrest"])
		if u > 70.0 and p["controller"] == cid and rng.chance(minf(0.25, (u - 70.0) / 100.0 * 0.8)):
			_revolt(s, cid, pid, rng)

static func _religious_unity(s: Dictionary, cid: String) -> float:
	var c: Dictionary = s["countries"][cid]
	var tot := 0.0
	var same := 0.0
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		tot += float(p["pop"])
		if p["religion"] == c["religion"]:
			same += float(p["pop"])
	return same / maxf(tot, 1.0)

static func ruler_dies(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var gov: Dictionary = Defs.governments.get(c["gov"], {})
	var old: String = str(c["ruler"]["name"])
	GS.note(s, cid, "politics", "NOTE_RULER_DIED", {"ruler": old})
	GS.history(s, cid, "politics", "HIST_RULER_DIED", {"ruler": old})
	match str(gov.get("succession", "hereditary")):
		"hereditary":
			DynastySystem.on_ruler_death(s, cid, rng)
		"elective":
			_new_leader(s, cid, rng, 35, 62, "")
		"theocratic":
			_new_leader(s, cid, rng, 50, 72, "adm")
			c["stability"] = maxf(0.0, float(c["stability"]) - 2.0)
		"military":
			_new_leader(s, cid, rng, 38, 58, "mil")
			c["stability"] = maxf(0.0, float(c["stability"]) - 6.0)
	GS.stat_add(s, cid, "rulers", 1.0)
	GovMechanics.on_leader_change(s, cid, c, rng)
	Mods.invalidate(s)

static func _succession_crisis(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	c["ruler"] = new_ruler(s, cid, 24, 50)
	c["ruler"]["name"] = str(c["ruler"]["name"])
	c["legitimacy"] = maxf(5.0, float(c["legitimacy"]) - 35.0)
	c["stability"] = maxf(0.0, float(c["stability"]) - 15.0)
	c["temp_mods"].append({"mods": {"unrest": 0.05, "tax": -0.05}, "until": int(s["turn"]) + 8, "key": "succession_crisis"})
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		p["unrest"] = minf(100.0, float(p["unrest"]) + 8.0)
	GS.note(s, cid, "politics", "NOTE_SUCCESSION_CRISIS", {"ruler": c["ruler"]["name"]})
	GS.history(s, cid, "politics", "HIST_SUCCESSION_CRISIS", {"ruler": c["ruler"]["name"]})

static func _new_leader(s: Dictionary, cid: String, rng: GameRng, a_lo: int, a_hi: int, bias: String) -> void:
	var c: Dictionary = s["countries"][cid]
	# the strongest faction pulls the new leader's strengths
	var best := ""
	var bp := -1.0
	for cls in Const.CLASSES:
		var pw := float(c["classes"][cls].get("power", 0.0))
		if pw > bp:
			bp = pw
			best = cls
	var b := bias
	if b == "":
		b = {"merchants": "dip", "military": "mil", "nobility": "mil", "clergy": "adm", "artisans": "adm", "peasants": ""}.get(best, "")
	c["ruler"] = new_ruler(s, cid, a_lo, a_hi, b)
	c["legitimacy"] = clampf(float(c["legitimacy"]) + 8.0, 0.0, 100.0)
	GS.note(s, cid, "politics", "NOTE_NEW_RULER", {"ruler": c["ruler"]["name"]})
	Mods.invalidate(s)

static func _election(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	c["election_turn"] = s["turn"]
	_new_leader(s, cid, rng, 38, 62, "")
	var winner := FactionsSystem.on_election(s, cid)
	GS.note(s, cid, "politics", "NOTE_ELECTION_WON", {"faction": winner})
	var wsat := float(c.get("faction_sat", 50.0))
	c["stability"] = clampf(float(c["stability"]) + (wsat - 50.0) * 0.12 - 1.0, 0.0, 100.0)
	c["legitimacy"] = clampf(55.0 + (wsat - 50.0) * 0.6 + rng.randf() * 10.0, 0.0, 100.0)
	GS.note(s, cid, "politics", "NOTE_ELECTION", {"ruler": c["ruler"]["name"]})
	GS.history(s, cid, "politics", "HIST_ELECTION", {"ruler": c["ruler"]["name"]})
	GS.stat_add(s, cid, "elections", 1.0)

static func _coup(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	c["ruler"] = new_ruler(s, cid, 35, 55, "mil")
	c["stability"] = minf(100.0, float(c["stability"]) + 12.0)
	c["legitimacy"] = 45.0
	GS.note(s, cid, "politics", "NOTE_COUP", {"ruler": c["ruler"]["name"]})
	GS.history(s, cid, "politics", "HIST_COUP", {"ruler": c["ruler"]["name"]})
	if c["gov"] != "military_government" and rng.chance(0.4) and not Defs.governments[c["gov"]].get("features", []).has("coup_risk"):
		var old_gov: String = c["gov"]
		c["gov"] = "military_government"
		FactionsSystem.on_government_change(s, cid, old_gov, "military_government")
		GS.note(s, cid, "politics", "NOTE_GOV_CHANGED", {"gov": "military_government"})
	Mods.invalidate(s)

static func _revolt(s: Dictionary, cid: String, pid: String, rng: GameRng) -> void:
	var p: Dictionary = s["provinces"][pid]
	var size := clampf(roundf(float(p["pop"]) * 0.004 * float(p["unrest"]) / 100.0 * 2.0), 1.0, 7.0)
	p["unrest"] = maxf(0.0, float(p["unrest"]) - 22.0)
	p["pop"] = float(p["pop"]) * 0.97
	var rb := MilitarySystem.spawn_rebels(s, pid, size)
	GS.note(s, cid, "uprising", "NOTE_REVOLT", {"province": pid}, pid)
	GS.history(s, cid, "uprising", "HIST_REVOLT", {"province": pid})
	GS.stat_add(s, cid, "revolts", 1.0)
	if not (p["buildings"] as Dictionary).is_empty() and rng.chance(0.35):
		var keys: Array = (p["buildings"] as Dictionary).keys()
		keys.sort()
		ConstructionSystem.demolish(s, cid, pid, str(rng.pick(keys)))

## --- reforms & government --------------------------------------------------------------------
static func can_adopt_reform(s: Dictionary, cid: String, rid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var r: Dictionary = Defs.reforms.get(rid, {})
	if r.is_empty():
		return {"ok": false, "reason": "ERR_INVALID"}
	if rid in c["reforms"]:
		return {"ok": false, "reason": "REFORM_ERR_HAVE"}
	for ex in r["excludes"]:
		if ex in c["reforms"]:
			return {"ok": false, "reason": "REFORM_ERR_EXCLUDES", "params": {"r": Loc.tx(Defs.reforms[ex]["name"])}}
	var govs: Array = r["governments"]
	if not govs.is_empty() and c["gov"] not in govs:
		return {"ok": false, "reason": "REFORM_ERR_GOV"}
	var req: Dictionary = r["requires"]
	if req.has("tech") and TechSystem.level(c, req["tech"][0]) < int(req["tech"][1]):
		return {"ok": false, "reason": "REFORM_ERR_TECH", "params": {"tech": "%s %d" % [Loc.tx(Defs.tech_lines[req["tech"][0]]["name"]), int(req["tech"][1])]}}
	var m := Mods.country(s, cid)
	var adm_cost := float(r["cost_admin"]) * clampf(1.0 + float(m.get("reform_cost", 0.0)), 0.4, 2.0)
	if float(c["admin"]) < adm_cost:
		return {"ok": false, "reason": "ERR_NO_ADMIN", "params": {"need": int(ceil(adm_cost))}}
	if float(c["gold"]) < float(r["cost_gold"]):
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(r["cost_gold"])}}
	return {"ok": true, "admin": adm_cost, "gold": float(r["cost_gold"])}

static func adopt_reform(s: Dictionary, cid: String, rid: String) -> Dictionary:
	var chk := can_adopt_reform(s, cid, rid)
	if not chk["ok"]:
		return chk
	var c: Dictionary = s["countries"][cid]
	var r: Dictionary = Defs.reforms[rid]
	c["admin"] = float(c["admin"]) - float(chk["admin"])
	c["gold"] = float(c["gold"]) - float(chk["gold"])
	c["reforms"].append(rid)
	# one-off class reactions from "<class>_sat" keys
	var off: Dictionary = c.get("class_offsets", {})
	for src in [r["advantages"], r["disadvantages"]]:
		for k in src:
			if str(k).ends_with("_sat"):
				var cls := str(k).substr(0, str(k).length() - 4)
				if cls in Const.CLASSES:
					c["classes"][cls]["sat"] = clampf(float(c["classes"][cls]["sat"]) + float(src[k]), 0.0, 100.0)
					off[cls] = float(off.get(cls, 0.0)) + float(src[k]) * 0.25
	c["class_offsets"] = off
	FactionsSystem.on_reform(c, rid)
	Mods.invalidate(s)
	GS.note(s, cid, "politics", "NOTE_REFORM", {"reform": rid})
	GS.history(s, cid, "politics", "HIST_REFORM", {"reform": rid})
	GS.stat_add(s, cid, "reforms", 1.0)
	return {"ok": true}

static func government_options(s: Dictionary, cid: String) -> Array:
	var c: Dictionary = s["countries"][cid]
	var out: Array = []
	var tr: Dictionary = Defs.gov_transitions.get(c["gov"], {})
	for to in tr:
		var t: Dictionary = tr[to]
		var req: Dictionary = t["requires"]
		var ok := true
		var why := ""
		if req.has("tech") and TechSystem.level(c, req["tech"][0]) < int(req["tech"][1]):
			ok = false
			why = "REFORM_ERR_TECH"
		if req.has("provinces") and GS.owned(s, cid).size() < int(req["provinces"]):
			ok = false
			why = "GOV_ERR_SIZE"
		if float(c["admin"]) < float(t["cost_admin"]):
			ok = false
			why = "ERR_NO_ADMIN"
		if FactionsSystem.in_transition(c):
			ok = false
			why = "GOV_ERR_TRANSITION"
		out.append({"to": to, "ok": ok, "reason": why, "cost_admin": t["cost_admin"], "stability_hit": t["stability_hit"]})
	return out

static func change_government(s: Dictionary, cid: String, to: String) -> Dictionary:
	for o in government_options(s, cid):
		if o["to"] == to:
			if not o["ok"]:
				return {"ok": false, "reason": o["reason"]}
			var c: Dictionary = s["countries"][cid]
			var old_gov: String = c["gov"]
			c["admin"] = float(c["admin"]) - float(o["cost_admin"])
			c["gov"] = to
			c["stability"] = maxf(0.0, float(c["stability"]) - float(o["stability_hit"]))
			c["legitimacy"] = float(Defs.governments[to].get("legit_start", 60)) if float(Defs.governments[to].get("legit_start", 60)) > 0.0 else 65.0
			c["election_turn"] = s["turn"]
			# reforms limited to the old government are lost
			var keep: Array = []
			for rid in c["reforms"]:
				var govs: Array = Defs.reforms[rid]["governments"]
				if govs.is_empty() or to in govs:
					keep.append(rid)
			c["reforms"] = keep
			FactionsSystem.on_government_change(s, cid, old_gov, to)
			DynastySystem.st(c)["law"] = DynastySystem.law_of(to)
			DynastySystem.init_country(s, cid)
			Mods.invalidate(s)
			GS.note(s, cid, "politics", "NOTE_GOV_CHANGED", {"gov": to})
			GS.history(s, cid, "politics", "HIST_GOV_CHANGED", {"gov": to})
			return {"ok": true}
	return {"ok": false, "reason": "ERR_INVALID"}
