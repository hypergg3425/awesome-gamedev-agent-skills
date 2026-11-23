"""Achievement badges, UI ornaments and launcher/store assets."""
import math
import random

import numpy as np
from PIL import Image

from art_kit import (PAL, Art, ROOT, bez, crown, fbm, finish, flame, galleon, gold_fill, hx, laurel_branch, leaf, mix, norm,
                     paper_grain, quill, rgba, rot, save_png, smoothstep, sword, vignette, strata)
from art_backgrounds import rays

INK = PAL["ink"]
GOLD, GOLD_L, GOLD_D = PAL["gold"], PAL["gold_light"], PAL["gold_dark"]
ILL = ROOT / "assets" / "illustrations"
UI = ROOT / "assets" / "ui"
ASSETS = ROOT / "assets"


def radial_disc(a, cx, cy, r, c_in, c_out, steps=40):
    for i in range(steps):
        t = i / (steps - 1)
        a.circle(cx, cy, r * (1 - t), mix(c_out, c_in, t))


def beads(a, cx, cy, R, n, r, color, outline=INK):
    for i in range(n):
        t = 2 * math.pi * i / n
        a.circle(cx + math.cos(t) * R, cy + math.sin(t) * R, r, color, outline, 0.5)


def ring_gold(a, cx, cy, R, w, hi=True):
    a.circle(cx, cy, R + w / 2 + 1, None, INK, 1.2)
    a.circle(cx, cy, R, None, GOLD, w)
    if hi:
        a.circle(cx, cy, R + w * 0.2, None, rgba(GOLD_L, 200), max(0.8, w * 0.28))
        a.circle(cx, cy, R - w * 0.3, None, rgba(GOLD_D, 200), max(0.8, w * 0.2))
    a.circle(cx, cy, R - w / 2 - 0.5, None, INK, 1.0)


# ------------------------------------------------------------------ badge emblems (centre 128,122)
def em_first_conquest(a):
    cx, cy = 128, 126
    gold_fill(a, [(cx - 34, cy + 44), (cx - 34, cy - 30), (cx + 34, cy - 30), (cx + 34, cy + 44)], INK, 1.8)
    for i in range(4):
        x = cx - 38 + i * 25
        gold_fill(a, [(x, cy - 30), (x, cy - 46), (x + 14, cy - 46), (x + 14, cy - 30)], INK, 1.5)
    a.poly([(cx - 12, cy + 44), (cx - 12, cy + 18), (cx, cy + 8), (cx + 12, cy + 18), (cx + 12, cy + 44)], PAL["navy_deep"], INK, 1.5)
    for wx in (-18, 18):
        a.poly([(cx + wx - 4, cy - 6), (cx + wx - 4, cy - 18), (cx + wx, cy - 22), (cx + wx + 4, cy - 18), (cx + wx + 4, cy - 6)], PAL["burgundy_dark"], INK, 1.2)
    a.line([(cx, cy - 46), (cx, cy - 92)], INK, 4)
    a.line([(cx, cy - 46), (cx, cy - 92)], GOLD_L, 2)
    a.poly([(cx + 1, cy - 92), (cx + 44, cy - 80), (cx + 30, cy - 70), (cx + 44, cy - 58), (cx + 1, cy - 62)], PAL["burgundy_light"], GOLD_L, 1.6)
    a.circle(cx, cy - 93, 3.5, GOLD_L, INK, 1)
    a.hatch([(cx, cy - 30), (cx + 34, cy - 30), (cx + 34, cy + 44), (cx, cy + 44)], GOLD_D, 70, 2.2, 0.8, 120)


