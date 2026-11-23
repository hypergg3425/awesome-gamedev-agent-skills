class_name AdConfig
extends RefCounted
## Advertising configuration. BANNER ONLY. There is no interstitial, rewarded or app-open code anywhere.
##
## Development uses Google's official adaptive-banner TEST unit. To go live:
##   1. Create your own AdMob app + banner unit in the AdMob console.
##   2. Put the *application id* in res://addons/admob/android/config.gd (APPLICATION_ID) as the plugin README
##      describes (see docs/ADMOB_SETUP.md) — it is never stored in this repository.
##   3. Put your *banner unit id* into PRODUCTION_BANNER_UNIT below (or leave it empty to keep test ads) and set
##      USE_TEST_ADS to false for the release build.
## Never ship test ids to production and never use production ids while developing.

const TEST_BANNER_UNIT := "ca-app-pub-3940256099942544/9214589741"   # Google official adaptive banner test unit
const PRODUCTION_BANNER_UNIT := ""   # <-- your own banner unit id, e.g. "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"
const USE_TEST_ADS := true            # release builds: false (only effective if PRODUCTION_BANNER_UNIT is set)

static func banner_unit() -> String:
	if USE_TEST_ADS or PRODUCTION_BANNER_UNIT == "":
		return TEST_BANNER_UNIT
	return PRODUCTION_BANNER_UNIT

static func using_test_ads() -> bool:
	return banner_unit() == TEST_BANNER_UNIT
