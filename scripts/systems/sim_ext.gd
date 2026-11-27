class_name SimExt
extends RefCounted
## Glue for the v2.1 simulation systems (espionage, dynasties, factions, economy depth): idempotent state
## initialisation, the save v3 -> v4 migration, per-turn phases, AI entry point and structural validation.

static func ensure(s: Dictionary) -> void:
	if not s.has("econ"):
		s["econ"] = {"forgiven": 0.0}
	if not s.has("rebel_hold"):
		s["rebel_hold"] = {}
	for cid in s["countries"]:
		ensure_country(s, cid)

static func ensure_country(s: Dictionary, cid: String) -> void:
	var c: Dictionary = s["countries"][cid]
	if cid == "REB":
		return
	if not c.has("esp"):
		c["esp"] = EspionageSystem.new_state()
	if not c.has("fac"):
		c["fac"] = FactionsSystem.new_state()
	if not c.has("eco"):
		c["eco"] = EconomyDepth.new_state()
	var d := DynastySystem.st(c)
	if not bool(d.get("init", false)):
		d["init"] = true
		DynastySystem.init_country(s, cid)

## save v3 -> v4: add the new structures (royal families are generated on first use, see ensure())
static func migrate_v4(state: Dictionary) -> void:
	state["econ"] = state.get("econ", {"forgiven": 0.0})
	state["rebel_hold"] = state.get("rebel_hold", {})
	for cid in state.get("countries", {}):
		if cid == "REB":
			continue
		var c: Dictionary = state["countries"][cid]
		c["esp"] = c.get("esp", EspionageSystem.new_state())
		c["fac"] = c.get("fac", FactionsSystem.new_state())
		c["eco"] = c.get("eco", EconomyDepth.new_state())
		if not c.has("dyn"):
			DynastySystem.st(c)
		if c.get("heir") is Dictionary and not (c["heir"] as Dictionary).has("id"):
			(c["heir"] as Dictionary)["id"] = -1

## runs after a country's economy
static func economy_phase(s: Dictionary, cid: String) -> void:
	var rng := GS.rng_of(s)
	EconomyDepth.process_turn(s, cid, rng)
	EspionageSystem.process_turn(s, cid)

## runs once per turn after politics
static func world_phase(s: Dictionary) -> void:
	CivilWar.process_rebel_holds(s, GS.rng_of(s))

static func ai_turn(s: Dictionary, cid: String, personality: String, rng: GameRng) -> void:
	EconomyDepth.ai_turn(s, cid)
	FactionsSystem.ai_turn(s, cid, rng)
	EspionageSystem.ai_turn(s, cid, personality, rng)

static func validate(s: Dictionary) -> Array:
	var errs: Array = []
	for cid in s["countries"]:
		var c: Dictionary = s["countries"][cid]
		if cid == "REB" or not c.get("alive", false):
			continue
		errs.append_array(EspionageSystem.validate(s, cid))
		errs.append_array(DynastySystem.validate(s, cid))
		errs.append_array(FactionsSystem.validate(s, cid))
		errs.append_array(EconomyDepth.validate(s, cid))
		if errs.size() > 12:
			break
	return errs