def em_great_diplomat(a):
    cx, cy = 128, 126
    body = [(cx - 52, cy - 22), (cx + 52, cy - 22), (cx + 52, cy + 22), (cx - 52, cy + 22)]
    a.fill_grad(body, hx("f4ead0"), hx("cdbf9c"), outline=INK, ow=1.8)
    for i in range(5):
        a.line([(cx - 40, cy - 12 + i * 6), (cx + 40 - (i % 2) * 18, cy - 12 + i * 6)], INK, 1.0, alpha=150)
    for sx in (-1, 1):
        x = cx + sx * 54
        a.ellipse(x, cy, 9, 28, None)
        a.fill_grad([(x - 9, cy - 28), (x + 9, cy - 28), (x + 9, cy + 28), (x - 9, cy + 28)], GOLD_L, GOLD_D, horizontal=True, outline=INK, ow=1.8)
        a.ellipse(x, cy - 28, 9, 4, GOLD_L, INK, 1.2)
        a.ellipse(x, cy + 28, 9, 4, GOLD_D, INK, 1.2)
    a.poly([(cx - 8, cy + 20), (cx - 20, cy + 52), (cx - 8, cy + 46), (cx, cy + 54)], PAL["burgundy_light"], INK, 1.4)
    a.poly([(cx + 8, cy + 20), (cx + 20, cy + 52), (cx + 8, cy + 46), (cx, cy + 54)], PAL["burgundy"], INK, 1.4)
    a.circle(cx, cy + 14, 17, PAL["burgundy_light"], INK, 1.8)
    a.circle(cx, cy + 14, 11, None, PAL["burgundy_dark"], 1.4)
    a.circle(cx, cy + 14, 4, GOLD_L)
    # olive sprig above
    for sgn in (-1, 1):
        for i in range(4):
            leaf(a, cx + sgn * (10 + i * 12), cy - 38 - (3 - i) * 3, -math.pi / 2 + sgn * (0.6 + i * 0.12) * -1 + math.pi / 2 * 0 + (math.pi if sgn < 0 else 0) * 0, 22, 6, mix(PAL["verdigris"], GOLD_L, 0.3), INK, 0.8)


def em_economic(a):
    cx, cy = 128, 138

    def stack(x, n, w, base):
        for i in range(n):
            y = base - i * 9
            a.ellipse(x, y + 5, w, w * 0.32, GOLD_D, INK, 1.0)
            a.rect(x - w, y - 4, x + w, y + 5, GOLD, None)
            a.ellipse(x, y - 4, w, w * 0.32, GOLD_L, INK, 1.0)
            a.line([(x - w, y - 4), (x - w, y + 5)], INK, 1.0)
            a.line([(x + w, y - 4), (x + w, y + 5)], INK, 1.0)
            a.line([(x - w + 3, y + 1), (x + w - 3, y + 3)], GOLD_D, 0.8, alpha=180)
    stack(86, 4, 24, cy + 36)
    stack(170, 5, 24, cy + 36)
    stack(128, 7, 28, cy + 42)
    a.ellipse(128, cy - 28 - 8, 22, 22 * 0.9, None)
    a.circle(128, cy - 56, 22, GOLD_L, INK, 1.8)
    a.circle(128, cy - 56, 15, None, GOLD_D, 1.4)
    a.poly([(128, cy - 66), (133, cy - 56), (128, cy - 46), (123, cy - 56)], GOLD_D, INK, 0.8)
    a.glow(128, cy - 56, 40, GOLD_L, 90, 2)


def em_military(a):
    cx, cy = 128, 126
    for ang in (-math.radians(52), -math.radians(128)):
        sword(a, cx + math.cos(ang) * 150 * 0.13, cy + 4 + math.sin(ang) * 150 * 0.13, 150, ang)
    sh = [(cx - 32, cy - 36), (cx + 32, cy - 36), (cx + 32, cy + 8)] + bez((cx + 32, cy + 8), (cx + 30, cy + 40), (cx, cy + 58), 12)[1:] + \
        bez((cx, cy + 58), (cx - 30, cy + 40), (cx - 32, cy + 8), 12)[1:]
    a.fill_grad(sh, PAL["burgundy_light"], PAL["burgundy_dark"], outline=INK, ow=2.2)
    a.line(sh + [sh[0]], GOLD, 3.2)
    a.line(sh + [sh[0]], INK, 1.0)
    a.line([(cx, cy - 34), (cx, cy + 56)], GOLD, 5)
    a.line([(cx - 31, cy - 8), (cx + 31, cy - 8)], GOLD, 5)
    a.circle(cx, cy - 8, 8, GOLD_L, INK, 1.2)


def em_world(a):
    cx, cy = 128, 150
    r = 42
    a.circle(cx, cy, r + 3, INK)
    radial_disc(a, cx - 10, cy - 10, r, hx("e6c876"), hx("8f7230"))
    for k in (-0.5, 0, 0.5):
        a.ellipse(cx, cy, r * abs(math.cos(k * math.pi / 2)) + 0.1, r, None, GOLD_D, 1.0)
    for yy in (-0.5, 0, 0.5):
        y = cy + yy * r
        hw = math.sqrt(max(0, 1 - yy * yy)) * r
        a.line([(cx - hw, y), (cx + hw, y)], GOLD_D, 1.0)
    rnd = random.Random(4)
    for pts in [[(-30, -20), (-10, -34), (6, -22), (-4, -4), (-22, 4), (-36, -6)], [(8, 4), (30, -6), (38, 16), (22, 36), (10, 22)]]:
        a.poly([(cx + x, cy + y) for x, y in pts], rgba(PAL["verdigris_dark"], 220), INK, 0.8)
    a.circle(cx, cy, r, None, INK, 1.8)
    a.line([(cx, cy + r), (cx, cy + r + 8)], INK, 4)
    a.rect(cx - 20, cy + r + 6, cx + 20, cy + r + 13, GOLD, INK, 1.4)
    crown(a, cx, cy - r - 16, 62)


