class_name VictorySystem
extends RefCounted
## Victory conditions, objectives, scoring and campaign statistics snapshots.

const HOLD_TURNS := 16
## Standard victories cannot trigger before this turn (or a quarter of the campaign, if longer).
const MIN_VICTORY_TURN := 60

static func total_provinces(s: Dictionary) -> int:
	return Defs.province_ids.size()

static func major(s: Dictionary, cid: String) -> bool:
	var c: Dictionary = s["countries"][cid]
	return c["alive"] and not c.get("native", false) and cid != "REB"

static func income_of(s: Dictionary, cid: String) -> float:
	return float(s["countries"][cid].get("budget", {}).get("income", 0.0))

static func bloc_share(s: Dictionary, cid: String) -> float:
	var members := [cid]
	for v in GS.vassals_of(s, cid):
		members.append(v)
	for oid in GS.alive_countries(s):
		if oid != cid and GS.allied(s, cid, oid):
			members.append(oid)
			for v2 in GS.vassals_of(s, oid):
				members.append(v2)
	var mine := 0.0
	var all := 0.0
	var pwc: Dictionary = s["_c"].get("bloc_pw", {})
	if pwc.is_empty():
		for oid in GS.alive_countries(s):
			pwc[oid] = DiplomacySystem.total_pop(s, oid) * 0.05 + income_of(s, oid)
		s["_c"]["bloc_pw"] = pwc
	for oid in GS.alive_countries(s):
		var pw: float = float(pwc.get(oid, 0.0))
		all += pw
		if oid in members:
			mine += pw
	return mine / maxf(all, 1.0)

static func cfg(s: Dictionary, key: String, default: Variant) -> Variant:
	return s.get("victory_cfg", {}).get(key, default)

