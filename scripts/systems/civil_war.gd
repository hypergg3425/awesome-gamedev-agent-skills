class_name CivilWar
extends RefCounted
## Civil wars (a country splits in two), independence movements (culture / religion minorities, conquered
## provinces), vassal independence and rebel-held provinces becoming states (the REB pseudo-country).

const REBEL_GOV := {"military": "military_government", "merchants": "republic", "nobility": "feudal_kingdom", "clergy": "theocracy", "popular": "republic"}
const REB_HOLD_TURNS := 6
const MOVE_RISING := 50.0
const MOVE_FREE := 100.0

## --- spawning a new country ------------------------------------------------------------------------------------------
static func _shift_color(hex: String) -> String:
	var col := Color.html(hex) if hex.begins_with("#") else Color.GRAY
	col.h = fposmod(col.h + 0.5, 1.0)
	col.s = clampf(col.s * 0.9 + 0.05, 0.0, 1.0)
	return "#" + col.to_html(false)

static func _next_tag(s: Dictionary, parent: String, suffix: String) -> String:
	var n := 1
	while s["countries"].has("%s_%s%d" % [parent, suffix, n]):
		n += 1
	return "%s_%s%d" % [parent, suffix, n]

## Creates a country from `pids` taken from `parent`. Gold, debt and stocks are split in proportion to
## population (no money is created), armies stationed in the provinces change sides.
static func spawn_country(s: Dictionary, parent: String, pids: Array, gov: String, name_en: String, name_tr: String, leader: String, rng: GameRng, suffix: String = "R") -> String:
	var pc: Dictionary = s["countries"][parent]
	var tag := _next_tag(s, parent, suffix)
	var total_pop := 0.0
	var part_pop := 0.0
	for pid in GS.owned(s, parent):
		total_pop += float(s["provinces"][pid]["pop"])
	var cap := ""
	var cap_pop := -1.0
	for pid in pids:
		var pp := float(s["provinces"][pid]["pop"])
		part_pop += pp
		if pp > cap_pop:
			cap_pop = pp
			cap = pid
	var share := clampf(part_pop / maxf(total_pop, 1.0), 0.02, 0.9)
	var cult: String = str(s["provinces"][cap]["culture"])
	var rel: String = str(s["provinces"][cap]["religion"])
	var cd := {"name": {"en": name_en, "tr": name_tr}, "short": {"en": name_en, "tr": name_tr}, "color": _shift_color(str(pc["color"])),
		"flag": (pc.get("flag", {}) as Dictionary).duplicate(true), "culture": cult, "religion": rel, "gov": gov, "civ": str(pc.get("civ", "average")), "capital": cap,
		"treasury": 0.0, "ruler": {"name": leader if leader != "" else PoliticsSystem.random_name(s, parent, rng), "adm": PoliticsSystem.random_skill(rng), "dip": PoliticsSystem.random_skill(rng),
			"mil": PoliticsSystem.random_skill(rng), "age": rng.randi_range(28, 50), "dynasty": ""}, "playable": false}
	var nc: Dictionary = ScenarioLoader._make_country(s, tag, cd)
	nc["is_player"] = false
	nc["tag_alias"] = tag
	s["countries"][tag] = nc
	nc["researched"] = (pc["researched"] as Dictionary).duplicate(true)
	nc["tech_level"] = (pc["tech_level"] as Dictionary).duplicate(true)
	nc["classes"] = (pc["classes"] as Dictionary).duplicate(true)
	nc["reforms"] = []
	for k in pc["stock"]:
		var moved := float(pc["stock"][k]) * share
		nc["stock"][k] = moved
		pc["stock"][k] = float(pc["stock"][k]) - moved
	var g := float(pc["gold"]) * share
	nc["gold"] = maxf(0.0, g)
	pc["gold"] = float(pc["gold"]) - maxf(0.0, g)
	var dsh := float(pc["debt"]) * share
	nc["debt"] = dsh
	pc["debt"] = float(pc["debt"]) - dsh
	nc["admin"] = 40.0
	nc["stability"] = 40.0
	nc["legitimacy"] = 50.0
	nc["manpower"] = float(pc["manpower"]) * share
	pc["manpower"] = float(pc["manpower"]) * (1.0 - share)
	nc["alive"] = true
	nc["spawned_turn"] = int(s["turn"])
	nc["parent"] = parent
	# provinces change hands
	for pid in pids:
		var p: Dictionary = s["provinces"][pid]
		p["owner"] = tag
		p["controller"] = tag
		p["siege"] = null
		p["queue"] = []
		p["unrest"] = 20.0
		p["conquered_turn"] = int(s["turn"])
		if tag not in p["cores"]:
			p["cores"].append(tag)
		if parent not in p["claims"]:
			p["claims"].append(parent)
	GS.rebuild_caches(s)
	# the parent claims what it lost, the new state claims nothing it does not hold
	# armies stationed in the seceding provinces follow them; rebels there join the new state
	for aid in s["armies"].keys():
		var a: Dictionary = s["armies"][aid]
		if a["loc"] in pids and (a["owner"] == parent and not a.get("naval", false) or a["owner"] == "REB"):
			a["owner"] = tag
	if GS.armies_of(s, tag).is_empty():
		var size := clampf(roundf(part_pop / 120.0), 1.0, 8.0)
		MilitarySystem.create_army(s, tag, cap, {UnitUtil.best_of(s, tag, "infantry"): size}, MilitarySystem.make_general(s, tag, int(nc["ruler"]["mil"])))
	GS.rebuild_caches(s)
	SimExt.ensure_country(s, tag)
	s["ai"][tag] = AISystem.new_ai_state(s, tag, "")
	Mods.invalidate(s)
	TradeSystem.invalidate(s)
	EconomySystem.invalidate_calc(s)
	return tag

