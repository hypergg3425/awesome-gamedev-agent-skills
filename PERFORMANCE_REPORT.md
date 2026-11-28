# Performance report

**Mobile performance was not measured** (no device/emulator). Numbers below are desktop (4-core Linux container, headless).

## Turn resolution (tests/sim.tscn, all countries AI, single process)
| Scenario | ms/turn (40-turn run) |
|---|---:|
| world_conquest | 327 |
| early_modern | 306 |
Earlier single-process runs of the largest scenarios: 0.14–0.55 s/turn. Seven simultaneous runs on 4 cores inflate this to 0.42–0.64 s/turn (not representative). A mid-range phone is typically several times slower than this container's CPU; whether the "<2 s worst case" goal holds on a phone is **unknown**.

## Memory leaks
Shutdown leak (AudioStreamPlaybackOggVorbis / OggPacketSequence, 2 resources in use) found and fixed (AudioManager releases streams). After the fix, boot, test runner and the UI screenshot tool exit without ObjectDB or resource warnings. In-game memory growth over long sessions was **not** measured.

## Size
| Artifact | Size |
|---|---:|
| Debug APK (arm64) | 114.8 MB (libgodot_android.so 76 MB uncompressed) |
| Release AAB | 59.5 MB |
| assets/audio / illustrations / backgrounds / fonts / data | 3.4 / 11 / 5.2 / 3.7 / 5.0 MB (source) |
Possible reductions (not done): exclude the AdMob plugin's sample/unused ad-format scripts from the export (sample scenes are now excluded via the preset filter), recompress illustrations.

## Not measured
Frame rate, touch latency, map redraw cost on a phone, label overlay cost, save duration on phone storage, battery/thermal.


## v2 integration numbers (desktop, shared 4-core machine, from agent measurements and the final run)
* Mean turn time, `docs/PERFORMANCE_NOTES.md`: world_conquest classic 0.49 s, extended 0.77 s; medieval_europe (136 countries) classic 0.55 s, extended 0.78 s. **Target <0.6 s is met only on the classic map.** The default is now the extended map (feature requirement); phone speed is unknown.
* Map: mesh vertices 173,844 (extended) vs 142,738 (classic); colour refresh ≈26 ms and overlay draw 4.5–13 ms on extended (software GL, desktop); relief build ≈170 ms.
* APK 119.6 MB (debug) / AAB 64.1 MB (release).
