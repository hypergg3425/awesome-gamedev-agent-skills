class_name GovMechanics
extends RefCounted
## The distinctive mechanic of each of the nine government types (data/governments.json -> politics.mech).
## Each one has a real upside and a real cost, so that the governments play differently, not just with different numbers.

static func process(s: Dictionary, cid: String, c: Dictionary, rng: GameRng) -> void:
	var mech := str(FactionsSystem.politics_of(c).get("mech", ""))
	var fs := FactionsSystem.st(c)
	var m: Dictionary = fs["mech"]
	var prov := GS.owned(s, cid).size()
	match mech:
		"court_favour":
			# the crown rules through its household: a loyal court pays, a resentful one steals
			if FactionsSystem.loyalty(c, "court") > 60.0:
				_temp(s, c, "court_favour", {"tax": 0.03, "admin_cap": 0.02})
			elif FactionsSystem.loyalty(c, "court") < 35.0:
				fs["corr"] = minf(100.0, float(fs["corr"]) + 0.3)
			var ru := DynastySystem.effective_ruler(c)
			if int(ru["adm"]) + int(ru["dip"]) + int(ru["mil"]) < 12:
				fs["corr"] = minf(100.0, float(fs["corr"]) + 0.15)
		"parliament":
			# parliament pulls every faction towards the consensus; calm politics steady the state, but taxes are capped
			var mean := FactionsSystem.mean_loyalty(c)
			for fid in FactionsSystem.FACTIONS:
				FactionsSystem.shift_loyalty(c, fid, (mean - FactionsSystem.loyalty(c, fid)) * 0.08)
			if mean > 55.0:
				_temp(s, c, "parliament", {"stability": 0.4, "research": 0.02})
		"elections":
			if float(c["legitimacy"]) < 40.0 and FactionsSystem.mean_loyalty(c) < 40.0:
				c["legitimacy"] = maxf(0.0, float(c["legitimacy"]) - 0.5)   # a government without a mandate bleeds legitimacy
		"oligarchy":
			# merchant princes govern cities well and land badly
			var lc := float(FactionsSystem.politics_of(c).get("land_cap", 8))
			if float(prov) > lc:
				var over := float(prov) - lc
				_temp(s, c, "oligarchy_strain", {"admin_cap": -0.03 * over, "unrest": 0.01 * over})
			if float(c["tax_rate"]) > 0.35:
				FactionsSystem.shift_loyalty(c, "merchants", -1.5)
		"governors":
			# far-flung governors: the empire's provinces drift towards autonomy
			if float(prov) >= 12.0 and FactionsSystem.loyalty(c, "military") < 50.0:
				fs["corr"] = minf(100.0, float(fs["corr"]) + 0.2)
		"clan_unity":
			var unity := float(m.get("unity", 70.0))
			var at_war := not GS.wars_of(s, cid).is_empty()
			unity += 0.6 if at_war else -0.35
			unity -= maxf(0.0, float(c["tax_rate"]) - 0.25) * 6.0
			m["unity"] = clampf(unity, 0.0, 100.0)
			_temp(s, c, "clan_unity", {"manpower": 0.15 * (float(m["unity"]) - 50.0) / 50.0})
		"clerical_authority":
			if FactionsSystem.loyalty(c, "clergy") < 30.0 and int(m.get("schism_turn", -99)) + 20 < int(s["turn"]) and rng.chance(0.08):
				m["schism_turn"] = int(s["turn"])
				c["stability"] = maxf(0.0, float(c["stability"]) - 8.0)
				c["legitimacy"] = maxf(0.0, float(c["legitimacy"]) - 10.0)
				for pid in GS.owned(s, cid):
					s["provinces"][pid]["unrest"] = minf(100.0, float(s["provinces"][pid]["unrest"]) + 6.0)
				GS.note(s, cid, "politics", "NOTE_SCHISM", {})
				GS.history(s, cid, "politics", "HIST_SCHISM", {})
			if FactionsSystem.loyalty(c, "clergy") > 65.0:
				_temp(s, c, "clerical_authority", {"unrest": -0.03, "prestige": 0.03})
		"vassal_lords":
			# great lords: loyal levies for a weak crown; a strong crown makes them restless
			var nl := FactionsSystem.loyalty(c, "nobility")
			_temp(s, c, "vassal_lords", {"manpower": 0.06 * (nl - 50.0) / 50.0})
			if float(c["legitimacy"]) > 65.0:
				FactionsSystem.shift_loyalty(c, "nobility", -0.3)
		"junta":
			FactionsSystem.shift_loyalty(c, "popular", -0.12)
			var ml := FactionsSystem.loyalty(c, "military")
			if ml < 55.0 and int(fs["coup_cool"]) <= int(s["turn"]) and rng.chance(0.012 * (55.0 - ml) / 55.0):
				_counter_coup(s, cid, c, rng)

static func _temp(s: Dictionary, c: Dictionary, key: String, mods: Dictionary) -> void:
	c["temp_mods"] = (c["temp_mods"] as Array).filter(func(t: Dictionary) -> bool: return t.get("key", "") != key)
	c["temp_mods"].append({"mods": mods, "until": int(s["turn"]) + 1, "key": key})

## inside a junta the generals replace one another: no government change, a new strongman
static func _counter_coup(s: Dictionary, cid: String, c: Dictionary, rng: GameRng) -> void:
	var fs := FactionsSystem.st(c)
	c["ruler"] = PoliticsSystem.new_ruler(s, cid, 38, 56, "mil")
	DynastySystem.st(c)["name"] = "Junta"
	c["stability"] = maxf(0.0, float(c["stability"]) - 5.0)
	fs["coup_cool"] = int(s["turn"]) + 24
	FactionsSystem.shift_loyalty(c, "military", 20.0)
	FactionsSystem.shift_loyalty(c, "popular", -6.0)
	GS.note(s, cid, "politics", "NOTE_COUNTER_COUP", {"ruler": c["ruler"]["name"]})
	GS.history(s, cid, "politics", "HIST_COUNTER_COUP", {"ruler": c["ruler"]["name"]})
	Mods.invalidate(s)

## tribal confederations may split when their chief dies and clan unity is low
static func on_leader_change(s: Dictionary, cid: String, c: Dictionary, rng: GameRng) -> void:
	if str(FactionsSystem.politics_of(c).get("mech", "")) != "clan_unity":
		return
	var m: Dictionary = FactionsSystem.st(c)["mech"]
	if float(m.get("unity", 70.0)) < 40.0 and GS.owned(s, cid).size() >= 4 and rng.chance(0.5):
		CivilWar.start(s, cid, "clan_split", "military", "", rng)
