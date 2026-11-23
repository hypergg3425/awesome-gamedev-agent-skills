class_name Achievements
extends RefCounted
## Achievements and lifetime statistics, persisted in user://profile.json. Every achievement is
## evaluated from real campaign state / events (never from UI actions).

const PATH := "user://profile.json"
const DEFS: Array = [
	{"id": "first_conquest", "icon": "war"},
	{"id": "great_diplomat", "icon": "diplomacy"},
	{"id": "economic_powerhouse", "icon": "gold"},
	{"id": "military_supremacy", "icon": "military"},
	{"id": "world_conqueror", "icon": "crown"},
	{"id": "peaceful_expansion", "icon": "peace"},
	{"id": "technological_pioneer", "icon": "technology"},
	{"id": "survived_against_all_odds", "icon": "fort"},
]

static func load_profile() -> Dictionary:
	var p := {"unlocked": {}, "lifetime": {"campaigns": 0, "victories": 0, "battles": 0, "battles_won": 0, "provinces_conquered": 0, "turns": 0, "best_score": 0.0, "wars_won": 0, "alliances": 0}}
	if FileAccess.file_exists(PATH):
		var jp := JSON.new()
		if jp.parse(FileAccess.get_file_as_string(PATH)) == OK and jp.data is Dictionary:
			var d: Dictionary = jp.data
			if d.get("unlocked") is Dictionary:
				p["unlocked"] = d["unlocked"]
			if d.get("lifetime") is Dictionary:
				for k in d["lifetime"]:
					p["lifetime"][k] = d["lifetime"][k]
	return p

static func save_profile(p: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(p))

static func is_unlocked(id: String) -> bool:
	return load_profile()["unlocked"].has(id)

## Evaluate achievements for the human player(s). Returns the ids unlocked just now.
static func check(s: Dictionary) -> Array:
	var prof := load_profile()
	var newly: Array = []
	var pl: String = s["player"]
	var c: Dictionary = s["countries"].get(pl, {})
	if c.is_empty() or not c.get("alive", false):
		return newly
	var st: Dictionary = c["stats"]
	var conds := {
		"first_conquest": float(st.get("provinces_conquered", 0.0)) + float(st.get("sieges_won", 0.0)) >= 1.0 and float(st.get("provinces_conquered", 0.0)) >= 1.0,
		"great_diplomat": float(st.get("alliances", 0.0)) >= 3.0 or GS.vassals_of(s, pl).size() >= 2,
		"economic_powerhouse": float(c.get("budget", {}).get("income", 0.0)) >= 1500.0 or (VictorySystem.progress(s, pl)["economic"]["value"] >= 0.25 and int(s["turn"]) > 20),
		"military_supremacy": UnitUtil.country_regiments(s, pl) >= 80.0 or float(st.get("wars_won", 0.0)) >= 3.0,
		"world_conqueror": s.get("victory_type", "") == "territory" and s.get("winner", "") == pl,
		"peaceful_expansion": GS.owned(s, pl).size() >= int(st.get("start_provinces", 99)) + 4 and float(st.get("wars", 0.0)) == 0.0,
		"technological_pioneer": TechSystem.avg_level(c) >= 3.5,
		"survived_against_all_odds": int(st.get("start_provinces", 99)) <= 3 and int(s["turn"]) >= 100 and c["overlord"] == "",
	}
	for id in conds:
		if conds[id] and not prof["unlocked"].has(id):
			prof["unlocked"][id] = Time.get_unix_time_from_system()
			newly.append(id)
	if not newly.is_empty():
		save_profile(prof)
	return newly

static func record_campaign_end(s: Dictionary) -> void:
	var prof := load_profile()
	var pl: String = s["player"]
	var lt: Dictionary = prof["lifetime"]
	lt["campaigns"] = int(lt["campaigns"]) + 1
	if s.get("winner", "") == pl:
		lt["victories"] = int(lt["victories"]) + 1
	var st: Dictionary = s["countries"][pl]["stats"]
	lt["battles"] = int(lt["battles"]) + int(st.get("battles", 0.0))
	lt["battles_won"] = int(lt["battles_won"]) + int(st.get("battles_won", 0.0))
	lt["provinces_conquered"] = int(lt["provinces_conquered"]) + int(st.get("provinces_conquered", 0.0))
	lt["wars_won"] = int(lt["wars_won"]) + int(st.get("wars_won", 0.0))
	lt["alliances"] = int(lt["alliances"]) + int(st.get("alliances", 0.0))
	lt["turns"] = int(lt["turns"]) + int(s["turn"])
	if s["countries"][pl]["alive"]:
		lt["best_score"] = maxf(float(lt["best_score"]), float(VictorySystem.score(s, pl)["total"]))
	save_profile(prof)
	check(s)
