extends Node
## Screenshot regression: renders key screens at several window sizes, downsamples them to small PNGs and compares them
## with the references in tests/ui_refs/ (tolerant: per-pixel channel threshold + maximum share of differing pixels).
## Compare:  xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 res://tests/ui_regress.tscn
## Update refs after an intentional visual change:   ... res://tests/ui_regress.tscn -- update=1
## Options: sizes=1280x720,854x393  pixel_tol=28 max_diff=0.03  out=/tmp/ui_regress (writes the current shots there)

const REF_DIR := "res://tests/ui_refs"
const REF_W := 320

var sizes: Array = ["1280x720", "854x393", "2400x1080"]
var update := false
var pixel_tol := 28
var max_diff := 0.03
var out_dir := ""
var failures: Array = []
var compared := 0

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	update = str(args.get("update", "0")) == "1"
	pixel_tol = int(args.get("pixel_tol", pixel_tol))
	max_diff = float(args.get("max_diff", max_diff))
	out_dir = str(args.get("out", ""))
	if args.has("sizes"):
		sizes = str(args["sizes"]).split(",")
	Settings.set_value("animations", false, false)
	Settings.set_value("tutorial_done", true, false)
	Settings.set_value("language", "en", false)
	Loc.set_language("en")
	Layout.install(get_window())
	get_tree().root.theme = UI.theme()
	Defs.load_geometry()
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	for sz in sizes:
		await _run(str(sz))
	print("ui_regress: %d compared, %d failures%s" % [compared, failures.size(), " (refs updated)" if update else ""])
	for f in failures:
		print("  FAIL ", f)
	get_tree().quit(1 if failures.size() > 0 and not update else 0)

func _frames(n: int = 4) -> void:
	for i in n:
		await get_tree().process_frame

func _clear(host: Node) -> void:
	for c in host.get_children():
		c.queue_free()
	await _frames(2)

func _run(sz: String) -> void:
	var p := sz.split("x")
	get_window().size = Vector2i(int(p[0]), int(p[1]))
	await _frames(4)
	UI.insets_override = {}
	await _clear(self)
	var menu: Control = load("res://scenes/menus/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(4)
	await _shot(sz, "menu")
	Game.new_game("early_modern", "FRA", "normal", 5)
	await _clear(self)
	var cs: CampaignScreen = load("res://scenes/campaign/campaign.tscn").instantiate()
	add_child(cs)
	await get_tree().create_timer(0.6).timeout
	await _frames(3)
	await _shot(sz, "campaign")
	cs.open_sheet("economy")
	await _frames(3)
	await _shot(sz, "sheet_economy")
	cs.close_sheets()
	cs.select_province("fra_normandy")
	cs.province_panel.tab = "build"
	cs.province_panel.refresh()
	await _frames(3)
	await _shot(sz, "province_build")
	cs.province_panel.dismiss()
	SettingsPanel.show_dialog(cs.overlay_layer)
	await _frames(4)
	await _shot(sz, "settings")
	await _clear(self)

func _shot(sz: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var h := int(round(float(REF_W) * img.get_height() / float(img.get_width())))
	img.resize(REF_W, h, Image.INTERPOLATE_BILINEAR)
	var key := "%s_%s.png" % [sz, name]
	if out_dir != "":
		img.save_png("%s/%s" % [out_dir, key])
	var path := "%s/%s" % [REF_DIR, key]
	if update:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REF_DIR))
		img.save_png(ProjectSettings.globalize_path(path))
		return
	compared += 1
	if not FileAccess.file_exists(path):
		failures.append("%s: no reference image (run with update=1)" % key)
		return
	var ref := Image.load_from_file(ProjectSettings.globalize_path(path))
	ref.convert(Image.FORMAT_RGB8)
	if ref.get_size() != img.get_size():
		failures.append("%s: size %s differs from reference %s" % [key, img.get_size(), ref.get_size()])
		return
	var d := compare(img, ref, pixel_tol)
	if d > max_diff:
		failures.append("%s: %.2f%% pixels differ (limit %.2f%%)" % [key, d * 100.0, max_diff * 100.0])

## Share of pixels whose largest channel difference exceeds `tol` (0..255).
static func compare(a: Image, b: Image, tol: int) -> float:
	var da := a.get_data()
	var db := b.get_data()
	var n := mini(da.size(), db.size()) / 3
	var bad := 0
	for i in n:
		var o := i * 3
		var m := maxi(maxi(absi(da[o] - db[o]), absi(da[o + 1] - db[o + 1])), absi(da[o + 2] - db[o + 2]))
		if m > tol:
			bad += 1
	return float(bad) / float(maxi(n, 1))
