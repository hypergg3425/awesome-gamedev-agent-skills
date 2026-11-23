extends Node
## Persistent user settings (autoload "Settings"). Stored in user://settings.cfg.

signal changed(key: String)

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"language": "",
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"muted": false,
	"map_labels": true,
	"animations": true,
	"text_scale": 1.0,
	"colorblind": false,
	"confirm_actions": true,
	"graphics_quality": 1,
	"fps_cap": 60,
	"army_markers": true,
	"ads_enabled": true,
	"autosave": true,
	"difficulty": "normal",
	"tutorial_done": false,
}

var values: Dictionary = {}

func _ready() -> void:
	values = DEFAULTS.duplicate()
	load_settings()
	if str(values["language"]) == "":
		var os_loc := OS.get_locale_language()
		values["language"] = "tr" if os_loc == "tr" else "en"
	apply_runtime()

func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

func set_value(key: String, v: Variant, persist: bool = true) -> void:
	if values.get(key) == v:
		return
	values[key] = v
	if persist:
		save_settings()
	apply_runtime()
	changed.emit(key)

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in DEFAULTS.keys():
		if cf.has_section_key("settings", k):
			var v: Variant = cf.get_value("settings", k)
			# type-validate against default to avoid corrupt files breaking the game
			if typeof(v) == typeof(DEFAULTS[k]) or (DEFAULTS[k] is float and v is int):
				values[k] = v

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values.keys():
		cf.set_value("settings", k, values[k])
	cf.save(PATH)

func apply_runtime() -> void:
	Engine.max_fps = int(values.get("fps_cap", 60))
	TranslationServer.set_locale(str(values.get("language", "en")))
