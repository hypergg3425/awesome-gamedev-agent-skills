class_name UI
extends RefCounted
## UI toolkit: palette, theme, fonts, icon cache and widget helpers. All colours follow
## docs/ART_DIRECTION.md. Text sizes follow Settings.text_scale.

const PARCHMENT := Color("e9dfc4")
const PARCHMENT_DARK := Color("cdbf9c")
const INK := Color("2a2118")
const NAVY := Color("14203a")
const NAVY_DEEP := Color("0b1326")
const NAVY_LIGHT := Color("1f3158")
const BURGUNDY := Color("5b1a24")
const BURGUNDY_LIGHT := Color("8a2b38")
const GOLD := Color("c9a24a")
const GOLD_LIGHT := Color("e6c876")
const VERDIGRIS := Color("3f7a6e")
const STEEL := Color("7d8aa3")
const GOOD := Color("7fc58a")
const BAD := Color("e0766b")
const WARN := Color("e6b85c")

static var _theme: Theme
static var _icons := {}
static var _fonts := {}

static func font(kind: String) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font
	match kind:
		"title":
			f = _variation(load("res://assets/fonts/Cinzel.ttf"), 700)
		"heading":
			f = _variation(load("res://assets/fonts/Cinzel.ttf"), 600)
		"body":
			f = _variation(load("res://assets/fonts/EBGaramond.ttf"), 500)
		"italic":
			f = load("res://assets/fonts/EBGaramond-Italic.ttf")
		"ui":
			f = _variation(load("res://assets/fonts/NotoSans.ttf"), 500)
		"ui_bold":
			f = _variation(load("res://assets/fonts/NotoSans.ttf"), 700)
		_:
			f = ThemeDB.fallback_font
	_fonts[kind] = f
	return f

static func _variation(base: Font, weight: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = base
	var tag := TextServerManager.get_primary_interface().name_to_tag("weight")
	fv.variation_opentype = {tag: weight}
	return fv

static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var path := "res://assets/icons/%s.svg" % id
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_icons[id] = t
	return t

static func scale() -> float:
	return clampf(float(Settings.get_value("text_scale")), 0.8, 1.4)

static func fs(n: int) -> int:
	return int(round(float(n) * scale()))

## --- safe area -------------------------------------------------------------------------------
## Returns insets in viewport (virtual) pixels: {left, top, right, bottom}
static func safe_insets(vp: Viewport) -> Dictionary:
	var win := DisplayServer.window_get_size()
	var vs := vp.get_visible_rect().size
	var zero := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	if win.x <= 0 or win.y <= 0:
		return zero
	var sa := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if sa.size.x <= 0 or screen.x <= 0 or OS.get_name() not in ["Android", "iOS"]:
		return zero
	var sx := vs.x / float(win.x)
	var sy := vs.y / float(win.y)
	return {"left": maxf(0.0, float(sa.position.x)) * sx, "top": maxf(0.0, float(sa.position.y)) * sy,
		"right": maxf(0.0, float(screen.x - sa.end.x)) * sx, "bottom": maxf(0.0, float(screen.y - sa.end.y)) * sy}

## --- theme ------------------------------------------------------------------------------------
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 8, margin: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin - 2
	s.content_margin_bottom = margin - 2
	return s

static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_build_theme(_theme)
	return _theme

static func rebuild_theme() -> Theme:
	_theme = Theme.new()
	_build_theme(_theme)
	return _theme

static func _fb(top: Color, bottom: Color, border: Color, bw: float = 2.0, radius: float = 8.0, margin: float = 10.0) -> FrameStyle:
	return FrameStyle.make(top, bottom, border, bw, radius, margin)

static func _button_styles(t: Theme, type: String, base: Color, border: Color, margin: float = 14.0, radius: float = 8.0) -> void:
	var n := _fb(base.lightened(0.10), base.darkened(0.12), border.darkened(0.25), 2.0, radius, margin)
	n.gloss = 0.10
	var h := _fb(base.lightened(0.22), base.lightened(0.02), border, 2.0, radius, margin)
	h.gloss = 0.14
	var p := _fb(base.darkened(0.35), base.darkened(0.15), GOLD_LIGHT, 2.0, radius, margin)
	var d := _fb(Color(0.15, 0.17, 0.23, 0.85), Color(0.11, 0.13, 0.19, 0.85), Color(0.3, 0.3, 0.32, 0.6), 1.0, radius, margin)
	var f := _fb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), GOLD_LIGHT, 2.0, radius, margin)
	t.set_stylebox("normal", type, n)
	t.set_stylebox("hover", type, h)
	t.set_stylebox("pressed", type, p)
	t.set_stylebox("disabled", type, d)
	t.set_stylebox("focus", type, f)

