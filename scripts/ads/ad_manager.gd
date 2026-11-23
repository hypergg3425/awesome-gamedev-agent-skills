extends Node
## AdManager (autoload "Ads"). Anchored adaptive BANNER at the bottom of the screen only.
## Everything ad related lives here; gameplay code only reads reserved_height() so that its layout
## keeps clear of the banner. The AdMob plugin (Poing Studios godot-admob-plugin v5.x) is bound
## dynamically: when it is not installed (desktop, headless, plugin-less builds) the manager reports
## "unavailable" and the game is unaffected. Consent uses Google's UMP through the same plugin.

signal state_changed(state: String)

var state := "idle"       # idle | unavailable | consent | initializing | loading | loaded | failed | hidden
var consent_status := "unknown"
var privacy_options_required := false
var last_error := ""
var _classes := {}
var _ad_view: Object = null
var _initialized := false
var _wanted_visible := false
var _banner_px := 0
const FALLBACK_DP := 50.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _platform_ok():
		_set_state("unavailable")
		return
	if not _bind_plugin():
		_set_state("unavailable")
		last_error = "AdMob plugin not installed"
		return
	_start()

func _platform_ok() -> bool:
	return OS.get_name() in ["Android", "iOS"] and bool(Settings.get_value("ads_enabled"))

func _bind_plugin() -> bool:
	for gc in ProjectSettings.get_global_class_list():
		_classes[str(gc["class"])] = str(gc["path"])
	for need in ["AdView", "AdSize", "AdPosition", "AdRequest", "AdListener", "MobileAds", "UserMessagingPlatform", "ConsentRequestParameters", "RequestConfiguration"]:
		if not _classes.has(need):
			return false
	return true

func _cls(name: String) -> GDScript:
	return load(_classes[name])

func _set_state(s: String) -> void:
	state = s
	state_changed.emit(s)

## --- consent + init -----------------------------------------------------------------------------
func _start() -> void:
	_set_state("consent")
	var ump: Object = _cls("UserMessagingPlatform")
	var params: Object = _cls("ConsentRequestParameters").new()
	# the game is not child-directed; no under-age flag is set
	var ci: Object = ump.consent_information
	ci.update(params, func() -> void: _on_consent_info_ok(), func(err: Object) -> void: _on_consent_failed(err))

func _on_consent_info_ok() -> void:
	var ump: Object = _cls("UserMessagingPlatform")
	_refresh_consent_flags()
	var ci: Object = ump.consent_information
	if bool(ci.get_is_consent_form_available()):
		ump.load_consent_form(func(form: Object) -> void:
			var st := int(ci.get_consent_status())
			# 2 == REQUIRED according to ConsentInformation.ConsentStatus
			if st == 2:
				form.show(func(_e: Object) -> void:
					_refresh_consent_flags()
					_init_sdk()
			)
			else:
				_init_sdk(),
		func(_err: Object) -> void: _init_sdk())
	else:
		_init_sdk()

func _on_consent_failed(err: Object) -> void:
	last_error = str(err.message) if err != null and "message" in err else "consent update failed"
	# ads may still be requested; UMP state decides personalisation. Never block the game.
	_init_sdk()

func _refresh_consent_flags() -> void:
	var ci: Object = _cls("UserMessagingPlatform").consent_information
	consent_status = ["unknown", "not_required", "required", "obtained"][clampi(int(ci.get_consent_status()), 0, 3)]
	privacy_options_required = int(ci.get_privacy_options_requirement_status()) == 2

func _init_sdk() -> void:
	if _initialized:
		return
	_initialized = true
	_set_state("initializing")
	var mobile_ads: GDScript = _cls("MobileAds")
	var rc: Object = _cls("RequestConfiguration").new()
	rc.max_ad_content_rating = "T"      # a strategy game with historical warfare: no mature-rated ads
	mobile_ads.set_request_configuration(rc)
	mobile_ads.initialize()
	if _wanted_visible:
		_load_banner()
	else:
		_set_state("hidden")

## --- banner ---------------------------------------------------------------------------------------------
func show_banner() -> void:
	_wanted_visible = true
	if state in ["unavailable", "consent", "initializing"]:
		return
	if _ad_view == null:
		_load_banner()
	else:
		_ad_view.show()
		if state == "hidden":
			_set_state("loaded")

func hide_banner() -> void:
	_wanted_visible = false
	if _ad_view != null:
		_ad_view.hide()
		_set_state("hidden")

func _load_banner() -> void:
	if _ad_view != null or not _classes.has("AdView"):
		return
	_set_state("loading")
	var size: Object = _cls("AdSize").get_current_orientation_anchored_adaptive_banner_ad_size(-1)   # AdSize.FULL_WIDTH
	var position: Variant = _cls("AdPosition").BOTTOM
	_ad_view = _cls("AdView").new(AdConfig.banner_unit(), size, position)
	var listener: Object = _cls("AdListener").new()
	listener.on_ad_loaded = func() -> void:
		_banner_px = int(_ad_view.get_height_in_pixels()) if _ad_view else 0
		_set_state("loaded")
	listener.on_ad_failed_to_load = func(err: Object) -> void:
		last_error = str(err.message) if err != null and "message" in err else "load failed"
		_destroy_banner()
		_set_state("failed")
		# retry later without blocking anything
		get_tree().create_timer(60.0).timeout.connect(func() -> void:
			if _wanted_visible and state == "failed":
				_load_banner())
	_ad_view.ad_listener = listener
	_ad_view.load_ad(_cls("AdRequest").new())

func _destroy_banner() -> void:
	if _ad_view != null:
		_ad_view.destroy()
		_ad_view = null

func _exit_tree() -> void:
	_destroy_banner()

## Height (in the game's virtual pixels) the UI must keep free at the bottom of the screen.
func reserved_height() -> float:
	if state in ["unavailable", "failed", "idle"] or not _wanted_visible:
		return 0.0
	var win := DisplayServer.window_get_size()
	var vs := get_viewport().get_visible_rect().size
	var ratio := vs.y / maxf(float(win.y), 1.0)
	if _banner_px > 0:
		return float(_banner_px) * ratio
	# not measured yet: reserve the typical adaptive banner height (dp -> px via screen scale)
	return FALLBACK_DP * DisplayServer.screen_get_scale() * ratio

## UMP privacy options form (required to be reachable from settings when privacy_options_required).
func show_privacy_options() -> void:
	if state == "unavailable":
		return
	_cls("UserMessagingPlatform").show_privacy_options_form(func(_e: Object) -> void: _refresh_consent_flags())

func status_text_key() -> String:
	return "ADS_STATE_" + state.to_upper()
