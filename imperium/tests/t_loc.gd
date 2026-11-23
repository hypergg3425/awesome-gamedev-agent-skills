extends TestCase
## Localization: complete EN/TR tables, consistent placeholders, correct Turkish characters, language switching.

func _used_keys() -> Array:
	var keys := {}
	var files: Array = []
	_walk("res://scripts", files)
	var rx := RegEx.new()
	rx.compile("\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	for f in files:
		var txt := FileAccess.get_file_as_string(f)
		for m in rx.search_all(txt):
			keys[m.get_string(1)] = f
	return keys.keys()

func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for s in d.get_directories():
		_walk(dir + "/" + s, out)

func test_every_key_exists_in_both_languages() -> void:
	ok(Loc.strings.size() > 900, "string table loaded (%d)" % Loc.strings.size())
	for k in Loc.strings:
		ok(Loc.has_lang(k, "en"), "%s has English" % k)
		ok(Loc.has_lang(k, "tr"), "%s has Turkish" % k)

func test_every_key_used_in_code_is_defined() -> void:
	var skip := ["REB", "NAT_", "A_B"]
	var rx_ok := RegEx.new()
	rx_ok.compile("^(RES|TERRAIN|REL|CULT|CLASS|CLASS_WANTS|UCLASS|BCAT|BRANCH|MODE|ACT|ACTD|CB|CBD|FEAT|AI|DIFF|DIFFD|SEASON|ACH|ACHD|CONSENT|ADS_STATE|VIC|VICD|END_REASON|ED_MIL|SET_QUALITY|CS_RATING|FACTOR|UNREST|SKILL|DR|MOD)_")
	var missing: Array = []
	for k in _used_keys():
		if k in Defs.units or k in Defs.buildings:
			continue
		if not Loc.strings.has(k):
			# constants such as Godot class names / env codes are not keys: only report plausible UI keys
			if k.begins_with("ERR_") or k.begins_with("NOTE_") or k.begins_with("HIST_") or k.begins_with("UI_") or k.begins_with("TIP_") or rx_ok.search(k) != null:
				missing.append(k)
	ok(missing.is_empty(), "keys used in scripts but missing from strings.json: %s" % str(missing.slice(0, 12)))

func test_data_driven_keys_are_covered() -> void:
	for gid in Defs.governments:
		for f in Defs.governments[gid]["features"]:
			ok(Loc.strings.has("FEAT_" + str(f).to_upper()), "feature text for %s" % f)
		for m in Defs.governments[gid]["mods"]:
			ok(Loc.strings.has("MOD_" + str(m).to_upper()), "modifier text for %s" % m)
	for tid in Defs.techs:
		for m in Defs.techs[tid]["effects"]:
			ok(Loc.strings.has("MOD_" + str(m).to_upper()), "tech modifier text for %s" % m)
	for rid in Defs.reforms:
		for src in ["advantages", "disadvantages"]:
			for m in Defs.reforms[rid][src]:
				ok(Loc.strings.has("MOD_" + str(m).to_upper()), "reform modifier text for %s" % m)
	for bid in Defs.buildings:
		for m in Defs.buildings[bid]["effects"]:
			ok(Loc.strings.has("MOD_" + str(m).to_upper()), "building effect text for %s" % m)

func test_placeholders_match_between_languages() -> void:
	var rx := RegEx.new()
	rx.compile("\\{[a-z_]+\\}")
	for k in Loc.strings:
		var e: Dictionary = Loc.strings[k]
		var a: Array = []
		var b: Array = []
		for m in rx.search_all(str(e.get("en", ""))):
			a.append(m.get_string())
		for m in rx.search_all(str(e.get("tr", ""))):
			b.append(m.get_string())
		a.sort()
		b.sort()
		eq(a, b, "placeholders of %s identical in EN and TR" % k)

func test_turkish_characters_present_and_language_switch() -> void:
	var all_tr := ""
	for k in Loc.strings:
		all_tr += str(Loc.strings[k].get("tr", ""))
	for ch in ["ç", "ğ", "ı", "İ", "ö", "ş", "ü"]:
		ok(all_tr.contains(ch), "Turkish text uses %s" % ch)
	var prev := Loc.lang
	Loc.set_language("en")
	var en := Loc.t("MENU_NEW")
	Loc.set_language("tr")
	var tr := Loc.t("MENU_NEW")
	ok(en != tr and tr == "Yeni kampanya", "language switches at runtime (%s / %s)" % [en, tr])
	ok(Loc.tx({"en": "a", "tr": "b"}) == "b", "inline localized values follow the language")
	ok(Loc.t("MONTHS").split(",").size() == 12, "month names")
	Loc.set_language(prev)
	# 'İ' and 'ı' must survive font rendering: the font must contain the glyphs
	var f := UI.font("body")
	for ch in "çğıİöşüÇĞÖŞÜ":
		ok(f.has_char(ch.unicode_at(0)), "body font has glyph %s" % ch)
	for kind in ["title", "heading", "ui"]:
		for ch in "çğıİöşü":
			ok(UI.font(kind).has_char(ch.unicode_at(0)), "%s font has glyph %s" % [kind, ch])

func test_content_is_bilingual() -> void:
	for id in Defs.all_scenarios():
		var d: Dictionary = Defs.all_scenarios()[id]
		for k in ["name", "desc"]:
			ok(str(d[k].get("tr", "")) != "" and str(d[k].get("en", "")) != "", "%s %s bilingual" % [id, k])
		for cid in d["countries"]:
			var n: Dictionary = d["countries"][cid]["name"]
			ok(str(n.get("tr", "")) != "" and str(n.get("en", "")) != "", "%s/%s name bilingual" % [id, cid])
	for uid in Defs.units:
		ok(str(Defs.units[uid]["name"]["tr"]) != "", "unit %s has Turkish" % uid)
	for tid in Defs.techs:
		ok(str(Defs.techs[tid]["name"]["tr"]) != "", "tech %s has Turkish" % tid)
	for pid in Defs.province_ids:
		ok(str(Defs.provinces[pid]["name_tr"]) != "", "province %s has a Turkish name" % pid)