static func _panel_style(top: Color, bottom: Color, border: Color, bw: float, radius: float, margin: float, inner: Color = Color(0, 0, 0, 0), corner: int = 0, shadow: float = 0.0) -> FrameStyle:
	var s := _fb(top, bottom, border, bw, radius, margin)
	s.inner = inner
	s.corner = corner as FrameStyle.Corner
	s.shadow = shadow
	return s

static func _build_theme(t: Theme) -> void:
	t.default_font = font("body")
	t.default_font_size = fs(22)
	# labels
	t.set_color("font_color", "Label", Color("efe6cf"))
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	for v in [["Title", "title", 44, GOLD_LIGHT], ["Heading", "heading", 28, GOLD_LIGHT], ["Sub", "heading", 21, GOLD], ["Small", "ui", 17, Color("cfc7b0")],
			["Tiny", "ui", 14, Color("a9a28d")], ["Value", "ui_bold", 20, Color("f4ecd6")], ["Num", "ui_bold", 22, Color("f4ecd6")], ["Ink", "body", 22, INK],
			["InkHeading", "heading", 26, BURGUNDY], ["Good", "ui_bold", 19, GOOD], ["Bad", "ui_bold", 19, BAD], ["Warn", "ui_bold", 19, WARN],
			["Eyebrow", "ui_bold", 13, GOLD], ["Hero", "title", 64, GOLD_LIGHT]]:
		t.add_type(v[0])
		t.set_type_variation(v[0], "Label")
		t.set_font(&"font", v[0], font(v[1]))
		t.set_font_size(&"font_size", v[0], fs(v[2]))
		t.set_color(&"font_color", v[0], v[3])
	t.set_color("font_shadow_color", "Hero", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_y", "Hero", 3)
	t.set_constant("shadow_offset_x", "Hero", 0)
	t.set_color("font_shadow_color", "Title", Color(0, 0, 0, 0.5))
	t.set_constant("shadow_offset_y", "Title", 2)
	# buttons
	_button_styles(t, "Button", NAVY_LIGHT, GOLD)
	t.set_font("font", "Button", font("ui_bold"))
	t.set_font_size("font_size", "Button", fs(20))
	t.set_color("font_color", "Button", Color("f4ecd6"))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD_LIGHT)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.55))
	t.set_color("icon_normal_color", "Button", Color("f4ecd6"))
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	t.set_color("icon_pressed_color", "Button", GOLD_LIGHT)
	t.set_color("icon_disabled_color", "Button", Color(0.5, 0.5, 0.5))
	t.set_constant("h_separation", "Button", 10)
	t.set_constant("icon_max_width", "Button", 30)
	_variation_button(t, "Primary", BURGUNDY, GOLD)
	_variation_button(t, "Good", VERDIGRIS.darkened(0.2), GOLD)
	_variation_button(t, "Tab", Color(0.1, 0.15, 0.27), GOLD.darkened(0.35), 12.0, 6.0)
	t.set_color("font_color", "Tab", Color("cfc7b0"))
	# flat (transparent) button
	t.add_type("Flat")
	t.set_type_variation("Flat", "Button")
	for st in ["normal", "disabled", "focus"]:
		t.set_stylebox(st, "Flat", _fb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0.0, 6.0, 10.0))
	t.set_stylebox("hover", "Flat", _fb(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0.0, 6.0, 10.0))
	t.set_stylebox("pressed", "Flat", _fb(Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0.0, 6.0, 10.0))
	# chip: small pill used by HUD stats
	t.add_type("Chip")
	t.set_type_variation("Chip", "Button")
	t.set_stylebox("normal", "Chip", _fb(Color(0.12, 0.18, 0.32, 0.55), Color(0.07, 0.11, 0.21, 0.55), Color(0.55, 0.46, 0.22, 0.45), 1.0, 14.0, 10.0))
	t.set_stylebox("hover", "Chip", _fb(Color(0.2, 0.28, 0.46, 0.8), Color(0.12, 0.18, 0.32, 0.8), GOLD, 1.0, 14.0, 10.0))
	t.set_stylebox("pressed", "Chip", _fb(Color(0.05, 0.08, 0.16, 0.9), Color(0.05, 0.08, 0.16, 0.9), GOLD_LIGHT, 1.0, 14.0, 10.0))
	t.set_stylebox("focus", "Chip", _fb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), GOLD_LIGHT, 2.0, 14.0, 10.0))
	# panels
	t.add_type("Sheet")
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", _panel_style(Color("172644"), Color("0e182f"), GOLD.darkened(0.1), 2.0, 12.0, 16.0, Color(0.79, 0.64, 0.29, 0.35), FrameStyle.Corner.FLOURISH, 0.55))
	t.add_type("Card")
	t.set_type_variation("Card", "PanelContainer")
	var card := _panel_style(Color(0.13, 0.2, 0.35, 0.94), Color(0.09, 0.14, 0.27, 0.94), Color(0.5, 0.42, 0.2, 0.7), 1.0, 8.0, 12.0)
	card.gloss = 0.05
	t.set_stylebox("panel", "Card", card)
	t.add_type("CardAccent")
	t.set_type_variation("CardAccent", "PanelContainer")
	t.set_stylebox("panel", "CardAccent", _panel_style(Color(0.25, 0.1, 0.14, 0.95), Color(0.16, 0.07, 0.12, 0.95), GOLD.darkened(0.2), 1.0, 8.0, 12.0))
	t.add_type("Paper")
	t.set_type_variation("Paper", "PanelContainer")
	t.set_stylebox("panel", "Paper", _panel_style(PARCHMENT.lightened(0.05), PARCHMENT_DARK, PARCHMENT_DARK.darkened(0.3), 2.0, 8.0, 16.0, Color(0.5, 0.35, 0.15, 0.3), FrameStyle.Corner.DIAMOND))
	t.add_type("Hud")
	t.set_type_variation("Hud", "PanelContainer")
	t.set_stylebox("panel", "Hud", _panel_style(Color(0.08, 0.12, 0.23, 0.96), Color(0.04, 0.07, 0.15, 0.94), Color(0.6, 0.5, 0.22, 0.85), 1.0, 0.0, 8.0, Color(0, 0, 0, 0), 0, 0.5))
	t.add_type("HudDrop")
	t.set_type_variation("HudDrop", "PanelContainer")
	t.set_stylebox("panel", "HudDrop", _panel_style(Color(0.08, 0.12, 0.23, 0.97), Color(0.05, 0.08, 0.17, 0.97), Color(0.6, 0.5, 0.22, 0.85), 1.0, 10.0, 10.0, Color(0, 0, 0, 0), 0, 0.5))
	t.add_type("Toast")
	t.set_type_variation("Toast", "PanelContainer")
	t.set_stylebox("panel", "Toast", _panel_style(Color(0.13, 0.19, 0.33, 0.97), Color(0.07, 0.11, 0.22, 0.97), GOLD, 2.0, 10.0, 14.0, Color(0, 0, 0, 0), 0, 0.5))
	t.set_stylebox("panel", "PanelContainer", _panel_style(Color(0.11, 0.17, 0.3, 0.9), Color(0.07, 0.11, 0.21, 0.9), Color(0.4, 0.34, 0.16, 0.6), 1.0, 8.0, 10.0))
	# inputs / bars
	t.set_stylebox("background", "ProgressBar", box(Color(0.04, 0.06, 0.12, 0.9), Color(0.3, 0.26, 0.12), 1, 6, 2))
	t.set_stylebox("fill", "ProgressBar", box(GOLD, Color(0, 0, 0, 0), 0, 5, 2))
	t.set_font("font", "ProgressBar", font("ui_bold"))
	t.set_font_size("font_size", "ProgressBar", fs(14))
	var slider_bg := box(Color(0.04, 0.06, 0.12), Color(0.3, 0.26, 0.12), 1, 4, 2)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", box(GOLD.darkened(0.2), Color(0, 0, 0, 0), 0, 4, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, Color(0, 0, 0, 0), 0, 4, 2))
	var grab := _circle_tex(26, GOLD_LIGHT)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	t.set_icon("grabber_disabled", "HSlider", grab)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.05, 0.08, 0.16, 0.97), GOLD, 1, 6, 10))
	t.set_font("font", "TooltipLabel", font("ui"))
	t.set_font_size("font_size", "TooltipLabel", fs(17))
	t.set_stylebox("normal", "LineEdit", box(Color(0.04, 0.06, 0.12), Color(0.45, 0.38, 0.18), 1, 6, 10))
	t.set_stylebox("focus", "LineEdit", box(Color(0.04, 0.06, 0.12), GOLD_LIGHT, 2, 6, 10))
	t.set_font("font", "LineEdit", font("ui"))
	t.set_font_size("font_size", "LineEdit", fs(20))
	t.set_color("font_color", "LineEdit", Color("f4ecd6"))
	# option button / checkbox
	_button_styles(t, "OptionButton", NAVY_LIGHT, GOLD)
	t.set_font("font", "OptionButton", font("ui_bold"))
	t.set_font_size("font_size", "OptionButton", fs(20))
	t.set_font("font", "CheckButton", font("ui"))
	t.set_font_size("font_size", "CheckButton", fs(20))
	t.set_font("font", "CheckBox", font("ui"))
	t.set_font_size("font_size", "CheckBox", fs(20))
	t.set_constant("v_separation", "CheckButton", 10)
	t.set_stylebox("panel", "PopupMenu", box(Color(0.06, 0.1, 0.2, 0.98), GOLD, 1, 6, 8))
	t.set_font("font", "PopupMenu", font("ui"))
	t.set_font_size("font_size", "PopupMenu", fs(20))
	t.set_constant("v_separation", "PopupMenu", 12)
	t.set_stylebox("hover", "PopupMenu", box(BURGUNDY, Color(0, 0, 0, 0), 0, 4, 8))
	# scroll
	var sb := box(Color(0.03, 0.05, 0.1, 0.6), Color(0, 0, 0, 0), 0, 6, 0)
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", box(GOLD.darkened(0.3), Color(0, 0, 0, 0), 0, 6, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(GOLD, Color(0, 0, 0, 0), 0, 6, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD_LIGHT, Color(0, 0, 0, 0), 0, 6, 0))
	t.set_stylebox("scroll", "HScrollBar", sb)
	t.set_stylebox("grabber", "HScrollBar", box(GOLD.darkened(0.3), Color(0, 0, 0, 0), 0, 6, 0))
	t.set_stylebox("panel", "ItemList", box(Color(0.04, 0.06, 0.12, 0.8), Color(0.3, 0.26, 0.12), 1, 6, 6))

