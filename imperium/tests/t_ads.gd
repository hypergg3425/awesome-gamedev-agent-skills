extends TestCase
## Advertising policy: banner only, test unit in debug builds, no forbidden ad formats in the code base.

func test_debug_builds_use_google_test_banner() -> void:
	ok(OS.is_debug_build(), "tests run in a debug build")
	eq(AdConfig.banner_unit(), "ca-app-pub-3940256099942544/9214589741", "debug/editor builds always use Google's test banner")
	ok(AdConfig.using_test_ads(), "using_test_ads() agrees")

func test_production_unit_is_the_developers_banner_unit() -> void:
	ok(AdConfig.PRODUCTION_BANNER_UNIT.begins_with("ca-app-pub-1178249482215901/"), "production banner unit configured")
	ok(not AdConfig.PRODUCTION_BANNER_UNIT.contains("~"), "a unit id contains '/', not '~' (that would be an application id)")

func test_application_id_is_configured_in_project_settings() -> void:
	var app_id := str(ProjectSettings.get_setting("admob/general/android/app_id", ""))
	ok(app_id.contains("~") and app_id.begins_with("ca-app-pub-1178249482215901~"), "application id present in project.godot")

func test_no_forbidden_ad_formats_in_code() -> void:
	var bad := ["InterstitialAd", "RewardedAd", "AppOpenAd", "RewardedInterstitial", "NativeOverlayAd"]
	var d := DirAccess.open("res://scripts/ads")
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/ads/" + f)
		for b in bad:
			ok(not src.contains(b), "%s does not reference %s" % [f, b])

func test_banner_manager_is_safe_without_plugin() -> void:
	var ads: Node = load("res://scripts/ads/ad_manager.gd").new()
	ads.show_banner()
	ads.hide_banner()
	ok(ads.reserved_height() >= 0.0, "reserved height never negative")
	ads.free()
