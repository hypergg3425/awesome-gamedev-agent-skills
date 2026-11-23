"""Backgrounds: menu sea-chart, four loading dioramas, parchment tile, vignette."""
import math
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

from art_kit import *  # noqa: F401,F403
from art_kit import PAL, Art, ROOT, bez, birds, castle, cloud, crenel, crown, finish, fbm, galleon, hx, house, mix, norm, \
    oak, paper_grain, person, pine, rain, rgba, ridge, ridge_pts, save_png, sea, smoke, smoothstep, soldier, \
    spire_tower, stars, strata, vignette, laurel_branch, leaf

OUT_BG = ROOT / "assets" / "backgrounds"


# ------------------------------------------------------------------ parchment
def make_parchment(w, h, seed=7, tile=True, fibers=True):
    scale = 128 if tile else 320
    n = norm(fbm(w, h, seed, scale, 5, tile))
    n2 = norm(fbm(w, h, seed + 1, 32 if tile else 90, 4, tile))
    base = np.array(PAL["parchment"], np.float32)
    dk = np.array(PAL["parchment_dark"], np.float32)
    t = np.clip(0.30 + n * 0.16 + n2 * 0.07, 0, 1)[..., None]
    arr = base * (1 - t) + dk * t
    f = norm(fbm(w, h, seed + 2, 32 if tile else 70, 3, tile))
    spots = np.clip((f - 1.2) * 0.45, 0, 1)[..., None]
    arr = arr * (1 - spots * 0.5) + np.array(hx("a98650"), np.float32) * spots * 0.5
    if fibers:
        rnd = random.Random(seed)
        dark = Image.new("L", (w, h), 0)
        light = Image.new("L", (w, h), 0)
        dd, dl = ImageDraw.Draw(dark), ImageDraw.Draw(light)
        offs = [(-w, -h), (-w, 0), (-w, h), (0, -h), (0, 0), (0, h), (w, -h), (w, 0), (w, h)] if tile else [(0, 0)]
        for _ in range(int(w * h / 420)):
            x, y = rnd.uniform(0, w), rnd.uniform(0, h)
            a = rnd.uniform(0, math.pi * 2)
            ln = rnd.uniform(5, 22)
            pts = bez((x, y), (x + math.cos(a + 0.6) * ln * 0.5, y + math.sin(a + 0.6) * ln * 0.5),
                      (x + math.cos(a) * ln, y + math.sin(a) * ln), 4)
            target = dd if rnd.random() < 0.6 else dl
            val = rnd.randint(40, 130)
            for ox, oy in offs:
                target.line([(px + ox, py + oy) for px, py in pts], fill=val, width=1)
        d_ = np.asarray(dark.filter(ImageFilter.GaussianBlur(0.5)), np.float32)[..., None] / 255
        l_ = np.asarray(light.filter(ImageFilter.GaussianBlur(0.5)), np.float32)[..., None] / 255
        arr = arr * (1 - d_ * 0.22) + 255 * l_ * 0.12
    arr += np.random.default_rng(seed + 9).normal(0, 2.6, (h, w, 1)).astype(np.float32)
    return np.clip(arr, 0, 255)


def render_parchment():
    arr = make_parchment(512, 512, 11, True)
    save_png(Image.fromarray(arr.astype(np.uint8), "RGB"), OUT_BG / "parchment.png")


def render_vignette():
    n = 1024
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d = np.sqrt(((xx - n / 2 + 0.5) / (n / 2)) ** 2 + ((yy - n / 2 + 0.5) / (n / 2)) ** 2)
    a = smoothstep(0.38, 1.28, d) ** 1.15 * 0.94
    a += np.random.default_rng(3).normal(0, 0.006, (n, n))
    a = np.clip(a, 0, 1)
    arr = np.zeros((n, n, 4), np.uint8)
    arr[..., 0], arr[..., 1], arr[..., 2] = PAL["navy_deep"]
    arr[..., 3] = (a * 255).astype(np.uint8)
    save_png(Image.fromarray(arr, "RGBA"), OUT_BG / "vignette.png")


# ------------------------------------------------------------------ shared decorations
def compass_rose(art, cx, cy, r, ink, gold, red, parch):
    for ang0, rr, col in ((0, 1.0, ink), (math.pi / 4, 0.7, ink)):
        for i in range(4):
            a = ang0 + i * math.pi / 2 - math.pi / 2
            tip = (cx + math.cos(a) * r * rr, cy + math.sin(a) * r * rr)
            l = (cx + math.cos(a - 0.22) * r * 0.2, cy + math.sin(a - 0.22) * r * 0.2)
            rr_ = (cx + math.cos(a + 0.22) * r * 0.2, cy + math.sin(a + 0.22) * r * 0.2)
            c = (cx, cy)
            art.poly([tip, rr_, c], red if ang0 == 0 else gold, ink, 0.9)
            art.poly([tip, l, c], parch, ink, 0.9)
    for i in range(16):
        if i % 2 == 0 and i % 4 != 0:
            a = i * math.pi / 8
            art.line([(cx + math.cos(a) * r * 0.2, cy + math.sin(a) * r * 0.2),
                      (cx + math.cos(a) * r * 0.5, cy + math.sin(a) * r * 0.5)], ink, 1.0)
    art.circle(cx, cy, r * 0.62, None, ink, 1.0)
    art.circle(cx, cy, r * 0.7, None, ink, 0.8)
    art.circle(cx, cy, r * 0.075, gold, ink, 0.9)
    art.circle(cx, cy, r * 1.08, None, ink, 1.2)
    for i in range(72):
        a = i * math.pi / 36
        ln = r * (0.07 if i % 6 == 0 else 0.035)
        art.line([(cx + math.cos(a) * r * 1.08, cy + math.sin(a) * r * 1.08),
                  (cx + math.cos(a) * (r * 1.08 + ln), cy + math.sin(a) * (r * 1.08 + ln))], ink, 0.9)


