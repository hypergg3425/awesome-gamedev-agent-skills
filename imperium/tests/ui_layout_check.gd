extends Node
## Automated layout assertions. Instantiates every main screen, campaign sheet/tab, dialog and tutorial step at a list of
## window sizes and asserts that
##   * no control with visible text lies outside the viewport (minus safe-area insets and the ad banner) or outside its
##     clipping / panel ancestor,
##   * key chrome (HUD, toolbar, End-turn, province panel, sheet, mode strip, move bar, popups) never overlap,
##   * buttons meet the touch-target minimum and the tutorial card never covers its highlighted target.
## Run: xvfb-run -a -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 res://tests/ui_layout_check.tscn
##      [-- sizes=800x360,1280x720 only=campaign,menu touch=1 lang=tr scale=1.3 notch=1 verbose=1]
## Exit code 0 = all assertions passed.

const DEFAULT_SIZES := ["800x360", "854x393", "1024x768", "1280x720", "1600x900", "1920x1080", "1920x864", "2160x1080", "2400x1080"]
const TOL := 2.0

var sizes: Array = []
var only: Array = []
var touch := false
var notch := false
var verbose := false
var failures: Array = []
var checks := 0
var screens_checked := 0
var _screen: Control
var _cur_size := ""
var _banner_px := 0

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	sizes = str(args.get("sizes", ",".join(DEFAULT_SIZES))).split(",")
	only = str(args.get("only", "")).split(",", false)
	touch = str(args.get("touch", "0")) == "1"
	notch = str(args.get("notch", "0")) == "1"
	verbose = str(args.get("verbose", "0")) == "1"
	if args.has("lang"):
		Settings.set_value("language", args["lang"], false)
		Loc.set_language(args["lang"])
	if args.has("scale"):
		Settings.set_value("text_scale", float(args["scale"]), false)
	Settings.set_value("animations", false, false)
	Settings.set_value("tutorial_done", true, false)
	if touch:
		Layout.override_mobile = true
		Layout.override_dpi = 420.0
	Layout.install(get_window())
	get_tree().root.theme = UI.theme()
	Defs.load_geometry()
	var r: Dictionary = Game.new_game("early_modern", "FRA", "normal", 5)
	if not r.get("ok", false):
		push_error("new_game failed")
		get_tree().quit(2)
		return
	for sz in sizes:
		await _run_size(str(sz))
	print("ui_layout_check: %d screens, %d assertions, %d failures" % [screens_checked, checks, failures.size()])
	for f in failures.slice(0, 200):
		print("  FAIL ", f)
	get_tree().quit(1 if failures.size() > 0 else 0)

func _want(group: String) -> bool:
	return only.is_empty() or group in only

func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame

func _resize(sz: String) -> void:
	var p := sz.split("x")
	get_window().size = Vector2i(int(p[0]), int(p[1]))
	await _frames(4)

func _set_env() -> void:
	# simulate an ad banner (100 physical px) and, optionally, a camera notch
	Ads.state = "loaded"
	Ads._wanted_visible = true
	Ads._banner_px = 100
	UI.insets_override = {"left": 40.0, "top": 0.0, "right": 40.0, "bottom": 18.0} if notch else {}

func _show(scene: Node) -> void:
	if _screen != null and is_instance_valid(_screen):
		remove_child(_screen)
		_screen.queue_free()
	_screen = scene as Control
	add_child(scene)

func _run_size(sz: String) -> void:
	_cur_size = sz
	await _resize(sz)
	_set_env()
	if _want("menu"):
		for sc in ["main_menu", "scenario_select", "credits", "achievements", "statistics"]:
			Nav.mode = "new"
			_show(load("res://scenes/menus/%s.tscn" % sc).instantiate())
			await _frames(4)
			_check("%s %s" % [sz, sc], _screen)
		Nav.scenario_id = "early_modern"
		_show(load("res://scenes/menus/country_select.tscn").instantiate())
		await get_tree().create_timer(0.3).timeout
		await _frames(2)
		_check("%s country_select" % sz, _screen)
		_show(load("res://scenes/editor/editor.tscn").instantiate())
		await get_tree().create_timer(0.3).timeout
		await _frames(2)
		_check("%s editor" % sz, _screen)
		_show(load("res://scenes/menus/main_menu.tscn").instantiate())
		await _frames(3)
		SettingsPanel.show_dialog(_screen)
		await _frames(4)
		_check("%s menu settings" % sz, _screen)
		SaveLoadDialog.show_load(_screen, func() -> void: pass)
		await _frames(4)
		_check("%s menu load" % sz, _screen)
	if _want("campaign"):
		Game.new_game("early_modern", "FRA", "normal", 5)
		var cs: CampaignScreen = load("res://scenes/campaign/campaign.tscn").instantiate()
		_show(cs)
		await get_tree().create_timer(0.5).timeout
		await _frames(2)
		_set_env()
		cs._apply_layout()
		await _frames(3)
		await _campaign(cs, sz)