## --- civil war -------------------------------------------------------------------------------------------------------------------
static func _bfs_dist(s: Dictionary, parent: String, start: String) -> Dictionary:
	var dist := {start: 0}
	var q: Array = [start]
	var qi := 0
	while qi < q.size():
		var u: String = q[qi]
		qi += 1
		for nb in Defs.neighbors(u):
			if not dist.has(nb) and s["provinces"][nb]["owner"] == parent:
				dist[nb] = int(dist[u]) + 1
				q.append(nb)
	return dist

static func pick_split(s: Dictionary, parent: String, rng: GameRng) -> Array:
	var pc: Dictionary = s["countries"][parent]
	var cap: String = str(pc["capital"])
	var owned := GS.owned(s, parent)
	var dist := _bfs_dist(s, parent, cap)
	var seeds: Array = []
	for pid in owned:
		if pid == cap or s["provinces"][pid]["controller"] != parent:
			continue
		seeds.append([float(s["provinces"][pid]["unrest"]) + 8.0 * float(dist.get(pid, 12)) + rng.randf() * 3.0, pid])
	seeds.sort_custom(func(x, y): return x[0] > y[0])
	var want := maxi(2, int(round(float(owned.size()) * rng.randf_range(0.35, 0.5))))
	var best_cluster: Array = []
	for sd in seeds.slice(0, 8):
		var cluster: Array = [sd[1]]
		var qi := 0
		while qi < cluster.size() and cluster.size() < want:
			var u: String = cluster[qi]
			qi += 1
			for nb in Defs.neighbors(u):
				if cluster.size() >= want:
					break
				var p: Dictionary = s["provinces"][nb]
				if nb != cap and p["owner"] == parent and p["controller"] == parent and nb not in cluster:
					cluster.append(nb)
		if cluster.size() > best_cluster.size():
			best_cluster = cluster
		if cluster.size() >= want:
			break
	return best_cluster

static func can_start(s: Dictionary, cid: String) -> bool:
	var c: Dictionary = s["countries"][cid]
	return GS.owned(s, cid).size() >= 4 and not bool(c.get("native", false)) and int(FactionsSystem.st(c)["civil_cool"]) <= int(s["turn"])

