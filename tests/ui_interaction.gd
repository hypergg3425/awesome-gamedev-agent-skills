extends Node
## UI interaction tests with real input events (InputEventScreenTouch / ScreenDrag / MouseButton) injected through the
## viewport, so they exercise the same GUI routing as a finger on a phone: toolbar taps, sheets, province selection,
## one-finger pan, pinch zoom, long press, accidental-gesture guard, End turn, back button, tutorial skip and replay.
## Run: xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 res://tests/ui_interaction.tscn
##      [-- size=1280x720]     Exit code 0 = all assertions passed.

var checks := 0
var failures: Array = []
var cs: CampaignScreen

func _ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)
		print("  FAIL ", msg)

func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame

## --- input helpers -----------------------------------------------------------------------------------------------
## Events from the OS arrive in window pixels; test coordinates are virtual (post-stretch) pixels.
func _send(e: InputEvent) -> void:
	var k := Vector2(get_window().size) / get_viewport().get_visible_rect().size
	if e is InputEventScreenTouch:
		(e as InputEventScreenTouch).position *= k
	elif e is InputEventScreenDrag:
		(e as InputEventScreenDrag).position *= k
		(e as InputEventScreenDrag).relative *= k
	elif e is InputEventMouseButton:
		(e as InputEventMouseButton).position *= k
		(e as InputEventMouseButton).global_position *= k
	Input.parse_input_event(e)
	await _frames(2)

func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	await _send(e)

func _drag(idx: int, from: Vector2, to: Vector2, steps: int = 6) -> void:
	for i in steps:
		var a := from.lerp(to, float(i) / float(steps))
		var b := from.lerp(to, float(i + 1) / float(steps))
		var e := InputEventScreenDrag.new()
		e.index = idx
		e.position = b
		e.relative = b - a
		await _send(e)

func _tap(pos: Vector2) -> void:
	await _touch(0, pos, true)
	await _touch(0, pos, false)
	await _frames(2)

func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _tap_control(c: Control) -> void:
	await _tap(_center(c))

