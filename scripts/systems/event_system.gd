class_name EventSystem
extends RefCounted
## Data-driven events (res://data/events/*.json). Conditions and effects are interpreted here; no
## event is hard-coded in gameplay scripts. Historical events are flagged and shown differently
## from randomly generated ones.

static func _cond(s: Dictionary, cid: String, c: Dictionary, cond: Dictionary, pid: String = "") -> bool:
	var v: Variant = cond.get("value", 0)
	var t: String = cond.get("type", "")
	var cc: Dictionary = s["countries"][cid]
	var d := GS.date_of(s)
	match t:
		"stability_below": return float(cc["stability"]) < float(v)
		"stability_above": return float(cc["stability"]) > float(v)
		"legitimacy_below": return float(cc["legitimacy"]) < float(v)
		"legitimacy_above": return float(cc["legitimacy"]) > float(v)
		"treasury_below": return float(cc["gold"]) < float(v)
		"treasury_above": return float(cc["gold"]) > float(v)
		"debt_above": return float(cc["debt"]) > float(v)
		"income_below": return float(cc.get("budget", {}).get("income", 0.0)) < float(v)
		"income_above": return float(cc.get("budget", {}).get("income", 0.0)) > float(v)
		"at_war": return not GS.wars_of(s, cid).is_empty()
		"not_at_war": return GS.wars_of(s, cid).is_empty()
		"at_war_with": return GS.at_war(s, cid, str(cond.get("tag", "")))
		"gov_is": return cc["gov"] == str(v)
		"gov_in": return cc["gov"] in cond.get("values", [])
		"has_tech": return TechSystem.level(cc, str(cond.get("line", ""))) >= int(cond.get("level", 1))
		"tech_avg_above": return TechSystem.avg_level(cc) > float(v)
		"provinces_above": return GS.owned(s, cid).size() > int(v)
		"provinces_below": return GS.owned(s, cid).size() < int(v)
		"food_ratio_below": return float(cc.get("food_ratio", 1.0)) < float(v)
		"food_stock_below": return float(cc["stock"]["food"]) < float(v)
		"religion_is": return cc["religion"] == str(v)
		"culture_is": return cc["culture"] == str(v)
		"flag_set": return flag_active(s, cc, str(cond.get("flag", "")))
		"flag_not_set": return not flag_active(s, cc, str(cond.get("flag", "")))
		"year_at_least": return int(d["year"]) >= int(v)
		"year_before": return int(d["year"]) < int(v)
		"is_player": return cid in s["players"]
		"is_ai": return cid not in s["players"]
		"ruler_age_above": return float(cc["ruler"]["age"]) > float(v)
		"ruler_skill_below": return float(cc["ruler"].get(str(cond.get("skill", "adm")), 5)) < float(v)
		"ruler_skill_above": return float(cc["ruler"].get(str(cond.get("skill", "adm")), 5)) > float(v)
		"prestige_above": return float(cc["prestige"]) > float(v)
		"prestige_below": return float(cc["prestige"]) < float(v)
		"manpower_below": return float(cc["manpower"]) < float(v)
		"has_reform": return str(v) in cc["reforms"]
		"war_exhaustion_above": return float(cc["war_exhaustion"]) > float(v)
		"season_is": return ["spring", "summer", "autumn", "winter"][GS.season_idx(int(d["month"]))] == str(v)
		"class_sat_below": return float(cc["classes"].get(str(cond.get("class", "peasants")), {}).get("sat", 50.0)) < float(cond.get("value", 40))
		"is_vassal": return cc["overlord"] != ""
		"has_vassals": return not GS.vassals_of(s, cid).is_empty()
		"alliances_at_least":
			var n := 0
			for oid in GS.alive_countries(s):
				if oid != cid and GS.allied(s, cid, oid):
					n += 1
			return n >= int(v)
		"owns_province": return s["provinces"].get(str(v), {}).get("owner", "") == cid
		"neighbors_tag": return DiplomacySystem.borders(s, cid, str(v))
		"armies_at_least": return GS.armies_of(s, cid).size() >= int(v)
		"inflation_above": return float(cc["inflation"]) > float(v)
		"bankrupt_recently": return int(cc["bankrupt_turns"]) > 0
		"heir_missing": return cc["heir"] == null
		"capital_coastal": return Defs.provinces.get(cc["capital"], {}).get("coastal", false)
	return FactionsSystem.event_cond(s, cid, t, cond)