def rays(art, cx, cy, r0, r1, n, color, alpha, seed=0, width=0.12):
    rnd = random.Random(seed)
    for i in range(n):
        a = i * 2 * math.pi / n + rnd.uniform(-0.02, 0.02)
        w = width * rnd.uniform(0.5, 1.3) * 2 * math.pi / n
        rr = r1 * rnd.uniform(0.7, 1.0)
        art.poly([(cx + math.cos(a - w) * r0, cy + math.sin(a - w) * r0), (cx + math.cos(a) * rr, cy + math.sin(a) * rr),
                  (cx + math.cos(a + w) * r0, cy + math.sin(a + w) * r0)], rgba(color, alpha))


def mountain_glyph(art, x, y, s, ink, parch):
    art.poly([(x - s, y), (x - s * 0.25, y - s * 1.1), (x + s * 0.2, y - s * 0.55), (x + s * 0.55, y - s * 0.9), (x + s * 1.05, y)],
             parch, ink, 0.9)
    art.hatch([(x + s * 0.2, y - s * 0.55), (x + s * 0.55, y - s * 0.9), (x + s * 1.05, y), (x - s * 0.1, y)], ink, 60, 1.6, 0.6, 150)


def tree_glyph(art, x, y, s, ink, fill):
    art.circle(x, y - s * 0.8, s * 0.6, fill, ink, 0.8)
    art.line([(x, y - s * 0.2), (x, y)], ink, 1.0)


