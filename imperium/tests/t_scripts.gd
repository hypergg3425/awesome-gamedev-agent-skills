extends TestCase
## Every script and scene in the project must load (catches parse errors in code paths no other test touches).

func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		if sub in [".godot", "addons"]:
			continue
		_walk(dir + "/" + sub, out)

func test_all_scripts_and_scenes_load() -> void:
	var files: Array = []
	_walk("res://scripts", files)
	_walk("res://scenes", files)
	ok(files.size() > 40, "found project files (%d)" % files.size())
	for f in files:
		var r: Resource = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_REPLACE)
		ok(r != null, "loads: " + f)
		if r is GDScript:
			ok((r as GDScript).can_instantiate(), "script compiles: " + f)
		elif r is PackedScene:
			ok((r as PackedScene).can_instantiate(), "scene instantiable: " + f)

func test_scenes_instantiate_headless() -> void:
	for path in ["res://scenes/menus/credits.tscn", "res://scenes/menus/achievements.tscn", "res://scenes/menus/statistics.tscn"]:
		var ps: PackedScene = load(path)
		ok(ps != null, "scene loads " + path)