static func start(s: Dictionary, cid: String, reason: String, faction: String, leader: String, rng: GameRng) -> String:
	if not can_start(s, cid):
		return ""
	var c: Dictionary = s["countries"][cid]
	var pids := pick_split(s, cid, rng)
	if pids.is_empty():
		return ""
	var gov := str(c["gov"]) if reason in ["succession", "clan_split"] or faction == "court" else str(REBEL_GOV.get(faction, c["gov"]))
	var en := "%s (Rebels)" % str((c["name"] as Dictionary).get("en", cid))
	var tr_n := "%s (İsyancılar)" % str((c["name"] as Dictionary).get("tr", cid))
	var tag := spawn_country(s, cid, pids, gov, en, tr_n, leader, rng, "C")
	var nc: Dictionary = s["countries"][tag]
	nc["civil_war_of"] = cid
	FactionsSystem.st(nc)["f"][faction if faction in FactionsSystem.FACTIONS else "military"]["loy"] = 85.0
	var wid := DiplomacySystem.start_war(s, [tag], [cid], "civil_war", [], true)
	s["wars"][wid]["civil"] = true
	GS.add_opinion(s, cid, tag, -100.0)
	GS.add_opinion(s, tag, cid, -100.0)
	var fs := FactionsSystem.st(c)
	fs["civil_cool"] = int(s["turn"]) + 40
	c["stability"] = clampf(float(c["stability"]) + 8.0, 0.0, 100.0)   # the loyalists rally
	c["legitimacy"] = maxf(10.0, float(c["legitimacy"]) - 5.0)
	for fid in FactionsSystem.FACTIONS:
		FactionsSystem.shift_loyalty(c, fid, 8.0)
	c["civil_war"] = {"with": tag, "turn": int(s["turn"]), "reason": reason}
	GS.note(s, cid, "uprising", "NOTE_CIVIL_WAR", {"other": tag, "reason": reason})
	GS.history(s, cid, "uprising", "HIST_CIVIL_WAR", {"other": tag})
	for oid in GS.alive_countries(s):
		if oid != cid and oid != tag:
			GS.note(s, oid, "world", "NOTE_CIVIL_WAR_ABROAD", {"country": cid})
	GS.stat_add(s, cid, "civil_wars", 1.0)
	return tag

