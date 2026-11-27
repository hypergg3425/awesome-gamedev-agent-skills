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

## Scene change with a short fade through navy (skipped when animations are off).
static func go(tree: SceneTree, key: String) -> void:
	if not Anim.enabled() or tree.root.has_node("NavFade"):
		tree.change_scene_to_file(SCENES[key])
		return
	var layer := CanvasLayer.new()
	layer.name = "NavFade"
	layer.layer = 100
	var rect := ColorRect.new()
	rect.color = UI.NAVY_DEEP
	rect.modulate.a = 0.0
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(rect)
	tree.root.add_child(layer)
	var tw := layer.create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, 0.16)
	tw.tween_callback(func() -> void: tree.change_scene_to_file(SCENES[key]))
	tw.tween_interval(0.08)
	tw.tween_property(rect, "modulate:a", 0.0, 0.22)
	tw.tween_callback(layer.queue_free)

static func background(host: Control, _path: String = "", dim: float = 0.35) -> void:
	MenuBackground.attach(host, MenuBackground.ART, dim, false)

## Root margin container honouring the safe area.
static func safe_root(host: Control) -> MarginContainer:
	Layout.install(host.get_window())
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
