class_name Nav
extends RefCounted
## Scene navigation + context passed between menu screens.

static var mode := "new"            # new | browse | custom
static var scenario_id := ""
static var hotseat: Array = []
static var difficulty := "normal"

const SCENES := {
	"boot": "res://scenes/main/boot.tscn", "menu": "res://scenes/menus/main_menu.tscn", "scenarios": "res://scenes/menus/scenario_select.tscn",
	"country": "res://scenes/menus/country_select.tscn", "campaign": "res://scenes/campaign/campaign.tscn", "credits": "res://scenes/menus/credits.tscn",
	"achievements": "res://scenes/menus/achievements.tscn", "statistics": "res://scenes/menus/statistics.tscn", "editor": "res://scenes/editor/editor.tscn",
}

static func go(tree: SceneTree, key: String) -> void:
	tree.change_scene_to_file(SCENES[key])

static func background(host: Control, path: String = "res://assets/backgrounds/menu_bg.png", dim: float = 0.35) -> void:
	var tr := TextureRect.new()
	if ResourceLoader.exists(path):
		tr.texture = load(path)
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	host.add_child(tr)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.1, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(shade)

## Root margin container honouring the safe area.
static func safe_root(host: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ins := UI.safe_insets(host.get_viewport())
	m.add_theme_constant_override("margin_left", 24 + int(ins["left"]))
	m.add_theme_constant_override("margin_right", 24 + int(ins["right"]))
	m.add_theme_constant_override("margin_top", 18 + int(ins["top"]))
	m.add_theme_constant_override("margin_bottom", 18 + int(ins["bottom"]) + int(Ads.reserved_height()))
	host.add_child(m)
	return m

static func header(parent: Control, title: String, back_cb: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.add_child(UI.icon_button("back", back_cb, Loc.t("UI_BACK"), 56.0))
	h.add_child(UI.label(title, "Title"))
	parent.add_child(h)
	parent.add_child(UI.hsep())