static func flag_active(s: Dictionary, cc: Dictionary, flag: String) -> bool:
	if not cc["flags"].has(flag):
		return false
	var u := int(cc["flags"][flag])
	return u == -1 or u >= int(s["turn"])

static func _pcond(s: Dictionary, cid: String, pid: String, cond: Dictionary) -> bool:
	var p: Dictionary = s["provinces"][pid]
	var pd: Dictionary = Defs.provinces[pid]
	var v: Variant = cond.get("value", 0)
	match cond.get("type", ""):
		"unrest_above": return float(p["unrest"]) > float(v)
		"unrest_below": return float(p["unrest"]) < float(v)
		"pop_above": return float(p["pop"]) > float(v)
		"pop_below": return float(p["pop"]) < float(v)
		"terrain_is": return pd["terrain"] == str(v)
		"coastal": return bool(pd["coastal"])
		"culture_is": return p["culture"] == str(v)
		"religion_is": return p["religion"] == str(v)
		"religion_differs": return p["religion"] != s["countries"][cid]["religion"]
		"has_building": return p["buildings"].has(str(v))
		"dev_below": return float(p["dev"]) < float(v)
		"dev_above": return float(p["dev"]) > float(v)
		"devastation_above": return float(p["devastation"]) > float(v)
		"occupied": return p["controller"] != p["owner"]
	return false

static func conds_ok(s: Dictionary, cid: String, conds: Array) -> bool:
	for c in conds:
		if not _cond(s, cid, c, c):
			return false
	return true

static func _date_num(d: Dictionary) -> int:
	return int(d.get("year", 0)) * 12 + int(d.get("month", 1)) - 1

static func eligible(s: Dictionary, cid: String, e: Dictionary) -> bool:
	var tr: Dictionary = e.get("trigger", {})
	if tr.has("scenarios") and s["scenario"] not in tr["scenarios"]:
		return false
	if tr.has("countries") and cid not in tr["countries"]:
		return false
	if int(s["turn"]) < int(tr.get("min_turn", 0)):
		return false
	var d := GS.date_of(s)
	var now := _date_num(d)
	if tr.has("date_from") and now + 2 < _date_num(tr["date_from"]):
		return false
	if tr.has("date_to") and now > _date_num(tr["date_to"]):
		return false
	var key: String = str(e["id"]) + "|" + cid
	var fired: Dictionary = s["events"]["fired"]
	if fired.has(key):
		if bool(e.get("once", false)) or bool(e.get("historical", false)):
			return false
		if int(s["turn"]) - int(fired[key]) < int(e.get("cooldown", 20)):
			return false
	return conds_ok(s, cid, tr.get("conds", []))

static func pick_province(s: Dictionary, cid: String, e: Dictionary, rng: GameRng) -> String:
	var cands: Array = []
	for pid in GS.owned(s, cid):
		var ok := true
		for pc in e.get("pconds", []):
			if not _pcond(s, cid, pid, pc):
				ok = false
				break
		if ok:
			cands.append(pid)
	if cands.is_empty():
		return ""
	return str(rng.pick(cands))

