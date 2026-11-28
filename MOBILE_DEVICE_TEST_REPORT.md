# Mobile device test report

## Verdict
**No real Android device and no emulator was available in the authoring environment. No test on real hardware was performed.** Everything below is static inspection of built artifacts or desktop screenshots at emulated resolutions.

## Build environment actually used
| Item | Version |
|---|---|
| Godot | 4.7.2-stable (official), export templates 4.7.2.stable from the official release |
| Android SDK | cmdline-tools 11076708; platform-tools; `platforms;android-36`; `build-tools;36.1.0`; `cmake;3.10.2.4988404`; `ndk;29.0.14206865` (versions taken from Godot 4.7.2 `platform/android/java/app/config.gradle`) |
| JDK | OpenJDK 21 (Godot's gradle config targets Java 17; the export worked with 21) |
| AdMob plugin | poingstudios/godot-admob-plugin **v5.1.0**, Android binaries `android-template-v4.7.2.zip` from the same release |
| Signing | debug: freshly generated debug keystore; release: **throw-away keystore generated for this test** (not the developer's, not usable for Play) |

## Artifacts produced (not delivered as release builds)
| Artifact | Size | Result |
|---|---:|---|
| `imperium-debug.apk` | 114.8 MB | export exit 0; apksigner verifies; arm64-v8a only |
| `imperium-release.aab` | 59.5 MB | export exit 0; `jarsigner -verify`: "jar verified" |

## Static checks on the APK (`aapt2`, `apksigner`)
* package `com.imperium.agecrowns` (placeholder), versionCode 1, versionName 0.1.0, compileSdk/targetSdk **36**, native-code `arm64-v8a`.
* Permissions: INTERNET, ACCESS_NETWORK_STATE (ours) + AD_ID, READ_BASIC_PHONE_STATE, WAKE_LOCK, FOREGROUND_SERVICE and a dynamic-receiver permission (added by the Google Mobile Ads / UMP libraries).
* Manifest meta-data `com.google.android.gms.ads.APPLICATION_ID = ca-app-pub-1178249482215901~1173982760` (developer's real app id).
* Activity `screenOrientation=11` (sensor landscape), `resizeableActivity=true`.
* Not checked: Play Console pre-launch rules, 16 KB page-size alignment of native libs, deobfuscation/R8.

## Layout checks (desktop screenshots, `tests/ui_shots.tscn`, Xvfb, `--resolution`)
Reviewed by eye: campaign HUD, province panel, economy sheet at **800×360, 1024×768, 1280×720 (EN/TR), 2400×1080**. No clipped buttons or text outside panels were seen at those sizes after the fixes in this iteration. Not reviewed at 854×393, 1600×900, 1920×1080, nor every screen at every size. Because the project scales a 1280×720 virtual canvas, text on very small physical screens is proportionally small (at 800×360 body text is ~60 % of its 720p size).

## NOT tested
Install/launch, touch pan/pinch/tap/long-press, back-button/gesture, banner display and adaptive size, UMP consent form and privacy options, banner retry/resume/orientation behaviour, safe areas (notch, gesture bar), frame rate, memory, battery, thermal, low-RAM devices, TalkBack, interruptions (calls, backgrounding) during a save.


## v2 integration rebuild (2026-11-28)
Rebuilt from the merged `v2-dev` (extended map default, AdMob plugin v5.1.0): debug APK **119.6 MB** (export exit 0; `apksigner verify` silent = OK; package `com.imperium.agecrowns`, targetSdk 36, arm64-v8a, manifest AdMob app id `ca-app-pub-1178249482215901~1173982760`) and release AAB **64.1 MB** (throw-away key, `jarsigner` ok). Still **no device/emulator**: nothing was installed or run. Layout was additionally checked by the automated `ui_layout_check` (800×360, 854×393, 1280×720, 1920×1080) and `ui_interaction` (real input events) under Xvfb — these are desktop renderings, not phones.
