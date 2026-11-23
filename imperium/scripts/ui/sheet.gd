class_name Sheet
extends PanelContainer
## Tabbed modal-ish panel used by every campaign screen (economy, military, diplomacy, ...).

signal closed()

var title_label: Label
var tab_bar: HBoxContainer
var body: VBoxContainer
var scroller: ScrollContainer
var tabs: Array = []     # {id, button, builder}
var current := ""
var icon_id := ""
var title_key := ""

func _init(p_title_key: String = "", p_icon: String = "") -> void:
	theme_type_variation = "Sheet"
	title_key = p_title_key
	icon_id = p_icon
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	root.add_child(head)
	if p_icon != "":
		head.add_child(UI.icon_rect(p_icon, 34, UI.GOLD_LIGHT))
	title_label = UI.label(Loc.t(p_title_key) if p_title_key != "" else "", "Heading")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	head.add_child(UI.icon_button("close", func() -> void: close(), Loc.t("UI_CLOSE"), 48.0))
	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 6)
	root.add_child(tab_bar)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	scroller = UI.scroll(body)
	root.add_child(scroller)
	Loc.language_changed.connect(func(_l: String) -> void: relocalize())

func relocalize() -> void:
	if title_key != "":
		title_label.text = Loc.t(title_key)
	for t in tabs:
		(t["button"] as Button).text = Loc.t(t["key"])
	refresh()

func add_tab(id: String, key: String, builder: Callable, icon: String = "") -> void:
	var b := UI.button(Loc.t(key), func() -> void: select_tab(id), "Tab", icon)
	b.custom_minimum_size = Vector2(0, 46)
	b.toggle_mode = false
	tab_bar.add_child(b)
	tabs.append({"id": id, "button": b, "builder": builder, "key": key})
	tab_bar.visible = tabs.size() > 1
	if current == "":
		current = id

func select_tab(id: String) -> void:
	current = id
	refresh()

func refresh() -> void:
	for t in tabs:
		var b: Button = t["button"]
		b.theme_type_variation = "Primary" if t["id"] == current else "Tab"
	UI.clear(body)
	for t in tabs:
		if t["id"] == current:
			(t["builder"] as Callable).call(body)
			break

func open() -> void:
	visible = true
	refresh()
	Audio.sfx("ui_open")

func close() -> void:
	visible = false
	Audio.sfx("ui_close")
	closed.emit()

## helpers for building rows -----------------------------------------------------------------------
static func row(parent: Control, left: Control, right: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	if right != null:
		h.add_child(right)
	parent.add_child(h)
	return h

static func kv(parent: Control, key: String, value: String, tip: String = "", tint: Color = Color("f4ecd6")) -> HBoxContainer:
	var h := HBoxContainer.new()
	var k := UI.label(key, "Small", -1, true)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.size_flags_stretch_ratio = 1.0
	k.tooltip_text = tip
	k.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(k)
	var v := UI.label(value, "Value", HORIZONTAL_ALIGNMENT_RIGHT, true)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_stretch_ratio = 1.2
	v.add_theme_color_override("font_color", tint)
	h.add_child(v)
	parent.add_child(h)
	return h

static func card(parent: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	parent.add_child(p)
	return v

static func header(parent: Control, text: String) -> Label:
	var l := UI.label(text, "Sub")
	parent.add_child(l)
	parent.add_child(UI.hsep())
	return l
