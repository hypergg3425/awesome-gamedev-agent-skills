class_name DynastySystem
extends RefCounted
## Dynasties: hereditary succession laws, royal family, heir quality, regency, ruler health and death,
## marriage diplomacy, dynastic claims, inheritance / personal unions and succession disputes.
## State: country["dyn"] = {name, law, royals:[], next_id, consort, designated, regent, crisis, marriages:[], claims:[], union_with}
## The ruler stays in country["ruler"], the designated heir is mirrored in country["heir"] (older systems and events read both).

const FEM_NAMES := ["Maria", "Anna", "Eleanor", "Isabella", "Matilda", "Theodora", "Zoe", "Fatima", "Leila", "Mei", "Ayse", "Sofia", "Margaret", "Catherine", "Adelheid", "Ingrid"]
const ADULT_AGE := 16.0
const MAX_ROYALS := 14
## succession law by government (hereditary governments only)
const LAW_OF := {"absolute_monarchy": "agnatic", "constitutional_monarchy": "cognatic", "empire": "designated", "feudal_kingdom": "agnatic"}
const LAW_NAMES := ["agnatic", "cognatic", "designated", "elective"]
const KIN_RANK := {"child": 0, "sibling": 1, "nephew": 2, "cousin": 3, "kin": 4}

static func is_hereditary(c: Dictionary) -> bool:
	return str(Defs.governments.get(c.get("gov", ""), {}).get("succession", "")) == "hereditary"

static func law_of(gov: String) -> String:
	return str(LAW_OF.get(gov, "elective"))

static func st(c: Dictionary) -> Dictionary:
	if not c.has("dyn"):
		c["dyn"] = {"name": str(c.get("dynasty", "")), "law": law_of(str(c.get("gov", ""))), "royals": [], "next_id": 1, "consort": null,
			"designated": -1, "regent": null, "crisis": null, "marriages": [], "claims": [], "union_with": "", "granted": []}
	return c["dyn"]

## ruler stats as the realm experiences them (a regent's weaker skills during a regency)
static func effective_ruler(c: Dictionary) -> Dictionary:
	var ru: Dictionary = c.get("ruler", {})
	if int(c.get("regency", 0)) > 0 and c.has("dyn"):
		var rg: Variant = c["dyn"].get("regent")
		if rg is Dictionary:
			return {"adm": maxi(1, int(rg["adm"]) - 1), "dip": maxi(1, int(rg["dip"]) - 1), "mil": maxi(1, int(rg["mil"]) - 1), "age": ru.get("age", 30)}
	return ru

## --- creation ----------------------------------------------------------------------------------------------------
static func _skill(rng: GameRng, mean: float) -> int:
	return clampi(int(round(rng.gauss(mean, 1.7))), 1, 9)

static func _new_royal(s: Dictionary, cid: String, d: Dictionary, rng: GameRng, age: float, rel: String, mean: float, sex: String = "") -> Dictionary:
	var sx := sex if sex != "" else ("m" if rng.chance(0.5) else "f")
	var nm := PoliticsSystem.random_name(s, cid, rng) if sx == "m" else str(rng.pick(FEM_NAMES))
	var q := Mods.get_mod(s, cid, "heir_quality") * 4.0
	var r := {"id": int(d["next_id"]), "name": nm, "age": age, "sex": sx, "adm": _skill(rng, mean + q), "dip": _skill(rng, mean + q), "mil": _skill(rng, mean + q),
		"health": clampf(rng.gauss(85.0, 8.0), 50.0, 100.0), "rel": rel, "spouse": null}
	d["next_id"] = int(d["next_id"]) + 1
	return r

