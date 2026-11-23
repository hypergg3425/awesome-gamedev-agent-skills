class_name AdConfig
extends RefCounted
## Advertising configuration. BANNER ONLY. There is no interstitial, rewarded or app-open code anywhere.
##
## Development uses Google's official adaptive-banner TEST unit. To go live:
##   1. Create your own AdMob app + banner unit in the AdMob console.
##   2. The *application id* is set in project.godot ([admob] general/android/app_id) — it is not a secret.
##   3. The *banner unit id* is PRODUCTION_BANNER_UNIT below; release exports use it, debug builds never do.

const TEST_BANNER_UNIT := "ca-app-pub-3940256099942544/9214589741"   # Google official adaptive banner test unit
## The developer's own banner unit. Used ONLY by release (non-debug) exports. The matching AdMob *application id*
## (ca-app-pub-1178249482215901~1173982760) lives in project.godot [admob] general/android/app_id.
const PRODUCTION_BANNER_UNIT := "ca-app-pub-1178249482215901/8669329404"
const USE_TEST_ADS := false           # force test ads even in release exports (QA builds)

## Debug / editor builds ALWAYS use Google's test unit (clicking your own live ads violates AdMob policy).
static func banner_unit() -> String:
	if USE_TEST_ADS or OS.is_debug_build() or PRODUCTION_BANNER_UNIT == "":
		return TEST_BANNER_UNIT
	return PRODUCTION_BANNER_UNIT

static func using_test_ads() -> bool:
	return banner_unit() == TEST_BANNER_UNIT
