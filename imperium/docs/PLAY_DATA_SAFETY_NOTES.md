# Play Console "Data safety" — working notes (NOT a legal answer; verify against Google's current form before submitting)

Basis: what the built APK actually declares (aapt2 dump of the v2.0 debug build, AdMob plugin v5.1.0, Google Mobile Ads + UMP SDK pulled by the plugin).

## Permissions found in the APK manifest
| Permission | Source |
|---|---|
| INTERNET, ACCESS_NETWORK_STATE | the game's export preset (needed for ads) |
| com.google.android.gms.permission.AD_ID, android.permission.AD_ID | Google Mobile Ads SDK (advertising ID) |
| READ_BASIC_PHONE_STATE, WAKE_LOCK, FOREGROUND_SERVICE, `<package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | libraries merged by Gradle |

## What the game itself does
No account, no analytics, no crash-reporting SDK, no user-generated content upload. Saves/settings/achievements stay in app-private storage.

## What the ad SDK does (per Google's SDK documentation — re-check the current text)
The AdMob SDK collects/uses device identifiers (advertising ID), IP address, coarse location derived from IP, app and ad-interaction diagnostics, to serve and measure ads. For EEA/UK/CH users the UMP form gates ad requests.

## Suggested Data-safety answers (to be confirmed by you)
* Data collected: Device or other IDs (advertising ID) — purpose: Advertising or marketing; shared with Google (AdMob). Approximate location (IP-derived) and app interactions/diagnostics — same purposes, collected by the SDK.
* Data encrypted in transit: yes (SDK traffic is HTTPS). Users can request deletion: the developer holds no personal data; users manage ad personalisation in Google settings.
* Ads declaration: **contains ads**. Target audience: not children.

## Not verified
Google's policy pages were not reachable from the authoring environment, so the current 2026 Play policies (target API level deadline, Data safety wording, UMP/TCF requirements) were **not re-checked online**. The preset targets API 36, the default of Godot 4.7.2.