# ------------------------------------------------------------------ menu background
def render_menu_bg():
    W, H = 1920, 1080
    rnd = random.Random(42)
    paper = make_parchment(W, H, 21, tile=False)
    # land field
    f = norm(fbm(W, H, 77, 520, 6))
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # open sea around crown cartouche and a channel across the middle
    crownx, crowny = 1290, 430
    hole = np.exp(-(((xx - crownx) / 330) ** 2 + ((yy - crowny) / 280) ** 2))
    chan = np.exp(-(((yy - (700 + 80 * np.sin(xx / 330))) / 90) ** 2)) * 0.9
    field = f * 0.55 + 0.25 * np.sin(xx / 410 + 1.0) * np.cos(yy / 330) - hole * 1.6 - chan * 0.8 + 0.12
    land = (field > 0.35).astype(np.float32)
    landL = Image.fromarray((land * 255).astype(np.uint8), "L")
    # remove tiny islands
    landL = landL.filter(ImageFilter.GaussianBlur(3)).point(lambda v: 255 if v > 150 else 0)
    L = np.asarray(landL, np.float32) / 255
    # ripple lines in sea
    arr = paper.copy()
    sea_tint = np.array(hx("6f8c8a"), np.float32)
    arr = arr * 0.62 + sea_tint * 0.38
    arr = arr * (1 - L[..., None] * 0.0)
    land_col = np.array(hx("f4ead0"), np.float32)
    arr = arr * (1 - L[..., None] * 0.7) + land_col * L[..., None] * 0.7
    ink = np.array(PAL["ink"], np.float32)
    navy = np.array(PAL["navy"], np.float32)
    ripples = np.zeros((H, W), np.float32)
    for i, sg in enumerate([4, 8, 13, 19, 26, 34, 43, 53, 64, 76]):
        B = np.asarray(landL.filter(ImageFilter.GaussianBlur(sg)), np.float32) / 255
        lvl = 0.5 - 0.22 * (1 - i / 8)
        line = np.clip(1 - np.abs(B - 0.30) / (0.04 + 0.0022 * sg), 0, 1)
        line *= (L < 0.5)
        ripples = np.maximum(ripples, line * (0.8 - i * 0.08))
    arr = arr * (1 - ripples[..., None] * 0.85) + navy * ripples[..., None] * 0.85
    # coast line
    Bc = np.asarray(landL.filter(ImageFilter.GaussianBlur(1.1)), np.float32) / 255
    coast = np.clip(1 - np.abs(Bc - 0.5) / 0.16, 0, 1)
    arr = arr * (1 - coast[..., None] * 0.9) + ink * coast[..., None] * 0.9
    # shaded sea side of coast: soft darkening just outside the coast
    near = np.asarray(landL.filter(ImageFilter.GaussianBlur(9)), np.float32) / 255
    arr = arr * (1 - (near * (1 - L))[..., None] * 0.30)
    # inland relief tint
    inland = np.asarray(landL.filter(ImageFilter.GaussianBlur(30)), np.float32) / 255
    rel = norm(fbm(W, H, 5, 90, 4)) * 0.04
    arr = arr * (1 + (rel * L)[..., None]) * (1 - (inland * L)[..., None] * 0.0)
    arr = np.clip(arr, 0, 255)
    base_img = Image.fromarray(arr.astype(np.uint8), "RGB").resize((W * 2, H * 2), Image.BICUBIC)
    art = Art(W, H, 2)
    art.im = base_img.convert("RGBA")

    # rhumb lines (faint)
    hubs = [(1290, 430, 0), (1650, 840, 0.1)]
    for hx_, hy_, ph in hubs:
        for i in range(32):
            a = i * math.pi / 16 + ph
            art.line([(hx_, hy_), (hx_ + math.cos(a) * 2600, hy_ + math.sin(a) * 2600)], PAL["ink"], 0.8, alpha=34)
    # mountain & tree glyphs on land interior
    inland_mask = np.asarray(landL.filter(ImageFilter.GaussianBlur(14)), np.float32) / 255
    glyphs = 0
    tries = 0
    while glyphs < 230 and tries < 6000:
        tries += 1
        x, y = rnd.uniform(40, W - 40), rnd.uniform(60, H - 40)
        if inland_mask[int(y), int(x)] < 0.92:
            continue
        if x < 560 and rnd.random() < 0.8:
            continue
        s = rnd.uniform(10, 22)
        if rnd.random() < 0.55:
            mountain_glyph(art, x, y, s, PAL["ink"], hx("efe6cc"))
        else:
            tree_glyph(art, x, y, s * 0.55, PAL["ink"], hx("c8c19b"))
        glyphs += 1
    # tiny town marks
    for _ in range(24):
        x, y = rnd.uniform(60, W - 60), rnd.uniform(80, H - 60)
        if inland_mask[int(y), int(x)] < 0.97 or x < 600:
            continue
        art.rect(x - 3, y - 3, x + 3, y + 3, PAL["burgundy"], PAL["ink"], 0.8)
        art.poly([(x - 4, y - 3), (x + 4, y - 3), (x, y - 8)], PAL["burgundy_light"], PAL["ink"], 0.8)

    # crown cartouche
    cx, cy = crownx, crowny
    art.glow(cx, cy, 420, hx("f2c36b"), 120, 2.2)
    rays(art, cx, cy, 175, 360, 36, PAL["gold"], 70, 3, 0.1)
    rays(art, cx, cy, 175, 270, 36, PAL["gold_light"], 90, 4, 0.06)
    art.circle(cx, cy, 190, rgba(PAL["navy"], 235))
    art.circle(cx, cy, 190, None, PAL["gold"], 4)
    art.circle(cx, cy, 176, None, PAL["gold_light"], 1.4)
    art.circle(cx, cy, 204, None, PAL["ink"], 1.6)
    for i in range(72):
        a = i * math.pi / 36
        r0, r1 = 190, 198 if i % 2 else 204
        art.line([(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * r1, cy + math.sin(a) * r1)], PAL["ink"], 1.0)
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        art.poly([(cx + math.cos(a - 0.06) * 176, cy + math.sin(a - 0.06) * 176), (cx + math.cos(a) * 150, cy + math.sin(a) * 150),
                  (cx + math.cos(a + 0.06) * 176, cy + math.sin(a + 0.06) * 176)], PAL["gold"])
    crown(art, cx, cy - 6, 230)
    # compass rose lower right
    compass_rose(art, 1650, 840, 120, PAL["ink"], PAL["gold"], PAL["burgundy_light"], hx("efe6cc"))
    # ships
    ships = [(1040, 640, 170, False), (1520, 330, 120, True), (900, 330, 90, False), (1700, 560, 100, False), (1180, 880, 140, True)]
    for sx, sy, ss_, fl in ships:
        art.ellipse(sx, sy + 4, ss_ * 0.55, ss_ * 0.035, rgba(PAL["navy"], 90))
        galleon(art, sx, sy, ss_, PAL["ink"], hx("f1e8cf"), PAL["gold"], PAL["ink"], flip=fl, flag=PAL["burgundy_light"], sail_hatch=PAL["ink"])
    # sea serpent-ish whirl marks / wave ticks
    for _ in range(150):
        x, y = rnd.uniform(560, W), rnd.uniform(60, H)
        ix, iy = int(min(W - 1, x)), int(min(H - 1, y))
        if inland_mask[iy, ix] > 0.1:
            continue
        art.line(bez((x, y), (x + 7, y - 5), (x + 14, y)), PAL["ink"], 0.9, alpha=90)
        art.line(bez((x + 14, y), (x + 21, y - 5), (x + 28, y)), PAL["ink"], 0.9, alpha=90)
    # neatline frame
    m = 26
    art.rect(m, m, W - m, H - m, None, PAL["ink"], 3)
    art.rect(m + 9, m + 9, W - m - 9, H - m - 9, None, PAL["ink"], 1.2)
    seg = 36
    for i in range(int((W - 2 * m - 18) / seg)):
        x0 = m + 9 + i * seg
        if i % 2 == 0:
            art.rect(x0, m + 3, x0 + seg, m + 9, PAL["ink"])
            art.rect(x0, H - m - 9, x0 + seg, H - m - 3, PAL["ink"])
    for i in range(int((H - 2 * m - 18) / seg)):
        y0 = m + 9 + i * seg
        if i % 2 == 0:
            art.rect(m + 3, y0, m + 9, y0 + seg, PAL["ink"])
            art.rect(W - m - 9, y0, W - m - 3, y0 + seg, PAL["ink"])

    # ---- lighting: warm candle glow, left calm navy shade, vignette
    art.glow(1380, 330, 1000, hx("f6c46a"), 85, 1.5)
    img = art.render().convert("RGB")
    a = np.asarray(img, np.float32)
    xs = np.linspace(0, 1, W, dtype=np.float32)[None, :, None]
    shade = (1 - smoothstep(0.0, 0.46, xs)) ** 1.1
    navy_deep = np.array(PAL["navy_deep"], np.float32)
    a = a * (1 - shade * 0.88) + navy_deep * shade * 0.88
    # bring down overall luminance of chart a touch for drama
    a = a * 0.97
    a = vignette(a, 0.6, 2.0, tint=np.array(hx('120d0a'), np.float32))
    a = paper_grain(a, 9, 0.035)
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    save_png(img, OUT_BG / "menu_bg.png", 1_450_000)


