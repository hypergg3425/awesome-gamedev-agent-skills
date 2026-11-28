class_name TestCase
extends RefCounted
## Minimal assertion helpers. Failures are collected, never thrown, so one run reports everything.

var failures: Array[String] = []
var checks := 0
var current := ""

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append("[%s] %s" % [current, msg])

func eq(a: Variant, b: Variant, msg: String) -> void:
	checks += 1
	if a != b:
		failures.append("[%s] %s (got %s, expected %s)" % [current, msg, str(a), str(b)])

func near(a: float, b: float, tol: float, msg: String) -> void:
	checks += 1
	if absf(a - b) > tol:
		failures.append("[%s] %s (got %f, expected %f)" % [current, msg, a, b])

func fail(msg: String) -> void:
	checks += 1
	failures.append("[%s] %s" % [current, msg])

## fixtures -------------------------------------------------------------------------------------
static func scenario(id: String) -> Dictionary:
	var defs: Dictionary = Defs.all_scenarios()
	return defs.get(id, {})

static func new_state(id: String = "early_modern", player: String = "", difficulty: String = "normal", seed_value: int = 777) -> Dictionary:
	Defs.use_map_set(Defs.default_map_set)   # isolate from tests that switched the active map set
	var def := scenario(id)
	if player == "":
		player = str(def.get("default_player", ""))
	return ScenarioLoader.build(def, player, difficulty, seed_value)

static func run_turns(s: Dictionary, n: int) -> Array:
	var errs: Array = []
	for i in n:
		var r := TurnManager.end_turn(s)
		if not r.get("ok", false):
			errs.append("turn failed at %d" % i)
			break
	return errs

static func state_hash(s: Dictionary) -> int:
	return JSON.stringify(Saves.export_state(s), "", true).hash()

## find two neighbouring non-native countries (a owns a province next to one of b)
static func neighbour_pair(s: Dictionary, min_provs: int = 1) -> Array:
	for a in GS.alive_countries(s):
		if str(a).begins_with("NAT_") or GS.owned(s, a).size() < min_provs:
			continue
		for pid in GS.owned(s, a):
			for nb in Defs.neighbors(pid):
				var o: String = s["provinces"][nb]["owner"]
				if o != a and o != "" and not str(o).begins_with("NAT_") and GS.owned(s, o).size() >= min_provs:
					if GS.overlord_of(s, a) != "" or GS.overlord_of(s, o) != "" or GS.allied(s, a, o) or GS.at_war(s, a, o):
						continue
					if not GS.vassals_of(s, a).is_empty() or not GS.vassals_of(s, o).is_empty():
						continue
					# the extended map finds different first neighbours; skip historic claim feuds so fixtures stay neutral
					if Defs.map_set == "extended" and (DiplomacySystem.claim_count(s, a, o) > 0 or DiplomacySystem.claim_count(s, o, a) > 0):
						continue
					return [a, o, pid, nb]
	return []