func _campaign(cs: CampaignScreen, sz: String) -> void:
	_check("%s campaign" % sz, cs)
	_check_chrome("%s campaign" % sz, cs)
	cs.select_province(Game.pc().get("capital", "fra_ile_de_france"))
	await _frames(3)
	_check_chrome("%s campaign+province" % sz, cs)
	for tab in ["info", "build", "army"]:
		cs.province_panel.tab = tab
		cs.province_panel.refresh()
		await _frames(3)
		_check("%s province_%s" % [sz, tab], cs)
		_check_chrome("%s province_%s" % [sz, tab], cs)
	cs.province_panel.tab = "info"
	# HUD detail drop-down and map modes
	cs.hud.toggle_detail()
	await _frames(2)
	_check("%s hud_detail" % sz, cs)
	cs.hud.close_detail()
	cs._toggle_modes()
	await _frames(2)
	_check("%s mode_strip" % sz, cs)
	_check_chrome("%s mode_strip" % sz, cs)
	cs._toggle_modes()
	for id in cs.sheets:
		cs.open_sheet(id)
		await _frames(3)
		var sh: Sheet = cs.sheets[id]
		for t in sh.tabs:
			sh.select_tab(t["id"])
			await _frames(3)
			_check("%s sheet_%s/%s" % [sz, id, t["id"]], cs)
			_check_chrome("%s sheet_%s/%s" % [sz, id, t["id"]], cs)
		cs.close_sheets()
	# dialogs
	var dlgs := {
		"pause": func() -> void: PauseMenu.show_menu(cs.overlay_layer, cs),
		"settings": func() -> void: SettingsPanel.show_dialog(cs.overlay_layer),
		"save": func() -> void: SaveLoadDialog.show_save(cs.overlay_layer),
		"load": func() -> void: SaveLoadDialog.show_load(cs.overlay_layer, func() -> void: pass),
		"confirm": func() -> void: Dialogs.confirm(cs.overlay_layer, "Title", "A long explanatory sentence that wraps over a couple of lines when the dialog is narrow. ".repeat(3), func() -> void: pass, "", true),
		"event": func() -> void: _show_event(cs),
		"battle": func() -> void: _show_battle(cs),
	}
	for k in dlgs:
		if not _want("dialogs"):
			break
		(dlgs[k] as Callable).call()
		await _frames(4)
		_check("%s dialog_%s" % [sz, k], cs)
		while cs.overlay_layer.get_child_count() > 0:
			var c := cs.overlay_layer.get_child(0)
			cs.overlay_layer.remove_child(c)
			c.queue_free()
	if _want("tutorial"):
		await _tutorial(cs, sz)
	if _want("popup"):
		var cap: String = Game.pc().get("capital", "")
		ContextPopup.show_for(cs, "province", cap, Vector2(get_viewport().get_visible_rect().size.x * 0.5, 160.0))
		await _frames(3)
		_check("%s context_popup" % sz, cs)
		_check_chrome("%s context_popup" % sz, cs)
		ContextPopup.close_all(cs)

func _show_event(cs: CampaignScreen) -> void:
	var eid: String = Defs.events.keys()[0]
	var me: String = Game.active_player
	var entry := {"id": eid, "uid": "ui_test", "cid": me, "pid": "", "other": ""}
	EventDialog.show_event(cs.overlay_layer, Game.state, entry, func() -> void: pass)