def em_peaceful(a):
    cx, cy = 128, 126
    body = [(cx - 40, cy + 14)] + bez((cx - 40, cy + 14), (cx - 20, cy - 10), (cx + 20, cy - 2), 12)[1:] + \
        bez((cx + 20, cy - 2), (cx + 44, cy - 6), (cx + 44, cy - 24), 8)[1:] + [(cx + 36, cy - 28)] + \
        bez((cx + 36, cy - 28), (cx + 20, cy - 24), (cx + 14, cy + 4), 8)[1:] + \
        bez((cx + 14, cy + 4), (cx - 10, cy + 40), (cx - 40, cy + 14), 12)[1:]
    wing = [(cx - 6, cy - 4)] + bez((cx - 6, cy - 4), (cx - 24, cy - 58), (cx + 12, cy - 70), 12)[1:] + \
        bez((cx + 12, cy - 70), (cx + 10, cy - 36), (cx + 22, cy - 6), 10)[1:]
    wing2 = [(cx - 14, cy - 2)] + bez((cx - 14, cy - 2), (cx - 52, cy - 38), (cx - 40, cy - 56), 10)[1:] + \
        bez((cx - 40, cy - 56), (cx - 22, cy - 40), (cx + 4, cy - 4), 10)[1:]
    a.poly(wing2, mix(hx("cdbf9c"), PAL["steel"], 0.2), INK, 1.4)
    a.fill_grad(body, hx("f6ecd2"), hx("c9bb98"), outline=INK, ow=1.8)
    a.fill_grad(wing, hx("f6ecd2"), hx("bfb08c"), outline=INK, ow=1.8)
    for i in range(5):
        a.line([(cx + 4 + i * 4, cy - 30 - i * 5), (cx + 8 + i * 3, cy - 4)], INK, 0.8, alpha=140)
    a.circle(cx + 34, cy - 20, 1.8, INK)
    a.poly([(cx + 43, cy - 20), (cx + 54, cy - 16), (cx + 43, cy - 14)], GOLD, INK, 1)
    a.poly([(cx - 40, cy + 14), (cx - 62, cy + 30), (cx - 46, cy + 6)], hx("cdbf9c"), INK, 1.2)
    # olive twig in beak
    a.line(bez((cx + 52, cy - 16), (cx + 66, cy - 6), (cx + 54, cy + 14), 12), PAL["verdigris_dark"], 2.2)
    for i in range(4):
        t = i / 3
        px, py = cx + 60 - 6 * math.sin(t * 3), cy - 6 + t * 18
        leaf(a, px, py, -0.5 + i * 0.3, 14, 4, PAL["verdigris"], INK, 0.7)
        leaf(a, px, py, 2.4 - i * 0.2, 14, 4, PAL["verdigris"], INK, 0.7)
    a.glow(cx, cy - 10, 70, GOLD_L, 60, 2)


def em_tech(a):
    cx, cy = 128, 124
    n = 12
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        for dt, rr in ((-0.17, 52), (-0.1, 66), (0.1, 66), (0.17, 52)):
            pts.append((cx + math.cos(t + dt) * rr, cy + math.sin(t + dt) * rr))
    gold_fill(a, pts, INK, 2)
    a.circle(cx, cy, 36, PAL["navy_deep"], INK, 2)
    a.circle(cx, cy, 36, None, GOLD_D, 1.4)
    star = []
    for i in range(16):
        t = i * math.pi / 8 - math.pi / 2
        rr = 32 if i % 4 == 0 else (22 if i % 2 == 0 else 10)
        star.append((cx + math.cos(t) * rr, cy + math.sin(t) * rr))
    gold_fill(a, star, INK, 1.2)
    a.circle(cx, cy, 5, PAL["burgundy_light"], INK, 1)
    for i in range(n):
        t = 2 * math.pi * i / n + math.pi / n
        a.circle(cx + math.cos(t) * 46, cy + math.sin(t) * 46, 2.2, GOLD_D)
    a.glow(cx, cy, 80, GOLD_L, 50, 2)