# ------------------------------------------------------------------ loading 1: castle at dusk
def mist(art, y, h, color, alpha, seed=0):
    def fn(t):
        rnd = random.Random(seed)
        x = -100
        while x < art.w + 100:
            w = rnd.uniform(160, 420)
            t.ellipse(x + w / 2, y + rnd.uniform(-h * 0.2, h * 0.2), w / 2, h / 2, rgba(color, alpha))
            x += w * 0.55
    art.blurred(fn, 14)


def loading_1():
    W, H = 1280, 720
    art = Art(W, H, 2)
    art.sky([(0, PAL["navy_deep"]), (0.3, PAL["navy"]), (0.55, hx("3b2347")), (0.72, PAL["burgundy"]),
             (0.86, PAL["ember"]), (1, PAL["gold_light"])], 0, 560, bands=11, seed=4, wob=0.03)
    stars(art, (0, 0, W, 200), 60, 3, PAL["gold_light"], 1.1)
    sx, sy = 790, 455
    art.glow(sx, sy, 380, PAL["gold_light"], 150, 2.0)
    art.circle(sx, sy, 46, PAL["gold_light"])
    art.circle(sx, sy, 46, None, PAL["gold"], 1.5)
    for r in (62, 80):
        art.circle(sx, sy, r, None, rgba(PAL["gold_light"], 70), 1.0)
    for i, (y, x0, x1, th, col, al) in enumerate([(300, 60, 520, 12, PAL["burgundy_light"], 190), (360, 600, 1220, 16, PAL["burgundy"], 200),
                                                  (410, 120, 640, 10, PAL["ember"], 170), (430, 900, 1280, 12, PAL["ember"], 150),
                                                  (230, 700, 1200, 10, hx("5a3558"), 180), (255, 80, 480, 9, hx("4a2d52"), 170)]):
        strata(art, y, x0, x1, th, col, al, i)
    birds(art, [(260, 280, 1.0), (300, 300, 0.8), (340, 270, 0.9), (1020, 330, 0.7), (1060, 345, 0.6)], PAL["navy_deep"], 7)
    # far ridges
    hz = hx("a05a46")
    ridge(art, 500, 26, 11, mix(hz, PAL["navy"], 0.30), rough=0.6)
    mist(art, 520, 40, hx("e0a46a"), 110, 1)
    ridge(art, 520, 32, 12, mix(hz, PAL["navy"], 0.55), rough=0.58)
    mist(art, 548, 40, hx("c07a56"), 90, 2)
    ridge(art, 545, 40, 13, mix(hz, PAL["navy"], 0.75), rough=0.55)
    # castle hill
    cx = 790
    pts = ridge_pts(art, 590, 14, 21, rough=0.5)
    pts2 = []
    for x, y in pts:
        bump = 190 * math.exp(-((x - cx) / 190) ** 2) + 38 * math.exp(-((x - cx + 80) / 330) ** 2)
        pts2.append((x, y - bump))
    hill_col = mix(PAL["navy_deep"], PAL["burgundy_dark"], 0.35)
    poly = pts2 + [(W + 10, H + 10), (-10, H + 10)]
    art.poly(poly, hill_col)
    art.hatch(poly, PAL["ink"], 72, 3.2, 0.9, 120)
    art.hatch([(x, y) for x, y in pts2 if x > cx] + [(W, 720), (cx, 720)], PAL["burgundy"], 20, 3.0, 0.8, 70)
    art.line(pts2, rgba(PAL["gold"], 150), 1.2)
    top_y = min(p[1] for p in pts2)
    castle(art, cx, top_y + 6, 250, mix(PAL["navy_deep"], PAL["burgundy_dark"], 0.5), mix(PAL["burgundy_dark"], PAL["navy_deep"], 0.5),
           PAL["gold_light"], PAL["burgundy_light"], ink=PAL["navy_deep"])
    # rim light on right side of castle
    art.glow(cx + 130, top_y + 30, 120, PAL["ember"], 60, 2)
    # winding road
    road = bez((cx - 4, top_y + 8), (cx - 140, top_y + 70), (cx - 40, top_y + 110), 18)[:-1] + \
           bez((cx - 40, top_y + 110), (cx + 120, top_y + 150), (cx - 150, top_y + 230), 18)[:-1] + \
           bez((cx - 150, top_y + 230), (cx - 260, top_y + 290), (cx - 300, H + 10), 18)
    left, right = [], []
    for i, (x, y) in enumerate(road):
        t = i / (len(road) - 1)
        w = 3 + 36 * t ** 1.3
        left.append((x - w, y))
        right.append((x + w, y))
    art.poly(left + right[::-1], rgba(mix(PAL["gold_dark"], PAL["burgundy"], 0.35), 215))
    art.line(left, rgba(PAL["gold_light"], 90), 1.0)
    # trees on the hill
    rr = random.Random(5)
    for i in range(26):
        x = rr.choice([rr.uniform(20, 560), rr.uniform(1000, 1260)])
        y = 640 + rr.uniform(-10, 70)
        pine(art, x, y, rr.uniform(34, 70), mix(PAL["navy_deep"], PAL["burgundy_dark"], 0.25))
    # foreground
    fg = ridge_pts(art, 668, 18, 31, rough=0.6)
    art.poly(fg + [(W + 10, H + 10), (-10, H + 10)], PAL["navy_deep"])
    for x in (60, 140, 1180, 1240, 1100, 20):
        pine(art, x, 690 + rr.uniform(-12, 12), rr.uniform(120, 200), PAL["ink"])
    # fence posts
    for i in range(9):
        x = 360 + i * 56
        art.rect(x, 690, x + 3, 710, PAL["ink"])
    art.line([(350, 695), (870, 695)], PAL["ink"], 1.6)
    art.line([(350, 703), (870, 703)], PAL["ink"], 1.2)
    img = finish(art, vig=0.5, grain=0.045, etch_k=0.22, seed=11, warm=0.0)
    save_png(img, OUT_BG / "loading_1.png", 1_300_000)


