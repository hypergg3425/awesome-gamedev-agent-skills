extends Node
func _norm(s: Dictionary) -> String:
	var txt := JSON.stringify(Saves.export_state(s), "", false, true)
	var parsed: Variant = JSON.parse_string(txt)
	return JSON.stringify(parsed, "  ", false, true)
func _w(path: String, t: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(t); f.close()
func _ready() -> void:
	var def: Dictionary = Defs.all_scenarios()["early_modern"]
	var a := ScenarioLoader.build(def, def["default_player"], "normal", 321)
	var b := ScenarioLoader.build(def, def["default_player"], "normal", 321)
	for i in 7:
		TurnManager.end_turn(a)
	for i in 7:
		TurnManager.end_turn(b)
	Saves.save_slot("pp", b)
	b = Saves.load_slot("pp")["state"]
	Saves.delete_slot("pp")
	for i in 7:
		TurnManager.end_turn(a)
	for i in 7:
		TurnManager.end_turn(b)
	var ha := _norm(a)
	var hb := _norm(b)
	if ha != hb:
		_w("/tmp/claude-0/orig.json", ha); _w("/tmp/claude-0/loaded.json", hb)
		print("divergence at end")
	else:
		print("identical")
	get_tree().quit(0)
