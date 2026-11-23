# Release checklist

Legend: [x] done in the authoring environment · [ ] you (or CI) still have to do/verify

## Build
- [x] Godot 4.7.2 project loads, all automated suites pass (see TEST_REPORT.md)
- [x] `export_presets.cfg` (arm64-v8a, min SDK 24, target SDK 36, Gradle build, INTERNET + ACCESS_NETWORK_STATE only)
- [x] PCK export + packed boot smoke run succeeds (data files included via `include_filter`)
- [ ] CI run of `.github/workflows/build.yml` is green (first run = first real verification of the Android steps)
- [ ] Debug APK installs and starts on a real device / emulator
- [ ] Release AAB builds with your upload keystore

## Identity (must be changed by you)
- [ ] `package/unique_name` in both presets (currently the placeholder `com.imperium.agecrowns`) — permanent once published
- [ ] `version/code` increments for every upload; `version/name`
- [ ] Developer name, contact e-mail, website, privacy-policy URL

## Signing (no secrets are in the repo)
1. Create an upload key once: `keytool -genkeypair -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000`
2. Back it up offline. Enrol in **Play App Signing**.
3. CI secrets: `ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload.keystore`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`. Locally use `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD`.

## AdMob (see docs/ADMOB_SETUP.md)
- [ ] AdMob app + banner unit created; app id in Project Settings/`ADMOB_ANDROID_APP_ID`
- [ ] `AdConfig.PRODUCTION_BANNER_UNIT` set and `USE_TEST_ADS=false` **only** for the release build
- [ ] UMP consent message published (EEA/UK/CH); consent form appears with a test geography
- [ ] Test banner visible, anchored at the bottom, not covering controls, correct with notch/gesture bar, orientation changes
- [ ] No interstitial / rewarded / app-open anywhere (true in code: `grep -ri "interstitial\|rewarded\|app_open" scripts` finds only comments)

## Play Console
- [ ] Target API level ≥ 36 (preset uses 36 — re-check Google's current deadline, it changes yearly)
- [ ] App content: privacy policy URL (docs/PRIVACY_POLICY_TEMPLATE.md), Data safety form (advertising ID via AdMob), ads declaration = contains ads, target audience ≠ children, content rating questionnaire (strategy game with historical warfare)
- [ ] Store listing: EN + TR texts, 512×512 icon (`assets/icon_512.png`), feature graphic (`assets/store_feature_graphic.png`), ≥2 phone screenshots (take on device), short/long description
- [ ] Closed testing track with testers (new personal developer accounts must meet Google's testing requirements before production access)
- [ ] Pre-launch report reviewed

## Device test checklist
Start every scenario · play 20 turns · save/quit/relaunch/load · airplane-mode launch (no crash without network) · rotate/multi-window · low-RAM device · back button · TalkBack/large text · TR and EN · banner after resume from background · battery/thermal over 30 min.

## Honest status
Nothing in the "[ ]" lists above has been verified yet. The project must not be described as publication-ready until they are.
