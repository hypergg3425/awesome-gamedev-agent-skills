# AdMob setup (banner only)

**Policy of this project:** one adaptive banner anchored at the bottom. No interstitial, rewarded or app-open ads exist in the code. Ads are shown only on menu / campaign screens (never covering controls: the UI reserves `Ads.reserved_height()` at the bottom). Everything lives in `scripts/ads/ad_manager.gd`; ids in `scripts/ads/ad_config.gd`.

## Identifiers
| What | Value | Where |
|---|---|---|
| AdMob application id | `ca-app-pub-1178249482215901~1173982760` | `project.godot` → `[admob] general/android/app_id` (written into the manifest at export; verified in the built APK with `aapt2 dump xmltree`) |
| Production banner unit | `ca-app-pub-1178249482215901/8669329404` | `AdConfig.PRODUCTION_BANNER_UNIT` |
| Test banner unit | `ca-app-pub-3940256099942544/9214589741` (Google) | `AdConfig.TEST_BANNER_UNIT` |

`AdConfig.banner_unit()` returns the **test** unit whenever `OS.is_debug_build()` (editor, debug APK) or `USE_TEST_ADS` is true, and the production unit only in release exports. This prevents clicking your own live ads while developing (an AdMob policy violation). The application id is the real one in all builds — that is Google's recommended way to run test units against your own app.
The developer also created an interstitial unit; it is intentionally **not used** (v2.0 requirement: banner only).
Desktop/headless runs never load ads: `Ads.state == "unavailable"`.

## Plugin
The plugin (Poing Studios, MIT) is **not committed**. `tools/ci/install_admob.sh <tag>` (pinned: **v5.1.0**) copies `addons/admob`, downloads the Android native library zip of that release, enables the editor plugin and (optionally) writes `admob/general/android/app_id`. Manually: Asset Library → "AdMob" (Poing Studios) → enable plugin → *Project → Tools → AdMob Manager → Android → Download & Install*; export with **Use Gradle Build** (already set in `export_presets.cfg`).

The binding in `ad_manager.gd` was checked against the plugin source of **v5.1.0** (the pinned release) and v5.2.0-nightly; the banner/UMP/MobileAds/AdSize/RequestConfiguration classes are identical in both. The v5.1.0 asset `android-template-v4.7.2.zip` exists and was used in a real Gradle export (see TEST_REPORT.md): `AdView(unit, AdSize, AdPosition)`, `AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(-1)`, `AdListener` callables, `MobileAds.initialize/set_request_configuration`, `UserMessagingPlatform.consent_information.update/load_consent_form`, `ConsentForm.show`, `show_privacy_options_form`. A desktop run with the plugin installed exercised creation, listener callbacks and hide/show without script errors (native calls are no-ops there).

## Remaining steps for the developer
1. In AdMob: link the app to its Play listing after the first upload; publish the UMP consent message (EEA/UK/CH).
2. Fill and host `docs/PRIVACY_POLICY_TEMPLATE.md`; answer Play *Data safety* (advertising ID/device identifiers shared with Google for advertising).

## What is NOT verified
The APK/AAB were built, but **no emulator or device was available**: banner display, adaptive sizing, safe-area behaviour, the UMP form and test-ad loading at runtime are **unverified**. Use the device checklist in `docs/RELEASE_CHECKLIST.md`.