def em_survived(a):
    cx, cy = 128, 130
    a.glow(cx, cy, 90, PAL["ember"], 120, 2)
    flame(a, cx, cy + 30, 130, 52, phase=0.8)
    flame(a, cx - 42, cy + 34, 80, 26, phase=2.0)
    flame(a, cx + 42, cy + 34, 80, 26, phase=3.6)
    sh = [(cx - 36, cy - 34), (cx + 36, cy - 34), (cx + 36, cy + 6)] + bez((cx + 36, cy + 6), (cx + 34, cy + 40), (cx, cy + 58), 12)[1:] + \
        bez((cx, cy + 58), (cx - 34, cy + 40), (cx - 36, cy + 6), 12)[1:]
    gold_fill(a, sh, INK, 2.4)
    inner = [(cx - 28, cy - 27), (cx + 28, cy - 27), (cx + 28, cy + 4)] + bez((cx + 28, cy + 4), (cx + 26, cy + 33), (cx, cy + 49), 12)[1:] + \
        bez((cx, cy + 49), (cx - 26, cy + 33), (cx - 28, cy + 4), 12)[1:]
    a.fill_grad(inner, PAL["navy_mid"], PAL["navy_deep"], outline=INK, ow=1.4)
    crack = [(cx + 6, cy - 27), (cx - 4, cy - 12), (cx + 8, cy - 2), (cx - 6, cy + 14), (cx + 2, cy + 26), (cx - 2, cy + 48)]
    a.line(crack, INK, 5)
    a.line(crack, GOLD_L, 2)
    a.line([(cx - 4, cy - 12), (cx - 20, cy - 8)], GOLD_L, 1.4)
    a.line([(cx + 8, cy - 2), (cx + 22, cy + 4)], GOLD_L, 1.4)
    # small rising star
    a.poly([(cx, cy - 52), (cx + 3, cy - 44), (cx + 11, cy - 44), (cx + 5, cy - 39), (cx + 7, cy - 31), (cx, cy - 36), (cx - 7, cy - 31),
            (cx - 5, cy - 39), (cx - 11, cy - 44), (cx - 3, cy - 44)], GOLD_L, INK, 1)


BADGES = {
    "first_conquest": (em_first_conquest, "burgundy"),
    "great_diplomat": (em_great_diplomat, "navy"),
    "economic_powerhouse": (em_economic, "navy"),
    "military_supremacy": (em_military, "burgundy"),
    "world_conqueror": (em_world, "navy"),
    "peaceful_expansion": (em_peaceful, "navy"),
    "technological_pioneer": (em_tech, "navy"),
    "survived_against_all_odds": (em_survived, "burgundy"),
}


def badge(emblem, field):
    a = Art(256, 256, 3)
    cx, cy = 128, 128
    a.circle(cx, cy + 3, 126, rgba((0, 0, 0), 70))
    # outer ring
    a.circle(cx, cy, 124, INK)
    a.circle(cx, cy, 122, GOLD_D)
    a.circle(cx, cy, 120, GOLD)
    a.circle(cx, cy, 116, GOLD_L)
    a.circle(cx, cy, 114, GOLD)
    a.circle(cx, cy, 113, None, INK, 1.0)
    beads(a, cx, cy, 107, 56, 2.0, GOLD_L)
    a.circle(cx, cy, 101, None, GOLD_D, 2.2)
    a.circle(cx, cy, 99, INK)
    dark, light = (PAL["burgundy_dark"], PAL["burgundy_light"]) if field == "burgundy" else (PAL["navy_deep"], PAL["navy_mid"])
    radial_disc(a, cx, cy - 8, 97, light, dark)
    rays(a, cx, cy - 8, 8, 96, 28, GOLD_L, 22, 3, 0.1)
    # clip rays outside the field: redraw ring over the edge
    a.circle(cx, cy, 108, None, GOLD, 17)
    a.circle(cx, cy, 99, None, INK, 1.2)
    beads(a, cx, cy, 107, 56, 2.0, GOLD_L)
    a.circle(cx, cy, 101, None, GOLD_D, 2.2)
    a.circle(cx, cy, 120, None, GOLD, 3)
    a.circle(cx, cy, 124, None, INK, 1.2)
    a.circle(cx, cy, 113.5, None, INK, 1.0)
    # laurels
    laurel_branch(a, cx, cy, 86, math.pi / 2 + 0.22, math.pi * 1.0 + 0.55, 19, 7, GOLD_L, GOLD, INK, 1)
    laurel_branch(a, cx, cy, 86, math.pi / 2 - 0.22, -0.55, 19, 7, GOLD_L, GOLD, INK, 1)
    emblem(a)
    # inner vignette
    img = a.render()
    arr = np.asarray(img, np.float32).copy()
    yy, xx = np.mgrid[0:256, 0:256].astype(np.float32)
    d = np.sqrt((xx - 127.5) ** 2 + (yy - 127.5) ** 2)
    shade = smoothstep(70, 100, d) * (d < 100) * 0.35
    arr[..., :3] *= (1 - shade[..., None])
    mask = (d <= 124.5)
    # paper grain
    g = np.random.default_rng(2).normal(0, 0.03, (256, 256))
    arr[..., :3] *= (1 + g[..., None])
    arr[..., 3] = arr[..., 3] * mask
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def render_badges():
    for key, (fn, field) in BADGES.items():
        save_png(badge(fn, field), ILL / f"ach_{key}.png")