# ------------------------------------------------------------------ loading 2: galleons at sea
def loading_2():
    W, H = 1280, 720
    art = Art(W, H, 2)
    hz = 330
    art.sky([(0, PAL["steel_dark"]), (0.35, PAL["steel"]), (0.7, hx("d8c9a3")), (1, PAL["gold_light"])], 0, hz + 4, bands=10, seed=8, wob=0.014)
    sx = 880
    art.glow(sx, hz - 20, 420, PAL["gold_light"], 170, 2.0)
    art.circle(sx, hz - 40, 40, hx("fbf0c9"))
    art.circle(sx, hz - 40, 40, None, PAL["gold"], 1.3)
    cl = [(160, 140, 340, 38), (520, 90, 300, 30), (1010, 150, 380, 44), (760, 210, 260, 26), (300, 250, 240, 22)]
    for i, (x, y, w, h) in enumerate(cl):
        cloud(art, x, y, w, h, mix(PAL["parchment"], PAL["gold_light"], 0.3), mix(PAL["steel"], PAL["gold_dark"], 0.45), i)
        art.hatch([(x - w / 2, y + h * 0.1), (x + w / 2, y + h * 0.1), (x + w / 2, y + h * 0.9), (x - w / 2, y + h * 0.9)], PAL["steel_dark"], 8, 4, 0.7, 40)
    for i, (y, x0, x1, th, col, al) in enumerate([(70, 40, 500, 8, PAL["steel"], 150), (300, 100, 420, 6, PAL["parchment"], 150),
                                                  (310, 900, 1260, 7, PAL["parchment"], 140)]):
        strata(art, y, x0, x1, th, col, al, 40 + i)
    birds(art, [(560, 200, 1.0), (600, 222, 0.8), (520, 224, 0.7)], PAL["navy_deep"], 8)
    # sea
    sea(art, hz, H, hx("6e7f95"), PAL["navy"], PAL["gold_light"], PAL["navy_deep"], sun_x=sx, seed=3, rows=30, bands=8)
    art.line([(0, hz), (W, hz)], rgba(PAL["navy"], 200), 1.2)
    # far ships
    for x, y, s, fl in [(300, hz + 6, 46, False), (1130, hz + 4, 38, True), (210, hz + 14, 36, True), (640, hz + 3, 28, False)]:
        galleon(art, x, y, s, mix(PAL["navy_deep"], PAL["steel"], 0.35), mix(PAL["parchment"], PAL["steel"], 0.5), PAL["gold_dark"], mix(PAL["navy_deep"], PAL["steel"], 0.25), flip=fl)
    # mid ship
    galleon(art, 930, 468, 280, PAL["burgundy_dark"], hx("efe3c4"), PAL["gold"], PAL["ink"], flip=True, flag=PAL["burgundy_light"], heel=0.03, sail_hatch=PAL["ink"])
    # wake of mid
    for i in range(7):
        y = 472 + i * 5
        art.line(bez((760 - i * 8, y), (850, y + 4 - i), (1100 + i * 12, y)), PAL["parchment"], 1.1, alpha=130 - i * 14)
    # main foreground ship
    galleon(art, 420, 640, 560, PAL["ink"], hx("f2e9cf"), PAL["gold"], PAL["ink"], flip=False, flag=PAL["burgundy_light"], heel=-0.025, sail_hatch=PAL["ink"])
    art.ellipse(420, 646, 250, 12, rgba(PAL["navy_deep"], 120))
    for i in range(10):
        y = 640 + i * 7
        art.line(bez((100 - i * 14, y), (260, y + 8), (400, y)), PAL["parchment"], 1.4, alpha=150 - i * 12)
        art.line(bez((720, y), (800, y + 6), (900 + i * 10, y)), PAL["parchment"], 1.2, alpha=140 - i * 12)
    # foam
    rr = random.Random(9)
    for _ in range(60):
        x, y = rr.uniform(0, W), rr.uniform(hz + 120, H)
        art.line(bez((x, y), (x + 10, y - 4), (x + 22, y)), PAL["parchment"], 1.3, alpha=120)
    img = finish(art, vig=0.5, grain=0.045, etch_k=0.2, seed=12)
    save_png(img, OUT_BG / "loading_2.png", 1_300_000)