static func init_country(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	var d := st(c)
	var ru: Dictionary = c["ruler"]
	if not ru.has("health"):
		ru["health"] = clampf(95.0 - maxf(0.0, float(ru.get("age", 35)) - 40.0) * 1.1, 35.0, 100.0)
	if not ru.has("sex"):
		ru["sex"] = "m"
	if d["name"] == "":
		d["name"] = str(ru.get("dynasty", "")) if str(ru.get("dynasty", "")) != "" else "House of " + str(ru["name"])
	d["law"] = law_of(str(c["gov"]))
	if not is_hereditary(c) or bool(c.get("native", false)):
		c["heir"] = null
		return
	var rng := GS.rng_of(s)
	var rage := float(ru.get("age", 35))
	if d["consort"] == null:
		d["consort"] = {"name": str(rng.pick(FEM_NAMES)), "age": maxf(16.0, rage - 3.0 + rng.randf() * 4.0), "cid": ""}
	# existing heir (from scenario data or the loader) becomes a royal child
	var h: Variant = c.get("heir")
	if h is Dictionary and (d["royals"] as Array).is_empty():
		var hr := {"id": int(d["next_id"]), "name": str((h as Dictionary)["name"]), "age": float(h["age"]), "sex": "m", "adm": int(h["adm"]), "dip": int(h["dip"]), "mil": int(h["mil"]),
			"health": 90.0, "rel": "child", "spouse": null}
		d["next_id"] = int(d["next_id"]) + 1
		d["royals"].append(hr)
	var mean := (float(ru.get("adm", 5)) + float(ru.get("dip", 5)) + float(ru.get("mil", 5))) / 3.0
	if (d["royals"] as Array).size() < 2:
		# children (for a ruler of child-bearing age), a sibling or two, perhaps a cousin: the cast of a court
		var kids := clampi(int((rage - 22.0) / 7.0), 0, 3)
		for i in kids:
			var ca := maxf(0.0, rage - 20.0 - float(i) * 3.0 - rng.randf() * 4.0)
			if ca >= 0.0:
				d["royals"].append(_new_royal(s, cid, d, rng, ca, "child", mean))
		for i in rng.randi_range(1, 2):
			d["royals"].append(_new_royal(s, cid, d, rng, maxf(2.0, rage + rng.randf_range(-9.0, 7.0)), "sibling", mean))
		if rng.chance(0.6):
			d["royals"].append(_new_royal(s, cid, d, rng, maxf(2.0, rage + rng.randf_range(-12.0, 8.0)), "cousin", mean))
	refresh_heir(c)

## --- line of succession ---------------------------------------------------------------------------------------------
static func _eligible(law: String, r: Dictionary, strict: bool) -> bool:
	if float(r["health"]) <= 0.0:
		return false
	if strict and law == "agnatic" and str(r["sex"]) != "m":
		return false
	return true

static func line_of_succession(c: Dictionary, strict: bool = true) -> Array:
	var d := st(c)
	var law: String = d["law"]
	var out: Array = []
	for r in d["royals"]:
		if _eligible(law, r, strict):
			out.append(r)
	var desg := int(d.get("designated", -1))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if law == "designated":
			var da: bool = int(a["id"]) == desg
			var db: bool = int(b["id"]) == desg
			if da != db:
				return da
			var ka := int(KIN_RANK.get(a["rel"], 4))
			var kb := int(KIN_RANK.get(b["rel"], 4))
			if ka != kb:
				return ka < kb
			return int(a["adm"]) + int(a["dip"]) + int(a["mil"]) > int(b["adm"]) + int(b["dip"]) + int(b["mil"])
		var ra := int(KIN_RANK.get(a["rel"], 4))
		var rb := int(KIN_RANK.get(b["rel"], 4))
		if ra != rb:
			return ra < rb
		if float(a["age"]) != float(b["age"]):
			return float(a["age"]) > float(b["age"])
		return int(a["id"]) < int(b["id"]))
	return out

static func refresh_heir(c: Dictionary) -> void:
	if not is_hereditary(c):
		c["heir"] = null
		return
	var line := line_of_succession(c, true)
	if line.is_empty():
		c["heir"] = null
		return
	var r: Dictionary = line[0]
	c["heir"] = {"id": int(r["id"]), "name": r["name"], "age": float(r["age"]), "adm": int(r["adm"]), "dip": int(r["dip"]), "mil": int(r["mil"]),
		"sex": r["sex"], "health": float(r["health"])}

static func royal_by_id(c: Dictionary, rid: int) -> Dictionary:
	for r in st(c)["royals"]:
		if int(r["id"]) == rid:
			return r
	return {}

static func quality(r: Dictionary) -> float:
	return (float(r["adm"]) + float(r["dip"]) + float(r["mil"])) / 3.0

## --- per-turn processing ----------------------------------------------------------------------------------------------
static func death_chance(age: float, health: float, protect: float) -> float:
	var hz := 0.0005
	if age > 75.0:
		hz = 0.04
	elif age > 60.0:
		hz = 0.012
	elif age > 40.0:
		hz = 0.003
	var frail := 1.0 + clampf((60.0 - health) / 40.0, 0.0, 1.5)
	return hz * frail * clampf(1.0 - protect, 0.4, 1.0)