# ------------------------------------------------------------------ UI
def corner_tile(ss=4):
    t = Art(48, 48, ss)
    # edge lines running off the tile (match the plain edges)
    t.line([(5, 5), (48, 5)], INK, 5.4)
    t.line([(5, 5), (5, 48)], INK, 5.4)
    t.line([(5, 5), (48, 5)], GOLD, 3)
    t.line([(5, 5), (5, 48)], GOLD, 3)
    t.line([(5, 3.8), (48, 3.8)], GOLD_L, 0.9)
    t.line([(3.8, 5), (3.8, 48)], GOLD_L, 0.9)
    t.line([(12, 12), (48, 12)], INK, 2.4)
    t.line([(12, 12), (12, 48)], INK, 2.4)
    t.line([(12, 12), (48, 12)], GOLD_D, 1.4)
    t.line([(12, 12), (12, 48)], GOLD_D, 1.4)
    # corner block (quarter bracket)
    blk = [(2, 2), (26, 2), (26, 8), (14, 8), (8, 14), (8, 26), (2, 26)]
    gold_fill(t, blk, INK, 1.2)
    # diamond
    d = [(20, 12), (28, 20), (20, 28), (12, 20)]
    gold_fill(t, d, INK, 1.2)
    t.poly([(20, 15.5), (24.5, 20), (20, 24.5), (15.5, 20)], PAL["burgundy_light"], INK, 0.8)
    t.circle(19, 19, 1.2, rgba((255, 255, 255), 200))
    # curls
    for sgn in (0, 1):
        pts = bez((30, 12), (40, 22), (34, 32), 12) if sgn == 0 else bez((12, 30), (22, 40), (32, 34), 12)
        t.line(pts, INK, 3.2)
        t.line(pts, GOLD, 1.8)
    t.circle(34, 31, 2.6, GOLD_L, INK, 0.8)
    t.circle(31, 34, 2.6, GOLD_L, INK, 0.8)
    t.circle(41, 12, 2.2, GOLD_L, INK, 0.7)
    t.circle(12, 41, 2.2, GOLD_L, INK, 0.7)
    return t.render()


def render_panel_frame():
    ss = 4
    a = Art(192, 192, ss)
    for (p0, p1) in [((5, 5), (187, 5)), ((5, 187), (187, 187)), ((5, 5), (5, 187)), ((187, 5), (187, 187))]:
        a.line([p0, p1], INK, 5.4)
    for (p0, p1) in [((5, 5), (187, 5)), ((5, 187), (187, 187)), ((5, 5), (5, 187)), ((187, 5), (187, 187))]:
        a.line([p0, p1], GOLD, 3)
    for (p0, p1) in [((5, 3.8), (187, 3.8)), ((5, 188.2), (187, 188.2)), ((3.8, 5), (3.8, 187)), ((188.2, 5), (188.2, 187))]:
        a.line([p0, p1], GOLD_L, 0.9)
    for (p0, p1) in [((12, 12), (180, 12)), ((12, 180), (180, 180)), ((12, 12), (12, 180)), ((180, 12), (180, 180))]:
        a.line([p0, p1], INK, 2.4)
        a.line([p0, p1], GOLD_D, 1.4)
    img = a.render()
    tile = corner_tile(ss)
    img.alpha_composite(tile, (0, 0))
    img.alpha_composite(tile.transpose(Image.FLIP_LEFT_RIGHT), (144, 0))
    img.alpha_composite(tile.transpose(Image.FLIP_TOP_BOTTOM), (0, 144))
    img.alpha_composite(tile.transpose(Image.ROTATE_180), (144, 144))
    save_png(img, UI / "panel_frame.png")


