class_name EventDialog
extends RefCounted
## Modal event presentation with illustration, text and choice buttons. Historical events are
## labelled with a real source; random events are labelled as such.

## Illustration used when an event's `image` key has no art of its own.
const IMAGE_FALLBACK := {"siege": "battle", "conquest": "battle", "treaty": "diplomacy", "ship": "harbor", "revolution": "uprising", "revolt": "uprising",
	"parliament": "court", "disaster": "fire", "tech": "science", "religion": "church", "succession": "coronation", "economic": "trade", "food": "famine"}
## Per-category default when the event names no image at all.
const CATEGORY_IMAGE := {"political": "court", "succession": "coronation", "economic": "trade", "food": "famine", "diplomatic": "diplomacy", "religious": "church",
	"military": "battle", "uprising": "uprising", "disaster": "storm", "tech": "science", "historical": "court"}

static func image_path(e: Dictionary) -> String:
	var key := str(e.get("image", ""))
	if key == "":
		key = str(CATEGORY_IMAGE.get(str(e.get("category", "")), "generic"))
	for k in [key, str(IMAGE_FALLBACK.get(key, "")), "generic"]:
		var path := "res://assets/illustrations/ev_%s.png" % k
		if k != "" and ResourceLoader.exists(path):
			return path
	return ""

static func show_event(host: Control, s: Dictionary, entry: Dictionary, on_done: Callable) -> void:
	var e: Dictionary = Defs.events.get(entry["id"], {})
	if e.is_empty():
		Game.state["events"]["pending"].erase(entry)
		on_done.call()
		return
	var dim := Dialogs.overlay(host, Callable(), 0.7)
	var v: VBoxContainer = Dialogs.frame(dim, 860.0)["box"]
	v.add_theme_constant_override("separation", 8)
	var hist: bool = e.get("historical", false)
	var cat := str(e.get("category", ""))
	var cat_name := Loc.t("EVT_CAT_" + cat.to_upper()) if Loc.strings.get("EVT_CAT_" + cat.to_upper()) != null else ""
	var tag := UI.label(("%s  |  %s" % [Loc.t("EVT_HISTORICAL") if hist else Loc.t("EVT_RANDOM"), cat_name]) if cat_name != "" else (Loc.t("EVT_HISTORICAL") if hist else Loc.t("EVT_RANDOM")), "Small")
	tag.add_theme_color_override("font_color", UI.GOLD_LIGHT if hist else UI.STEEL)
	v.add_child(tag)
	v.add_child(UI.label(EventSystem.render(s, entry, e["title"]), "Heading", -1, true))
	var img_path := image_path(e)
	if img_path != "":
		var tr := TextureRect.new()
		tr.texture = load(img_path)
		tr.custom_minimum_size = Vector2(0, clampf(Dialogs.free_area(host).size.y * 0.24, 80.0, 190.0))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		v.add_child(tr)
	var tl := UI.label(EventSystem.render(s, entry, e["text"]), "", -1, true)
	v.add_child(tl)
	if hist:
		var src_txt := Loc.tf("EVT_SOURCE", {"src": str(e.get("source", ""))})
		if str(e.get("reference", "")) != "":
			src_txt += " (" + str(e["reference"]) + ")"
		v.add_child(UI.label(src_txt, "Tiny", -1, true))
	else:
		v.add_child(UI.label(Loc.t("EVT_RANDOM_NOTE"), "Tiny", -1, true))
	v.add_child(UI.hsep())
	var opts := EventSystem.available_options(s, entry)
	var all_opts: Array = e["options"]
	for o in all_opts:
		var available: bool = o in opts
		var ob := Button.new()
		ob.focus_mode = Control.FOCUS_NONE
		ob.custom_minimum_size = Vector2(0, 56)
		ob.clip_text = false
		ob.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ob.text = Loc.tx(o["name"])
		ob.theme_type_variation = "Primary" if available else ""
		ob.disabled = not available
		var oid: String = o["id"]
		ob.pressed.connect(func() -> void:
			Audio.sfx("ui_confirm")
			Game.cmd_event_choice(entry["uid"], oid)
			dim.queue_free()
			on_done.call())
		v.add_child(ob)
		if o.has("tip"):
			var tp := UI.label(Loc.tx(o["tip"]), "Tiny", -1, true)
			v.add_child(tp)
		v.add_child(_consequences(o, available))
	Audio.sfx("event_pop")

## Plain-text consequence list of one option: every concrete effect, coloured good / bad.
static func _consequences(o: Dictionary, available: bool) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 0)
	if not available:
		var l := UI.label(Loc.t("EVT_OPTION_LOCKED"), "Tiny")
		l.add_theme_color_override("font_color", UI.BAD)
		flow.add_child(l)
		return flow
	for fx in o.get("effects", []):
		var line := EventExt.describe(fx)
		if line == "":
			continue
		var l := UI.label(line, "Tiny")
		var t := EventExt.tone(fx)
		if t != 0:
			l.add_theme_color_override("font_color", UI.GOOD if t > 0 else UI.BAD)
		flow.add_child(l)
	return flow