func _find_button(root: Node, text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and b.text == text:
			return b
	return null

## Screen position of a province centre; moves the camera first so it is on screen and clear of chrome.
func _province_pos(pid: String) -> Vector2:
	var i: int = Defs.province_index[pid]
	cs.mapview.focus_on(cs.mapview.prov_center[i], 3.0, false)
	await _frames(2)
	return cs.mapview.world_to_screen(cs.mapview.prov_center[i]) + cs.mapview.global_position

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if args.has("size"):
		var p := str(args["size"]).split("x")
		get_window().size = Vector2i(int(p[0]), int(p[1]))
		await _frames(4)
	Settings.set_value("animations", false, false)
	Settings.set_value("tutorial_done", true, false)
	Settings.set_value("confirm_actions", false, false)
	Layout.install(get_window())
	get_tree().root.theme = UI.theme()
	Defs.load_geometry()
	var r: Dictionary = Game.new_game("early_modern", "FRA", "normal", 5)
	_ok(r.get("ok", false), "new_game")
	cs = load("res://scenes/campaign/campaign.tscn").instantiate()
	get_tree().root.add_child.call_deferred(cs)
	await _frames(2)
	get_tree().current_scene = cs
	await get_tree().create_timer(0.6).timeout
	await _frames(3)
	await _test_toolbar_and_sheets()
	await _test_hud_chips()
	await _test_select_province()
	await _test_pan_and_pinch()
	await _test_long_press()
	await _test_ui_guard()
	await _test_map_modes()
	await _test_back_button()
	await _test_tutorial()
	await _test_end_turn()
	print("ui_interaction: %d assertions, %d failures" % [checks, failures.size()])
	cs.queue_free()
	get_tree().quit(1 if failures.size() > 0 else 0)

## --- tests ---------------------------------------------------------------------------------------------------------
func _test_toolbar_and_sheets() -> void:
	cs.close_sheets()
	await _frames(2)
	var names := ["economy", "military", "diplomacy", "technology", "politics", "objectives"]
	for i in names.size():
		var b: Button = cs.toolbar.get_child(i)
		await _tap_control(b)
		_ok(cs.open_sheet_name == names[i], "toolbar tap %d opens %s (got '%s')" % [i, names[i], cs.open_sheet_name])
		_ok((cs.sheets[names[i]] as Control).visible, "sheet %s visible" % names[i])
		if cs.layout["compact"]:
			cs.close_sheets()
			await _frames(2)
	if not cs.layout["compact"]:
		# tapping the same button again toggles the sheet closed
		await _tap_control(cs.toolbar.get_child(names.size() - 1))
		_ok(cs.open_sheet_name == "", "second tap closes the sheet")
	cs.open_sheet("economy")
	await _frames(3)
	var close: Button = cs.sheets["economy"].find_child("CloseButton", true, false)
	await _tap_control(close)
	_ok(cs.open_sheet_name == "", "sheet close button closes it")
	# tab switching by touch
	cs.open_sheet("economy")
	await _frames(3)
	var sh: Sheet = cs.sheets["economy"]
	var second: Button = sh.tabs[1]["button"]
	await _tap_control(second)
	_ok(sh.current == sh.tabs[1]["id"], "tab tap selects second tab")
	cs.close_sheets()
	await _frames(2)

func _test_hud_chips() -> void:
	await _tap_control(cs.hud.refs["gold"])
	_ok(cs.open_sheet_name == "economy", "treasury chip opens economy")
	cs.close_sheets()
	await _frames(2)
	await _tap_control(cs.hud.refs["manpower"])
	_ok(cs.open_sheet_name == "military", "manpower chip opens military")
	cs.close_sheets()
	await _frames(2)
	var more: Button = cs.hud.box.get_child(cs.hud.box.get_child_count() - 3)
	await _tap_control(more)
	_ok(cs.hud.detail.visible, "'more' button reveals secondary stats")
	_ok(cs.hud.refs["d_prestige"].text != "", "detail panel shows prestige")
	await _tap_control(more)
	_ok(not cs.hud.detail.visible, "'more' button collapses them again")
	await _tap_control(cs.hud.refs["events_btn"])
	_ok(cs.open_sheet_name == "events", "bell opens events")
	cs.close_sheets()
	await _frames(2)

func _test_select_province() -> void:
	cs.close_sheets()
	cs.province_panel.dismiss()
	Game.selected_province = ""
	var pid := "fra_normandy"
	var pos := await _province_pos(pid)
	await _tap(pos)
	_ok(Game.selected_province == pid, "tap on province selects it (selected '%s')" % Game.selected_province)
	_ok(cs.province_panel.visible, "province panel opens on selection")
	# tapping empty sea clears the selection
	cs.mapview.focus_on(Vector2(-300, 700), 1.0, false)
	await _frames(2)
	var sea := Vector2(200, 400) + cs.mapview.global_position
	var before := Game.selected_province
	if cs.mapview.province_id_at_screen(sea) == "":
		await _tap(sea)
		_ok(not cs.province_panel.visible, "tap on empty sea closes the province panel (was '%s')" % before)

func _test_pan_and_pinch() -> void:
	cs.province_panel.dismiss()
	cs.close_sheets()
	cs.mapview.fit_world()
	cs.mapview.focus_on(cs.mapview.bounds.get_center(), 2.0, false)
	await _frames(3)
	var c0 := cs.mapview.center
	var sel0 := Game.selected_province
	var start := cs.mapview.size * 0.5 + cs.mapview.global_position + Vector2(40, 20)
	await _touch(0, start, true)
	await _drag(0, start, start + Vector2(-160, 0))
	await _touch(0, start + Vector2(-160, 0), false)
	_ok(cs.mapview.center.x > c0.x + 20.0, "one-finger drag left pans the map right (dx=%.1f)" % (cs.mapview.center.x - c0.x))
	_ok(Game.selected_province == sel0, "a drag does not select a province")
	# pinch out
	cs.mapview.focus_on(cs.mapview.bounds.get_center(), 2.0, false)
	await _frames(2)
	var z0 := cs.mapview.zoom
	var mid := cs.mapview.size * 0.5 + cs.mapview.global_position
	var a := mid + Vector2(-40, 0)
	var b := mid + Vector2(40, 0)
	await _touch(0, a, true)
	await _touch(1, b, true)
	for i in 6:
		a += Vector2(-20, 0)
		b += Vector2(20, 0)
		var e0 := InputEventScreenDrag.new()
		e0.index = 0
		e0.position = a
		e0.relative = Vector2(-20, 0)
		await _send(e0)
		var e1 := InputEventScreenDrag.new()
		e1.index = 1
		e1.position = b
		e1.relative = Vector2(20, 0)
		await _send(e1)
	await _touch(0, a, false)
	await _touch(1, b, false)
	_ok(cs.mapview.zoom > z0 * 1.3, "pinch out zooms in (%.2f -> %.2f)" % [z0, cs.mapview.zoom])
	_ok(Game.selected_province == sel0, "a pinch does not select a province")
	# pinch in
	var z1 := cs.mapview.zoom
	a = mid + Vector2(-140, 0)
	b = mid + Vector2(140, 0)
	await _touch(0, a, true)
	await _touch(1, b, true)
	for i in 6:
		a += Vector2(18, 0)
		b += Vector2(-18, 0)
		var e2 := InputEventScreenDrag.new()
		e2.index = 0
		e2.position = a
		e2.relative = Vector2(18, 0)
		await _send(e2)
		var e3 := InputEventScreenDrag.new()
		e3.index = 1
		e3.position = b
		e3.relative = Vector2(-18, 0)
		await _send(e3)
	await _touch(0, a, false)
	await _touch(1, b, false)
	_ok(cs.mapview.zoom < z1 * 0.8, "pinch in zooms out (%.2f -> %.2f)" % [z1, cs.mapview.zoom])
	# mouse wheel zoom
	var z2 := cs.mapview.zoom
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_UP
	w.pressed = true
	w.position = mid
	w.global_position = mid
	await _send(w)
	_ok(cs.mapview.zoom > z2, "mouse wheel up zooms in")

func _test_long_press() -> void:
	cs.province_panel.dismiss()
	Game.selected_province = ""
	var pos := await _province_pos("fra_normandy")
	await _touch(0, pos, true)
	await get_tree().create_timer(GestureLayer.LONG_PRESS_SEC + 0.25).timeout
	await _frames(2)
	var popup: Node = cs.ui_root.get_node_or_null("ContextPopup")
	_ok(popup != null, "long press opens the context popup")
	await _touch(0, pos, false)
	_ok(Game.selected_province == "", "releasing after a long press does not also select (selected '%s')" % Game.selected_province)
	if popup != null:
		var r := (popup as Control).get_global_rect()
		_ok(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(r), "popup stays inside the viewport %s" % r)
		# "Open province" button of the popup selects the province
		var open := _find_button(popup, Loc.t("CTX_OPEN"))
		_ok(open != null, "popup has an Open button")
		if open != null:
			await _tap_control(open)
			_ok(Game.selected_province == "fra_normandy", "popup Open selects the province")
	# popup dismissed by tapping empty map / back
	ContextPopup.show_for(cs, "province", "fra_normandy", Vector2(500, 300))
	await _frames(2)
	cs.on_back_requested()
	await _frames(2)
	_ok(cs.ui_root.get_node_or_null("ContextPopup") == null, "back button dismisses the popup")

func _test_ui_guard() -> void:
	# a drag that starts on a toolbar button must not pan the map
	cs.close_sheets()
	cs.mapview.focus_on(cs.mapview.bounds.get_center(), 2.0, false)
	await _frames(3)
	var c0 := cs.mapview.center
	var b: Button = cs.toolbar.get_child(0)
	var p := _center(b)
	await _touch(0, p, true)
	await _drag(0, p, p + Vector2(200, 40))
	await _touch(0, p + Vector2(200, 40), false)
	_ok(cs.mapview.center.distance_to(c0) < 0.5, "drag starting on a toolbar button does not pan the map")
	# touch on the open sheet does not reach the map either
	cs.close_sheets()
	cs.open_sheet("economy")
	await _frames(3)
	var sh: Control = cs.sheets["economy"]
	var sp := sh.get_global_rect().get_center()
	var sel := Game.selected_province
	await _tap(sp)
	_ok(Game.selected_province == sel, "tap on an open sheet does not select a province behind it")
	cs.close_sheets()
	await _frames(2)

func _test_map_modes() -> void:
	var map_btn: Button = cs.toolbar.get_child(cs.toolbar.get_child_count() - 1)
	await _tap_control(map_btn)
	_ok(cs.mode_strip.visible, "map button shows the mode strip")
	var terrain: Button = null
	for b in cs.mode_row.get_children():
		if b.get_meta("mode", "") == "terrain":
			terrain = b
	await _tap_control(terrain)
	_ok(cs.cmap.mode == "terrain", "mode button switches the map mode")
	_ok(not cs.mode_strip.visible, "mode strip closes after choosing")
	cs.set_map_mode("political")

func _test_back_button() -> void:
	cs.close_sheets()
	cs.province_panel.dismiss()
	cs.open_sheet("military")
	await _frames(2)
	Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	_ok(cs.open_sheet_name == "", "back closes the open sheet")
	cs.select_province("fra_normandy")
	await _frames(2)
	_ok(cs.province_panel.visible, "province panel visible before back")
	Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	_ok(not cs.province_panel.visible, "back closes the province panel")
	Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_ok(cs.overlay_layer.get_child_count() == 1, "back with nothing open shows the pause menu")
	Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_ok(cs.overlay_layer.get_child_count() == 0, "back dismisses the pause menu")
	# a proposal must be answered explicitly: back is ignored
	var req := {"id": "ui_test", "from": "ENG", "to": Game.active_player, "action": "alliance", "params": {}, "shown": true}
	DiplomacyPrompts.show_request(cs.overlay_layer, req)
	await _frames(3)
	Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	_ok(cs.overlay_layer.get_child_count() == 1, "back does not dismiss a diplomatic proposal")
	for c in cs.overlay_layer.get_children():
		c.queue_free()
	await _frames(2)

func _tutorial_node() -> Tutorial:
	for c in cs.get_children():
		if c is Tutorial:
			return c as Tutorial
	return null

func _test_tutorial() -> void:
	Settings.set_value("tutorial_done", false, false)
	Tutorial.start(cs, true)
	await _frames(4)
	var t := _tutorial_node()
	_ok(t != null, "tutorial starts")
	if t == null:
		return
	var skip := _find_button(t, Loc.t("TUT_SKIP"))
	_ok(skip != null, "tutorial has a Skip button")
	var next := _find_button(t, Loc.t("TUT_NEXT"))
	if next != null:
		await _tap_control(next)
		_ok(t.step == 1, "Next advances the tutorial (step %d)" % t.step)
	await _tap_control(skip)
	await _frames(3)
	_ok(_tutorial_node() == null, "Skip removes the tutorial")
	_ok(bool(Settings.get_value("tutorial_done")), "skipping marks the tutorial done")
	# replay from the pause menu
	await _tap_control(cs.hud.refs["menu_btn"])
	await _frames(3)
	var replay := _find_button(cs.overlay_layer, Loc.t("TUT_TITLE"))
	_ok(replay != null, "pause menu lists the tutorial replay")
	if replay != null:
		await _tap_control(replay)
		await _frames(4)
		_ok(_tutorial_node() != null, "replay restarts the tutorial")
		var t2 := _tutorial_node()
		if t2 != null:
			t2.finish(true)
	await _frames(3)

func _test_end_turn() -> void:
	cs.close_sheets()
	for c in cs.overlay_layer.get_children():
		c.queue_free()
	await _frames(2)
	Settings.set_value("tutorial_done", true, false)
	var turn0 := int(Game.state["turn"])
	# events block the turn; answer pending ones first
	while not Game.pending_events().is_empty():
		var ev: Dictionary = Game.pending_events()[0]
		var e: Dictionary = Defs.events[ev["id"]]
		Game.cmd_event_choice(ev["uid"], e["options"][0]["id"])
	await _tap_control(cs.end_btn)
	await get_tree().create_timer(1.5).timeout
	await _frames(3)
	_ok(int(Game.state["turn"]) == turn0 + 1, "End turn button advances the turn (%d -> %d)" % [turn0, int(Game.state["turn"])])
	for c in cs.overlay_layer.get_children():
		c.queue_free()
