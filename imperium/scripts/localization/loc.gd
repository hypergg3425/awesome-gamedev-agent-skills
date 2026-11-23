extends Node
## Localization (autoload "Loc"). UI strings live in res://data/localization/strings.json as
## { "KEY": {"en": "...", "tr": "..."} }. Content definitions carry inline {"en","tr"} dictionaries.

signal language_changed(lang: String)

const LANGS: Array[String] = ["en", "tr"]
var strings: Dictionary = {}
var lang := "en"
var missing_reported: Dictionary = {}

func _ready() -> void:
	reload()
	lang = str(Settings.get_value("language"))
	Settings.changed.connect(_on_setting_changed)

func reload() -> void:
	strings.clear()
	var dir := DirAccess.open("res://data/localization")
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".json"):
			var txt := FileAccess.get_file_as_string("res://data/localization/" + f)
			var parsed: Variant = JSON.parse_string(txt)
			if parsed is Dictionary:
				strings.merge(parsed, true)

func _on_setting_changed(key: String) -> void:
	if key == "language":
		set_language(str(Settings.get_value("language")))

func set_language(l: String) -> void:
	if l not in LANGS:
		l = "en"
	lang = l
	TranslationServer.set_locale(l)
	language_changed.emit(l)

## Translate a UI key. Missing keys return the key itself (and are recorded for tests).
func t(key: String) -> String:
	var e: Variant = strings.get(key)
	if e is Dictionary:
		var s: String = (e as Dictionary).get(lang, "")
		if s == "":
			s = (e as Dictionary).get("en", key)
		return s
	missing_reported[key] = true
	return key

## Translate with {name} placeholders.
func tf(key: String, params: Dictionary) -> String:
	var s := t(key)
	for k in params.keys():
		s = s.replace("{" + str(k) + "}", str(params[k]))
	return s

## Resolve an inline localized value: {"en":..,"tr":..} or plain string or key.
func tx(v: Variant) -> String:
	if v is Dictionary:
		var d: Dictionary = v
		var s: String = d.get(lang, "")
		if s == "":
			s = d.get("en", "")
		return s
	if v is String:
		return t(v) if strings.has(v) else v
	return ""

func has_key(key: String) -> bool:
	return strings.has(key)

func has_lang(key: String, l: String) -> bool:
	var e: Variant = strings.get(key)
	return e is Dictionary and str((e as Dictionary).get(l, "")) != ""