static func process_turn(s: Dictionary) -> void:
	var rng := GS.rng_of(s)
	var evs: Array = []
	var now := _date_num(GS.date_of(s))
	for id in Util.sorted_keys(Defs.events):
		var e: Dictionary = Defs.events[id]
		var tr: Dictionary = e.get("trigger", {})
		if tr.has("scenarios") and s["scenario"] not in tr["scenarios"]:
			continue
		if tr.has("date_from") and now + 2 < _date_num(tr["date_from"]):
			continue
		if tr.has("date_to") and now > _date_num(tr["date_to"]):
			continue
		evs.append(e)
	# queued follow-up events first
	var q: Array = s["events"]["queue"]
	s["events"]["queue"] = []
	for item in q:
		if Defs.events.has(item["id"]) and s["countries"].get(item["cid"], {}).get("alive", false):
			_fire(s, item["cid"], Defs.events[item["id"]], rng, "")
	for cid in GS.alive_countries(s):
		var c: Dictionary = s["countries"][cid]
		if c.get("native", false):
			continue
		var fired_this := false
		var random_turn := (int(s["turn"]) + hash(cid)) % 3 == 0
		for e in evs:
			var hist := bool(e.get("historical", false))
			if (fired_this or not random_turn) and not hist:
				continue
			if not eligible(s, cid, e):
				continue
			var mtth := float(e.get("mtth", 60))
			var p := 1.0 if mtth <= 1.0 else 1.0 - exp(-3.0 / mtth)
			if rng.chance(p):
				var pid := ""
				if e.get("scope", "country") == "province":
					pid = pick_province(s, cid, e, rng)
					if pid == "":
						continue
				_fire(s, cid, e, rng, pid)
				if not bool(e.get("historical", false)):
					fired_this = true

static func _other_for(s: Dictionary, cid: String, e: Dictionary, rng: GameRng) -> String:
	# the "other" country used in text and relation effects
	var nbs: Array = []
	for pid in GS.owned(s, cid):
		for nb in Defs.neighbors(pid):
			var o: String = s["provinces"][nb]["owner"]
			if o != cid and o != "" and o != "REB" and o not in nbs and s["countries"][o]["alive"]:
				nbs.append(o)
	nbs.sort()
	var en := GS.enemies_of(s, cid)
	for ef in e.get("options", []):
		for fx in ef.get("effects", []):
			if fx.get("type") == "relation" and fx.get("target") == "enemy" and not en.is_empty():
				return str(rng.pick(en))
	if nbs.is_empty():
		return ""
	return str(rng.pick(nbs))

static func _fire(s: Dictionary, cid: String, e: Dictionary, rng: GameRng, pid: String) -> void:
	s["events"]["fired"][str(e["id"]) + "|" + cid] = s["turn"]
	var entry := {"uid": "%s@%d@%s" % [e["id"], int(s["turn"]), cid], "id": e["id"], "cid": cid, "pid": pid, "other": _other_for(s, cid, e, rng), "turn": s["turn"]}
	GS.stat_add(s, cid, "events", 1.0)
	if cid in s["players"]:
		s["events"]["pending"].append(entry)
		GS.note(s, cid, "event", "NOTE_EVENT", {"event": e["id"]})
	else:
		var opts := available_options(s, entry)
		if opts.is_empty():
			return
		var weights: Array = []
		for o in opts:
			weights.append(float(o.get("ai_weight", 1.0)))
		var pick: Variant = Util.weighted_pick(rng, opts, weights)
		if pick != null:
			apply_option(s, entry, str(pick["id"]))

static func available_options(s: Dictionary, entry: Dictionary) -> Array:
	var e: Dictionary = Defs.events.get(entry["id"], {})
	var out: Array = []
	for o in e.get("options", []):
		if conds_ok(s, entry["cid"], o.get("requires", [])):
			out.append(o)
	return out

static func render(s: Dictionary, entry: Dictionary, field: Variant) -> String:
	var txt := Loc.tx(field)
	var c: Dictionary = s["countries"][entry["cid"]]
	txt = txt.replace("{country}", GS.country_name(s, entry["cid"]))
	txt = txt.replace("{ruler}", str(c["ruler"]["name"]))
	txt = txt.replace("{province}", Defs.province_name_in(s, entry["pid"]) if entry["pid"] != "" else Defs.province_name_in(s, c["capital"]))
	txt = txt.replace("{other}", GS.country_name(s, entry["other"]) if entry["other"] != "" else "?")
	return txt