static func _variation_button(t: Theme, name: String, base: Color, border: Color, margin: float = 16.0, radius: float = 8.0) -> void:
	t.add_type(name)
	t.set_type_variation(name, "Button")
	_button_styles(t, name, base, border, margin, radius)

static func _circle_tex(d: int, c: Color) -> Texture2D:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for x in d:
		for y in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if dist <= r - 1.0:
				img.set_pixel(x, y, c)
			elif dist <= r:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, r - dist))
	return ImageTexture.create_from_image(img)

## --- widget helpers ----------------------------------------------------------------------------
static func label(text: String, variation: String = "", align: int = -1, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if align >= 0:
		l.horizontal_alignment = align as HorizontalAlignment
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, cb: Callable = Callable(), variation: String = "", icon_id: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.focus_mode = Control.FOCUS_NONE
	if variation != "":
		b.theme_type_variation = variation
	if icon_id != "":
		b.icon = icon(icon_id)
		b.expand_icon = true
	if cb.is_valid():
		b.pressed.connect(func() -> void:
			Audio.sfx("ui_click")
			cb.call())
	return b

static func icon_button(icon_id: String, cb: Callable = Callable(), tip: String = "", size: float = 56.0, variation: String = "") -> Button:
	var b := Button.new()
	b.icon = icon(icon_id)
	b.expand_icon = true
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(size * 0.55))
	if variation != "":
		b.theme_type_variation = variation
	if cb.is_valid():
		b.pressed.connect(func() -> void:
			Audio.sfx("ui_click")
			cb.call())
	return b

