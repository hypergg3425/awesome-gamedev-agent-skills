class_name Dialogs
extends RefCounted
## Modal dialogs drawn on an overlay layer (confirmation before destructive actions, info, amount prompts).
## Every dialog is responsive: its width is capped to the viewport (minus safe-area insets and banner), its content
## scrolls when taller than the free height, it fades in (Settings "animations") and - unless it must be answered
## explicitly - closes on the Android back button through `dismiss_top()`.

const MARGIN := 12.0

## Free area available to modal content in virtual pixels.
static func free_area(host: Control) -> Rect2:
	var vs := host.get_viewport_rect().size
	var ins := UI.safe_insets(host.get_viewport())
	var banner := Ads.reserved_height()
	return Rect2(float(ins["left"]), float(ins["top"]), vs.x - float(ins["left"]) - float(ins["right"]),
			vs.y - float(ins["top"]) - float(ins["bottom"]) - banner)

static func modal_width(host: Control, want: float) -> float:
	return minf(want, free_area(host).size.x - 2.0 * MARGIN)

static func overlay(host: Control, on_back: Callable = Callable(), alpha: float = 0.62) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if on_back.is_valid():
		dim.set_meta("back", on_back)
	host.add_child(dim)
	Anim.fade_in(dim, 0.15)
	return dim

## Closes the topmost dismissible dialog of `host`. Returns false when there is none (or it must be answered).
static func dismiss_top(host: Control) -> bool:
	if host.get_child_count() == 0:
		return false
	var top := host.get_child(host.get_child_count() - 1)
	if top.has_meta("back"):
		(top.get_meta("back") as Callable).call()
		return true
	return false

## Builds dim -> safe margin -> centred Sheet panel -> [header slot, scroll(content)]. Returns {box, head, panel, dim}.
static func frame(dim: Control, width: float) -> Dictionary:
	var area := free_area(dim.get_parent() as Control)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", int(area.position.x + MARGIN))
	m.add_theme_constant_override("margin_right", int(dim.get_viewport_rect().size.x - area.end.x + MARGIN))
	m.add_theme_constant_override("margin_top", int(area.position.y + MARGIN))
	m.add_theme_constant_override("margin_bottom", int(dim.get_viewport_rect().size.y - area.end.y + MARGIN))
	dim.add_child(m)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(center)
	var pc := PanelContainer.new()
	pc.theme_type_variation = "Sheet"
	pc.custom_minimum_size = Vector2(minf(width, area.size.x - 2.0 * MARGIN), 0)
	center.add_child(pc)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	pc.add_child(outer)
	var head := VBoxContainer.new()
	outer.add_child(head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var max_h := area.size.y - 2.0 * MARGIN - 40.0
	var fit := func() -> void:
		var head_h := head.get_combined_minimum_size().y + 8.0
		sc.custom_minimum_size.y = minf(v.get_combined_minimum_size().y, maxf(80.0, max_h - head_h - 40.0))
	v.minimum_size_changed.connect(fit)
	head.minimum_size_changed.connect(fit)
	fit.call_deferred()
	Anim.pop_in.call_deferred(pc)
	return {"box": v, "head": head, "panel": pc, "dim": dim}

static func _title_row(head: VBoxContainer, title: String, close: Callable = Callable()) -> void:
	var h := HBoxContainer.new()
	var t := UI.label(title, "Heading", -1, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if close.is_valid():
		h.add_child(UI.icon_button("close", close, Loc.t("UI_CLOSE"), 48.0))
	head.add_child(h)
	head.add_child(UI.hsep())

static func info(host: Control, title: String, text: String, ok_text: String = "") -> void:
	var dim := overlay(host)
	var close := func() -> void: dim.queue_free()
	dim.set_meta("back", close)
	var f := frame(dim, 640.0)
	_title_row(f["head"], title)
	var v: VBoxContainer = f["box"]
	v.add_child(UI.label(text, "", -1, true))
	v.add_child(UI.button(ok_text if ok_text != "" else Loc.t("UI_OK"), close, "Primary"))
	Audio.sfx("ui_open")

static func confirm(host: Control, title: String, text: String, on_yes: Callable, yes_text: String = "", danger: bool = false) -> void:
	if not bool(Settings.get_value("confirm_actions")) and not danger:
		on_yes.call()
		return
	var dim := overlay(host)
	var close := func() -> void: dim.queue_free()
	dim.set_meta("back", close)
	var f := frame(dim, 640.0)
	_title_row(f["head"], title)
	var v: VBoxContainer = f["box"]
	v.add_child(UI.label(text, "", -1, true))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var no := UI.button(Loc.t("UI_CANCEL"), close)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := UI.button(yes_text if yes_text != "" else Loc.t("UI_CONFIRM"), func() -> void:
		dim.queue_free()
		on_yes.call(), "Primary")
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(no)
	h.add_child(yes)
	v.add_child(h)
	Audio.sfx("ui_open")

## Slider prompt: calls on_ok(value)
static func amount(host: Control, title: String, text: String, min_v: float, max_v: float, step: float, start: float, on_ok: Callable, unit: String = "") -> void:
	var dim := overlay(host)
	var close := func() -> void: dim.queue_free()
	dim.set_meta("back", close)
	var f := frame(dim, 640.0)
	_title_row(f["head"], title)
	var v: VBoxContainer = f["box"]
	v.add_child(UI.label(text, "Small", -1, true))
	var val := UI.label(str(start) + unit, "Num", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(val)
	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = maxf(max_v, min_v + step)
	sl.step = step
	sl.value = start
	sl.custom_minimum_size = Vector2(0, 44)
	sl.value_changed.connect(func(x: float) -> void: val.text = str(int(x)) + unit)
	v.add_child(sl)
	var h := HBoxContainer.new()
	var no := UI.button(Loc.t("UI_CANCEL"), close)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := UI.button(Loc.t("UI_CONFIRM"), func() -> void:
		dim.queue_free()
		on_ok.call(sl.value), "Primary")
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(no)
	h.add_child(yes)
	v.add_child(h)

## Generic modal with a content builder; returns the content VBox and a close callable.
static func custom(host: Control, title: String, width: float = 760.0) -> Dictionary:
	var dim := overlay(host)
	var close := func() -> void: dim.queue_free()
	dim.set_meta("back", close)
	var f := frame(dim, width)
	_title_row(f["head"], title, close)
	return {"box": f["box"], "close": close, "dim": dim}