def render_divider():
    W, H = 512, 24
    a = Art(W, H, 4)
    cx, cy = 256, 12
    for sgn in (-1, 1):
        # tapered line
        a.poly([(cx + sgn * 46, cy - 1.6), (cx + sgn * 250, cy - 0.3), (cx + sgn * 250, cy + 0.3), (cx + sgn * 46, cy + 1.6)], GOLD)
        a.line([(cx + sgn * 46, cy), (cx + sgn * 250, cy)], GOLD_L, 0.5)
        for i, x in enumerate(range(70, 220, 30)):
            r = 2.2 - i * 0.28
            a.circle(cx + sgn * x, cy, max(0.8, r), GOLD, INK, 0.5)
        # scroll curl
        c1 = bez((cx + sgn * 44, cy), (cx + sgn * 34, cy - 12), (cx + sgn * 24, cy - 4), 14)
        c2 = bez((cx + sgn * 44, cy), (cx + sgn * 34, cy + 12), (cx + sgn * 24, cy + 4), 14)
        for c in (c1, c2):
            a.line(c, INK, 3.0)
            a.line(c, GOLD, 1.8)
        a.circle(cx + sgn * 26, cy - 3.5, 2.2, GOLD_L, INK, 0.6)
        a.circle(cx + sgn * 26, cy + 3.5, 2.2, GOLD_L, INK, 0.6)
    gold_fill(a, [(cx, cy - 10), (cx + 12, cy), (cx, cy + 10), (cx - 12, cy)], INK, 1.2)
    a.poly([(cx, cy - 6), (cx + 7, cy), (cx, cy + 6), (cx - 7, cy)], PAL["burgundy_light"], INK, 0.8)
    a.circle(cx - 1.5, cy - 1.5, 1.2, rgba((255, 255, 255), 200))
    img = a.render()
    arr = np.asarray(img).astype(np.float32).copy()
    xs = np.arange(W, dtype=np.float32)
    fade = smoothstep(0, 70, xs) * smoothstep(0, 70, W - 1 - xs)
    arr[..., 3] *= fade[None, :]
    save_png(Image.fromarray(arr.astype(np.uint8), "RGBA"), UI / "divider.png")


def render_ribbon():
    W, H = 384, 96
    a = Art(W, H, 4)
    B, BL, BD = PAL["burgundy"], PAL["burgundy_light"], PAL["burgundy_dark"]
    for sgn in (-1, 1):
        x0 = 6 if sgn < 0 else W - 6
        xin = 84 if sgn < 0 else W - 84
        notch = x0 + sgn * 20
        tail = [(x0, 30), (xin, 30), (xin, 86), (x0, 86), (notch, 58)]
        a.fill_grad(tail, mix(B, BD, 0.4), BD, outline=INK, ow=1.8)
        a.hatch(tail, BD, 75, 2.6, 0.7, 130)
        # fold shadow
        xb = 56 if sgn < 0 else W - 56
        a.poly([(xb, 72), (xin, 72), (xin, 86)] if sgn < 0 else [(xb, 72), (xin, 72), (xin, 86)], mix(BD, INK, 0.5), INK, 1.4)
        a.line([(x0 + sgn * 3, 33), (xin, 33)], rgba(GOLD, 180), 1.2)
    band = [(52, 14), (W - 52, 14), (W - 52, 72), (52, 72)]
    a.fill_grad(band, BL, B, outline=INK, ow=2.2)
    a.hatch(band, BD, 78, 3.0, 0.7, 70)
    # sheen
    a.rect(54, 16, W - 54, 22, rgba((255, 255, 255), 28))
    # gold trim
    for y, w in ((20.5, 1.8), (65.5, 1.8)):
        a.line([(52, y), (W - 52, y)], INK, w + 1.6)
        a.line([(52, y), (W - 52, y)], GOLD, w)
    for y in (24.5, 61.5):
        a.line([(56, y), (W - 56, y)], rgba(GOLD_L, 150), 0.8)
    for sx in (-1, 1):
        x = 52 if sx < 0 else W - 52
        a.line([(x, 14), (x, 72)], INK, 2.2)
        a.circle(x + (-sx) * 12, 43, 3.2, GOLD_L, INK, 0.8)
        a.circle(x + (-sx) * 22, 43, 2.0, GOLD, INK, 0.6)
    # central lozenge
    gold_fill(a, [(W / 2 - 16, 43), (W / 2, 33), (W / 2 + 16, 43), (W / 2, 53)], INK, 1.2)
    save_png(a.render(), UI / "ribbon.png")


def render_crown_ui():
    a = Art(256, 256, 3)
    crown(a, 128, 128, 232, outline_w=1.6)
    save_png(a.render(), UI / "crown.png")