static func process_turn(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var d := st(c)
	var ru: Dictionary = c["ruler"]
	var protect := Mods.get_mod(s, cid, "royal_health")
	ru["age"] = float(ru["age"]) + 0.25
	_health_step(ru, rng, protect, true)
	var age := float(ru["age"])
	var hz := death_chance(age, float(ru["health"]), protect)
	if bool(c.get("native", false)):
		hz *= 1.2
	var dies := rng.chance(hz)
	if not is_hereditary(c) or bool(c.get("native", false)):
		c["heir"] = null
		d["royals"] = []
		_update_regency(s, cid, c, d)
		if dies:
			PoliticsSystem.ruler_dies(s, cid, rng)
		return
	# royal family ages, sickens, is born
	var gone: Array = []
	for r in d["royals"]:
		r["age"] = float(r["age"]) + 0.25
		_health_step(r, rng, protect, false)
		var ch := death_chance(float(r["age"]), float(r["health"]), protect)
		if float(r["age"]) < 5.0:
			ch += 0.006
		if rng.chance(ch) or float(r["health"]) <= 0.0:
			gone.append(r)
	for r in gone:
		(d["royals"] as Array).erase(r)
		_unmarry(s, cid, r)
		GS.note(s, cid, "politics", "NOTE_ROYAL_DIED", {"name": r["name"]})
	var cons: Variant = d["consort"]
	if cons is Dictionary:
		cons["age"] = float(cons["age"]) + 0.25
		if rng.chance(death_chance(float(cons["age"]), 80.0, protect) + 0.0006):
			d["consort"] = null
			cons = null
	elif age < 55.0 and rng.chance(0.05):
		d["consort"] = {"name": str(rng.pick(FEM_NAMES)), "age": rng.randf_range(18.0, 28.0), "cid": ""}
		cons = d["consort"]
	if cons is Dictionary and float(cons["age"]) <= 42.0 and age >= 18.0 and age <= 62.0 and (d["royals"] as Array).size() < MAX_ROYALS:
		var kids := 0
		for r in d["royals"]:
			if str(r["rel"]) == "child":
				kids += 1
		if rng.chance(0.032 * maxf(0.15, 1.0 - float(kids) * 0.14)):
			var mean := (float(ru["adm"]) + float(ru["dip"]) + float(ru["mil"])) / 3.0
			var kid := _new_royal(s, cid, d, rng, 0.0, "child", mean)
			d["royals"].append(kid)
			GS.note(s, cid, "politics", "NOTE_HEIR_BORN", {"name": kid["name"]})
	if dies:
		PoliticsSystem.ruler_dies(s, cid, rng)
		return
	refresh_heir(c)
	_update_regency(s, cid, c, d)
	_process_crisis(s, cid, c, d, rng)
	_expire_claims(s, cid, d)

static func _health_step(r: Dictionary, rng: GameRng, protect: float, is_ruler: bool) -> void:
	var h := float(r["health"])
	var age := float(r["age"])
	if age > 45.0:
		h -= (age - 45.0) * 0.012
	if rng.chance(0.012 * clampf(1.0 - protect, 0.4, 1.0)):
		h -= rng.randf_range(10.0, 30.0)
	h += 1.2 + protect * 6.0
	r["health"] = clampf(h, 0.0, 100.0)
	if is_ruler:
		r["ill"] = float(r["health"]) < 28.0

## minors and incapacitated rulers are governed by a regent
static func _update_regency(s: Dictionary, cid: String, c: Dictionary, d: Dictionary) -> void:
	var ru: Dictionary = c["ruler"]
	var left := 0
	if float(ru["age"]) < ADULT_AGE:
		left = int(ceil((ADULT_AGE - float(ru["age"])) * 4.0))
	if bool(ru.get("ill", false)):
		left = maxi(left, 1)
	var was := int(c.get("regency", 0)) > 0
	c["regency"] = left
	if left > 0:
		if d["regent"] == null:
			d["regent"] = _pick_regent(s, cid, c, d)
		c["temp_mods"] = (c["temp_mods"] as Array).filter(func(t: Dictionary) -> bool: return t.get("key", "") != "regency")
		c["temp_mods"].append({"mods": {"reform_cost": 0.25, "diplo": -0.05, "stability": -0.0}, "until": int(s["turn"]) + 1, "key": "regency"})
		c["legitimacy"] = maxf(0.0, float(c["legitimacy"]) - 0.25)
		if not was:
			GS.note(s, cid, "politics", "NOTE_REGENCY", {"ruler": ru["name"]})
	else:
		d["regent"] = null

static func _pick_regent(s: Dictionary, cid: String, c: Dictionary, d: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var bq := -1.0
	for r in d["royals"]:
		if float(r["age"]) >= ADULT_AGE and str(r["rel"]) != "child":
			var q: float = float(r["adm"]) * 1.5 + float(r["dip"]) + float(r["mil"]) * 0.5
			if q > bq:
				bq = q
				best = r
	if not best.is_empty():
		return {"name": best["name"], "adm": best["adm"], "dip": best["dip"], "mil": best["mil"], "kind": "royal", "id": best["id"]}
	var rng := GS.rng_of(s)
	return {"name": "Council of " + str(c["ruler"]["name"]), "adm": _skill(rng, 5.0), "dip": _skill(rng, 5.0), "mil": _skill(rng, 5.0), "kind": "council", "id": -1}

## --- death and succession ------------------------------------------------------------------------------------------------
static func on_ruler_death(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var d := st(c)
	var line := line_of_succession(c, true)
	var strict_ok := not line.is_empty()
	if line.is_empty():
		line = line_of_succession(c, false)   # no man left under an agnatic law: a woman's claim is accepted, at a price
	var old_dynasty := str(d["name"])
	if line.is_empty():
		_extinct(s, cid, c, d, rng)
		return
	var heir: Dictionary = line[0]
	var ruler := {"name": heir["name"], "adm": int(heir["adm"]), "dip": int(heir["dip"]), "mil": int(heir["mil"]), "age": float(heir["age"]),
		"dynasty": c["ruler"].get("dynasty", old_dynasty), "term_start": int(s["turn"]), "health": float(heir["health"]), "sex": heir["sex"], "ill": false}
	(d["royals"] as Array).erase(heir)
	_unmarry_keep_spouse(s, cid, heir)
	# new ruler's spouse comes with them, children stay in the line
	var rest: Array = d["royals"]
	for r in rest:
		_rekin(r, heir)
	d["consort"] = null if str(heir["sex"]) == "f" else {"name": str(rng.pick(FEM_NAMES)), "age": maxf(16.0, float(heir["age"]) - 2.0), "cid": ""}
	if heir.get("spouse") is Dictionary and str(heir["spouse"].get("cid", "")) != "":
		d["consort"] = {"name": heir["spouse"]["name"], "age": float(heir["age"]), "cid": heir["spouse"]["cid"]}
	c["ruler"] = ruler
	d["designated"] = -1
	c["stability"] = maxf(0.0, float(c["stability"]) - 2.0)
	if not strict_ok:
		c["legitimacy"] = maxf(0.0, float(c["legitimacy"]) - 18.0)
		GS.note(s, cid, "politics", "NOTE_FEMALE_CLAIM", {"ruler": ruler["name"]})
	if float(ruler["age"]) < ADULT_AGE:
		c["stability"] = maxf(0.0, float(c["stability"]) - 3.0)
		c["legitimacy"] = maxf(0.0, float(c["legitimacy"]) - 8.0)
	GS.note(s, cid, "politics", "NOTE_NEW_RULER", {"ruler": ruler["name"]})
	Mods.invalidate(s)
	refresh_heir(c)
	_update_regency(s, cid, c, d)
	_succession_dispute(s, cid, c, d, heir, rng)
	_union_on_death(s, cid, rng)
	GS.stat_add(s, cid, "rulers", 1.0)

static func _rekin(r: Dictionary, new_ruler: Dictionary) -> void:
	## relationship terms are relative to the ruler: the former heir's children become the ruler's children, and so on
	var was := str(new_ruler["rel"])
	var rel := str(r["rel"])
	if rel == "child" and was == "child":
		r["rel"] = "sibling"
	elif rel == "child" and was != "child":
		r["rel"] = "nephew"
	elif rel == "sibling" and was == "child":
		r["rel"] = "kin"
	elif rel == "sibling":
		r["rel"] = "sibling"
	elif rel == "nephew":
		r["rel"] = "nephew"
	new_ruler["rel"] = "ruler"

static func _extinct(s: Dictionary, cid: String, c: Dictionary, d: Dictionary, rng: GameRng) -> void:
	# claimants through marriage inherit; otherwise a new dynasty rises amid a legitimacy crisis
	var heir_cid := _marriage_claimant(s, cid, c)
	if heir_cid != "":
		_inherit_by_marriage(s, cid, heir_cid, rng)
		return
	PoliticsSystem._succession_crisis(s, cid, rng)
	var ru: Dictionary = c["ruler"]
	ru["health"] = 90.0
	ru["sex"] = "m"
	ru["ill"] = false
	d["royals"] = []
	d["name"] = "House of " + str(ru["name"])
	d["consort"] = {"name": str(rng.pick(FEM_NAMES)), "age": maxf(16.0, float(ru["age"]) - 3.0), "cid": ""}
	d["crisis"] = null
	d["designated"] = -1
	GS.note(s, cid, "politics", "NOTE_DYNASTY_EXTINCT", {"ruler": ru["name"]})
	GS.history(s, cid, "politics", "HIST_DYNASTY_EXTINCT", {"ruler": ru["name"]})
	var mean := (float(ru["adm"]) + float(ru["dip"]) + float(ru["mil"])) / 3.0
	d["royals"].append(_new_royal(s, cid, d, rng, maxf(2.0, float(ru["age"]) - 12.0), "sibling", mean))
	refresh_heir(c)
	_update_regency(s, cid, c, d)

## --- succession disputes -------------------------------------------------------------------------------------------------------
static func dispute_risk(s: Dictionary, cid: String, c: Dictionary, d: Dictionary, heir: Dictionary) -> float:
	var risk := 0.08
	if float(heir["age"]) < ADULT_AGE:
		risk += 0.18
	if float(c["legitimacy"]) < 40.0:
		risk += 0.15
	elif float(c["legitimacy"]) > 70.0:
		risk -= 0.06
	if quality(heir) < 4.0:
		risk += 0.08
	var rivals := 0
	for r in d["royals"]:
		if float(r["age"]) >= ADULT_AGE and str(r["rel"]) in ["sibling", "kin", "cousin", "nephew"]:
			rivals += 1
	risk += 0.06 * float(mini(rivals, 3))
	risk -= (FactionsSystem.loyalty(c, "nobility") - 50.0) * 0.002
	if str(d["law"]) == "designated":
		risk -= 0.05
	return clampf(risk, 0.02, 0.6)

static func _succession_dispute(s: Dictionary, cid: String, c: Dictionary, d: Dictionary, new_ruler: Dictionary, rng: GameRng) -> void:
	if d["crisis"] != null:
		return
	var as_heir := {"age": c["ruler"]["age"], "adm": c["ruler"]["adm"], "dip": c["ruler"]["dip"], "mil": c["ruler"]["mil"]}
	if not rng.chance(dispute_risk(s, cid, c, d, as_heir)):
		return
	var rival: Dictionary = {}
	var rq := -1.0
	for r in d["royals"]:
		if float(r["age"]) >= ADULT_AGE and str(r["rel"]) != "child":
			var q := quality(r) + float(r["age"]) * 0.02
			if q > rq:
				rq = q
				rival = r
	var foreign := ""
	if rival.is_empty():
		foreign = _marriage_claimant(s, cid, c)
		if foreign == "":
			return
		rival = {"id": -1, "name": "Claimant of " + GS.country_name(s, foreign), "adm": 5, "dip": 5, "mil": 5, "age": 30.0, "foreign": foreign}
	var dur := rng.randi_range(6, 10)
	d["crisis"] = {"rival": rival.duplicate(true), "start": int(s["turn"]), "ends": int(s["turn"]) + dur, "foreign": foreign}
	c["legitimacy"] = maxf(0.0, float(c["legitimacy"]) - 10.0)
	GS.note(s, cid, "politics", "NOTE_SUCCESSION_DISPUTE", {"rival": rival["name"]})
	GS.history(s, cid, "politics", "HIST_SUCCESSION_DISPUTE", {"rival": rival["name"]})
	if foreign != "":
		_grant_claims(s, foreign, cid, 16)

static func _process_crisis(s: Dictionary, cid: String, c: Dictionary, d: Dictionary, rng: GameRng) -> void:
	var cr: Variant = d["crisis"]
	if not (cr is Dictionary):
		return
	c["temp_mods"] = (c["temp_mods"] as Array).filter(func(t: Dictionary) -> bool: return t.get("key", "") != "succession_dispute")
	c["temp_mods"].append({"mods": {"unrest": 0.04, "tax": -0.05}, "until": int(s["turn"]) + 1, "key": "succession_dispute"})
	c["legitimacy"] = maxf(0.0, float(c["legitimacy"]) - 0.8)
	if int(s["turn"]) >= int(cr["ends"]):
		var win_p := clampf(0.35 + float(c["legitimacy"]) / 200.0 + (FactionsSystem.loyalty(c, "nobility") - 50.0) * 0.004
			+ (quality(c["ruler"]) - quality(cr["rival"])) * 0.04, 0.15, 0.85)
		resolve_crisis(s, cid, rng.chance(win_p), rng)
	elif FactionsSystem.loyalty(c, "nobility") < 30.0 and rng.chance(0.07) and GS.owned(s, cid).size() >= 5:
		var rv: Dictionary = cr["rival"]
		d["crisis"] = null
		CivilWar.start(s, cid, "succession", "nobility", str(rv["name"]), rng)

## ends the dispute; `ruler_wins=false` puts the rival on the throne
static func resolve_crisis(s: Dictionary, cid: String, ruler_wins: bool, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var d := st(c)
	var cr: Variant = d["crisis"]
	if not (cr is Dictionary):
		return
	d["crisis"] = null
	c["temp_mods"] = (c["temp_mods"] as Array).filter(func(t: Dictionary) -> bool: return t.get("key", "") != "succession_dispute")
	var rival: Dictionary = cr["rival"]
	if ruler_wins:
		c["legitimacy"] = minf(100.0, float(c["legitimacy"]) + 6.0)
		(d["royals"] as Array).erase(royal_by_id(c, int(rival.get("id", -1))))
		GS.note(s, cid, "politics", "NOTE_DISPUTE_WON", {"rival": rival["name"]})
	else:
		var old: Dictionary = c["ruler"]
		var exiled := {"id": int(d["next_id"]), "name": old["name"], "age": float(old["age"]), "sex": old.get("sex", "m"), "adm": int(old["adm"]), "dip": int(old["dip"]),
			"mil": int(old["mil"]), "health": float(old.get("health", 90.0)), "rel": "kin", "spouse": null}
		d["next_id"] = int(d["next_id"]) + 1
		var rr := royal_by_id(c, int(rival.get("id", -1)))
		if not rr.is_empty():
			(d["royals"] as Array).erase(rr)
		c["ruler"] = {"name": rival["name"], "adm": int(rival["adm"]), "dip": int(rival["dip"]), "mil": int(rival["mil"]), "age": float(rival["age"]),
			"dynasty": old.get("dynasty", ""), "term_start": int(s["turn"]), "health": float(rr.get("health", 85.0)), "sex": rr.get("sex", "m"), "ill": false}
		d["royals"].append(exiled)
		c["legitimacy"] = maxf(20.0, float(c["legitimacy"]) - 4.0)
		c["stability"] = maxf(0.0, float(c["stability"]) - 4.0)
		GS.note(s, cid, "politics", "NOTE_DISPUTE_LOST", {"rival": rival["name"]})
		Mods.invalidate(s)
	refresh_heir(c)
	_update_regency(s, cid, c, d)

## player / AI: buy off the contesting faction (gold) so that the ruler's claim prevails
static func crisis_cost(s: Dictionary, cid: String) -> float:
	var inc := maxf(10.0, float(s["countries"][cid].get("budget", {}).get("income", 20.0)))
	return snappedf(60.0 + inc * 3.0, 0.1)

static func buy_off_rival(s: Dictionary, cid: String) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	var d := st(c)
	if d["crisis"] == null:
		return {"ok": false, "reason": "DYN_ERR_NO_CRISIS"}
	var cost := crisis_cost(s, cid)
	if float(c["gold"]) < cost:
		return {"ok": false, "reason": "ERR_NO_GOLD", "params": {"need": int(ceil(cost))}}
	c["gold"] = float(c["gold"]) - cost
	FactionsSystem.shift_loyalty(c, "nobility", 6.0)
	resolve_crisis(s, cid, true, GS.rng_of(s))
	return {"ok": true}

## --- designation ---------------------------------------------------------------------------------------------------------------------
static func can_designate(s: Dictionary, cid: String, rid: int) -> Dictionary:
	var c: Dictionary = s["countries"][cid]
	if str(st(c)["law"]) != "designated":
		return {"ok": false, "reason": "DYN_ERR_LAW"}
	if royal_by_id(c, rid).is_empty():
		return {"ok": false, "reason": "ERR_INVALID"}
	if float(c["admin"]) < 25.0:
		return {"ok": false, "reason": "ERR_NO_ADMIN", "params": {"need": 25}}
	return {"ok": true}

static func designate(s: Dictionary, cid: String, rid: int) -> Dictionary:
	var chk := can_designate(s, cid, rid)
	if not chk["ok"]:
		return chk
	var c: Dictionary = s["countries"][cid]
	c["admin"] = float(c["admin"]) - 25.0
	st(c)["designated"] = rid
	FactionsSystem.shift_loyalty(c, "court", 3.0)
	refresh_heir(c)
	return {"ok": true}

## --- marriage diplomacy -----------------------------------------------------------------------------------------------------------------
static func marriageable(c: Dictionary) -> Array:
	var out: Array = []
	if not is_hereditary(c):
		return out
	for r in st(c)["royals"]:
		if float(r["age"]) >= ADULT_AGE and r["spouse"] == null:
			out.append(r)
	return out

static func married(s: Dictionary, a: String, b: String) -> bool:
	for m in st(s["countries"][a])["marriages"]:
		if str(m["partner"]) == b:
			return true
	return false

static func _match_for(c_to: Dictionary, sex: String) -> Dictionary:
	var best: Dictionary = {}
	var bq := -1.0
	for r in marriageable(c_to):
		if str(r["sex"]) != sex:
			var q := quality(r)
			if q > bq:
				bq = q
				best = r
	return best

static func can_propose_marriage(s: Dictionary, from: String, to: String, rid: int) -> Dictionary:
	if from == to or not s["countries"].get(to, {}).get("alive", false):
		return {"ok": false, "reason": "ERR_INVALID"}
	var cf: Dictionary = s["countries"][from]
	var ct: Dictionary = s["countries"][to]
	if not is_hereditary(cf) or not is_hereditary(ct):
		return {"ok": false, "reason": "DYN_ERR_NO_DYNASTY"}
	if GS.at_war(s, from, to):
		return {"ok": false, "reason": "DIPLO_ERR_AT_WAR"}
	if married(s, from, to):
		return {"ok": false, "reason": "DYN_ERR_MARRIED"}
	var mine := royal_by_id(cf, rid)
	if mine.is_empty() or float(mine["age"]) < ADULT_AGE or mine["spouse"] != null:
		return {"ok": false, "reason": "DYN_ERR_NO_ROYAL"}
	var theirs := _match_for(ct, str(mine["sex"]))
	if theirs.is_empty():
		return {"ok": false, "reason": "DYN_ERR_NO_MATCH"}
	return {"ok": true, "theirs": theirs}

static func marriage_eval(s: Dictionary, from: String, to: String, mine: Dictionary, theirs: Dictionary) -> Dictionary:
	var reasons: Array = []
	var score := 0.0
	var op := GS.opinion(s, to, from)
	reasons.append({"key": "DR_OPINION", "value": snappedf(op * 0.2, 0.1)})
	score += op * 0.2
	var same_rel: bool = s["countries"][from]["religion"] == s["countries"][to]["religion"]
	var rb := 12.0 if same_rel else -14.0
	reasons.append({"key": "DR_RELIGION_SAME" if same_rel else "DR_RELIGION_DIFF", "value": rb})
	score += rb
	var ratio := DiplomacySystem.power_score(s, from) / maxf(DiplomacySystem.power_score(s, to), 1.0)
	var pw := clampf((ratio - 1.0) * 6.0, -10.0, 10.0)
	reasons.append({"key": "DR_STRENGTH", "value": snappedf(pw, 0.1)})
	score += pw
	var rq := (quality(mine) - quality(theirs)) * 2.0
	reasons.append({"key": "DR_OFFER_VALUE", "value": snappedf(rq, 0.1)})
	score += rq
	var cl := -float(DiplomacySystem.claim_count(s, from, to) + DiplomacySystem.claim_count(s, to, from)) * 6.0
	if absf(cl) >= 0.5:
		reasons.append({"key": "DR_CLAIMS", "value": cl})
	score += cl
	if GS.allied(s, from, to):
		reasons.append({"key": "DR_ALLIES", "value": 10.0})
		score += 10.0
	var pers := DiplomacySystem.personality(s, to)
	var pp: float = {"diplomatic": 10.0, "coalition_builder": 8.0, "isolationist": -12.0, "aggressive": -4.0}.get(pers, 0.0)
	if pp != 0.0:
		reasons.append({"key": "DR_PERSONALITY", "value": pp})
	score += pp
	return {"accept": score >= 8.0, "score": score, "threshold": 8.0, "reasons": reasons}

static func propose_marriage(s: Dictionary, from: String, to: String, rid: int) -> Dictionary:
	var chk := can_propose_marriage(s, from, to, rid)
	if not chk["ok"]:
		return chk
	var cf: Dictionary = s["countries"][from]
	var ct: Dictionary = s["countries"][to]
	var mine := royal_by_id(cf, rid)
	var theirs: Dictionary = chk["theirs"]
	var ev := marriage_eval(s, from, to, mine, theirs)
	if not ev["accept"]:
		GS.add_opinion(s, to, from, -2.0)
		return {"ok": true, "accepted": false, "eval": ev}
	marry(s, from, mine, to, theirs)
	return {"ok": true, "accepted": true, "eval": ev}

static func marry(s: Dictionary, a: String, ra: Dictionary, b: String, rb: Dictionary) -> void:
	ra["spouse"] = {"cid": b, "name": rb["name"]}
	rb["spouse"] = {"cid": a, "name": ra["name"]}
	st(s["countries"][a])["marriages"].append({"partner": b, "mine": int(ra["id"]), "theirs": rb["name"], "turn": int(s["turn"])})
	st(s["countries"][b])["marriages"].append({"partner": a, "mine": int(rb["id"]), "theirs": ra["name"], "turn": int(s["turn"])})
	GS.add_opinion(s, a, b, 25.0)
	GS.add_opinion(s, b, a, 25.0)
	var r := GS.rel(s, a, b)
	r["trust"] = clampf(float(r["trust"]) + 8.0, 0.0, 100.0)
	GS.note(s, a, "diplomacy", "NOTE_MARRIAGE", {"other": b})
	GS.note(s, b, "diplomacy", "NOTE_MARRIAGE", {"other": a})
	GS.history(s, a, "diplomacy", "HIST_MARRIAGE", {"other": b})
	GS.stat_add(s, a, "marriages", 1.0)
	FactionsSystem.shift_loyalty(s["countries"][a], "court", 2.0)
	FactionsSystem.shift_loyalty(s["countries"][b], "court", 2.0)

static func _unmarry(s: Dictionary, cid: String, r: Dictionary) -> void:
	if not (r["spouse"] is Dictionary):
		return
	var other: String = str(r["spouse"]["cid"])
	var marr: Array = st(s["countries"][cid])["marriages"]
	for m in marr.duplicate():
		if int(m["mine"]) == int(r["id"]):
			marr.erase(m)
	if s["countries"].has(other):
		var om: Array = st(s["countries"][other])["marriages"]
		for m in om.duplicate():
			if str(m["partner"]) == cid and str(m["theirs"]) == str(r["name"]):
				om.erase(m)
				var spouse_royal := {}
				for rr in st(s["countries"][other])["royals"]:
					if rr["spouse"] is Dictionary and str(rr["spouse"].get("cid", "")) == cid and str(rr["spouse"].get("name", "")) == str(r["name"]):
						spouse_royal = rr
				if not spouse_royal.is_empty():
					spouse_royal["spouse"] = null

static func _unmarry_keep_spouse(s: Dictionary, cid: String, r: Dictionary) -> void:
	## a royal who becomes ruler keeps a foreign spouse as consort, so the tie stays in the marriage list
	if r["spouse"] is Dictionary:
		var marr: Array = st(s["countries"][cid])["marriages"]
		for m in marr:
			if int(m["mine"]) == int(r["id"]):
				m["mine"] = -1

## --- claims, inheritance and unions -------------------------------------------------------------------------------------------------------------
## the best foreign claimant: a hereditary realm tied to this one by marriage and not at war with it
static func _marriage_claimant(s: Dictionary, cid: String, c: Dictionary) -> String:
	var best := ""
	var bp := -1.0
	for m in st(c)["marriages"]:
		var o: String = str(m["partner"])
		if not s["countries"].get(o, {}).get("alive", false) or GS.at_war(s, cid, o) or not is_hereditary(s["countries"][o]):
			continue
		if GS.overlord_of(s, o) != "" or GS.overlord_of(s, cid) != "" and GS.overlord_of(s, cid) != o:
			continue
		var p := DiplomacySystem.power_score(s, o)
		if p > bp:
			bp = p
			best = o
	return best

static func _grant_claims(s: Dictionary, claimer: String, target: String, turns: int) -> void:
	var cc: Dictionary = s["countries"][claimer]
	var d := st(cc)
	var pids: Array = []
	var cap: String = str(s["countries"][target]["capital"])
	for pid in GS.owned(s, target):
		if pids.size() >= 6:
			break
		var p: Dictionary = s["provinces"][pid]
		if (pid == cap or p["culture"] == s["countries"][target]["culture"]) and claimer not in p["claims"] and claimer not in p["cores"]:
			p["claims"].append(claimer)
			pids.append(pid)
	d["claims"].append({"on": target, "until": int(s["turn"]) + turns, "pids": pids})
	GS.note(s, claimer, "diplomacy", "NOTE_THRONE_CLAIM", {"other": target})

static func _expire_claims(s: Dictionary, cid: String, d: Dictionary) -> void:
	for cl in (d["claims"] as Array).duplicate():
		if int(cl["until"]) < int(s["turn"]):
			for pid in cl["pids"]:
				var p: Dictionary = s["provinces"].get(pid, {})
				if not p.is_empty():
					(p["claims"] as Array).erase(cid)
			(d["claims"] as Array).erase(cl)

static func _inherit_by_marriage(s: Dictionary, cid: String, heir_cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	var hc: Dictionary = s["countries"][heir_cid]
	var d := st(c)
	var hd := st(hc)
	var mean := (float(hc["ruler"]["adm"]) + float(hc["ruler"]["dip"]) + float(hc["ruler"]["mil"])) / 3.0
	var nm := PoliticsSystem.random_name(s, heir_cid, rng)
	c["ruler"] = {"name": nm, "adm": _skill(rng, mean), "dip": _skill(rng, mean), "mil": _skill(rng, mean), "age": rng.randf_range(20.0, 32.0),
		"dynasty": hd["name"], "term_start": int(s["turn"]), "health": 90.0, "sex": "m", "ill": false}
	d["name"] = hd["name"]
	d["royals"] = []
	d["consort"] = {"name": str(rng.pick(FEM_NAMES)), "age": 22.0, "cid": ""}
	d["crisis"] = null
	c["legitimacy"] = maxf(15.0, float(c["legitimacy"]) - 15.0)
	c["stability"] = maxf(0.0, float(c["stability"]) - 5.0)
	DiplomacySystem.make_vassal(s, heir_cid, cid, false)
	c["union_with"] = heir_cid
	d["union_with"] = heir_cid
	GS.note(s, cid, "politics", "NOTE_UNION_INHERITED", {"other": heir_cid})
	GS.note(s, heir_cid, "politics", "NOTE_UNION_GAINED", {"other": cid})
	GS.history(s, heir_cid, "politics", "HIST_UNION", {"other": cid})
	GS.stat_add(s, heir_cid, "unions", 1.0)
	var mean2 := mean
	d["royals"].append(_new_royal(s, cid, d, rng, 3.0, "child", mean2))
	refresh_heir(c)
	_update_regency(s, cid, c, d)
	Mods.invalidate(s)

## when the senior partner of a personal union dies the junior realm may go its own way
static func _union_on_death(s: Dictionary, cid: String, rng: GameRng) -> void:
	for oid in GS.alive_countries(s):
		var o: Dictionary = s["countries"][oid]
		if str(o.get("union_with", "")) != cid:
			continue
		if rng.chance(0.4):
			o["union_with"] = ""
			st(o)["union_with"] = ""
			DiplomacySystem.release_vassal(s, cid, oid)
			GS.note(s, oid, "politics", "NOTE_UNION_ENDED", {"other": cid})
			GS.note(s, cid, "politics", "NOTE_UNION_ENDED", {"other": oid})

## --- AI ---------------------------------------------------------------------------------------------------------------------------------------
const MARRIAGE_APPETITE := {"diplomatic": 2.0, "coalition_builder": 1.8, "naval_trade": 1.2, "economic": 1.0, "defensive": 1.3, "opportunistic": 1.0,
	"expansionist": 0.9, "aggressive": 0.5, "isolationist": 0.3}

static func ai_turn(s: Dictionary, cid: String, rng: GameRng) -> void:
	var c: Dictionary = s["countries"][cid]
	if not is_hereditary(c) or bool(c.get("native", false)):
		return
	var d := st(c)
	var inc := maxf(10.0, float(c.get("budget", {}).get("income", 20.0)))
	if d["crisis"] != null and float(c["gold"]) > crisis_cost(s, cid) + inc * 2.0 and rng.chance(0.5):
		buy_off_rival(s, cid)
	if str(d["law"]) == "designated" and int(d["designated"]) < 0 and float(c["admin"]) > 60.0:
		var best: Dictionary = {}
		var bq := -1.0
		for r in d["royals"]:
			if float(r["age"]) >= ADULT_AGE and quality(r) > bq:
				bq = quality(r)
				best = r
		if not best.is_empty():
			designate(s, cid, int(best["id"]))
	if (int(s["turn"]) + hash(cid)) % 4 != 0:
		return
	var avail := marriageable(c)
	if avail.is_empty():
		return
	var pers := DiplomacySystem.personality(s, cid)
	if not rng.chance(0.12 * float(MARRIAGE_APPETITE.get(pers, 1.0))):
		return
	var best_o := ""
	var bs := -1e9
	for oid in GS.alive_countries(s):
		if oid == cid or married(s, cid, oid) or not is_hereditary(s["countries"][oid]) or bool(s["countries"][oid].get("native", false)):
			continue
		if not (DiplomacySystem.borders(s, cid, oid) or GS.allied(s, cid, oid)):
			continue
		if GS.at_war(s, cid, oid):
			continue
		var sc := GS.opinion(s, oid, cid) * 0.1 + DiplomacySystem.power_score(s, oid) * 0.01 + rng.randf()
		if GS.allied(s, cid, oid):
			sc += 3.0
		if sc > bs:
			bs = sc
			best_o = oid
	if best_o == "":
		return
	# offer the least capable adult royal: the realm keeps its best
	var offer: Dictionary = avail[0]
	for r in avail:
		if quality(r) < quality(offer):
			offer = r
	propose_marriage(s, cid, best_o, int(offer["id"]))

## validation
static func validate(s: Dictionary, cid: String) -> Array:
	var errs: Array = []
	var c: Dictionary = s["countries"][cid]
	if not (c.get("dyn") is Dictionary):
		return ["country %s: dyn missing" % cid]
	var d: Dictionary = c["dyn"]
	var seen := {}
	for r in d["royals"]:
		if seen.has(int(r["id"])):
			errs.append("country %s: duplicate royal id" % cid)
		seen[int(r["id"])] = true
		if float(r["age"]) < 0.0 or float(r["health"]) < 0.0:
			errs.append("country %s: bad royal" % cid)
	if is_hereditary(c) and c["heir"] != null and not (c["heir"] is Dictionary):
		errs.append("country %s: heir malformed" % cid)
	return errs