# ------------------------------------------------------------------ loading 3: army column on a bridge
def loading_3():
    W, H = 1280, 720
    art = Art(W, H, 2)
    hz = 430
    art.sky([(0, PAL["navy"]), (0.28, PAL["steel_dark"]), (0.6, hx("c9b896")), (1, PAL["gold_light"])], 0, hz + 30, bands=10, seed=14, wob=0.012)
    sx, sy = 330, 330
    art.glow(sx, sy, 460, PAL["gold_light"], 170, 2.0)
    art.circle(sx, sy, 36, hx("fbf0cc"))
    art.circle(sx, sy, 36, None, rgba(PAL["gold"], 160), 1.2)
    for i, (y, x0, x1, th, col, al) in enumerate([(120, 600, 1250, 10, PAL["steel"], 150), (200, 100, 700, 9, hx("c8a68a"), 160),
                                                  (270, 700, 1270, 10, hx("d4b17a"), 150), (360, 560, 1100, 7, hx("e0b96f"), 170)]):
        strata(art, y, x0, x1, th, col, al, 70 + i)
    cloud(art, 940, 215, 360, 34, hx("c9b39a"), PAL["steel_dark"], 5)
    cloud(art, 220, 150, 300, 28, hx("d2bd9c"), PAL["steel_dark"], 6)
    birds(art, [(480, 230, 1.0), (515, 248, 0.8), (445, 252, 0.7)], PAL["navy_deep"], 8)
    far = hx("93a0b5")
    ridge(art, 385, 55, 51, mix(far, PAL["gold_light"], 0.35), rough=0.62, bottom=hz + 80)
    mist(art, 425, 40, hx("e8d4a6"), 150, 3)
    ridge(art, 430, 44, 52, mix(far, PAL["navy"], 0.2), rough=0.6, bottom=hz + 100)
    mist(art, 462, 34, hx("d8c498"), 140, 4)
    ridge(art, 470, 34, 53, mix(far, PAL["navy"], 0.45), rough=0.55, bottom=hz + 130)
    rr = random.Random(7)
    for i in range(46):
        pine(art, rr.uniform(0, W), 492 + rr.uniform(-6, 18), rr.uniform(26, 54), mix(PAL["steel_dark"], PAL["navy"], 0.6))
    # distant watch-tower on the far bank
    spire_tower(art, 1130, 495, 22, 70, mix(PAL["steel_dark"], PAL["navy"], 0.5), PAL["burgundy_dark"], PAL["navy"], None, crenel=True)
    # river
    ry0 = 492
    art.sky([(0, hx("8d9aad")), (0.4, hx("55637b")), (1, PAL["navy"])], ry0, H, bands=7, seed=19, wob=0.01)
    art.glow(sx, ry0 + 40, 220, PAL["gold_light"], 90, 2)
    for i in range(40):
        y = ry0 + 6 + i * 6
        x = rr.uniform(-40, W)
        L = rr.uniform(50, 160)
        art.line([(x, y), (x + L, y)], PAL["gold_light"] if rr.random() < 0.5 else PAL["navy_deep"], 0.8 + i * 0.03, alpha=100)
    # bridge
    deck_y = 520
    ink = PAL["ink"]
    stone = mix(PAL["navy_deep"], PAL["parchment_dark"], 0.24)
    stone_hi = mix(PAL["navy"], PAL["parchment_dark"], 0.5)
    piers = [(110 + i * 210) for i in range(7)]
    art.rect(-10, deck_y, W + 10, deck_y + 100, stone, None)
    for i in range(6):
        ax = (piers[i] + piers[i + 1]) / 2
        aw, ah = 84, 80
        pts = [(ax - aw, deck_y + 100)]
        for j in range(25):
            t = math.pi * j / 24
            pts.append((ax - aw * math.cos(t), deck_y + 100 - ah * math.sin(t)))
        pts.append((ax + aw, deck_y + 100))
        art.poly(pts, rgba(hx("56647e")))
        art.glow(ax, deck_y + 85, 64, PAL["gold_light"], 90, 2)
        art.hatch(pts, ink, 60, 3, 0.7, 60)
        art.line(pts, ink, 2.2)
        # voussoir ring
        ring = [(ax - (aw + 10) * math.cos(math.pi * j / 24), deck_y + 100 - (ah + 10) * math.sin(math.pi * j / 24)) for j in range(25)]
        art.line(ring, mix(stone_hi, ink, 0.3), 2.0)
    for px in piers:
        art.poly([(px - 26, deck_y + 20), (px + 26, deck_y + 20), (px + 36, deck_y + 150), (px - 36, deck_y + 150)], stone, ink, 1.2)
        art.hatch([(px - 26, deck_y + 20), (px + 26, deck_y + 20), (px + 36, deck_y + 150), (px - 36, deck_y + 150)], ink, 80, 3.5, 0.8, 90)
        # cutwater highlight
        art.line([(px + 18, deck_y + 24), (px + 25, deck_y + 146)], stone_hi, 1.4, alpha=150)
    art.rect(-10, deck_y - 4, W + 10, deck_y + 18, stone_hi, ink, 1.4)
    art.rect(-10, deck_y - 34, W + 10, deck_y - 16, stone, ink, 1.2)
    for i in range(-1, 70):
        art.rect(i * 20, deck_y - 42, i * 20 + 11, deck_y - 34, stone, ink, 0.8)
    for r in range(4):
        y = deck_y + 30 + r * 22
        art.line([(0, y), (W, y)], ink, 0.8, alpha=70)
    for x in range(0, W, 46):
        art.line([(x + (x // 46 % 2) * 23, deck_y + 20), (x + (x // 46 % 2) * 23, deck_y + 36)], ink, 0.8, alpha=60)
    # water under arches foam
    for px in piers:
        for i in range(6):
            art.line(bez((px - 40 - i * 4, 655 + i * 5), (px, 660 + i * 5), (px + 40 + i * 4, 655 + i * 5)), PAL["parchment"], 1.1, alpha=120 - i * 15)
    # army column
    col = PAL["ink"]
    y_line = deck_y + 12
    n = 27
    for i in range(n):
        x = 30 + i * 49
        h = 62 + math.sin(i * 1.7) * 2.5
        lean = math.sin(i * 0.9) * 0.02 + 0.012
        soldier(art, x, y_line + (i % 2) * 5, h, col, True, True, lean=lean, banner=PAL["burgundy_light"] if i in (4, 13, 22) else None)
    for cx_ in (470, 1010):
        art.rect(cx_ - 54, y_line - 12, cx_ + 28, y_line - 4, col)
        art.line([(cx_ - 52, y_line - 8), (cx_ + 70, y_line - 22)], col, 9)
        art.circle(cx_ - 20, y_line - 2, 17, col)
        art.circle(cx_ - 20, y_line - 2, 17, None, PAL["gold_dark"], 1.4)
        art.circle(cx_ - 20, y_line - 2, 4.5, PAL["gold_dark"])
        for sp in range(8):
            a = sp * math.pi / 4
            art.line([(cx_ - 20, y_line - 2), (cx_ - 20 + math.cos(a) * 16, y_line - 2 + math.sin(a) * 16)], PAL["gold_dark"], 0.9)
    # banners
    for bx in (230, 700, 1160):
        art.line([(bx, y_line - 10), (bx, y_line - 175)], col, 2.2)
        pts = [(bx, y_line - 175), (bx + 70, y_line - 158), (bx + 52, y_line - 130), (bx + 66, y_line - 100), (bx, y_line - 112)]
        art.poly(pts, PAL["burgundy_light"], col, 1.2)
        art.hatch(pts, PAL["burgundy_dark"], 70, 2.6, 0.8, 150)
        art.circle(bx + 28, y_line - 138, 7, PAL["gold"], col, 0.8)
    # foreground rocks & reeds
    fg = ridge_pts(art, 700, 20, 61, rough=0.65)
    art.poly(fg + [(W + 10, H + 10), (-10, H + 10)], PAL["navy_deep"])
    for i in range(70):
        x = rr.choice([rr.uniform(0, 330), rr.uniform(940, 1280)])
        y = 712 + rr.uniform(-4, 8)
        h = rr.uniform(30, 90)
        art.line(bez((x, y), (x + rr.uniform(-6, 6), y - h * 0.6), (x + rr.uniform(-14, 14), y - h)), PAL["ink"], 1.5)
    img = finish(art, vig=0.5, grain=0.045, etch_k=0.2, seed=13)
    save_png(img, OUT_BG / "loading_3.png", 1_300_000)


# ------------------------------------------------------------------ loading 4: walled city with towers
def loading_4():
    W, H = 1280, 720
    art = Art(W, H, 2)
    hz = 330
    art.sky([(0, PAL["navy"]), (0.3, hx("3d3d63")), (0.55, PAL["burgundy_light"]), (0.78, hx("d9915a")), (1, PAL["gold_light"])], 0, hz + 80, bands=11, seed=23, wob=0.014)
    sx, sy = 640, 300
    art.glow(sx, sy, 600, PAL["gold_light"], 130, 2.0)
    # god-rays
    for i in range(18):
        a = math.radians(-170 + i * 10)
        w = 0.025
        art.poly([(sx, sy), (sx + math.cos(a - w) * 900, sy + math.sin(a - w) * 900), (sx + math.cos(a + w) * 900, sy + math.sin(a + w) * 900)], rgba(PAL["gold_light"], 26))
    for i, (y, x0, x1, th, col, al) in enumerate([(80, 80, 600, 9, hx("5c3f68"), 170), (140, 760, 1240, 10, hx("6d3a5a"), 160),
                                                  (210, 20, 440, 9, PAL["burgundy_light"], 150), (240, 800, 1270, 10, PAL["ember"], 140),
                                                  (180, 450, 900, 7, hx("8a4b5a"), 140)]):
        strata(art, y, x0, x1, th, col, al, 90 + i)
    birds(art, [(220, 190, 1.0), (260, 205, 0.8), (1010, 150, 0.9)], PAL["navy_deep"], 8)
    # distant hills
    hz_c = hx("b0705a")
    ridge(art, 330, 20, 71, mix(hz_c, PAL["navy"], 0.25), rough=0.58, bottom=420)
    mist(art, 352, 30, hx("e5a96a"), 120, 5)
    ridge(art, 360, 22, 72, mix(hz_c, PAL["navy"], 0.5), rough=0.56, bottom=440)
    # --- city (rows back to front)
    rr = random.Random(33)
    c_back = mix(hx("8d5c62"), PAL["navy"], 0.35)
    base_y = 470
    col_by_depth = lambda d: mix(c_back, PAL["navy_deep"], d)
    roofs = [PAL["burgundy"], PAL["burgundy_dark"], hx("4a2a38"), PAL["navy_mid"]]

    def row(y, d, x0, x1, hmin, hmax, wmin, wmax, lit_p):
        x = x0
        col = col_by_depth(d)
        while x < x1:
            w = rr.uniform(wmin, wmax)
            h = rr.uniform(hmin, hmax)
            house(art, x, y, w, h, col, mix(col, roofs[rr.randrange(4)], 0.5 - d * 0.2), lit=PAL["gold_light"] if rr.random() < lit_p else None)
            x += w * rr.uniform(0.8, 1.05)

    art.rect(0, 430, W, H, col_by_depth(0.7))
    row(base_y - 70, 0.15, 170, 1110, 16, 34, 20, 34, 0.1)
    # back towers
    for x, h, w in [(250, 110, 20), (400, 140, 24), (870, 150, 24), (1010, 120, 20)]:
        spire_tower(art, x, base_y - 70, w, h, col_by_depth(0.2), mix(col_by_depth(0.2), PAL["burgundy"], 0.5), PAL["navy_deep"], PAL["gold_light"], cone=1.7)
    row(base_y - 40, 0.35, 150, 1130, 22, 44, 22, 40, 0.18)
    # cathedral (no religious symbols)
    cx = 640
    cc = col_by_depth(0.45)
    art.rect(cx - 120, base_y - 40 - 90, cx + 120, base_y - 40, cc, PAL["navy_deep"], 0.8)
    for i in range(7):
        x = cx - 108 + i * 36
        art.poly([(x - 8, base_y - 40), (x - 8, base_y - 100), (x, base_y - 116), (x + 8, base_y - 100), (x + 8, base_y - 40)], mix(cc, PAL["gold_light"], 0.15))
    for sx_ in (cx - 80, cx + 80):
        art.rect(sx_ - 22, base_y - 40 - 190, sx_ + 22, base_y - 40, cc, PAL["navy_deep"], 0.8)
        art.poly([(sx_ - 26, base_y - 230), (sx_ + 26, base_y - 230), (sx_, base_y - 340)], mix(cc, PAL["burgundy"], 0.5), PAL["navy_deep"], 0.8)
        art.line([(sx_, base_y - 340), (sx_, base_y - 366)], PAL["navy_deep"], 1.5)
        art.circle(sx_, base_y - 370, 3, PAL["gold"])
        art.rect(sx_ - 6, base_y - 205, sx_ + 6, base_y - 165, mix(PAL["gold_light"], PAL["ember"], 0.3))
    art.poly([(cx - 40, base_y - 130), (cx + 40, base_y - 130), (cx, base_y - 270)], mix(cc, PAL["burgundy"], 0.5), PAL["navy_deep"], 0.8)
    art.circle(cx, base_y - 150, 14, PAL["gold_light"], PAL["navy_deep"], 1.0)
    row(base_y - 8, 0.55, 140, 1140, 24, 52, 24, 44, 0.22)
    # castle/palace to the right
    castle(art, 1030, base_y - 8, 150, col_by_depth(0.55), mix(col_by_depth(0.55), PAL["burgundy"], 0.4), PAL["gold_light"], PAL["burgundy_light"], ink=PAL["navy_deep"])
    row(base_y + 24, 0.62, 70, 1210, 14, 30, 22, 40, 0.15)
    # main wall + towers
    wall_col = col_by_depth(0.8)
    wall_top = base_y + 20
    art.rect(60, wall_top, 1220, wall_top + 78, wall_col, PAL["navy_deep"], 1.0)
    crenel(art, 60, 1220, wall_top, 8, wall_col, 8, PAL["navy_deep"])
    art.hatch([(60, wall_top), (1220, wall_top), (1220, wall_top + 78), (60, wall_top + 78)], PAL["navy_deep"], 80, 4, 0.9, 80)
    for tx in (60, 260, 470, 810, 1020, 1220):
        spire_tower(art, tx, wall_top + 78, 44, 130, wall_col, mix(wall_col, PAL["burgundy"], 0.5), PAL["navy_deep"], PAL["gold_light"], cone=1.1)
        art.line([(tx, wall_top - 52 - 48), (tx, wall_top - 52 - 74)], PAL["navy_deep"], 1.4)
        art.poly([(tx, wall_top - 52 - 74), (tx + 18, wall_top - 52 - 68), (tx, wall_top - 52 - 62)], PAL["burgundy_light"])
    # gatehouse
    gx = 640
    art.rect(gx - 66, wall_top - 40, gx + 66, wall_top + 78, mix(wall_col, PAL["ink"], 0.2), PAL["navy_deep"], 1.2)
    crenel(art, gx - 66, gx + 66, wall_top - 40, 9, mix(wall_col, PAL["ink"], 0.2), 9, PAL["navy_deep"])
    pts = [(gx - 30, wall_top + 78)] + [(gx - 30 * math.cos(math.pi * j / 20), wall_top + 24 - 30 * math.sin(math.pi * j / 20)) for j in range(21)] + [(gx + 30, wall_top + 78)]
    art.poly(pts, rgba(hx("f1a44f")), PAL["ink"], 1.6)
    art.glow(gx, wall_top + 40, 50, PAL["gold_light"], 160, 2)
    for i in range(5):
        art.line([(gx - 24 + i * 12, wall_top + 24), (gx - 24 + i * 12, wall_top + 78)], PAL["ink"], 1.6)
    # river & foreground fields
    art.sky([(0, hx("4d4a58")), (1, PAL["navy_deep"])], wall_top + 78, H, bands=6, seed=33, wob=0.02)
    # road
    road = [(gx - 28, wall_top + 78), (gx + 28, wall_top + 78), (gx + 160, H), (gx - 220, H)]
    art.poly(road, rgba(hx("a9855a"), 190))
    art.hatch(road, PAL["ink"], 85, 6, 0.8, 70)
    for i in range(8):
        t = i / 7
        y = wall_top + 100 + t * (H - wall_top - 110)
        h = 14 + t * 18
        person(art, gx - 40 + (i % 3) * 22 - t * 40 + 24, y, h, PAL["ink"], hat="cap" if i % 2 else "wide")
    # furrows
    for i in range(30):
        t = i / 29
        y = wall_top + 100 + t ** 1.5 * (H - wall_top - 100)
        art.line([(0, y), (gx - 150 - 60 * t, y + 4)], PAL["ink"], 1.0 + t, alpha=70)
        art.line([(gx + 140 + 90 * t, y), (W, y + 4)], PAL["ink"], 1.0 + t, alpha=70)
    for x, y, h in [(60, 700, 120), (120, 712, 160), (1210, 705, 150), (1140, 716, 120)]:
        pine(art, x, y, h, PAL["ink"])
    img = finish(art, vig=0.5, grain=0.045, etch_k=0.2, seed=14)
    save_png(img, OUT_BG / "loading_4.png", 1_300_000)