## --- independence movements ------------------------------------------------------------------------------------------------------------
static func movement_growth(s: Dictionary, cid: String, pid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var p: Dictionary = s["provinces"][pid]
	var parts := {}
	if p["culture"] != c["culture"]:
		parts["MOVE_CULTURE"] = 0.8
	if p["religion"] != c["religion"]:
		parts["MOVE_RELIGION"] = 0.5
	if cid not in p["cores"]:
		parts["MOVE_NOT_CORE"] = 0.5
	if int(s["turn"]) - int(p.get("conquered_turn", -999)) < 40:
		parts["MOVE_CONQUERED"] = 0.5
	if parts.is_empty():
		return {"total": 0.0, "parts": parts}
	parts["MOVE_UNREST"] = (float(p["unrest"]) - 35.0) * 0.05
	parts["MOVE_STABILITY"] = -(float(c["stability"]) - 50.0) * 0.02
	var garrison := 0.0
	for aid in GS.armies_at(s, pid):
		var a: Dictionary = s["armies"][aid]
		if a["owner"] == cid and not a.get("naval", false):
			garrison += UnitUtil.army_size(a)
	parts["MOVE_GARRISON"] = -minf(garrison * 0.8, 3.0)
	var total := 0.0
	for k in parts:
		total += float(parts[k])
	if str(FactionsSystem.politics_of(c).get("mech", "")) == "governors":
		total *= 1.4
	return {"total": total, "parts": parts}

static func process_turn(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	if bool(c.get("native", false)):
		return
	var fs := FactionsSystem.st(c)
	var move: Dictionary = fs["move"]
	var freed := ""
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		if p["controller"] != cid:
			continue
		if p["culture"] == c["culture"] and p["religion"] == c["religion"] and cid in p["cores"] and not move.has(pid):
			continue
		if float(p["unrest"]) < 20.0 and not move.has(pid):
			continue
		var g := float(movement_growth(s, cid, pid)["total"])
		var cur := float(move.get(pid, 0.0))
		cur = clampf(cur + (g if g > 0.0 else -1.0), 0.0, 120.0)
		if cur <= 0.0:
			move.erase(pid)
			continue
		move[pid] = cur
		if cur >= MOVE_RISING and float(p["unrest"]) > 55.0 and rng.chance(0.15) and not _rebels_in(s, pid) and pid != c["capital"]:
			MilitarySystem.spawn_rebels(s, pid, 2.0)
			GS.note(s, cid, "uprising", "NOTE_INDEPENDENCE_RISING", {"province": pid}, pid)
		if cur >= MOVE_FREE and freed == "" and pid != c["capital"] and GS.owned(s, cid).size() > 2:
			freed = pid
	if freed != "":
		declare_independence(s, cid, freed, rng)
	_vassal_independence(s, cid, rng)

static func _rebels_in(s: Dictionary, pid: String) -> bool:
	for aid in GS.armies_at(s, pid):
		if s["armies"][aid]["owner"] == "REB":
			return true
	return false

static func declare_independence(s: Dictionary, cid: String, pid: String, rng: GameRng) -> String:
	var c: Dictionary = s["countries"][cid]
	var fs := FactionsSystem.st(c)
	var pids: Array = [pid]
	for nb in Defs.neighbors(pid):
		var p: Dictionary = s["provinces"][nb]
		if pids.size() < 4 and p["owner"] == cid and p["controller"] == cid and nb != c["capital"] and float(fs["move"].get(nb, 0.0)) >= 25.0 and p["culture"] == s["provinces"][pid]["culture"]:
			pids.append(nb)
	var year := int(GS.date_of(s)["year"])
	var gov := "feudal_kingdom" if year < 1700 else "republic"
	var pn := Defs.province_name(pid)
	var tag := spawn_country(s, cid, pids, gov, "Free " + pn, "Özgür " + pn, "", rng, "I")
	for q in pids:
		fs["move"].erase(q)
	var wid := DiplomacySystem.start_war(s, [tag], [cid], "independence", [], true)
	s["wars"][wid]["civil"] = true
	GS.add_opinion(s, cid, tag, -80.0)
	GS.add_opinion(s, tag, cid, -80.0)
	GS.note(s, cid, "uprising", "NOTE_INDEPENDENCE", {"other": tag})
	GS.history(s, cid, "uprising", "HIST_INDEPENDENCE", {"other": tag})
	GS.stat_add(s, cid, "secessions", 1.0)
	return tag

## vassals that despise their overlord and are not much weaker break away
static func _vassal_independence(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var ov: String = str(c.get("overlord", ""))
	if ov == "" or str(c.get("union_with", "")) == ov or not s["countries"].get(ov, {}).get("alive", false):
		return
	if int(s["turn"]) - int(c.get("vassal_since", 0)) < 12 or int(s["turn"]) % 2 != 0:
		return
	var op := GS.opinion(s, cid, ov)
	if op > -30.0:
		return
	var ratio := DiplomacySystem.power_score(s, cid) / maxf(DiplomacySystem.power_score(s, ov), 1.0)
	var p := 0.015 * clampf(-op / 60.0, 0.3, 2.0) * clampf(ratio * 2.0, 0.2, 2.0)
	if rng.chance(p):
		c["overlord"] = ""
		var wid := DiplomacySystem.start_war(s, [cid], [ov], "independence", [], true)
		s["wars"][wid]["civil"] = true
		GS.note(s, ov, "diplomacy", "NOTE_VASSAL_REVOLT", {"other": cid})
		GS.history(s, cid, "diplomacy", "HIST_VASSAL_REVOLT", {"other": ov})
		Mods.invalidate(s)

## --- rebel-held provinces become states -------------------------------------------------------------------------------------------------
static func process_rebel_holds(s: Dictionary, rng: GameRng) -> void:
	var hold: Dictionary = s["rebel_hold"]
	var now := {}
	for aid in s["armies"]:
		var a: Dictionary = s["armies"][aid]
		if a["owner"] == "REB" and a["loc"] != "":
			var p: Dictionary = s["provinces"][a["loc"]]
			if p["controller"] == "REB" and p["owner"] != "REB" and p["owner"] != "":
				now[a["loc"]] = true
	for pid in hold.keys():
		if not now.has(pid):
			hold.erase(pid)
	for pid in Util.sorted_keys(now):
		if not hold.has(pid):
			hold[pid] = int(s["turn"])
			continue
		if int(s["turn"]) - int(hold[pid]) >= REB_HOLD_TURNS:
			var p: Dictionary = s["provinces"][pid]
			var owner: String = p["owner"]
			if not s["countries"].get(owner, {}).get("alive", false) or GS.owned(s, owner).size() <= 2 or pid == s["countries"][owner]["capital"]:
				continue
			hold.erase(pid)
			declare_independence(s, owner, pid, rng)
			return
