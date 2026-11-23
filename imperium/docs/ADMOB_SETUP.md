# AdMob setup (banner only)

**Policy of this project:** one adaptive banner anchored at the bottom. No interstitial, rewarded or app-open ads exist in the code. Ads are shown only on menu / campaign screens (never covering controls: the UI reserves `Ads.reserved_height()` at the bottom). Everything lives in `scripts/ads/ad_manager.gd`; ids in `scripts/ads/ad_config.gd`.

## Development (default)
* Banner unit: Google's official adaptive-banner **test** unit `ca-app-pub-3940256099942544/9214589741` (`AdConfig.TEST_BANNER_UNIT`).
* App id: the plugin's default is Google's public test app id `ca-app-pub-3940256099942544~3347511713`.
* The game never shows or loads ads on desktop/headless; `Ads.state == "unavailable"` and layout reserves 0 px.

## Plugin
The plugin (Poing Studios, MIT) is **not committed**. `tools/ci/install_admob.sh <tag>` copies `addons/admob`, downloads the Android native library zip of that release, enables the editor plugin and (optionally) writes `admob/general/android/app_id`. Manually: Asset Library → "AdMob" (Poing Studios) → enable plugin → *Project → Tools → AdMob Manager → Android → Download & Install*; export with **Use Gradle Build** (already set in `export_presets.cfg`).

The binding in `ad_manager.gd` was checked against the plugin source (v5.2.0-nightly): `AdView(unit, AdSize, AdPosition)`, `AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(-1)`, `AdListener` callables, `MobileAds.initialize/set_request_configuration`, `UserMessagingPlatform.consent_information.update/load_consent_form`, `ConsentForm.show`, `show_privacy_options_form`. A desktop run with the plugin installed exercised creation, listener callbacks and hide/show without script errors (native calls are no-ops there).

## Going to production
1. Create an AdMob app and one banner ad unit.
2. Put the **application id** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`) in *Project Settings → Admob → General → Android → App Id* (or the repository variable `ADMOB_ANDROID_APP_ID` used by CI).
3. Put the **banner unit id** into `AdConfig.PRODUCTION_BANNER_UNIT` and set `USE_TEST_ADS := false` **only in the release build**. Leave test ids in every development build. (Left empty here on purpose — no production id has been invented.)
4. Configure the UMP consent message in AdMob → Privacy & messaging (EEA/UK/CH). The game requests consent info on start and shows the form when required; Settings shows a "Privacy options" button when Google reports it is required.
5. Publish `docs/PRIVACY_POLICY_TEMPLATE.md` (filled in) and complete Play Console *Data safety* (advertising ID collected by AdMob; shared with Google).

## What is NOT verified
No Android build was produced in the authoring environment, so banner display, adaptive sizing, safe-area behaviour, consent form and test-ad load on a real device/emulator are **unverified**. Use the device checklist in `docs/RELEASE_CHECKLIST.md`.
