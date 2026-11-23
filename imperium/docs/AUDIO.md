# IMPERIUM audio

**All audio in `assets/audio/` is original.** It is generated entirely by
`tools/assets/gen_audio.py` (numpy synthesis + `soundfile` OGG Vorbis writer). No samples, loops or
third-party recordings are used anywhere. The output is covered by the project's own licence.

Regenerate: `python3 tools/assets/gen_audio.py` (optional `--only name ...`, `--analyse-only`).
Requires `numpy` and `soundfile` (libsndfile with Vorbis). Output is deterministic (fixed seeds, fixed
Ogg stream serial) and byte-reproducible.

## Technique
Additive, FM and Karplus-Strong plucks; additive brass/string-pad models; filtered noise for drums, paper,
wind and whooshes; synthetic-impulse-response reverb (filtered decaying noise + early taps, FFT convolution).
Format: 44.1 kHz OGG Vorbis, quality 0.4; music stereo, SFX mono.

**Loudness** (ART_DIRECTION): peak <= -3 dBFS (verified on the *decoded* file, encoder re-trimmed if Vorbis
overshoots), music ~ -16 LUFS (BS.1770 K-weighted, gated), SFX ~ -12 LUFS (active-region measure, min 400 ms
window). Very short/transient SFX (ui_click, cannon, march) sit below -12 LUFS because the -3 dBFS peak
ceiling takes priority.

**Seamless loops**: music is built circularly. Notes wrap past the loop end, drones/shimmer use frequencies
snapped to whole cycles per loop, modulation LFOs have whole cycles per loop, and reverb is circular
convolution. The analysis checks the sample jump at the seam against the 99.9th-percentile sample step
(ratio < 2 passes; all loops measure < 0.7).

## Music
| file | length | description |
|---|---|---|
| music_menu.ogg | 71.3 s | Stately D Dorian processional, 54 BPM, 16 bars. Lute (Karplus-Strong) melody, harp arpeggios, soft string pad, plucked bass, frame drum that thickens in the second half. |
| music_campaign.ogg | 88.2 s | Calm A Dorian ambience for long sessions: slow beating drones (A/E), wind bed, glassy shimmer, slow-moving pad chords (2 bars each), very soft sub pulse (rests every 4th bar), sparse pentatonic harp phrases with echoes (seeded random walk). Dark, low-density spectrum (centroid ~420 Hz) to avoid fatigue. |
| music_battle.ogg | 46.4 s | Tense E Phrygian, ~103 BPM, 20 bars. Taiko pattern, low brass swells (E / F minor-second tension), urgent 16th-note staccato string ostinato, high brass theme in bars 13-16, field drum, snare-roll builds that lead back into the loop start. |

## SFX
| file | description |
|---|---|
| ui_click | short wooden tick |
| ui_back | lower, falling tick |
| ui_open | rising paper/air swish + two plucked notes (D5, A5) |
| ui_close | falling swish + plucks, mirror of ui_open |
| ui_error | two dissonant (tritone) buzz pulses with thud |
| ui_confirm | rising plucked fifth with bell shimmer |
| coin | two bright FM metallic pings (B6, E7) |
| build_complete | three hammer knocks then a D-major pluck chord and bell |
| recruit | two frame-drum hits and a short brass call |
| march | four boot stomps with scuff noise and mail/buckle jingle |
| clash | three overlapping inharmonic metallic clangs with drum thump (battle start) |
| battle_win | brass fanfare to a held D-major chord, drums, bell |
| battle_lose | descending minor brass line, low drum tolls |
| cannon | pitch-dropping boom, blast, crack, rumble, long dark reverb |
| notification | soft two-note bell chime (E6, A6) |
| diplomacy_notify | gentle harp arpeggio over a soft string pad (verdigris/positive) |
| event_pop | bubble pop with two high plucks |
| research_done | rising harp arpeggio (D F A D) with bell sparkle |
| war_declared | low brass horn swell (D2/A2/D3) with war drums |
| peace_bell | large D4 church-style bell, struck twice, long decay |
| victory | short brass fanfare, drums, cymbal-noise swell, bell |
| defeat | slow descending minor brass with low bell toll |
| turn_end | page-turn swish and paper crinkle |
| sword | blade swish into a metallic ring |

## Verified results (decoded files)
All 27 files: 44.1 kHz, no NaN, no clipping, peak between -3.2 and -4.2 dBFS, SFX 4-60 KB (limit 150 KB),
music 0.6-1.2 MB (limit 2.5 MB). Music is -16.0 to -16.2 LUFS.
