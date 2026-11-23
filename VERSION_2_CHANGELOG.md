# Version 2.0 changelog (work completed so far — see VERSION_2_AUDIT.md §4 for what is NOT done)

## Added
* Interactive 12-step tutorial (EN/TR), skippable, replayable from Settings and the pause menu; `tutorial_done` is now a real setting.
* AI personalities `naval_trade` and `coalition_builder` (now 9 total, as documented) with distinct behaviour.
* Hotseat test suite; tutorial, AI-personality and ads-policy test suites.
* Real Android export pipeline run end to end: debug APK and release AAB (throw-away key) produced and statically inspected.
* AdMob: developer's app id in `project.godot`; production banner unit `ca-app-pub-1178249482215901/8669329404` used by release exports only; debug/editor builds always use Google's test unit; plugin pinned to v5.1.0.
* New documents: VERSION_2_AUDIT, HISTORICAL_SOURCES, MOBILE_DEVICE_TEST_REPORT, AI_BALANCE_REPORT, PERFORMANCE_REPORT.

## Changed
* Technology start levels capped at 3 (late scenarios started with every line maxed).
* Victory pacing: minimum turn 60 / ¼ of the campaign, hold counter starts after it, technological victory needs a 0.5-level lead, economic share 40 %.
* Android back button: closes panels / opens pause menu in a campaign, returns to the menu elsewhere, never quits mid-campaign.
* Province panel and sheets shrink instead of overflowing in Turkish; raw modifier keys replaced by labels; achievement toast wired; `crown` icon added.
* Export presets exclude plugin samples/docs.

## Fixed
* Audio shutdown leak (see audit #15). Stale victory test. Missing `victory_type` default. Missing `crown` icon.

## Reverted / not done
* An interstitial-ad implementation was started and **reverted** because the v2.0 brief requires banner-only advertising; the interstitial unit id is intentionally not used.