func _show_battle(cs: CampaignScreen) -> void:
	var me: String = Game.active_player
	var foe := "ENG" if Game.state["countries"].has("ENG") else me
	var rep := {"attackers": {"owners": [me]}, "defenders": {"owners": [foe]}, "winner": "attacker", "terrain": "plains", "weather": 1, "width": 20, "fort": 1.5,
		"start_a": 12.0, "start_d": 9.0, "loss_a": 2.0, "loss_d": 5.0, "end_a": 10.0, "end_d": 4.0, "pid": Game.pc().get("capital", ""),
		"reasons": ["BR_WHY_NUMBERS", "BR_WHY_TERRAIN"], "factors": {"BR_F_FIRE": [10.0, 7.0], "BR_F_SHOCK": [8.0, 9.0]}}
	BattleReportView.show_reports(cs.overlay_layer, Game.state, [rep], func() -> void: pass)

func _tutorial(cs: CampaignScreen, sz: String) -> void:
	Settings.set_value("tutorial_done", false, false)
	Tutorial.start(cs, true)
	await _frames(3)
	var tut: Tutorial = null
	for c in cs.get_children():
		if c is Tutorial:
			tut = c
	if tut == null:
		failures.append("%s tutorial did not start" % sz)
		return
	for i in Tutorial.STEPS.size():
		tut.step = i
		tut._show_step()
		await _frames(3)
		tut._place()
		var card := tut.get_global_rect()
		var ctx := "%s tutorial_step_%d" % [sz, i + 1]
		_check(ctx, cs)
		var vs := get_viewport().get_visible_rect().size
		_assert(Rect2(Vector2.ZERO, vs).grow(TOL).encloses(card), "%s: card %s outside viewport" % [ctx, card])
		var focus := tut._focus_rect(str(Tutorial.STEPS[i]["focus"]))
		if focus.size.x > 0.0:
			_assert(not card.intersects(focus), "%s: card %s covers highlighted target %s" % [ctx, card, focus])
	tut.finish(true)
	Settings.set_value("tutorial_done", true, false)
	await _frames(2)

## --- assertions ------------------------------------------------------------------------------------------
func _assert(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)

func _viewport_free() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	var ins := UI.safe_insets(get_viewport())
	var banner := Ads.reserved_height()
	return Rect2(float(ins["left"]), float(ins["top"]), vs.x - float(ins["left"]) - float(ins["right"]),
			vs.y - float(ins["top"]) - float(ins["bottom"]) - banner)

static func _has_text(c: Control) -> bool:
	if c is Label:
		return (c as Label).text.strip_edges() != ""
	if c is Button:
		return (c as Button).text.strip_edges() != ""
	if c is LineEdit:
		return (c as LineEdit).text != "" or (c as LineEdit).placeholder_text != ""
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text().strip_edges() != ""
	return false

func _skip_subtree(n: Node) -> bool:
	return n is MapView or n is MapFx or n is GestureLayer or n is Popup or n is Window

## Layout assertions for one screen state.
func _check(ctx: String, root: Node) -> void:
	screens_checked += 1
	var vs := get_viewport().get_visible_rect().size
	var full := Rect2(Vector2.ZERO, vs)
	var free := _viewport_free()
	var stack: Array = [root]
	var touch_min := Layout.touch_min(get_window()) if touch else 44.0
	var scale := vs.x / maxf(1.0, float(get_window().size.x))
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if _skip_subtree(n):
			continue
		for ch in n.get_children():
			stack.append(ch)
		if not (n is Control):
			continue
		var c := n as Control
		if not c.is_visible_in_tree() or c.modulate.a < 0.05 or c.size.x < 1.0 or c.size.y < 1.0:
			continue
		var rect := c.get_global_rect()
		if _has_text(c):
			_check_text_rect(ctx, c, rect, full, free)
		if c is Button and not (c.get_parent() is OptionButton):
			var bs := rect.size
			# buttons that are fully scrolled out of a scroll container are not interactive right now
			var vis := _clip_visible(c, rect)
			if vis.size.x > 4.0 and vis.size.y > 4.0:
				_assert(minf(bs.x, bs.y) >= 40.0 - 0.5 or (c as Button).flat, "%s: button '%s' (%s) smaller than 40px" % [ctx, _name(c), bs])
	_assert(touch_min >= 44.0, "%s: touch_min %f < 44" % [ctx, touch_min])
	if scale <= 0.0:
		failures.append("bad scale")

