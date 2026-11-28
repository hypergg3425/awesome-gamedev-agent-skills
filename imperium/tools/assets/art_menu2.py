"""IMPERIUM v2.0 main-menu artwork: 'Twilight Harbour' key illustration + tileable cloud layer.

Original, code-generated art (Pillow + numpy) in the shared engraving style. Outputs:
  assets/backgrounds/menu_twilight.png   1920x1080 key art (castle city on a cliff, galleons, dusk sky)
  assets/backgrounds/menu_clouds.png     1024x256 RGBA tileable cloud band used for the drifting parallax layer
"""
import math
import random

import numpy as np
from PIL import Image

from art_kit import (PAL, Art, bez, birds, castle, fbm, finish, galleon, hx, mix, norm, pine, rgba, ridge, ridge_pts, save_png,
                     sea, smoothstep, stars, strata, ROOT)
from art_backgrounds import mist

OUT = ROOT / "assets" / "backgrounds"


def render_twilight():
    W, H = 1920, 1080
    art = Art(W, H, 2)
    hz = 640
    art.sky([(0, PAL["navy_deep"]), (0.28, PAL["navy"]), (0.5, hx("3b2347")), (0.68, PAL["burgundy"]),
             (0.84, PAL["ember"]), (1, PAL["gold_light"])], 0, hz + 6, bands=12, seed=9, wob=0.03)
    stars(art, (0, 0, W, 330), 110, 7, PAL["gold_light"], 1.3)
    sx, sy = 930, hz - 40
    art.glow(sx, sy, 520, PAL["gold_light"], 150, 2.0)
    art.circle(sx, sy, 62, PAL["gold_light"])
    art.circle(sx, sy, 62, None, PAL["gold"], 2)
    for r in (84, 110):
        art.circle(sx, sy, r, None, rgba(PAL["gold_light"], 60), 1.2)
    for i, (y, x0, x1, th, col, al) in enumerate([(360, 700, 1400, 14, PAL["burgundy_light"], 180), (430, 900, 1800, 18, PAL["burgundy"], 190),
                                                  (500, 600, 1200, 12, PAL["ember"], 160), (470, 1450, 1920, 12, PAL["ember"], 140),
                                                  (270, 1000, 1700, 12, hx("5a3558"), 170), (300, 120, 700, 10, hx("4a2d52"), 150)]):
        strata(art, y, x0, x1, th, col, al, i)
    birds(art, [(980, 330, 1.2), (1030, 352, 0.9), (1090, 320, 1.0), (620, 420, 0.8)], PAL["navy_deep"], 8)
    hzc = hx("a05a46")
    ridge(art, hz - 40, 34, 14, mix(hzc, PAL["navy"], 0.32), rough=0.6)
    mist(art, hz - 20, 50, hx("e0a46a"), 110, 3)
    ridge(art, hz - 14, 40, 15, mix(hzc, PAL["navy"], 0.6), rough=0.56)
    # sea
    sea(art, hz, H, mix(PAL["burgundy"], PAL["gold"], 0.35), PAL["navy_deep"], hx("e6c876"), PAL["navy"], sun_x=sx, seed=12, rows=30)
    # cliff with a castle city on the right
    cx = 1560
    pts = ridge_pts(art, hz + 46, 10, 22, rough=0.5)
    pts2 = []
    for x, y in pts:
        if x < cx - 700:
            continue
        t = (x - (cx - 700)) / 700.0
        bump = 300 * math.exp(-((x - cx) / 250) ** 2) + 60 * float(smoothstep(0.0, 1.0, min(t, 1.0)))
        pts2.append((x, y - bump))
    hill = mix(PAL["navy_deep"], PAL["burgundy_dark"], 0.4)
    x0h = pts2[0][0]
    shore = [(x, hz + 52 + 230 * float(smoothstep(x0h, W, x))) for x in np.linspace(W + 10, x0h, 40)]
    poly = pts2 + shore
    art.poly(poly, hill)
    art.hatch(poly, PAL["ink"], 72, 3.4, 0.9, 120)
    art.line(pts2, rgba(PAL["gold"], 160), 1.4)
    top_y = min(p[1] for p in pts2 if p[0] > cx - 100)
    castle(art, cx, top_y + 6, 330, mix(PAL["navy_deep"], PAL["burgundy_dark"], 0.55), mix(PAL["burgundy_dark"], PAL["navy_deep"], 0.5),
           PAL["gold_light"], PAL["burgundy_light"], ink=PAL["navy_deep"])
    art.glow(cx - 90, top_y + 30, 160, PAL["ember"], 70, 2)
    rnd = random.Random(31)
    for i in range(9):  # lit town houses on the slope
        x = cx - 330 + i * 52 + rnd.uniform(-8, 8)
        y = top_y + 150 + 22 * math.sin(i * 0.9) + rnd.uniform(0, 30)
        w = rnd.uniform(24, 38)
        art.rect(x, y - 26, x + w, y, mix(PAL["navy_deep"], PAL["burgundy_dark"], 0.3), PAL["ink"], 0.8)
        art.poly([(x - 2, y - 26), (x + w + 2, y - 26), (x + w / 2, y - 42)], PAL["burgundy_dark"], PAL["ink"], 0.8)
        art.rect(x + w * 0.35, y - 16, x + w * 0.62, y - 8, PAL["gold_light"])
    # galleons on the water
    for gx, gy, gs, fl, hl in [(1010, 770, 170, False, 0.05), (640, 830, 250, True, -0.04), (1330, 980, 190, False, 0.03)]:
        galleon(art, gx, gy, gs, mix(PAL["navy_deep"], PAL["burgundy_dark"], 0.5), hx("e8dcc0"), PAL["gold"], PAL["ink"], flip=fl,
                flag=PAL["burgundy_light"], heel=hl, sail_hatch=PAL["steel_dark"])
    # dark foreground rocks and pines at the left (text side)
    fg = ridge_pts(art, 960, 30, 33, rough=0.62, n=96)
    fg = [(x, y - 190 * float(smoothstep(820, 0, x))) for x, y in fg if x < 900]
    art.poly(fg + [(900, H + 10), (-10, H + 10)], PAL["navy_deep"])
    art.hatch(fg + [(900, H + 10), (-10, H + 10)], PAL["ink"], 60, 4, 0.9, 90)
    rr = random.Random(5)
    for x in (40, 110, 190, 270, 70, 150):
        pine(art, x, 860 + rr.uniform(-30, 50), rr.uniform(190, 300), PAL["ink"])
    img = finish(art, vig=0.55, grain=0.04, etch_k=0.2, seed=17)
    save_png(img, OUT / "menu_twilight.png", 1_500_000)


def render_clouds():
    W, H = 1024, 256
    f = fbm(W, H, 5, 96, 5, tile=True)
    g = fbm(W, H, 9, 40, 4, tile=True)
    d = norm(f) * 0.8 + norm(g) * 0.3
    yy = np.linspace(-1, 1, H, dtype=np.float32)[:, None]
    mask = np.clip((d - 0.15) * 0.9, 0, 1) * np.exp(-(yy ** 2) * 1.8)
    mask = smoothstep(0.05, 0.75, mask)
    a = (mask * 150).astype(np.uint8)
    rgb = np.zeros((H, W, 3), np.uint8)
    warm = np.array(hx("f0d9b0"), np.float32)
    cool = np.array(hx("8d86a8"), np.float32)
    t = np.clip(0.5 + 0.5 * norm(g), 0, 1)[..., None]
    rgb[:] = (cool * (1 - t) + warm * t).astype(np.uint8)
    img = Image.fromarray(np.dstack([rgb, a]), "RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / "menu_clouds.png", optimize=True)
    print("  wrote assets/backgrounds/menu_clouds.png")


if __name__ == "__main__":
    render_twilight()
    render_clouds()