static func apply_option(s: Dictionary, entry: Dictionary, option_id: String) -> bool:
	var e: Dictionary = Defs.events.get(entry["id"], {})
	for o in e.get("options", []):
		if o["id"] == option_id:
			if not conds_ok(s, entry["cid"], o.get("requires", [])):
				return false
			for fx in o["effects"]:
				apply_effect(s, entry, fx)
			GS.history(s, entry["cid"], "event", "HIST_EVENT", {"event": e["id"], "option": option_id, "historical": bool(e.get("historical", false))})
			var pend: Array = s["events"]["pending"]
			for i in range(pend.size()):
				if pend[i]["uid"] == entry["uid"]:
					pend.remove_at(i)
					break
			Mods.invalidate(s)
			return true
	return false

static func apply_effect(s: Dictionary, entry: Dictionary, fx: Dictionary) -> void:
	var cid: String = entry["cid"]
	var c: Dictionary = s["countries"][cid]
	var v: Variant = fx.get("value", 0)
	var rng := GS.rng_of(s)
	if FactionsSystem.event_effect(s, cid, str(fx.get("type", "")), fx):
		return
	match fx.get("type", ""):
		"gold": c["gold"] = float(c["gold"]) + float(v)
		"manpower": c["manpower"] = clampf(float(c["manpower"]) + float(v), 0.0, maxf(float(c["manpower_max"]), 1.0) * 1.2)
		"stability": c["stability"] = clampf(float(c["stability"]) + float(v), 0.0, 100.0)
		"legitimacy": c["legitimacy"] = clampf(float(c["legitimacy"]) + float(v), 0.0, 100.0)
		"prestige": c["prestige"] = float(c["prestige"]) + float(v)
		"admin": c["admin"] = maxf(0.0, float(c["admin"]) + float(v))
		"inflation": c["inflation"] = clampf(float(c["inflation"]) + float(v), 0.0, 0.9)
		"debt": c["debt"] = maxf(0.0, float(c["debt"]) + float(v))
		"stock":
			var rs := str(fx.get("res", "food"))
			if c["stock"].has(rs):
				c["stock"][rs] = maxf(0.0, float(c["stock"][rs]) + float(v))
		"set_flag":
			var turns := int(fx.get("turns", -1))
			c["flags"][str(fx.get("flag", ""))] = (int(s["turn"]) + turns) if turns > 0 else -1
		"clear_flag": c["flags"].erase(str(fx.get("flag", "")))
		"temp_mod":
			c["temp_mods"].append({"mods": fx.get("mods", {}), "until": int(s["turn"]) + int(fx.get("turns", 8)), "key": entry["id"]})
		"class_sat":
			var cl := str(fx.get("class", "peasants"))
			if c["classes"].has(cl):
				c["classes"][cl]["sat"] = clampf(float(c["classes"][cl]["sat"]) + float(v), 0.0, 100.0)
		"pop_pct":
			for pid in GS.owned(s, cid):
				s["provinces"][pid]["pop"] = maxf(5.0, float(s["provinces"][pid]["pop"]) * (1.0 + float(v) / 100.0))
		"province_unrest":
			if entry["pid"] != "":
				s["provinces"][entry["pid"]]["unrest"] = clampf(float(s["provinces"][entry["pid"]]["unrest"]) + float(v), 0.0, 100.0)
			else:
				for pid in GS.owned(s, cid):
					s["provinces"][pid]["unrest"] = clampf(float(s["provinces"][pid]["unrest"]) + float(v), 0.0, 100.0)
		"province_pop_pct":
			if entry["pid"] != "":
				s["provinces"][entry["pid"]]["pop"] = maxf(5.0, float(s["provinces"][entry["pid"]]["pop"]) * (1.0 + float(v) / 100.0))
		"province_devastation":
			if entry["pid"] != "":
				s["provinces"][entry["pid"]]["devastation"] = clampf(float(s["provinces"][entry["pid"]]["devastation"]) + float(v), 0.0, 0.9)
		"province_dev":
			if entry["pid"] != "":
				s["provinces"][entry["pid"]]["dev"] = clampf(float(s["provinces"][entry["pid"]]["dev"]) + float(v), 0.2, 10.0)
		"add_building":
			var pid2: String = entry["pid"] if entry["pid"] != "" else c["capital"]
			var bid := str(fx.get("bid", ""))
			if Defs.buildings.has(bid) and s["provinces"][pid2]["owner"] == cid:
				var lvl := int(s["provinces"][pid2]["buildings"].get(bid, 0))
				if lvl < int(Defs.buildings[bid]["max_level"]):
					s["provinces"][pid2]["buildings"][bid] = lvl + 1
		"destroy_building":
			var pid3: String = entry["pid"] if entry["pid"] != "" else str(rng.pick(GS.owned(s, cid)))
			var pb: Dictionary = s["provinces"][pid3]["buildings"]
			var bid2 := str(fx.get("bid", ""))
			if bid2 == "" and not pb.is_empty():
				var ks: Array = pb.keys()
				ks.sort()
				bid2 = str(rng.pick(ks))
			if pb.has(bid2):
				ConstructionSystem.demolish(s, cid, pid3, bid2)
		"ruler_skill":
			var sk := str(fx.get("skill", "adm"))
			c["ruler"][sk] = clampi(int(c["ruler"].get(sk, 5)) + int(v), 1, 9)
		"kill_ruler": PoliticsSystem.ruler_dies(s, cid, rng)
		"spawn_rebels":
			var rp: String = entry["pid"]
			if rp == "":
				var bu := -1.0
				for pid4 in GS.owned(s, cid):
					if float(s["provinces"][pid4]["unrest"]) > bu:
						bu = float(s["provinces"][pid4]["unrest"])
						rp = pid4
			if rp != "":
				MilitarySystem.spawn_rebels(s, rp, float(fx.get("size", 2)))
		"relation":
			var tgt := str(fx.get("target", "random_neighbor"))
			var other := ""
			if tgt in ["random_neighbor", "enemy"]:
				other = entry["other"]
			elif s["countries"].has(tgt):
				other = tgt
			if other != "" and s["countries"].has(other):
				GS.add_opinion(s, other, cid, float(v))
				GS.add_opinion(s, cid, other, float(v) * 0.5)
		"research_points":
			c["research"]["bank"] = float(c["research"].get("bank", 0.0)) + float(v)
		"add_claim":
			var tg := str(fx.get("target", ""))
			if tg == "random_neighbor" or tg == "":
				tg = entry["other"]
			if s["countries"].has(tg):
				var cp := str(fx.get("province", ""))
				var cand: Array = []
				if cp != "" and s["provinces"].has(cp):
					cand.append(cp)
				else:
					for pid5 in GS.owned(s, tg):
						for nb in Defs.neighbors(pid5):
							if s["provinces"][nb]["owner"] == cid:
								cand.append(pid5)
								break
				if not cand.is_empty():
					var pick := str(rng.pick(cand))
					if cid not in s["provinces"][pick]["claims"]:
						s["provinces"][pick]["claims"].append(cid)
		"trigger_event":
			s["events"]["queue"].append({"id": str(fx.get("id", "")), "cid": cid})
		"disband_pct":
			for aid in GS.armies_of(s, cid):
				var a: Dictionary = s["armies"][aid]
				for uid in a["units"].keys():
					a["units"][uid] = float(a["units"][uid]) * (1.0 - float(v) / 100.0)
					a["target"][uid] = float(a["target"].get(uid, 0.0)) * (1.0 - float(v) / 100.0)
				if UnitUtil.army_size(a) < 0.3:
					MilitarySystem.disband_army(s, aid)
		"add_regiments":
			var uid2 := str(fx.get("unit", ""))
			if Defs.units.has(uid2):
				var loc: String = entry["pid"] if entry["pid"] != "" else c["capital"]
				if s["provinces"][loc]["owner"] != cid:
					loc = c["capital"]
				MilitarySystem.create_army(s, cid, loc, {uid2: float(fx.get("n", 1))}, null)
		"war_exhaustion": c["war_exhaustion"] = clampf(float(c["war_exhaustion"]) + float(v), 0.0, 100.0)
		"reform_cost_free": c["admin"] = float(c["admin"]) + 60.0
		"change_religion_province":
			if entry["pid"] != "":
				var rv := str(v)
				s["provinces"][entry["pid"]]["religion"] = c["religion"] if rv == "state" else rv