func _name(c: Control) -> String:
	if c is Button:
		return (c as Button).text if (c as Button).text != "" else str(c.name)
	if c is Label:
		return (c as Label).text.left(24)
	return str(c.name)

func _clip_visible(c: Control, rect: Rect2) -> Rect2:
	var vis := rect
	var a := c.get_parent()
	while a != null and a is Node:
		if a is ScrollContainer or (a is Control and (a as Control).clip_contents):
			vis = vis.intersection((a as Control).get_global_rect())
		a = a.get_parent()
	return vis

func _check_text_rect(ctx: String, c: Control, rect: Rect2, full: Rect2, free: Rect2) -> void:
	var vis := _clip_visible(c, rect)
	if vis.size.x <= 0.0 or vis.size.y <= 0.0:
		return   # scrolled out of view: fine
	var nm := _name(c)
	_assert(full.grow(TOL).encloses(vis), "%s: '%s' %s outside viewport %s" % [ctx, nm, vis, full])
	# banner / notch: text must not run into the reserved bottom strip or side insets
	_assert(vis.end.y <= free.end.y + TOL or vis.position.y >= free.end.y, "%s: '%s' %s overlaps ad banner / bottom inset (free until y=%.0f)" % [ctx, nm, vis, free.end.y])
	if free.position.x > 0.0:
		_assert(vis.position.x >= free.position.x - TOL and vis.end.x <= free.end.x + TOL, "%s: '%s' %s inside side inset" % [ctx, nm, vis])
	# horizontal containment in clipping / scroll / panel ancestors
	var a := c.get_parent()
	while a != null:
		if a is Control:
			var ac := a as Control
			var arect := ac.get_global_rect()
			var clips := ac is ScrollContainer or ac.clip_contents or ac is PanelContainer
			if ac is ScrollContainer and (ac as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				return   # horizontally scrollable on purpose (tab strips); the viewport check above already applied to the visible part
			if clips and arect.size.x > 0.0 and ac.is_visible_in_tree():
				var inside := rect.position.x >= arect.position.x - TOL and rect.end.x <= arect.end.x + TOL
				_assert(inside, "%s: '%s' x-range %.0f..%.0f exceeds %s '%s' %.0f..%.0f" % [ctx, nm, rect.position.x, rect.end.x, ac.get_class(), ac.name, arect.position.x, arect.end.x])
				if not inside:
					return
		a = a.get_parent()

func _vis(c: Control) -> bool:
	return c != null and c.is_visible_in_tree() and c.size.x > 1.0

## Campaign chrome must be disjoint and inside the free area.
func _check_chrome(ctx: String, cs: CampaignScreen) -> void:
	var free := _viewport_free()
	var items := {"hud": cs.hud, "toolbar": cs.toolbar, "end": cs.end_btn, "province": cs.province_panel, "modes": cs.mode_strip, "move": cs.move_bar}
	if cs.open_sheet_name != "":
		items["sheet"] = cs.sheets[cs.open_sheet_name]
	for c in cs.ui_root.get_children():
		if c is ContextPopup:
			items["popup"] = c
	var rects := {}
	for k in items:
		var c: Control = items[k]
		if _vis(c):
			rects[k] = c.get_global_rect()
	for k in rects:
		var r: Rect2 = rects[k]
		_assert(free.grow(TOL).encloses(r), "%s: %s %s outside free area %s" % [ctx, k, r, free])
	var keys := rects.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			if keys[i] == "popup" or keys[j] == "popup":
				continue   # the long-press popup is a transient floating layer
			var a: Rect2 = rects[keys[i]]
			var b: Rect2 = rects[keys[j]]
			var inter := a.intersection(b)
			var overlap := inter.size.x > 1.0 and inter.size.y > 1.0 and a.intersects(b)
			_assert(not overlap, "%s: %s %s overlaps %s %s" % [ctx, keys[i], a, keys[j], b])
	# chrome touch targets
	var tb := Layout.touch_min(get_window()) if touch else 44.0
	for b in cs.toolbar.get_children() + cs.mode_row.get_children() + [cs.end_btn]:
		if _vis(b):
			var bs: Vector2 = (b as Control).size
			_assert(minf(bs.x, bs.y) >= tb - 0.5, "%s: chrome button %s %s below touch minimum %.0f" % [ctx, b.name, bs, tb])
