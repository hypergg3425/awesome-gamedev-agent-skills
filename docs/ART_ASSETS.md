# IMPERIUM — Art assets

All images below are **original** and **script-generated** (Python 3, Pillow + numpy; no third-party art, fonts,
photos, stock or AI-image sources). Style follows `docs/ART_DIRECTION.md`: layered silhouettes, etched hatching,
paper grain and vignettes in the project palette. No text is rendered into any image.

Regenerate everything: `python3 tools/assets/gen_art.py` (or groups: `parchment vignette menu loading events badges ui icons`).

Generator modules (`tools/assets/`): `gen_art.py` (entry), `art_kit.py` (canvas, hatching, noise, scenery, galleon,
crown, figures), `art_backgrounds.py`, `art_events.py`, `art_ui.py`.
`assets/icon.svg` is a hand-written SVG (embedded as a literal in `art_ui.py` and written on render).

## Backgrounds (`assets/backgrounds/`)
| file | size | notes |
|---|---|---|
| menu_bg.png | 1920x1080 | sea-chart with crown cartouche, galleons, compass rose; left third kept calm/dark for buttons |
| loading_1.png … loading_4.png | 1280x720 | castle on hill at dusk; galleons at sea; army column crossing a bridge; walled city with towers |
| parchment.png | 512x512 | seamless tileable paper texture |
| vignette.png | 1024x1024 | RGBA radial navy vignette (transparent centre) |

## Event illustrations (`assets/illustrations/`, 960x540)
ev_famine, ev_plague, ev_uprising, ev_court, ev_battle, ev_trade, ev_storm, ev_fire, ev_church, ev_diplomacy,
ev_science, ev_coronation, ev_harbor, ev_mine, ev_generic (`.png`).

## Achievement badges (`assets/illustrations/`, 256x256, transparent outside circle)
ach_first_conquest, ach_great_diplomat, ach_economic_powerhouse, ach_military_supremacy, ach_world_conqueror,
ach_peaceful_expansion, ach_technological_pioneer, ach_survived_against_all_odds (`.png`).

## UI (`assets/ui/`)
| file | size | notes |
|---|---|---|
| panel_frame.png | 192x192 | gold frame on transparent, 48 px corners, uniform edges (9-patch margins 48) |
| divider.png | 512x24 | ornamental gold divider, faded ends |
| ribbon.png | 384x96 | burgundy title ribbon, no text |
| crown.png | 256x256 | gold crown emblem on transparent |
| logo_mark.png | 512x512 | crown over crossed sword and quill in a laurel ring, gold on navy disc |

## Launcher / store (`assets/`)
icon.svg (512, navy + gold crown), icon_foreground.png (432, adaptive foreground, safe-zone padded),
icon_background.png (432, textured navy), icon_512.png (512 store icon), splash.png (1080, logo on navy),
store_feature_graphic.png (1024x500).