static func icon_rect(id: String, size: float = 28.0, tint: Color = Color("f4ecd6")) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(id)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	return t

static func spacer(h: float = 8.0, w: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	return c

static func hsep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_stylebox_override("separator", box(Color(0.6, 0.5, 0.22, 0.5), Color(0, 0, 0, 0), 0, 0, 0))
	s.add_theme_constant_override("separation", 2)
	return s

static func margin(child: Control, m: int = 8) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", m)
	mc.add_theme_constant_override("margin_right", m)
	mc.add_theme_constant_override("margin_top", m)
	mc.add_theme_constant_override("margin_bottom", m)
	mc.add_child(child)
	return mc

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

## icon + text pair (resource displays)
static func stat(icon_id: String, text: String, tint: Color = Color("f4ecd6"), tip: String = "", variation: String = "Value") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(icon_rect(icon_id, 26, tint))
	var l := label(text, variation)
	h.add_child(l)
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h

static func progress(value: float, max_v: float, color: Color = GOLD, text: String = "") -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = 0.0
	p.max_value = max_v
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, 18)
	var fill := box(color, Color(0, 0, 0, 0), 0, 5, 2)
	p.add_theme_stylebox_override("fill", fill)
	if text != "":
		p.show_percentage = false
		var l := label(text, "Tiny", HORIZONTAL_ALIGNMENT_CENTER)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
	return p

static func scroll(child: Control, min_h: float = 0.0) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, min_h)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

static func fmt(v: float) -> String:
	return Util.fmt_num(v)

static func signed(v: float, d: int = 0) -> String:
	var s := Util.fmt_signed(v, d)
	return s

static func color_for(v: float) -> Color:
	return GOOD if v > 0.0 else (BAD if v < 0.0 else Color("f4ecd6"))

static func tint_label(l: Label, v: float) -> void:
	l.add_theme_color_override("font_color", color_for(v))