def logo_art(size, ss=3, bg=True):
    k = size / 512.0
    a = Art(size, size, ss)
    c = size / 2

    def R(v):
        return v * k
    if bg:
        a.circle(c, c, R(254), INK)
        radial_disc(a, c, c - R(30), R(252), PAL["navy_mid"], PAL["navy_deep"], 50)
        rays(a, c, c - R(40), R(60), R(250), 36, GOLD_L, 14, 5, 0.09)
        a.circle(c, c, R(250), None, PAL["navy_deep"], R(10))
    # rings
    ring_gold(a, c, c, R(242), R(7))
    ring_gold(a, c, c, R(226), R(3), hi=False)
    # laurel
    lc = R(184)
    laurel_branch(a, c, c, lc, math.pi / 2 + 0.2, math.pi * 1.5 - 0.42, R(40), 9, GOLD_L, GOLD, INK, 1)
    laurel_branch(a, c, c, lc, math.pi / 2 - 0.2, -math.pi / 2 + 0.42, R(40), 9, GOLD_L, GOLD, INK, 1)
    # crossed sword and quill
    L = R(190)
    cyx = c + R(92)
    sa, qa = -0.62, math.pi + 0.62
    sword(a, c + math.cos(sa) * L * 0.13, cyx + math.sin(sa) * L * 0.13, L, sa)
    quill(a, c + math.cos(qa) * L * 0.08, cyx + math.sin(qa) * L * 0.08, L, qa)
    a.circle(c, cyx, R(8), GOLD, INK, R(2))
    crown(a, c, c - R(56), R(200), outline_w=max(1.2, 2.2 * k))
    return a.render()


def render_logo():
    save_png(logo_art(512), UI / "logo_mark.png")


def render_ui():
    render_panel_frame()
    render_divider()
    render_ribbon()
    render_crown_ui()
    render_logo()


