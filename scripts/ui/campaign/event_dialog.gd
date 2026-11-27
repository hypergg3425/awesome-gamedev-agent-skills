class_name EventDialog
extends RefCounted
## Modal event presentation with illustration, text and choice buttons. Historical events are
## labelled with a real source; random events are labelled as such.

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
	var tag := UI.label(Loc.t("EVT_HISTORICAL") if hist else Loc.t("EVT_RANDOM"), "Small")
	tag.add_theme_color_override("font_color", UI.GOLD_LIGHT if hist else UI.STEEL)
	v.add_child(tag)
	v.add_child(UI.label(EventSystem.render(s, entry, e["title"]), "Heading", -1, true))
	var img_path := "res://assets/illustrations/ev_%s.png" % str(e.get("image", "generic"))
	if not ResourceLoader.exists(img_path):
		img_path = "res://assets/illustrations/ev_generic.png"
	if ResourceLoader.exists(img_path):
		var tr := TextureRect.new()
		tr.texture = load(img_path)
		tr.custom_minimum_size = Vector2(0, clampf(Dialogs.free_area(host).size.y * 0.24, 80.0, 190.0))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		v.add_child(tr)
	var tl := UI.label(EventSystem.render(s, entry, e["text"]), "", -1, true)
	v.add_child(tl)
	if hist:
		var src := UI.label(Loc.tf("EVT_SOURCE", {"src": str(e.get("source", ""))}), "Tiny", -1, true)
		v.add_child(src)
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
	Audio.sfx("event_pop")
