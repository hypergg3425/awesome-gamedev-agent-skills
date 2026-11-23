class_name TechSystem
extends RefCounted
## Research: three-way investment (research points, gold, time). Prerequisites are enforced.

static func level(c: Dictionary, line: String) -> int:
	return int(c.get("tech_level", {}).get(line, 0))

static func avg_level(c: Dictionary) -> float:
	var tl: Dictionary = c.get("tech_level", {})
	var tot := 0.0
	for line in Defs.tech_lines:
		tot += float(tl.get(line, 0))
	return tot / maxf(1.0, float(Defs.tech_lines.size()))

static func branch_level(c: Dictionary, branch: String) -> float:
	var tl: Dictionary = c.get("tech_level", {})
	var tot := 0.0
	var n := 0
	for line in Defs.tech_lines:
		if Defs.tech_lines[line]["branch"] == branch:
			tot += float(tl.get(line, 0))
			n += 1
	return tot / maxf(1.0, float(n))

static func grant(s: Dictionary, cid: String, tid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	var t: Dictionary = Defs.techs.get(tid, {})
	if t.is_empty():
		return
	c["researched"][tid] = true
	var ln: String = t["line"]
	c["tech_level"][ln] = maxi(int(c["tech_level"].get(ln, 0)), int(t["level"]))
	Mods.invalidate(s)

## Grant every tech up to `lv` in a line (used for scenario setup).
static func grant_line_to(s: Dictionary, cid: String, line: String, lv: int) -> void:
	for l in range(1, lv + 1):
		grant(s, cid, "%s_%d" % [line, l])

static func can_research(s: Dictionary, cid: String, tid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var t: Dictionary = Defs.techs.get(tid, {})
	if t.is_empty():
		return {"ok": false, "reason": "TECH_ERR_UNKNOWN"}
	if c["researched"].has(tid):
		return {"ok": false, "reason": "TECH_ERR_DONE"}
	for pre in t["prereq"]:
		if not c["researched"].has(pre):
			return {"ok": false, "reason": "TECH_ERR_PREREQ", "params": {"tech": Defs.tech_name(pre)}}
	var branch: String = t["branch"]
	var cur: String = str(c["research"]["current"].get(branch, ""))
	if cur != "" and cur != tid:
		return {"ok": false, "reason": "TECH_ERR_BUSY"}
	return {"ok": true}

static func cost_rp(s: Dictionary, cid: String, tid: String) -> float:
	var t: Dictionary = Defs.techs[tid]
	var c: Dictionary = s["countries"][cid]
	var base := float(t["cost_rp"])
	# catching up is cheaper, running ahead of the pack is costlier ("tech neighbourhood")
	var lvl := float(t["level"])
	var peers := _avg_peer_level(s, cid)
	var ahead := lvl - 1.0 - peers
	var m := 1.0 + clampf(ahead * 0.12, -0.25, 0.5)
	if c.get("gov", "") == "tribal_confederation":
		m *= 1.15
	return base * m

static func _avg_peer_level(s: Dictionary, cid: String) -> float:
	if s["_c"].has("peer_level") and int(s["_c"].get("peer_turn", -1)) == int(s["turn"]):
		return float(s["_c"]["peer_level"])
	var tot := 0.0
	var n := 0
	for oid in s["countries"]:
		var o: Dictionary = s["countries"][oid]
		if o.get("alive", false) and not str(oid).begins_with("NAT_"):
			tot += avg_level(o)
			n += 1
	var v := tot / maxf(1.0, float(n))
	s["_c"]["peer_level"] = v
	s["_c"]["peer_turn"] = s["turn"]
	return v

static func start_research(s: Dictionary, cid: String, tid: String) -> Dictionary:
	var chk := can_research(s, cid, tid)
	if not chk["ok"]:
		return chk
	var c: Dictionary = s["countries"][cid]
	var t: Dictionary = Defs.techs[tid]
	var gold := float(t["cost_gold"]) * (1.0 + float(c.get("inflation", 0.0)))
	if float(c["gold"]) < gold:
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(gold)}}
	c["gold"] = float(c["gold"]) - gold
	c["research"]["current"][t["branch"]] = tid
	if not c["research"]["progress"].has(tid):
		c["research"]["progress"][tid] = 0.0
	return {"ok": true}

## Research points produced per turn for the country (before allocation).
static func points(s: Dictionary, cid: String) -> float:
	var c: Dictionary = s["countries"][cid]
	var total := 0.0
	var lit_pop := 0.0
	for pid in GS.owned(s, cid):
		var p: Dictionary = s["provinces"][pid]
		var pm := Mods.province(s, pid)
		total += float(pm.get("research_pts", 0.0)) * (0.6 + float(p.get("literacy", 0.05)) * 2.0)
		lit_pop += float(p["pop"]) * float(p.get("literacy", 0.05))
	total += lit_pop * 0.0025
	total += 1.5 + float(GS.owned(s, cid).size()) * 0.15
	total *= 1.0 + Mods.get_mod(s, cid, "research")
	if float(c.get("stability", 50.0)) < 25.0:
		total *= 0.6
	return maxf(0.0, total)

static func process_turn(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	var pts := points(s, cid)
	c["research"]["last_points"] = pts
	var alloc: Dictionary = c["research"]["alloc"]
	var wsum := 0.0
	var active: Array = []
	for b in Const.BRANCHES:
		var cur := str(c["research"]["current"].get(b, ""))
		if cur != "":
			active.append(b)
			wsum += float(alloc.get(b, 1.0))
	var banked := float(c["research"].get("bank", 0.0))
	if active.is_empty():
		c["research"]["bank"] = minf(banked + pts, 600.0)  # unused points are partly kept
		return
	var pool := pts + banked
	c["research"]["bank"] = 0.0
	for b in active:
		var tid: String = c["research"]["current"][b]
		var share := pool * float(alloc.get(b, 1.0)) / maxf(wsum, 0.001)
		var prog := float(c["research"]["progress"].get(tid, 0.0)) + share
		var need := cost_rp(s, cid, tid)
		if prog >= need:
			grant(s, cid, tid)
			c["research"]["progress"].erase(tid)
			c["research"]["current"][b] = ""
			c["research"]["bank"] = float(c["research"]["bank"]) + (prog - need) * 0.5
			GS.note(s, cid, "tech", "NOTE_TECH_DONE", {"tech": tid})
			GS.stat_add(s, cid, "techs", 1.0)
			GS.history(s, cid, "tech", "HIST_TECH", {"tech": tid})
		else:
			c["research"]["progress"][tid] = prog

## Techs researchable right now (prereqs met, not done)
static func available(s: Dictionary, cid: String) -> Array:
	var out: Array = []
	var c: Dictionary = s["countries"][cid]
	for tid in Defs.techs:
		if c["researched"].has(tid):
			continue
		var ok := true
		for pre in Defs.techs[tid]["prereq"]:
			if not c["researched"].has(pre):
				ok = false
				break
		if ok:
			out.append(tid)
	out.sort()
	return out