# ------------------------------------------------------------------ launcher & store
ICON_SVG = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <radialGradient id="bg" cx="50%" cy="38%" r="75%">
      <stop offset="0" stop-color="#22345a"/>
      <stop offset="1" stop-color="#0b1326"/>
    </radialGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#e6c876"/>
      <stop offset="0.55" stop-color="#c9a24a"/>
      <stop offset="1" stop-color="#8f7230"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" fill="url(#bg)"/>
  <rect x="20" y="20" width="472" height="472" fill="none" stroke="#c9a24a" stroke-width="5"/>
  <rect x="32" y="32" width="448" height="448" fill="none" stroke="#c9a24a" stroke-opacity="0.55" stroke-width="2"/>
  <g transform="translate(256 270) scale(3.1)" stroke="#2a2118" stroke-width="1.1" stroke-linejoin="round">
    <path d="M-39 8 Q0 -60 39 8 L39 12 L-39 12 Z" fill="#5b1a24"/>
    <path d="M-42 -14 Q-30 -52 0 -40 Q30 -52 42 -14" fill="none" stroke="#2a2118" stroke-width="4.8"/>
    <path d="M-42 -14 Q-30 -52 0 -40 Q30 -52 42 -14" fill="none" stroke="#c9a24a" stroke-width="3.4"/>
    <path d="M-40 16 L-47 -19 L-31 -3 L-22 -27 L-10 -5 L0 -34 L10 -5 L22 -27 L31 -3 L47 -19 L40 16 Z" fill="url(#gold)"/>
    <rect x="-42" y="15" width="84" height="17" fill="url(#gold)"/>
    <circle cx="-47" cy="-19" r="4.2" fill="#e6c876"/>
    <circle cx="47" cy="-19" r="4.2" fill="#e6c876"/>
    <circle cx="-22" cy="-27" r="4.6" fill="#e6c876"/>
    <circle cx="22" cy="-27" r="4.6" fill="#e6c876"/>
    <circle cx="0" cy="-40" r="5.6" fill="#e6c876"/>
    <path d="M-30 18.8 L-25.8 24 L-30 29.2 L-34.2 24 Z" fill="#22345a"/>
    <path d="M-15 19.2 L-11.2 24 L-15 28.8 L-18.8 24 Z" fill="#3f7a6e"/>
    <path d="M0 17.2 L5.4 24 L0 30.8 L-5.4 24 Z" fill="#8a2b38"/>
    <path d="M15 19.2 L18.8 24 L15 28.8 L11.2 24 Z" fill="#3f7a6e"/>
    <path d="M30 18.8 L34.2 24 L30 29.2 L25.8 24 Z" fill="#22345a"/>
  </g>
</svg>
'''


def navy_texture(w, h, seed=5, rays_on=True):
    n = norm(fbm(w, h, seed, max(24, w // 5), 5))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h * 0.42) / (h / 2)) ** 2)
    t = np.clip(1 - d / 1.2, 0, 1)[..., None]
    c0, c1 = np.array(PAL["navy_deep"], np.float32), np.array(PAL["navy_mid"], np.float32)
    arr = c0 * (1 - t) + c1 * t
    if rays_on:
        ang = np.arctan2(yy - h * 0.42, xx - w / 2)
        r = (np.sin(ang * 18) > 0.6).astype(np.float32) * 0.05 * np.clip(1 - d / 1.5, 0, 1)
        arr = arr * (1 + r[..., None])
    arr = arr * (1 + n[..., None] * 0.035)
    arr += np.random.default_rng(seed).normal(0, 1.6, (h, w, 1))
    return np.clip(arr, 0, 255)


def render_icons():
    ASSETS.mkdir(exist_ok=True)
    (ASSETS / "icon.svg").write_text(ICON_SVG)
    print("  wrote assets/icon.svg")
    # foreground
    a = Art(432, 432, 3)
    crown(a, 216, 216, 236, outline_w=2.2)
    save_png(a.render(), ASSETS / "icon_foreground.png")
    # background
    save_png(Image.fromarray(navy_texture(432, 432, 8).astype(np.uint8), "RGB"), ASSETS / "icon_background.png")
    # 512 store icon
    bgimg = Image.fromarray(navy_texture(512, 512, 9).astype(np.uint8), "RGB").convert("RGBA")
    a = Art(512, 512, 3)
    a.rect(20, 20, 492, 492, None, GOLD, 5)
    a.rect(32, 32, 480, 480, None, rgba(GOLD, 140), 2)
    crown(a, 256, 250, 310, outline_w=2.6)
    bgimg.alpha_composite(a.render())
    save_png(bgimg.convert("RGB"), ASSETS / "icon_512.png")
    # splash
    S = 1080
    bg = navy_texture(S, S, 12)
    arr = vignette(bg.astype(np.float32), 0.45, 2.0)
    base = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    logo = logo_art(640, 3, bg=True)
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    base.alpha_composite(logo, ((S - 640) // 2, (S - 640) // 2))
    save_png(base.convert("RGB"), ASSETS / "splash.png", 600_000)
    # feature graphic
    render_feature()


def render_feature():
    W, H = 1024, 500
    a = Art(W, H, 2, bg=PAL["navy_deep"])
    rnd = random.Random(7)
    a.sky([(0, PAL["navy_deep"]), (0.6, PAL["navy"]), (1, hx("2a3d66"))], 0, H, bands=9, seed=3, wob=0.014)
    # rhumb lines
    for hub in ((512, 230), (160, 420), (860, 380)):
        for i in range(24):
            t = i * math.pi / 12
            a.line([hub, (hub[0] + math.cos(t) * 1400, hub[1] + math.sin(t) * 1400)], GOLD, 0.8, alpha=22)
    for i in range(1, 8):
        a.circle(512, 230, 60 + i * 60, None, rgba(GOLD, 26), 1.0)
    rays(a, 512, 230, 100, 620, 40, GOLD_L, 16, 8, 0.07)
    # sea wave lines
    for r in range(18):
        y = 330 + r * 10
        x = -rnd.uniform(0, 40)
        while x < W + 30:
            L = rnd.uniform(20, 60) * (1 + r * 0.05)
            a.line(bez((x, y), (x + L / 2, y - 3), (x + L, y)), GOLD_L, 1.0, alpha=rnd.uniform(25, 70))
            x += L * rnd.uniform(1.0, 1.9)
    # ships
    galleon(a, 150, 400, 260, hx("0b1326"), mix(PAL["parchment"], PAL["steel"], 0.3), GOLD, PAL["ink"], flag=PAL["burgundy_light"], sail_hatch=PAL["ink"])
    galleon(a, 880, 410, 230, hx("0b1326"), mix(PAL["parchment"], PAL["steel"], 0.3), GOLD, PAL["ink"], flip=True, flag=PAL["burgundy_light"], sail_hatch=PAL["ink"])
    galleon(a, 330, 330, 80, hx("0b1326"), mix(PAL["navy"], PAL["steel"], 0.5), GOLD_D, PAL["ink"])
    galleon(a, 720, 336, 70, hx("0b1326"), mix(PAL["navy"], PAL["steel"], 0.5), GOLD_D, PAL["ink"], flip=True)
    img = a.render().convert("RGB")
    arr = np.asarray(img).astype(np.float32)
    # emblem glow and emblem
    base = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    logo = logo_art(400, 3, bg=True)
    base.alpha_composite(logo, (W // 2 - 200, 40))
    arr = vignette(np.asarray(base.convert("RGB")).astype(np.float32), 0.5, 2.0)
    arr = paper_grain(arr, 4, 0.03)
    save_png(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB"), ASSETS / "store_feature_graphic.png", 700_000)
