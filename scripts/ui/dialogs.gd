class_name Dialogs
extends RefCounted
## Modal dialogs drawn on an overlay layer (confirmation before destructive actions, info, amount prompts).

static func _overlay(host: Control) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(dim)
	return dim

static func _box(dim: Control, width: float = 640.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var pc := PanelContainer.new()
	pc.theme_type_variation = "Sheet"
	pc.custom_minimum_size = Vector2(width, 0)
	center.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	return v

static func info(host: Control, title: String, text: String, ok_text: String = "") -> void:
	var dim := _overlay(host)
	var v := _box(dim)
	v.add_child(UI.label(title, "Heading"))
	v.add_child(UI.hsep())
	v.add_child(UI.label(text, "", -1, true))
	var b := UI.button(ok_text if ok_text != "" else Loc.t("UI_OK"), func() -> void: dim.queue_free(), "Primary")
	v.add_child(b)
	Audio.sfx("ui_open")

static func confirm(host: Control, title: String, text: String, on_yes: Callable, yes_text: String = "", danger: bool = false) -> void:
	if not bool(Settings.get_value("confirm_actions")) and not danger:
		on_yes.call()
		return
	var dim := _overlay(host)
	var v := _box(dim)
	v.add_child(UI.label(title, "Heading"))
	v.add_child(UI.hsep())
	v.add_child(UI.label(text, "", -1, true))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var no := UI.button(Loc.t("UI_CANCEL"), func() -> void: dim.queue_free())
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
	var dim := _overlay(host)
	var v := _box(dim)
	v.add_child(UI.label(title, "Heading"))
	v.add_child(UI.label(text, "Small", -1, true))
	var val := UI.label(str(start) + unit, "Num", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(val)
	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = maxf(max_v, min_v + step)
	sl.step = step
	sl.value = start
	sl.custom_minimum_size = Vector2(0, 40)
	sl.value_changed.connect(func(x: float) -> void: val.text = str(int(x)) + unit)
	v.add_child(sl)
	var h := HBoxContainer.new()
	var no := UI.button(Loc.t("UI_CANCEL"), func() -> void: dim.queue_free())
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
	var dim := _overlay(host)
	var v := _box(dim, width)
	var head := HBoxContainer.new()
	var t := UI.label(title, "Heading")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.icon_button("close", func() -> void: dim.queue_free(), Loc.t("UI_CLOSE"), 48.0))
	v.add_child(head)
	v.add_child(UI.hsep())
	return {"box": v, "close": func() -> void: dim.queue_free(), "dim": dim}