## Returns progress per victory type for display: {type: {value, target, done}}
static func progress(s: Dictionary, cid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var n := GS.owned(s, cid).size()
	var pct := float(n) / float(total_provinces(s))
	var tgt_pct := float(cfg(s, "territory_pct", 0.22))
	var inc := income_of(s, cid)
	var second := 0.0
	var world_inc := 0.0
	for oid in GS.alive_countries(s):
		world_inc += maxf(0.0, income_of(s, oid))
		if oid != cid and major(s, oid):
			second = maxf(second, income_of(s, oid))
	var econ_ratio := inc / maxf(second, 1.0)
	var econ_share := inc / maxf(world_inc, 1.0)
	var tech := TechSystem.avg_level(c)
	var tech_second := 0.0
	for oid2 in GS.alive_countries(s):
		if oid2 != cid and major(s, oid2):
			tech_second = maxf(tech_second, TechSystem.avg_level(s["countries"][oid2]))
	var tech_done := tech >= float(cfg(s, "tech_avg", 3.8)) and tech - tech_second >= 0.5
	var bloc := bloc_share(s, cid)
	var hold: Dictionary = c.get("victory_hold", {})
	return {
		"territory": {"value": pct, "target": tgt_pct, "done": pct >= tgt_pct, "hold": int(hold.get("territory", 0))},
		"economic": {"value": econ_share, "target": float(cfg(s, "econ_share", 0.4)), "done": econ_share >= float(cfg(s, "econ_share", 0.4)) and econ_ratio >= 3.0 and inc > 80.0, "hold": int(hold.get("economic", 0))},
		"diplomatic": {"value": bloc, "target": float(cfg(s, "bloc_share", 0.55)), "done": bloc >= float(cfg(s, "bloc_share", 0.55)), "hold": int(hold.get("diplomatic", 0))},
		"technological": {"value": tech, "target": float(cfg(s, "tech_avg", 3.8)), "done": tech_done, "hold": int(hold.get("technological", 0))},
	}

static func check_objective(s: Dictionary, cid: String, ob: Dictionary) -> bool:
	var c: Dictionary = s["countries"][cid]
	match str(ob.get("type", "")):
		"own_provinces":
			var n := 0
			for pid in GS.owned(s, cid):
				for pat in ob.get("provinces", []):
					if Util.glob_match(str(pat), pid):
						n += 1
						break
			return n >= int(ob.get("count", 1))
		"own_all":
			for pat in ob.get("provinces", []):
				for pid in Defs.province_ids:
					if Util.glob_match(str(pat), pid) and s["provinces"][pid]["owner"] != cid:
						return false
			return true
		"provinces_count": return GS.owned(s, cid).size() >= int(ob.get("count", 1))
		"tech_avg": return TechSystem.avg_level(c) >= float(ob.get("level", 1))
		"treasury": return float(c["gold"]) >= float(ob.get("amount", 0))
		"survive_until": return int(s["turn"]) >= int(ob.get("turn", 0)) and c["alive"]
		"alliance_with": return GS.allied(s, cid, str(ob.get("target", "")))
		"vassalize": return s["countries"].get(str(ob.get("target", "")), {}).get("overlord", "") == cid
		"destroy": return not s["countries"].get(str(ob.get("target", "")), {"alive": true})["alive"]
		"capital_of":
			var pid2 := str(ob.get("province", ""))
			return s["provinces"].get(pid2, {}).get("owner", "") == cid
		"wars_won": return float(c["stats"].get("wars_won", 0.0)) >= float(ob.get("count", 1))
		"income": return income_of(s, cid) >= float(ob.get("amount", 0))
	return false

static func process_turn(s: Dictionary) -> void:
	# objectives (tracked for the player(s))
	for pl in s["players"]:
		if not s["countries"].get(pl, {}).get("alive", false):
			continue
		for ob in s["objectives"]:
			if ob.get("done", false):
				continue
			if check_objective(s, pl, ob):
				ob["done"] = true
				ob["done_turn"] = s["turn"]
				GS.note(s, pl, "objective", "NOTE_OBJECTIVE_DONE", {"obj": ob.get("id", "")})
				GS.history(s, pl, "objective", "HIST_OBJECTIVE", {"obj": ob.get("id", "")})
				s["countries"][pl]["prestige"] = float(s["countries"][pl]["prestige"]) + 20.0
			elif ob.has("by_turn") and int(s["turn"]) > int(ob["by_turn"]):
				ob["failed"] = true
	# standard victory conditions for every major power (AI too)
	var winner := ""
	var vtype := ""
	var min_turn := maxi(MIN_VICTORY_TURN, int(s.get("turn_limit", 0)) / 4)
	for cid in GS.alive_countries(s):
		if not major(s, cid) or (GS.owned(s, cid).size() < 8 and cid not in s["players"]):
			continue
		var c: Dictionary = s["countries"][cid]
		var pr := progress(s, cid)
		var hold: Dictionary = c.get("victory_hold", {})
		for t in pr:
			if pr[t]["done"] and int(s["turn"]) >= min_turn:
				hold[t] = int(hold.get(t, 0)) + 1
			else:
				hold[t] = 0
		c["victory_hold"] = hold
		var need := HOLD_TURNS if int(s["turn"]) >= min_turn else 9999
		for t in pr:
			if int(hold.get(t, 0)) >= need and winner == "":
				# vassals cannot win
				if c["overlord"] == "":
					winner = cid
					vtype = t
	if winner != "":
		_end_game(s, winner, vtype)
		return
	# scenario objectives flagged as victory
	for pl in s["players"]:
		var all_victory := true
		var any := false
		for ob in s["objectives"]:
			if ob.get("victory", false):
				any = true
				if not ob.get("done", false):
					all_victory = false
		if any and all_victory:
			_end_game(s, pl, "scenario")
			return
	# defeat
	for pl in s["players"]:
		if not s["countries"][pl]["alive"]:
			_end_game(s, "", "defeat")
			return
	# end of campaign
	if int(s["turn_limit"]) > 0 and int(s["turn"]) >= int(s["turn_limit"]):
		var best := ""
		var bs := -1.0
		for cid in GS.alive_countries(s):
			if major(s, cid):
				var sc: float = score(s, cid)["total"]
				if sc > bs:
					bs = sc
					best = cid
		var pl: String = s["player"]
		var surv := _survival_win(s, pl)
		_end_game(s, pl if surv else best, "survival" if surv else "score")

static func _survival_win(s: Dictionary, cid: String) -> bool:
	if not s["countries"][cid]["alive"] or s["countries"][cid]["overlord"] != "":
		return false
	var start_n := int(s["countries"][cid]["stats"].get("start_provinces", 99))
	return start_n <= 4

static func _end_game(s: Dictionary, winner: String, vtype: String) -> void:
	s["game_over"] = true
	s["winner"] = winner
	s["victory_type"] = vtype
	for pl in s["players"]:
		GS.note(s, pl, "game", "NOTE_GAME_OVER", {"winner": winner, "type": vtype})

## Final / running score with breakdown.
static func score(s: Dictionary, cid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var st: Dictionary = c["stats"]
	var parts := {}
	parts["SCORE_TERRITORY"] = float(GS.owned(s, cid).size()) * 12.0
	var devs := 0.0
	var pop := 0.0
	for pid in GS.owned(s, cid):
		devs += float(s["provinces"][pid]["dev"])
		pop += float(s["provinces"][pid]["pop"])
	parts["SCORE_DEVELOPMENT"] = devs * 3.0
	parts["SCORE_POPULATION"] = pop / 100.0
	parts["SCORE_ECONOMY"] = income_of(s, cid) * 1.5
	parts["SCORE_TECH"] = TechSystem.avg_level(c) * 60.0 + float(st.get("techs", 0.0)) * 3.0
	parts["SCORE_PRESTIGE"] = maxf(0.0, float(c["prestige"])) * 0.5
	parts["SCORE_MILITARY"] = float(st.get("battles_won", 0.0)) * 2.0 + float(st.get("wars_won", 0.0)) * 25.0
	parts["SCORE_DIPLOMACY"] = float(st.get("alliances", 0.0)) * 8.0 + float(GS.vassals_of(s, cid).size()) * 15.0 + float(st.get("countries_annexed", 0.0)) * 20.0
	var ob := 0.0
	for o in s["objectives"]:
		if o.get("done", false) and cid in s["players"]:
			ob += float(o.get("score", 100))
	parts["SCORE_OBJECTIVES"] = ob
	var total := 0.0
	for k in parts:
		total += float(parts[k])
	return {"total": total, "parts": parts}

## Record per-turn history snapshot for statistics / charts.
static func snapshot(s: Dictionary) -> void:
	if int(s["turn"]) % 2 != 0:
		return
	var st: Dictionary = s["stats"]
	if not st.has("series"):
		st["series"] = {}
	for pl in s["players"]:
		var c: Dictionary = s["countries"][pl]
		if not c["alive"]:
			continue
		var ser: Dictionary = st["series"]
		if not ser.has(pl):
			ser[pl] = {"turns": [], "provinces": [], "income": [], "pop": [], "army": [], "gold": [], "tech": []}
		var d: Dictionary = ser[pl]
		d["turns"].append(s["turn"])
		d["provinces"].append(GS.owned(s, pl).size())
		d["income"].append(snappedf(income_of(s, pl), 0.1))
		d["pop"].append(snappedf(DiplomacySystem.total_pop(s, pl), 1.0))
		d["army"].append(snappedf(UnitUtil.country_regiments(s, pl), 0.1))
		d["gold"].append(snappedf(float(c["gold"]), 1.0))
		d["tech"].append(snappedf(TechSystem.avg_level(c), 0.01))
		for k in d.keys():
			if (d[k] as Array).size() > 300:
				(d[k] as Array).pop_front()
