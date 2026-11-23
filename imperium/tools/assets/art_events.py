"""Event illustrations (960x540): ev_<key>.png"""
import math
import random

import numpy as np
from PIL import Image

from art_kit import (PAL, Art, ROOT, bez, birds, castle, cloud, crenel, crown, finish, flame, galleon, hx, house, mix,
                     oak, person, pine, rain, rgba, ridge, ridge_pts, save_png, sea, smoke, soldier, spire_tower, stars,
                     strata, tree_dead, fbm, norm)
from art_backgrounds import make_parchment, mist, compass_rose, rays

OUT = ROOT / "assets" / "illustrations"
W, H = 960, 540
INK = PAL["ink"]


def new():
    return Art(W, H, 2, bg=PAL["navy_deep"])


def done(a, name, vig=0.5, etch_k=0.2, seed=1, limit=900_000, grain=0.045):
    img = finish(a, vig=vig, grain=grain, etch_k=etch_k, seed=seed)
    save_png(img, OUT / f"ev_{name}.png", limit)


# ------------------------------------------------------------------ helpers
def ground(a, y, color, amp=6, seed=1, hatch=True, color2=None, bottom=None):
    pts = ridge_pts(a, y, amp, seed, rough=0.6)
    poly = pts + [(W + 10, (bottom or H) + 10), (-10, (bottom or H) + 10)]
    if color2:
        a.fill_grad(poly, color, color2)
    else:
        a.poly(poly, color)
    if hatch:
        a.hatch(poly, INK, 78, 3.4, 0.8, 70)
    return pts


def checker_floor(a, vx, hz, c1, c2, ncols=14, nrows=9, xspan=1500, line=None):
    depth = H - hz
    rows = [hz + depth * (r / nrows) ** 1.8 for r in range(nrows + 1)]
    for r in range(nrows):
        y0, y1 = rows[r], rows[r + 1]
        for c in range(-ncols // 2 - 1, ncols // 2 + 1):
            xb0 = vx + c * xspan / ncols
            xb1 = vx + (c + 1) * xspan / ncols
            f0, f1 = (y0 - hz) / depth, (y1 - hz) / depth
            pts = [(vx + (xb0 - vx) * f0, y0), (vx + (xb1 - vx) * f0, y0), (vx + (xb1 - vx) * f1, y1), (vx + (xb0 - vx) * f1, y1)]
            a.poly(pts, c1 if (r + c) % 2 == 0 else c2)
    if line:
        for r in range(nrows + 1):
            a.line([(0, rows[r]), (W, rows[r])], line, 0.8, alpha=90)


def column(a, x, ytop, ybot, w, color, hi=None):
    a.rect(x - w / 2, ytop, x + w / 2, ybot, color, INK, 1.0)
    a.rect(x - w * 0.72, ytop - w * 0.28, x + w * 0.72, ytop, mix(color, PAL["gold_dark"], 0.3), INK, 1.0)
    a.rect(x - w * 0.72, ybot - w * 0.3, x + w * 0.72, ybot, mix(color, PAL["gold_dark"], 0.3), INK, 1.0)
    for i in range(1, 4):
        xx = x - w / 2 + w * i / 4
        a.line([(xx, ytop), (xx, ybot)], INK, 0.8, alpha=60)
    a.line([(x - w * 0.28, ytop + 2), (x - w * 0.28, ybot - 2)], hi or PAL["gold_light"], max(1, w * 0.08), alpha=60)
    a.hatch([(x + w * 0.1, ytop), (x + w / 2, ytop), (x + w / 2, ybot), (x + w * 0.1, ybot)], INK, 80, 2.2, 0.7, 110)


def pointed_arch(cx, base, w, h):
    s = base - h + w * 0.78
    left = [(cx - w / 2, base), (cx - w / 2, s)] + bez((cx - w / 2, s), (cx - w / 2, s - w * 0.45), (cx, base - h), 14)[1:]
    right = bez((cx, base - h), (cx + w / 2, s - w * 0.45), (cx + w / 2, s), 14)[1:] + [(cx + w / 2, base)]
    return left + right


def light_shaft(a, xa, xb, ya, xc, xd, yb, color, alpha):
    a.poly([(xa, ya), (xb, ya), (xd, yb), (xc, yb)], rgba(color, alpha))


def torch(a, x, y, h, glow=70, col=None):
    a.line([(x, y), (x, y - h)], INK, 2.2)
    flame(a, x, y - h, h * 0.55, h * 0.16, phase=x * 0.1)
    a.glow(x, y - h - 4, glow, PAL["gold_light"], 120, 2)


def lantern(a, x, y, s, glow=60):
    a.glow(x, y, glow, PAL["gold_light"], 150, 2)
    a.rect(x - s * 0.5, y - s * 0.7, x + s * 0.5, y + s * 0.7, rgba(PAL["gold_light"], 255), INK, 1.0)
    a.line([(x - s * 0.5, y - s * 0.7), (x, y - s * 1.1), (x + s * 0.5, y - s * 0.7)], INK, 1.0)


def tex_fill(a, pts, tex, alpha=255):
    mask, x0, y0 = a.poly_mask(pts)
    bw, bh = mask.size
    t = tex.crop((x0, y0, x0 + bw, y0 + bh)).convert("RGBA")
    t.putalpha(mask.point(lambda v: v * alpha // 255))
    a.paste(t, x0, y0)


def rioter(a, x, y, h, col, prop, rnd):
    person(a, x, y, h, col, hat=rnd.choice([None, "cap", "cap", "wide"]), arm=(0.18, 0.5 + rnd.random() * 0.12))
    hx_, hy_ = x + 0.2 * h, y - h * 1.1
    if prop == "fork":
        a.line([(hx_, hy_ + h * 0.45), (hx_ + h * 0.03, hy_ - h * 0.7)], col, max(1, h * 0.03))
        for d in (-0.08, 0, 0.08):
            a.line([(hx_ + h * 0.03 + d * h, hy_ - h * 0.7), (hx_ + h * 0.03 + d * h, hy_ - h * 0.88)], col, max(0.8, h * 0.025))
        a.line([(hx_ + h * 0.03 - 0.08 * h, hy_ - h * 0.7), (hx_ + h * 0.03 + 0.08 * h, hy_ - h * 0.7)], col, max(0.8, h * 0.03))
    elif prop == "torch":
        a.line([(hx_, hy_ + h * 0.25), (hx_, hy_ - h * 0.3)], col, max(1, h * 0.035))
        flame(a, hx_, hy_ - h * 0.3, h * 0.35, h * 0.1, phase=x)
        a.glow(hx_, hy_ - h * 0.45, h * 0.55, PAL["gold_light"], 80, 2)
    elif prop == "pike":
        a.line([(hx_ - h * 0.05, hy_ + h * 0.7), (hx_ + h * 0.05, hy_ - h * 0.9)], col, max(1, h * 0.03))
        a.poly([(hx_ + h * 0.03, hy_ - h * 0.82), (hx_ + h * 0.07, hy_ - h * 0.82), (hx_ + h * 0.05, hy_ - h * 1.0)], col)


# ------------------------------------------------------------------ 1 famine
def ev_famine():
    a = new()
    hz = 300
    a.sky([(0, PAL["steel_dark"]), (0.35, hx("8a7a6a")), (0.7, hx("d2a864")), (1, PAL["gold_light"])], 0, hz + 10, bands=9, seed=2, wob=0.014)
    sx, sy = 640, 262
    a.glow(sx, sy, 330, hx("f3d58a"), 170, 2)
    for r, al in ((86, 50), (70, 80)):
        a.circle(sx, sy, r, rgba(hx("f6e6b2"), al))
    a.circle(sx, sy, 52, hx("f6e6b2"))
    for i, (y, x0, x1, th, c, al) in enumerate([(120, 80, 520, 8, PAL["steel"], 130), (180, 520, 900, 9, hx("b79a74"), 150), (240, 60, 420, 7, hx("c9a272"), 150)]):
        strata(a, y, x0, x1, th, c, al, i)
    ridge(a, hz - 6, 14, 3, mix(hx("b98e60"), PAL["steel"], 0.35), rough=0.6, bottom=hz + 40)
    mist(a, hz + 10, 26, hx("e6c98a"), 130, 1)
    ridge(a, hz + 4, 10, 4, mix(hx("a07a52"), PAL["steel_dark"], 0.3), rough=0.55, bottom=hz + 60)
    gp = ground(a, hz + 14, hx("7b5b3a"), 3, 5, hatch=False, color2=hx("2d2018"))
    a.hatch(gp + [(W, H), (0, H)], INK, 80, 4, 0.9, 80)
    rr = random.Random(7)
    vx = 480
    for i in range(-16, 17):
        xb = vx + i * 95
        a.line([(vx + i * 5, hz + 16), (xb, H)], INK, 0.8 + abs(i) * 0.04, alpha=90)
    for r in range(10):
        y = hz + 30 + (r / 10) ** 1.8 * (H - hz - 30)
        a.line([(0, y), (W, y)], INK, 0.6 + r * 0.1, alpha=35)
    # cracked earth
    for _ in range(46):
        x, y = rr.uniform(0, W), rr.uniform(hz + 70, H)
        sc = 0.4 + (y - hz) / (H - hz) * 1.8
        pts = [(x, y)]
        ang = rr.uniform(0, 6.28)
        for _ in range(rr.randint(4, 8)):
            ang += rr.uniform(-0.9, 0.9)
            ln = rr.uniform(6, 16) * sc
            x, y = x + math.cos(ang) * ln, y + math.sin(ang) * ln * 0.45
            pts.append((x, y))
        a.line(pts, INK, 0.8 + sc * 0.5, alpha=200)
        if rr.random() < 0.5:
            bx, by = pts[len(pts) // 2]
            a.line([(bx, by), (bx + rr.uniform(-18, 18) * sc, by + rr.uniform(0, 8) * sc)], INK, 0.8, alpha=170)
    # farmstead
    dark = mix(INK, hx("5a3a2a"), 0.35)
    a.poly([(110, hz + 20), (110, hz - 6), (150, hz - 22), (196, hz - 8), (196, hz + 20)], dark)
    a.poly([(100, hz - 4), (150, hz - 30), (206, hz - 6), (200, hz - 4), (150, hz - 25), (106, hz - 2)], mix(dark, PAL["burgundy_dark"], 0.5), INK, 1)
    a.rect(140, hz + 2, 154, hz + 20, INK)
    for hxp in (230, 258):
        a.poly([(hxp - 16, hz + 20)] + bez((hxp - 16, hz + 20), (hxp - 16, hz - 8), (hxp, hz - 8), 8)[1:] + bez((hxp, hz - 8), (hxp + 16, hz - 8), (hxp + 16, hz + 20), 8)[1:], hx("8a6a3a"), INK, 1)
    # dead tree
    tree_dead(a, 790, 440, 330, INK, seed=11)
    # fallen cart wheel
    a.circle(560, 468, 32, None, INK, 3.0)
    for k in range(8):
        t = k * math.pi / 4
        a.line([(560, 468), (560 + math.cos(t) * 32, 468 + math.sin(t) * 32)], INK, 1.6)
    a.circle(560, 468, 6, INK)
    a.line([(520, 500), (610, 492)], INK, 4)
    # figures
    for x, y, h in [(300, 400, 70), (340, 408, 66), (390, 398, 60), (200, 372, 40), (252, 376, 38)]:
        person(a, x, y, h, INK, hat="wide" if x % 2 else "cap")
        a.line([(x + h * 0.25, y - h * 0.55), (x + h * 0.32, y)], INK, max(1, h * 0.04))
    # sacks
    for x in (430, 452):
        a.poly([(x - 12, 455), (x - 10, 430), (x - 4, 424), (x + 4, 424), (x + 10, 430), (x + 12, 455)], hx("6b5a3e"), INK, 1)
    # crows
    birds(a, [(420, 120, 1.5), (470, 150, 1.3), (520, 100, 1.2), (390, 170, 1.0), (880, 190, 1.4), (850, 140, 1.1), (600, 190, 1.0), (260, 210, 1.2)], INK, 10)
    for x, y in [(520, 515), (600, 470), (700, 495)]:
        a.ellipse(x, y, 9, 5, INK)
        a.poly([(x + 8, y - 2), (x + 14, y), (x + 8, y + 1)], INK)
        a.circle(x + 7, y - 4, 3.2, INK)
    done(a, "famine", seed=21)


# ------------------------------------------------------------------ 2 plague
def hood(a, x, y, h, col, beak=True):
    w = h * 0.22
    a.poly([(x - w * 1.1, y), (x - w * 0.5, y - h * 0.7), (x + w * 0.5, y - h * 0.7), (x + w * 1.1, y)], col)
    a.poly([(x - h * 0.14, y - h * 0.66), (x, y - h * 0.98), (x + h * 0.14, y - h * 0.66)], col)
    if beak:
        a.poly([(x + h * 0.02, y - h * 0.78), (x + h * 0.26, y - h * 0.7), (x + h * 0.02, y - h * 0.68)], col)
    a.ellipse(x - h * 0.02, y - h * 0.8, h * 0.18, h * 0.04, col)


def ev_plague():
    a = new()
    hz = 330
    a.sky([(0, PAL["navy_deep"]), (0.45, hx("1c3a3c")), (0.8, hx("4a7466")), (1, hx("9bb59c"))], 0, hz + 20, bands=9, seed=6, wob=0.014)
    a.glow(700, 150, 260, hx("a9c8b2"), 120, 2)
    a.circle(700, 150, 40, hx("dfe8cf"))
    a.circle(700, 150, 40, None, rgba(hx("a9c8b2"), 150), 1.2)
    for i, (y, x0, x1, th, c, al) in enumerate([(110, 100, 600, 9, PAL["verdigris_dark"], 150), (200, 500, 940, 8, hx("3a6a5c"), 130), (250, 40, 460, 9, hx("4f7a6a"), 120)]):
        strata(a, y, x0, x1, th, c, al, 30 + i)
    rr = random.Random(12)
    # back skyline
    far = mix(hx("2c4a48"), PAL["verdigris"], 0.2)
    x = -20
    while x < W + 20:
        w, h = rr.uniform(26, 52), rr.uniform(30, 80)
        house(a, x, hz + 30, w, h, far, mix(far, PAL["navy_deep"], 0.5), lit=PAL["gold_light"] if rr.random() < 0.08 else None)
        x += w * 0.9
    for sx_, h in [(250, 150), (800, 170)]:
        spire_tower(a, sx_, hz + 30, 30, h, far, mix(far, PAL["navy_deep"], 0.6), INK, None, cone=2.6)
    mist(a, hz + 30, 40, hx("7fa28d"), 120, 5)
    near = mix(hx("14292b"), PAL["verdigris_dark"], 0.2)
    x = 60
    while x < W - 40:
        w, h = rr.uniform(48, 90), rr.uniform(70, 130)
        house(a, x, hz + 60, w, h, near, mix(near, PAL["navy_deep"], 0.7), lit=hx("e6c876") if rr.random() < 0.18 else None)
        if rr.random() < 0.5:
            smoke(a, x + w * 0.8, hz + 60 - h - w * 0.5, 70, 8, hx("6c8f80"), 90, int(x), 4)
        x += w * 0.95
    # street
    gp = [(0, hz + 60), (W, hz + 60), (W, H), (0, H)]
    a.fill_grad(gp, hx("5a7a6c"), hx("1a2a28"))
    for i in range(-14, 15):
        a.line([(480 + i * 12, hz + 62), (480 + i * 110, H)], INK, 0.8, alpha=80)
    for r in range(12):
        y = hz + 62 + (r / 12) ** 1.8 * (H - hz - 62)
        a.line([(0, y), (W, y)], INK, 0.7 + r * 0.07, alpha=70)
    a.hatch(gp, INK, 80, 4, 0.8, 70)
    # framing houses
    for side in (1, -1):
        bx = 0 if side > 0 else W
        col = hx("162a2a")
        a.poly([(bx, 70), (bx + side * 150, 150), (bx + side * 150, H), (bx, H)], col, INK, 1.4)
        a.poly([(bx, 20), (bx + side * 170, 135), (bx + side * 150, 150), (bx, 70)], mix(col, PAL["burgundy_dark"], 0.5), INK, 1.2)
        for k in range(1, 5):
            a.line([(bx + side * 150 * k / 5, 150 + (k * 8)), (bx + side * 150 * k / 5, H)], hx("3a5a52"), 1.2, alpha=90)
        for yy in (240, 350):
            a.rect(bx + side * 40, yy, bx + side * 90, yy + 55, hx("0a1214") if yy > 300 else hx("e6c876"), INK, 1.4)
            a.line([(bx + side * 65, yy), (bx + side * 65, yy + 55)], INK, 1.2)
            a.line([(bx + side * 40, yy + 27), (bx + side * 90, yy + 27)], INK, 1.2)
        lantern(a, bx + side * 160, 255, 7, 80)
        a.line([(bx + side * 150, 250), (bx + side * 160, 250)], INK, 1.5)
    # cart
    cx = 470
    ink = INK
    a.rect(cx - 92, 452, cx + 82, 466, mix(ink, hx("4a3a2a"), 0.4), ink, 1.0)
    for i in range(6):
        a.line([(cx - 90 + i * 28, 452), (cx - 90 + i * 28, 438)], ink, 2.0)
    a.line([(cx - 92, 438), (cx + 82, 438)], ink, 2.0)
    for k, (bx2, w2) in enumerate([(-70, 40), (-24, 42), (22, 44)]):
        bp = [(cx + bx2, 438), (cx + bx2 + 2, 424)] + bez((cx + bx2 + 2, 424), (cx + bx2 + w2 / 2, 414), (cx + bx2 + w2 - 2, 424), 8)[1:] + [(cx + bx2 + w2, 438)]
        a.poly(bp, hx("b7a988"), ink, 1.0)
        a.hatch(bp, ink, 70, 3, 0.7, 120)
        for tz in (0.25, 0.75):
            a.line([(cx + bx2 + w2 * tz, 438), (cx + bx2 + w2 * tz, 421)], ink, 1.2)
    for wx in (-52, 50):
        a.circle(cx + wx, 484, 26, None, ink, 3.2)
        for k in range(8):
            t = k * math.pi / 4
            a.line([(cx + wx, 484), (cx + wx + math.cos(t) * 26, 484 + math.sin(t) * 26)], ink, 1.5)
        a.circle(cx + wx, 484, 5, ink)
    a.line([(cx + 82, 458), (cx + 170, 440)], ink, 3.0)
    hood(a, cx + 180, 482, 120, ink, True)
    a.line([(cx + 196, 482), (cx + 200, 370)], ink, 2.4)
    lantern(a, cx + 200, 366, 9, 100)
    hood(a, cx + 280, 470, 96, ink, True)
    hood(a, 250, 470, 90, ink, False)
    # crows
    for x, y in [(130, 218), (845, 232), (610, hz + 8), (300, hz + 12)]:
        a.ellipse(x, y, 9, 5, INK)
        a.circle(x + 7, y - 4, 3.2, INK)
        a.poly([(x + 8, y - 5), (x + 14, y - 3), (x + 8, y - 2)], INK)
    birds(a, [(560, 90, 1.2), (600, 120, 1.0), (420, 70, 1.0)], INK, 9)
    mist(a, 400, 40, hx("8fb09c"), 60, 7)
    done(a, "plague", seed=22)


# ------------------------------------------------------------------ 3 uprising
def ev_uprising():
    a = new()
    hz = 330
    rr = random.Random(5)
    a.sky([(0, PAL["navy_deep"]), (0.4, hx("3c1a30")), (0.7, PAL["burgundy"]), (0.9, PAL["ember"]), (1, PAL["gold"])], 0, hz + 20, bands=10, seed=3, wob=0.014)
    a.glow(480, hz - 20, 520, PAL["ember"], 140, 2)
    for i, (y, x0, x1, th, c, al) in enumerate([(90, 40, 540, 10, hx("2a1426"), 190), (160, 420, 920, 9, hx("4a1c30"), 170), (230, 80, 400, 8, PAL["burgundy_light"], 140)]):
        strata(a, y, x0, x1, th, c, al, i)
    # palace
    pal_c = mix(PAL["navy_deep"], PAL["burgundy_dark"], 0.5)
    a.rect(220, hz - 70, 740, hz + 40, pal_c, INK, 1.2)
    crenel(a, 220, 740, hz - 70, 9, pal_c, 9, INK)
    for tx, th in [(220, 150), (740, 150), (330, 120), (630, 120), (480, 200)]:
        spire_tower(a, tx, hz + 40, 44 if tx != 480 else 76, th, pal_c, mix(pal_c, PAL["burgundy"], 0.5), INK, PAL["gold_light"], cone=1.1)
    for wx in range(250, 720, 34):
        if 430 < wx < 530:
            continue
        a.poly(pointed_arch(wx, hz + 5, 12, 30), mix(PAL["gold"], PAL["ember"], 0.4) if rr.random() < 0.5 else hx("1a1020"))
    gate = pointed_arch(480, hz + 40, 56, 80)
    a.poly(gate, hx("0a0610"), INK, 1.6)
    a.glow(480, hz + 10, 60, PAL["ember"], 120, 2)
    a.line([(480, hz - 160), (480, hz - 200)], INK, 1.6)
    a.poly([(480, hz - 200), (516, hz - 190), (480, hz - 180)], PAL["burgundy_light"])
    # fire/smoke behind
    for x in (160, 790):
        smoke(a, x, hz + 20, 260, 40, hx("2a1a22"), 150, int(x), 10)
        flame(a, x, hz + 40, 70, 22, phase=x)
        a.glow(x, hz, 130, PAL["ember"], 120, 2)
    # plaza
    gp = [(0, hz + 40), (W, hz + 40), (W, H), (0, H)]
    a.fill_grad(gp, hx("6a3a48"), hx("1c0e18"))
    for r in range(10):
        y = hz + 44 + (r / 10) ** 1.8 * (H - hz - 44)
        a.line([(0, y), (W, y)], INK, 0.7, alpha=70)
    # crowd rows
    rows = [(405, 52, 46, 0.30, 0), (440, 74, 36, 0.22, 1), (490, 106, 24, 0.12, 2), (545, 160, 13, 0.0, 3)]
    props = ["fork", "torch", "pike", "fork", "torch", None]
    for y, h, n, dk, ri in rows:
        col = mix(INK, hx("3a2030"), dk * 1.5)
        for i in range(n):
            x = (i + 0.5) * W / n + rr.uniform(-12, 12)
            rioter(a, x, y + rr.uniform(-4, 4), h * rr.uniform(0.9, 1.1), col, rr.choice(props), rr)
        if ri == 1:
            for bx in (150, 480, 810):
                a.line([(bx, y), (bx, y - 250)], INK, 2.4)
                pts = [(bx, y - 250), (bx + 90, y - 232), (bx + 70, y - 196), (bx + 88, y - 160), (bx, y - 176)]
                a.poly(pts, PAL["burgundy_light"], INK, 1.2)
                a.hatch(pts, PAL["burgundy_dark"], 70, 2.6, 0.8, 150)
                a.circle(bx + 40, y - 205, 9, PAL["gold"], INK, 1)
    birds(a, [(120, 120, 1.2), (160, 140, 1.0), (840, 100, 1.1)], INK, 9)
    done(a, "uprising", seed=23)


# ------------------------------------------------------------------ 4 court
def ev_court():
    a = new()
    hz = 330
    wall = hx("16233f")
    a.sky([(0, hx("0e182e")), (1, hx("22345a"))], 0, hz + 5, bands=7, seed=1, wob=0.01)
    # windows + light shafts
    for wx in (150, 480, 810):
        arch = pointed_arch(wx, 250, 110, 200)
        a.poly(arch, hx("e8cf8a"), INK, 2.0)
        a.glow(wx, 140, 120, PAL["gold_light"], 130, 2)
        a.line([(wx, 50), (wx, 250)], INK, 1.5)
        a.line([(wx - 55, 150), (wx + 55, 150)], INK, 1.5)
        a.line([(wx - 55, 200), (wx + 55, 200)], INK, 1.0)
    for wx, dx in ((150, 120), (810, -120)):
        light_shaft(a, wx - 52, wx + 52, 140, wx - 52 + dx * 2.2, wx + 52 + dx * 2.8, H, PAL["gold_light"], 28)
    light_shaft(a, 432, 528, 140, 300, 660, H, PAL["gold_light"], 24)
    # tapestries
    for tx in (305, 655):
        pts = [(tx - 36, 60), (tx + 36, 60), (tx + 36, 230), (tx, 250), (tx - 36, 230)]
        a.poly(pts, PAL["burgundy"], PAL["gold"], 2)
        a.hatch(pts, PAL["burgundy_dark"], 70, 2.8, 0.8, 140)
        a.circle(tx, 120, 16, PAL["gold"], INK, 1)
        a.poly([(tx, 150), (tx + 12, 180), (tx, 200), (tx - 12, 180)], PAL["gold"], INK, 1)
    checker_floor(a, 480, hz, hx("2a3d66"), hx("101a33"), 16, 10, 1800, PAL["gold"])
    a.rect(0, hz - 40, W, hz, hx("1a2a4c"))
    a.hatch([(0, hz - 40), (W, hz - 40), (W, hz), (0, hz)], INK, 80, 3, 0.8, 70)
    # carpet
    a.poly([(440, hz), (520, hz), (700, H), (260, H)], PAL["burgundy"], PAL["gold"], 2)
    a.hatch([(440, hz), (520, hz), (700, H), (260, H)], PAL["burgundy_dark"], 80, 3.5, 0.8, 100)
    a.line([(448, hz), (290, H)], PAL["gold"], 1.6)
    a.line([(512, hz), (670, H)], PAL["gold"], 1.6)
    # dais
    for i, (y0, hw) in enumerate([(hz + 6, 130), (hz - 4, 105), (hz - 14, 80)]):
        a.rect(480 - hw, y0, 480 + hw, y0 + 12, mix(PAL["gold_dark"], PAL["burgundy"], 0.4 + i * 0.1), INK, 1.2)
    # canopy
    cp = [(380, hz - 180), (580, hz - 180), (610, hz - 60), (350, hz - 60)]
    a.poly([(480, hz - 230), (620, hz - 150), (340, hz - 150)], PAL["burgundy"], PAL["gold"], 2)
    a.poly([(340, hz - 150), (620, hz - 150), (630, hz - 40), (570, hz - 70), (480, hz - 40), (390, hz - 70), (330, hz - 40)], PAL["burgundy_light"], PAL["gold"], 1.5)
    a.hatch([(340, hz - 150), (620, hz - 150), (630, hz - 40), (330, hz - 40)], PAL["burgundy_dark"], 80, 3, 0.8, 150)
    for i in range(14):
        x = 336 + i * 21
        a.poly([(x, hz - 150), (x + 16, hz - 150), (x + 8, hz - 140)], PAL["gold"])
    # throne
    tp = [(430, hz - 10), (430, hz - 95), (445, hz - 130), (480, hz - 150), (515, hz - 130), (530, hz - 95), (530, hz - 10)]
    a.fill_grad(tp, PAL["gold_light"], PAL["gold_dark"], outline=INK, ow=1.6)
    a.rect(425, hz - 60, 535, hz - 46, PAL["burgundy"], INK, 1.2)
    a.rect(425, hz - 46, 535, hz - 6, PAL["burgundy_light"], INK, 1.2)
    # seated figure
    a.poly([(455, hz - 46), (462, hz - 100), (498, hz - 100), (505, hz - 46)], hx("24203a"), INK, 1.2)
    a.poly([(462, hz - 100), (480, hz - 92), (498, hz - 100), (492, hz - 70), (468, hz - 70)], PAL["gold"], INK, 1)
    a.circle(480, hz - 112, 9, hx("d9c096"), INK, 1)
    crown(a, 480, hz - 128, 24, outline_w=0.8, band_gems=False)
    # columns
    for x, w, yt in [(60, 52, 40), (220, 36, 110), (740, 36, 110), (900, 52, 40)]:
        column(a, x, yt, H if w > 40 else hz + 40, w, hx("2f4572"))
    # courtiers
    rr = random.Random(9)
    cols = [PAL["burgundy"], PAL["navy_mid"], hx("3b2a4a"), PAL["verdigris_dark"], INK]
    for side in (-1, 1):
        for i in range(6):
            x = 480 + side * (170 + i * 48 + rr.uniform(-6, 6))
            y = hz + 46 + (i % 3) * 22 + i * 14
            h = 72 + (i % 3) * 18 + i * 8
            person(a, x, y, h, rr.choice(cols), hat=rr.choice(["cap", "wide", None, "crown"]))
    # chandeliers
    for cx_ in (300, 660):
        a.line([(cx_, 0), (cx_, 40)], INK, 1.2)
        a.ellipse(cx_, 46, 36, 8, PAL["gold_dark"], INK, 1.2)
        for k in range(-3, 4):
            x = cx_ + k * 10
            a.rect(x - 1.5, 34, x + 1.5, 44, hx("e8dcc0"))
            a.glow(x, 30, 22, PAL["gold_light"], 160, 2)
            flame(a, x, 34, 8, 2.2)
    done(a, "court", seed=24, vig=0.55)


# ------------------------------------------------------------------ 5 battle
def ev_battle():
    a = new()
    hz = 310
    rr = random.Random(11)
    a.sky([(0, PAL["steel_dark"]), (0.4, hx("6c6670")), (0.75, hx("c8905a")), (1, PAL["gold_light"])], 0, hz + 10, bands=9, seed=9, wob=0.014)
    a.glow(480, hz - 10, 460, hx("f0a85a"), 120, 2)
    for i, (y, x0, x1, th, c, al) in enumerate([(100, 100, 600, 9, hx("4a4650"), 180), (170, 500, 930, 10, hx("5a4a4a"), 170), (230, 30, 380, 8, hx("8a5a4a"), 140)]):
        strata(a, y, x0, x1, th, c, al, i + 3)
    ridge(a, hz - 14, 16, 13, mix(hx("8a7a76"), PAL["steel"], 0.2), rough=0.6, bottom=hz + 40)
    # far fortress
    castle(a, 760, hz - 6, 120, mix(hx("6a5a60"), PAL["steel"], 0.2), hx("5a4048"), hx("e6c876"), PAL["burgundy_light"], ink=hx("3a3036"))
    mist(a, hz + 6, 30, hx("c0a07a"), 140, 6)
    gp = ground(a, hz + 6, hx("9a7a52"), 3, 8, hatch=False, color2=hx("3a2a1c"))
    a.hatch(gp + [(W, H), (0, H)], INK, 80, 4, 0.9, 80)
    # distant armies
    def line_of(x0, x1, y, h, col, n, ban):
        for i in range(n):
            x = x0 + (x1 - x0) * (i + rr.random() * 0.3) / n
            soldier(a, x, y + rr.uniform(-3, 3), h, col, True, True, lean=rr.uniform(-0.05, 0.1), banner=ban if i % 9 == 4 else None)
    cL, cR = mix(INK, PAL["burgundy"], 0.25), mix(INK, PAL["navy_mid"], 0.35)
    line_of(40, 420, hz + 30, 26, mix(cL, hx("6a5a60"), 0.4), 24, PAL["burgundy_light"])
    line_of(520, 930, hz + 30, 26, mix(cR, hx("6a5a60"), 0.4), 24, PAL["steel"])
    line_of(20, 400, hz + 60, 40, mix(cL, hx("4a3a40"), 0.2), 16, PAL["burgundy_light"])
    line_of(540, 940, hz + 60, 40, mix(cR, hx("4a3a40"), 0.2), 16, PAL["steel"])
    # clash smoke in the middle
    for i in range(5):
        smoke(a, 470 + (i - 2) * 60, hz + 90, 150, 38, hx("7a7078"), 95, 40 + i, 8)
    # mid line
    line_of(30, 400, hz + 112, 62, cL, 8, PAL["burgundy_light"])
    line_of(560, 950, hz + 112, 62, cR, 8, PAL["steel"])
    # sparks of musket/cannon fire
    for x, y in [(430, hz + 80), (500, hz + 95), (470, hz + 60)]:
        flame(a, x, y, 26, 8, phase=x)
        a.glow(x, y - 8, 48, PAL["gold_light"], 140, 2)
    # foreground: cannon and fallen
    fgp = ridge_pts(a, 460, 8, 77, rough=0.6)
    a.fill_grad(fgp + [(W + 10, H + 10), (-10, H + 10)], hx("4a3828"), hx("140e0a"))
    a.hatch(fgp + [(W, H), (0, H)], INK, 70, 3.4, 0.9, 100)
    # cannon
    a.fill_grad([(170, 470), (170, 440), (330, 428), (338, 450), (330, 466), (190, 480)], hx("9a7a3a"), hx("3a2a14"), outline=INK, ow=1.5)
    a.fill_grad([(330, 428), (338, 450), (350, 454), (350, 424), (338, 424)], hx("5a4a30"), hx("2a1e10"), outline=INK, ow=1)
    a.rect(120, 430, 230, 440, INK)
    a.circle(235, 480, 40, None, INK, 5)
    a.circle(235, 480, 40, None, hx("a07a40"), 1.2)
    for k in range(10):
        t = k * math.pi / 5
        a.line([(235, 480), (235 + math.cos(t) * 40, 480 + math.sin(t) * 40)], INK, 2)
    a.circle(235, 480, 8, INK)
    flame(a, 355, 440, 40, 12, phase=1)
    a.glow(360, 436, 80, PAL["gold_light"], 150, 2)
    smoke(a, 380, 430, 120, 36, hx("7a7078"), 150, 77, 8)
    # kneeling gunner and standing
    person(a, 150, 480, 96, INK, hat="cap", arm=(0.3, 0.1))
    person(a, 130, 540, 150, INK, hat="wide")
    # fallen pikes
    for i in range(6):
        x = 600 + i * 55 + rr.uniform(-10, 10)
        y = 500 + rr.uniform(0, 30)
        ang = rr.uniform(-0.3, 0.3)
        a.line([(x - 70 * math.cos(ang), y + 70 * math.sin(ang)), (x + 70 * math.cos(ang), y - 70 * math.sin(ang))], INK, 2.2)
    # banner foreground right
    a.line([(790, 540), (790, 260)], INK, 3)
    pts = [(790, 260), (900, 285), (872, 326), (896, 372), (790, 350)]
    a.poly(pts, PAL["navy_mid"], INK, 1.6)
    a.hatch(pts, PAL["navy_deep"], 70, 2.8, 0.8, 150)
    a.circle(845, 316, 14, PAL["gold"], INK, 1.2)
    # birds
    birds(a, [(300, 160, 1.2), (340, 190, 1.0), (700, 140, 1.1)], INK, 9)
    done(a, "battle", seed=25)


# ------------------------------------------------------------------ 6 trade
def awning(a, x0, x1, y, h, c1, c2, n=8):
    w = (x1 - x0) / n
    for i in range(n):
        a.poly([(x0 + i * w, y), (x0 + (i + 1) * w, y), (x0 + (i + 1) * w + 2, y + h), (x0 + i * w - 2, y + h)], c1 if i % 2 == 0 else c2, INK, 0.8)
        a.poly([(x0 + i * w - 2, y + h), (x0 + (i + 1) * w + 2, y + h), (x0 + (i + 0.5) * w, y + h + 10)], c1 if i % 2 == 0 else c2, INK, 0.8)


def barrel(a, x, y, w, h, col):
    pts = [(x - w * 0.42, y - h)] + bez((x - w * 0.42, y - h), (x - w * 0.62, y - h * 0.5), (x - w * 0.42, y), 8)[1:] + \
          [(x + w * 0.42, y)] + bez((x + w * 0.42, y), (x + w * 0.62, y - h * 0.5), (x + w * 0.42, y - h), 8)[1:]
    a.fill_grad(pts, mix(col, (255, 255, 255), 0.2), mix(col, INK, 0.4), horizontal=True, outline=INK, ow=1.0)
    for f in (0.2, 0.8):
        a.line([(x - w * 0.55, y - h * f), (x + w * 0.55, y - h * f)], PAL["gold_dark"], 1.6)


def crate(a, x, y, w, h, col):
    a.rect(x, y - h, x + w, y, col, INK, 1.2)
    a.line([(x, y - h), (x + w, y)], INK, 1.0, alpha=140)
    a.line([(x + w, y - h), (x, y)], INK, 1.0, alpha=140)
    a.hatch([(x, y - h), (x + w, y - h), (x + w, y), (x, y)], INK, 80, 3, 0.7, 70)


def ev_trade():
    a = new()
    hz = 300
    rr = random.Random(21)
    a.sky([(0, PAL["steel"]), (0.5, hx("d8c4a0")), (1, PAL["gold_light"])], 0, hz + 10, bands=8, seed=4, wob=0.014)
    a.glow(300, hz - 40, 380, PAL["gold_light"], 150, 2)
    cloud(a, 700, 90, 260, 26, hx("efe0c2"), PAL["steel"], 3)
    # harbor masts in distance
    for x in (560, 640, 720, 810):
        a.line([(x, hz + 10), (x, hz - 90 + (x % 3) * 12)], INK, 1.6)
        a.line([(x - 18, hz - 60 + (x % 3) * 12), (x + 18, hz - 60 + (x % 3) * 12)], INK, 1.2)
        a.poly([(x - 16, hz - 56 + (x % 3) * 12), (x + 16, hz - 56 + (x % 3) * 12), (x + 14, hz - 24), (x - 14, hz - 24)], hx("d8c8a2"), INK, 0.8)
    # buildings both sides
    for side in (-1, 1):
        x = 0 if side < 0 else W
        for i in range(4):
            w = 140 - i * 10
            xx = i * 110 if side < 0 else W - w - i * 110
            h = 190 - i * 28
            col = mix(hx("6b5646"), PAL["navy"], 0.25 + i * 0.12)
            house(a, xx, hz + 40 + i * 8, w, h, col, mix(col, PAL["burgundy"], 0.5), lit=None, ink=INK, rw=0.08)
            for wy in range(2):
                for wx in range(2):
                    a.rect(xx + 18 + wx * 52, hz + 40 + i * 8 - h + 30 + wy * 52, xx + 38 + wx * 52, hz + 40 + i * 8 - h + 54 + wy * 52,
                           hx("e6c876") if rr.random() < 0.3 else hx("1a2236"), INK, 1)
    # square
    gp = [(0, hz + 40), (W, hz + 40), (W, H), (0, H)]
    a.fill_grad(gp, hx("a58a64"), hx("3a2c20"))
    for i in range(-14, 15):
        a.line([(480 + i * 10, hz + 42), (480 + i * 100, H)], INK, 0.8, alpha=60)
    for r in range(10):
        y = hz + 42 + (r / 10) ** 1.8 * (H - hz - 42)
        a.line([(0, y), (W, y)], INK, 0.7, alpha=60)
    # stalls
    def stall(x, y, w, c1, c2):
        a.rect(x, y - 70, x + 3, y, INK)
        a.rect(x + w - 3, y - 70, x + w, y, INK)
        a.rect(x, y - 24, x + w, y, mix(hx("5a4030"), INK, 0.2), INK, 1.2)
        awning(a, x - 6, x + w + 6, y - 82, 22, c1, c2, 8)
        for i in range(8):
            cx_ = x + 8 + i * (w - 16) / 8
            a.circle(cx_, y - 30, 7, rr.choice([PAL["gold"], PAL["burgundy_light"], PAL["verdigris"]]), INK, 0.8)
    stall(230, 400, 170, PAL["burgundy"], PAL["parchment"])
    stall(560, 392, 160, PAL["verdigris_dark"], PAL["parchment"])
    # barrels and crates, sacks
    for x, y, w, h in [(120, 470, 46, 56), (170, 478, 46, 56), (800, 468, 50, 60), (850, 480, 46, 56)]:
        barrel(a, x, y, w, h, hx("7a5436"))
    crate(a, 30, 470, 60, 50, hx("8a6a44"))
    crate(a, 880, 482, 56, 46, hx("8a6a44"))
    for x in (440, 470, 500):
        a.poly([(x - 14, 440), (x - 12, 414), (x - 4, 408), (x + 4, 408), (x + 12, 414), (x + 14, 440)], hx("c4b08a"), INK, 1)
        a.hatch([(x - 14, 440), (x - 12, 414), (x + 12, 414), (x + 14, 440)], INK, 70, 3, 0.7, 70)
    # merchants / customers
    for x, y, h, c, hat in [(300, 440, 70, PAL["burgundy"], "wide"), (350, 450, 64, hx("2e3a4e"), "cap"), (640, 436, 70, hx("3a2a44"), "wide"),
                            (690, 446, 66, PAL["verdigris_dark"], "cap"), (500, 520, 110, INK, "wide"), (420, 508, 100, PAL["navy_mid"], "cap")]:
        person(a, x, y, h, c, hat=hat, arm=(0.2, 0.2) if x % 20 == 0 else None)
    # hanging balance scales foreground
    sx, sy = 480, 20
    a.line([(sx, 0), (sx, 120)], PAL["gold_dark"], 3)
    a.line([(sx - 130, 120), (sx + 130, 120)], PAL["gold_dark"], 4)
    a.poly([(sx - 10, 120), (sx + 10, 120), (sx, 100)], PAL["gold"], INK, 1)
    for sgn in (-1, 1):
        px = sx + sgn * 130
        a.line([(px, 120), (px - 40, 210)], PAL["gold_dark"], 1.2)
        a.line([(px, 120), (px + 40, 210)], PAL["gold_dark"], 1.2)
        pan = [(px - 50, 210)] + bez((px - 50, 210), (px, 240), (px + 50, 210), 12)[1:]
        a.fill_grad(pan, PAL["gold_light"], PAL["gold_dark"], outline=INK, ow=1.4)
        a.circle(px, 120, 5, PAL["gold"], INK, 1)
    for i in range(5):
        for j in range(3 - i // 2):
            a.ellipse(sx - 130 - 20 + i * 10, 204 - j * 6, 9, 3.6, PAL["gold_light"], INK, 0.8)
    for i in range(3):
        a.rect(sx + 130 - 14 + i * 10, 200 - i * 6, sx + 130 - 4 + i * 10, 208, hx("8a8a98"), INK, 1)
    birds(a, [(200, 120, 1.1), (240, 140, 0.9), (860, 150, 1.0)], INK, 9)
    done(a, "trade", seed=26)


# ------------------------------------------------------------------ 7 storm
def wave_layer(a, y, amp, wl, color, seed, foam=None, sharp=0.75):
    rnd = random.Random(seed)
    ph = rnd.uniform(0, 6)
    pts, crests = [], []
    n = int((W + 60) / 3)
    for i in range(n + 1):
        x = -30 + i * 3
        s = math.sin(x / wl * 2 * math.pi + ph) * 0.62 + math.sin(x / (wl * 0.41) * 2 * math.pi + ph * 2) * 0.38
        yy = y - amp * (s ** sharp if s > 0 else s * 0.55)
        pts.append((x, yy))
        if s > 0.82 and y > 330:
            crests.append((x, yy))
    poly = pts + [(W + 30, H + 10), (-30, H + 10)]
    a.fill_grad(poly, color, mix(color, PAL["navy_deep"], 0.55), outline=None)
    a.line(pts, mix(color, (255, 255, 255), 0.35), 1.0, alpha=90)
    if foam:
        for x, yy in crests:
            a.line(bez((x - 5, yy + 4), (x, yy - 2), (x + 8, yy + 5)), foam, 1.4, alpha=210)
            for k in range(3):
                a.line([(x - 3 + k * 4, yy + 6 + k * 3), (x + 2 + k * 4, yy + 10 + k * 3)], foam, 1.0, alpha=140)
    a.hatch(poly, INK, 15, 3.2, 0.7, 60)
    return pts


def ev_storm():
    a = new()
    hz = 250
    rr = random.Random(33)
    a.sky([(0, PAL["navy_deep"]), (0.4, hx("1c2540")), (0.75, PAL["steel_dark"]), (1, hx("8a8f9c"))], 0, hz + 40, bands=9, seed=15, wob=0.02)
    for i in range(7):
        y = 40 + i * 32
        strata(a, y, rr.uniform(-60, 400), rr.uniform(500, 1020), 18 + i * 2, mix(PAL["navy"], PAL["steel_dark"], i / 7), 200, i)
    for i, (cx, cy, w, h) in enumerate([(180, 190, 400, 50), (650, 160, 520, 56), (480, 235, 460, 36)]):
        cloud(a, cx, cy, w, h, hx("4a526a"), hx("1e2740"), i)
    # lightning
    bolt = [(640, 100)]
    x, y = 640, 100
    while y < 330:
        x += rr.uniform(-34, 22)
        y += rr.uniform(26, 46)
        bolt.append((x, y))
    a.glow(640, 200, 280, hx("dfe6ff"), 90, 2)
    a.line(bolt, rgba(hx("dfe8ff"), 120), 9)
    a.line(bolt, hx("f4f0d8"), 3.4)
    br = bolt[3:]
    a.line([br[0], (br[0][0] + 40, br[0][1] + 40), (br[0][0] + 55, br[0][1] + 90)], hx("f4f0d8"), 2)
    # sea
    wave_layer(a, hz + 50, 14, 220, hx("3a4a66"), 1, hx("dfe6ee"))
    wave_layer(a, hz + 100, 22, 180, hx("2e3e5c"), 2, hx("dfe6ee"))
    # ship
    galleon(a, 470, 360, 360, PAL["ink"], hx("d8d0b8"), PAL["gold_dark"], PAL["ink"], flip=False, flag=PAL["burgundy_light"], heel=0.17, sail_hatch=PAL["ink"])
    wave_layer(a, hz + 170, 36, 240, hx("26354f"), 3, hx("e8ecf0"))
    wave_layer(a, hz + 245, 52, 300, hx("1a2640"), 4, hx("f2f2ee"))
    wave_layer(a, hz + 320, 40, 200, hx("101a30"), 5, hx("dfe6ee"))
    rain(a, (0, 0, W, H), 420, 3, hx("c8d0e0"), 22, 0.35, 90, 0.9)
    a.glow(640, 330, 200, hx("dfe6ff"), 50, 2)
    birds(a, [(820, 230, 1.2), (860, 250, 1.0)], INK, 9)
    done(a, "storm", seed=27, vig=0.55)


# ------------------------------------------------------------------ 8 fire
def ev_fire():
    a = new()
    hz = 360
    rr = random.Random(44)
    a.sky([(0, hx("0a0a14")), (0.4, hx("2a1020")), (0.7, PAL["burgundy"]), (1, PAL["ember"])], 0, hz + 10, bands=10, seed=17, wob=0.014)
    a.glow(480, hz - 20, 700, PAL["ember"], 160, 1.8)
    # smoke columns
    for x in (200, 480, 740):
        smoke(a, x, hz - 40, 320, 70, hx("2a2028"), 200, int(x), 16)
    # skyline
    base_c = hx("1a1018")
    x = -10
    xs = []
    while x < W + 20:
        w, h = rr.uniform(40, 80), rr.uniform(50, 120)
        house(a, x, hz + 20, w, h, mix(base_c, PAL["burgundy_dark"], rr.random() * 0.4), mix(base_c, PAL["burgundy_dark"], 0.7), lit=PAL["gold_light"] if rr.random() < 0.5 else None, ink=INK)
        xs.append((x + w / 2, hz + 20 - h))
        x += w * 0.92
    for sx_, h in [(130, 200), (610, 240), (860, 170)]:
        spire_tower(a, sx_, hz + 20, 34, h, mix(base_c, PAL["burgundy_dark"], 0.2), mix(base_c, PAL["burgundy"], 0.5), INK, PAL["gold_light"], cone=2.4)
    for bx, by in xs[::2]:
        if 150 < bx < 800 or rr.random() < 0.4:
            hh = rr.uniform(70, 130)
            a.glow(bx, by + 20, hh * 1.4, PAL["ember"], 140, 2)
            flame(a, bx, by + 30, hh, hh * 0.28, phase=bx * 0.05)
    for bx in (300, 480, 560):
        a.glow(bx, hz - 70, 180, PAL["gold_light"], 120, 2)
        flame(a, bx, hz + 10, 190, 52, phase=bx)
    # sparks
    for _ in range(140):
        x, y = rr.uniform(100, 880), rr.uniform(60, hz)
        a.circle(x, y, rr.uniform(0.6, 1.6), rgba(PAL["gold_light"], rr.randint(120, 255)))
    # river
    gp = [(0, hz + 20), (W, hz + 20), (W, H), (0, H)]
    a.fill_grad(gp, hx("3a1a1c"), hx("0c0710"))
    for r in range(26):
        y = hz + 28 + r * 7
        for k in range(10):
            x = rr.uniform(100, 860)
            L = rr.uniform(20, 80)
            a.line([(x, y), (x + L, y)], mix(PAL["ember"], PAL["gold_light"], rr.random()), 1.2 + r * 0.05, alpha=rr.randint(70, 170))
    a.glow(480, hz + 60, 360, PAL["ember"], 90, 2)
    # bucket chain
    for i in range(10):
        x = 60 + i * 42
        y = 470 + abs(math.sin(i * 0.8)) * 10 + (i % 2) * 8
        person(a, x, y, 70 + (i % 3) * 4, INK, hat="cap", arm=(0.28, 0.3))
        a.rect(x + 18, y - 56, x + 28, y - 44, INK)
    for x in (770, 830, 890):
        person(a, x, 500, 100, INK, hat="wide", arm=(0.22, 0.55))
    # foreground pier
    a.rect(0, 510, W, H, INK)
    a.hatch([(0, 510), (W, 510), (W, H), (0, H)], hx("5a3a30"), 0, 4, 0.8, 90)
    birds(a, [(100, 140, 1.1), (140, 170, 0.8)], INK, 9)
    done(a, "fire", seed=28, vig=0.55)


# ------------------------------------------------------------------ 9 church (cathedral architecture, no religious iconography)
def ev_church():
    a = new()
    hz = 410
    a.sky([(0, PAL["navy_deep"]), (0.35, PAL["navy"]), (0.65, hx("5a3a52")), (0.85, hx("c07a5a")), (1, PAL["gold_light"])], 0, hz, bands=10, seed=19, wob=0.014)
    stars(a, (0, 0, W, 160), 60, 4, PAL["gold_light"], 1.1)
    a.glow(480, hz - 40, 540, PAL["gold_light"], 120, 2)
    for i, (y, x0, x1, th, c, al) in enumerate([(220, 40, 380, 8, PAL["burgundy_light"], 160), (260, 620, 930, 8, PAL["ember"], 150), (150, 600, 900, 7, hx("5a3a52"), 150)]):
        strata(a, y, x0, x1, th, c, al, i + 20)
    ridge(a, hz - 10, 16, 14, mix(hx("8a5a5a"), PAL["navy"], 0.4), rough=0.6, bottom=hz + 30)
    stone = hx("2a2e48")
    st2 = hx("1b1f36")
    # nave
    a.rect(250, 190, 710, hz + 5, stone, INK, 1.4)
    a.poly([(250, 190), (480, 100), (710, 190)], hx("3a2a44"), INK, 1.6)
    a.hatch([(250, 190), (480, 100), (710, 190)], INK, 60, 3, 0.8, 90)
    # twin towers
    for tx in (222, 738):
        a.rect(tx - 56, 130, tx + 56, hz + 5, st2, INK, 1.4)
        a.rect(tx - 62, 125, tx + 62, 136, stone, INK, 1)
        a.poly(pointed_arch(tx, 250, 40, 100), hx("e8cf8a"), INK, 1.4)
        a.glow(tx, 205, 45, PAL["gold_light"], 100, 2)
        a.line([(tx, 150), (tx, 250)], INK, 1.2)
        a.poly([(tx - 54, 125), (tx + 54, 125), (tx, 14)], mix(st2, PAL["burgundy"], 0.4), INK, 1.6)
        a.line([(tx, 14), (tx, -6)], INK, 1.5)
        a.circle(tx, -8, 4, PAL["gold"], INK, 1)
        for k in range(3):
            y = 60 + k * 18
            a.poly([(tx - 5, y), (tx + 5, y), (tx + 5, y + 14), (tx - 5, y + 14)], hx("1a1020"))
        a.hatch([(tx, 125), (tx + 54, 125), (tx, 14)], PAL["burgundy_dark"], 70, 3, 0.8, 130)
        for k in range(5):
            a.rect(tx - 58 + k * 24, 113, tx - 48 + k * 24, 125, stone, INK, 0.8)
    # spire center
    a.poly([(440, 105), (520, 105), (480, 20)], mix(st2, PAL["burgundy"], 0.4), INK, 1.4)
    # rose window
    rx, ry = 480, 220
    a.circle(rx, ry, 68, hx("1a1830"), INK, 2.4)
    a.circle(rx, ry, 62, PAL["gold_dark"], INK, 1.6)
    cols = [PAL["burgundy_light"], PAL["navy_mid"], PAL["gold_light"], PAL["verdigris"]]
    for k in range(12):
        t0, t1 = k * math.pi / 6, (k + 1) * math.pi / 6
        pts = [(rx, ry)] + [(rx + math.cos(t0 + (t1 - t0) * j / 8) * 60, ry + math.sin(t0 + (t1 - t0) * j / 8) * 60) for j in range(9)]
        a.poly(pts, cols[k % 4], INK, 1.2)
    a.circle(rx, ry, 22, PAL["gold_light"], INK, 1.4)
    a.glow(rx, ry, 120, PAL["gold_light"], 140, 2)
    for k in range(12):
        t = k * math.pi / 6
        a.line([(rx + math.cos(t) * 22, ry + math.sin(t) * 22), (rx + math.cos(t) * 62, ry + math.sin(t) * 62)], INK, 1.1)
    a.circle(rx, ry, 41, None, INK, 1.2)
    # portal (3 pointed arches)
    for px, w, h in [(480, 90, 130), (402, 54, 90), (558, 54, 90)]:
        a.poly(pointed_arch(px, hz + 5, w, h), hx("f1b25a"), INK, 1.8)
        a.glow(px, hz - h / 2, h * 0.6, PAL["gold_light"], 100, 2)
        a.line([(px, hz + 5 - h + 14), (px, hz + 5)], INK, 1.4)
    # buttresses
    for bx, s in [(330, 1), (630, -1)]:
        a.poly([(bx, 190), (bx + s * 18, 190), (bx + s * 18, hz + 5), (bx - s * 4, hz + 5)], st2, INK, 1.1)
    # lancet windows nave
    for wx in (300, 360, 600, 660):
        a.poly(pointed_arch(wx, 330, 20, 70), hx("e8cf8a"), INK, 1)
    # steps and plaza
    for i in range(5):
        y = hz + 5 + i * 10
        a.rect(330 - i * 20, y, 630 + i * 20, y + 10, mix(st2, PAL["parchment_dark"], 0.1 + i * 0.03), INK, 1.0)
    gp = [(0, hz + 22), (W, hz + 22), (W, H), (0, H)]
    a.fill_grad(gp, hx("3a3040"), hx("0c0a14"))
    for i in range(-12, 13):
        a.line([(480 + i * 12, hz + 55), (480 + i * 120, H)], INK, 0.8, alpha=70)
    # light spill on plaza
    a.poly([(400, hz + 55), (560, hz + 55), (700, H), (260, H)], rgba(PAL["gold_light"], 36))
    rr = random.Random(7)
    for i in range(13):
        x = 330 + rr.uniform(0, 300)
        y = hz + 70 + (i % 4) * 20 + i * 4
        person(a, x, y, 40 + (y - hz) * 0.25, INK, hat=rr.choice(["cap", "wide", None]))
    for x in (60, 900):
        oak(a, x, 480, 220, INK)
    done(a, "church", seed=29)


# ------------------------------------------------------------------ 10 diplomacy
def ev_diplomacy():
    a = new()
    hz = 330
    wall = hx("1c3a3a")
    a.sky([(0, hx("11262a")), (1, hx("2a5048"))], 0, hz + 10, bands=7, seed=3, wob=0.01)
    # windows
    for wx in (130, 330, 630, 830):
        a.poly(pointed_arch(wx, 250, 90, 180), hx("e8d9a2"), INK, 2)
        a.line([(wx, 90), (wx, 250)], INK, 1.4)
        a.line([(wx - 45, 150), (wx + 45, 150)], INK, 1.2)
        a.glow(wx, 150, 90, PAL["gold_light"], 90, 2)
    # banners behind each delegation
    for bx, col, dk in [(170, PAL["burgundy"], PAL["burgundy_dark"]), (790, PAL["navy_mid"], PAL["navy_deep"])]:
        a.line([(bx, 20), (bx, 330)], PAL["gold_dark"], 3)
        pts = [(bx - 70, 40), (bx + 70, 40), (bx + 70, 250), (bx, 280), (bx - 70, 250)]
        a.poly(pts, col, PAL["gold"], 2.2)
        a.hatch(pts, dk, 70, 3, 0.8, 150)
        a.circle(bx, 120, 26, PAL["gold"], INK, 1.4)
        a.poly([(bx, 160), (bx + 16, 200), (bx, 230), (bx - 16, 200)], PAL["gold"], INK, 1)
    # floor
    checker_floor(a, 480, hz, hx("26453f"), hx("11231f"), 16, 9, 1800, PAL["gold_dark"])
    a.rect(0, hz - 36, W, hz, hx("1a3330"))
    a.hatch([(0, hz - 36), (W, hz - 36), (W, hz), (0, hz)], INK, 80, 3, 0.8, 70)
    # delegations
    rr = random.Random(14)
    def group(xs, cols, hats, facing):
        for i, (x, c, hat) in enumerate(zip(xs, cols, hats)):
            h = 150 - abs(i - 1) * 8
            person(a, x, 395 + (i % 2) * 6, h, c, hat=hat, arm=(0.24 * facing, 0.35) if i == 0 else None)
            a.circle(x, 395 - h * 0.62 + 8, 4, PAL["gold"])
    group([300, 230, 150], [PAL["burgundy"], hx("3a1a30"), PAL["burgundy_dark"]], ["crown", "wide", "cap"], 1)
    group([660, 730, 810], [PAL["navy_mid"], hx("1c2a48"), PAL["navy"]], ["crown", "cap", "wide"], -1)
    # table
    ty = 400
    a.poly([(110, ty), (850, ty), (880, ty + 24), (80, ty + 24)], hx("5a3a2a"), INK, 1.6)
    a.poly([(80, ty + 24), (880, ty + 24), (860, 540), (100, 540)], PAL["verdigris_dark"], INK, 1.6)
    a.hatch([(80, ty + 24), (880, ty + 24), (860, 540), (100, 540)], INK, 85, 4, 0.9, 70)
    for i in range(14):
        x = 100 + i * 56
        a.poly([(x, ty + 24), (x + 28, ty + 24), (x + 22, 540), (x + 6, 540)], rgba(PAL["verdigris"], 70))
    a.line([(80, ty + 30), (880, ty + 30)], PAL["gold"], 2.4)
    for i in range(40):
        x = 82 + i * 20
        a.poly([(x, ty + 30), (x + 8, ty + 30), (x + 4, ty + 42)], PAL["gold"])
    # treaty scroll & seal & quill
    a.poly([(400, ty - 4), (560, ty - 4), (570, ty + 8), (390, ty + 8)], hx("efe3c6"), INK, 1.4)
    a.ellipse(397, ty + 2, 8, 12, hx("e0d2ae"), INK, 1.2)
    a.ellipse(563, ty + 2, 8, 12, hx("e0d2ae"), INK, 1.2)
    for i in range(5):
        a.line([(420, ty + 0 + i * 1.5), (540 - (i % 2) * 18, ty + 0 + i * 1.5)], INK, 0.7, alpha=130)
    a.circle(480, ty + 2, 13, PAL["burgundy_light"], INK, 1.4)
    a.circle(480, ty + 2, 8, None, PAL["burgundy_dark"], 1)
    a.line([(480, ty - 4), (472, ty + 30)], PAL["burgundy"], 3)
    a.glow(480, ty - 6, 50, PAL["gold_light"], 90, 2)
    for qx in (500, 620):
        pass
    # candles
    for cx_ in (210, 750):
        a.rect(cx_ - 4, ty - 36, cx_ + 4, ty, hx("e8dcc0"), INK, 1)
        flame(a, cx_, ty - 36, 16, 4.5)
        a.glow(cx_, ty - 46, 50, PAL["gold_light"], 140, 2)
    done(a, "diplomacy", seed=30, vig=0.55)


# ------------------------------------------------------------------ 11 science
def armillary(a, cx, cy, r):
    gold, gd = PAL["gold"], PAL["gold_dark"]
    for rx, ry, ang in [(r, r, 0), (r, r * 0.34, 0), (r * 0.86, r * 0.86, 0), (r, r * 0.34, 1.05), (r, r * 0.3, -0.5)]:
        pts = [(cx + rx * math.cos(t) * math.cos(ang) - ry * math.sin(t) * math.sin(ang),
                cy + rx * math.cos(t) * math.sin(ang) + ry * math.sin(t) * math.cos(ang)) for t in np.linspace(0, 2 * math.pi, 80)]
        a.line(pts + [pts[0]], INK, 4.2)
        a.line(pts + [pts[0]], gold, 2.6)
    a.line([(cx - r * 0.2, cy - r * 1.15), (cx + r * 0.2, cy + r * 1.15)], INK, 3)
    a.circle(cx, cy, r * 0.17, hx("5a8a6a"), INK, 1.4)
    a.circle(cx, cy, r * 0.17, None, gold, 1.0)


def ev_science():
    a = new()
    rr = random.Random(6)
    a.sky([(0, hx("070d1e")), (0.5, hx("0e1a38")), (1, hx("1f3560"))], 0, 330, bands=9, seed=23, wob=0.012)
    stars(a, (0, 0, W, 300), 220, 9, hx("f1e6b8"), 1.4)
    # window arch (right) with night sky
    wx = 640
    arch = pointed_arch(wx, 420, 420, 380)
    a.poly(arch, hx("0a1328"))
    a.fill_grad(arch, hx("0a1226"), hx("2a4a7a"))
    stars_pts = [(rr.uniform(450, 830), rr.uniform(70, 360)) for _ in range(110)]
    for x, y in stars_pts:
        a.circle(x, y, rr.uniform(0.5, 1.6), rgba(hx("f4ecc8"), rr.randint(130, 255)))
    # moon (crescent) & constellation
    a.glow(740, 130, 90, hx("f4ecc8"), 110, 2)
    a.circle(740, 130, 30, hx("f2e8c0"))
    a.circle(752, 124, 27, hx("0e1a38"))
    cons = [(520, 230), (560, 190), (610, 210), (650, 160), (700, 190), (740, 250)]
    a.line(cons, rgba(PAL["gold_light"], 130), 1.0)
    for x, y in cons:
        a.glow(x, y, 12, PAL["gold_light"], 200, 2)
        a.circle(x, y, 2.6, hx("fff4cc"))
    # dome observatory silhouette across the way on hills
    ridge(a, 380, 12, 5, hx("0a1022"), rough=0.6, bottom=430, x0=430, x1=860)
    dx = 770
    a.poly([(dx - 50, 380), (dx - 44, 336)] + [(dx + 44 * math.cos(math.pi - t), 336 - 44 * math.sin(t)) for t in np.linspace(0, math.pi, 20)][1:] + [(dx + 50, 380)], hx("0a1022"), INK, 1.2)
    a.line([(dx - 6, 300), (dx - 2, 336)], hx("2a3a5a"), 5)
    a.line([(dx + 4, 300), (dx + 30, 272)], INK, 5)
    a.glow(dx, 360, 50, PAL["gold_light"], 90, 2)
    a.rect(420, 420, W, H, hx("121a30"))
    a.hatch([(420, 420), (W, 420), (W, H), (420, H)], INK, 80, 5, 0.8, 80)
    # window frame
    outer = pointed_arch(wx, 420, 440, 400)
    a.line(outer + [outer[0]], hx("3a4260"), 18)
    a.line(outer, INK, 2.0)
    a.line([(wx, 80), (wx, 420)], hx("3a4260"), 6)
    a.line([(wx - 210, 250), (wx + 210, 250)], hx("3a4260"), 6)
    # wall left & right with books
    a.rect(0, 0, 420, 540, hx("1b2238"))
    a.hatch([(0, 0), (420, 0), (420, 540), (0, 540)], INK, 80, 5, 0.8, 80)
    for x0, y0 in [(0, 60), (0, 140)]:
        a.rect(x0, y0 + 60, 200, y0 + 66, hx("5a4030"), INK, 1)
        bx = x0 + 6
        while bx < 190:
            w = rr.uniform(8, 16)
            h = rr.uniform(36, 56)
            a.rect(bx, y0 + 60 - h, bx + w, y0 + 60, rr.choice([PAL["burgundy"], PAL["navy_mid"], PAL["verdigris_dark"], hx("5a4030")]), INK, 0.8)
            a.line([(bx + 2, y0 + 60 - h + 8), (bx + w - 2, y0 + 60 - h + 8)], PAL["gold"], 0.8)
            bx += w
    # desk
    a.poly([(0, 430), (560, 430), (600, 540), (0, 540)], hx("3a2a20"), INK, 1.6)
    a.hatch([(0, 430), (560, 430), (600, 540), (0, 540)], INK, 15, 4, 0.8, 80)
    a.line([(0, 436), (565, 436)], PAL["gold_dark"], 1.5, alpha=180)
    armillary(a, 230, 330, 86)
    a.poly([(200, 430), (260, 430), (250, 410), (210, 410)], PAL["gold_dark"], INK, 1.2)
    # globe-like astrolabe & books
    a.poly([(340, 430), (470, 430), (468, 416), (342, 416)], PAL["burgundy"], INK, 1.2)
    a.poly([(350, 416), (462, 416), (460, 402), (352, 402)], hx("d8c8a2"), INK, 1.2)
    a.poly([(356, 402), (456, 402), (454, 388), (358, 388)], PAL["navy_mid"], INK, 1.2)
    a.circle(410, 360, 26, PAL["gold"], INK, 1.6)
    a.circle(410, 360, 19, None, INK, 1)
    for k in range(8):
        t = k * math.pi / 4
        a.line([(410, 360), (410 + math.cos(t) * 26, 360 + math.sin(t) * 26)], INK, 0.8)
    a.poly([(410, 340), (416, 360), (410, 380), (404, 360)], PAL["burgundy_light"], INK, 0.8)
    a.poly([(60, 430), (160, 430), (170, 462), (50, 462)], hx("e8dcc0"), INK, 1.2)
    for i in range(5):
        a.line([(70, 438 + i * 4), (150, 438 + i * 4)], INK, 0.8, alpha=130)
    # quill & ink, candle
    a.rect(500, 380, 516, 430, hx("e8dcc0"), INK, 1)
    flame(a, 508, 380, 26, 7)
    a.glow(508, 364, 150, PAL["gold_light"], 130, 2)
    a.glow(300, 330, 330, PAL["gold_light"], 40, 2)
    # telescope on stand
    a.line([(30, 540), (118, 400)], INK, 6)
    a.line([(200, 540), (118, 400)], INK, 6)
    a.poly([(110, 408), (330, 300), (338, 316), (118, 424)], hx("7a4a2a"), INK, 1.6)
    a.line([(150, 400), (322, 310)], PAL["gold"], 1.6)
    a.circle(334, 308, 11, PAL["gold_dark"], INK, 1.4)
    done(a, "science", seed=31, vig=0.55)


# ------------------------------------------------------------------ 12 coronation
def ev_coronation():
    a = new()
    hz = 320
    rr = random.Random(8)
    a.sky([(0, hx("160f22")), (1, hx("3a2238"))], 0, hz + 10, bands=7, seed=5, wob=0.01)
    # high windows
    for wx in (160, 320, 640, 800):
        a.poly(pointed_arch(wx, 240, 70, 190), hx("f0d68a"), INK, 2)
        a.line([(wx, 80), (wx, 240)], INK, 1.2)
        a.glow(wx, 150, 80, PAL["gold_light"], 100, 2)
    a.glow(480, 200, 380, PAL["gold_light"], 90, 2)
    for wx, dx in ((160, 160), (320, 160), (640, -160), (800, -160)):
        light_shaft(a, wx - 34, wx + 34, 150, wx - 34 + dx, wx + 34 + dx * 1.5, H, PAL["gold_light"], 24)
    checker_floor(a, 480, hz, hx("3a2a46"), hx("1a1228"), 16, 9, 1800, PAL["gold_dark"])
    a.rect(0, hz - 50, W, hz, hx("2a1c38"))
    a.hatch([(0, hz - 50), (W, hz - 50), (W, hz), (0, hz)], INK, 80, 3, 0.8, 70)
    # carpet
    cp = [(450, hz), (510, hz), (720, H), (240, H)]
    a.poly(cp, PAL["burgundy"], PAL["gold"], 2.4)
    a.hatch(cp, PAL["burgundy_dark"], 80, 3.5, 0.8, 110)
    for t in (0.15, 0.4, 0.7):
        y = hz + (H - hz) * t * t
        f = (y - hz) / (H - hz)
        a.line([(480 - 30 - 210 * f, y), (480 + 30 + 210 * f, y)], PAL["gold"], 1.2, alpha=150)
    # dais
    for i, (y0, hw) in enumerate([(hz + 4, 190), (hz - 8, 160), (hz - 20, 130)]):
        a.rect(480 - hw, y0, 480 + hw, y0 + 14, mix(PAL["gold_dark"], PAL["burgundy"], 0.3 + i * 0.1), INK, 1.2)
    # radiant rays behind crown
    cx, cy = 480, 190
    a.glow(cx, cy, 260, PAL["gold_light"], 200, 1.6)
    rays(a, cx, cy, 70, 330, 28, PAL["gold_light"], 44, 7, 0.1)
    # pedestal & cushion
    a.poly([(448, hz - 20), (512, hz - 20), (504, 240), (456, 240)], hx("3a2a48"), INK, 1.6)
    a.rect(440, 236, 520, 248, PAL["gold_dark"], INK, 1.2)
    a.poly([(446, 236), (514, 236), (524, 216), (436, 216)], PAL["burgundy_light"], PAL["gold"], 1.6)
    crown(a, 480, 168, 100)
    # columns with banners
    for x, w, yt, yb in [(70, 56, 30, H), (210, 40, 100, hz + 50), (750, 40, 100, hz + 50), (890, 56, 30, H)]:
        column(a, x, yt, yb, w, hx("4a3a5c"))
    for x, y in ((70, 120), (890, 120)):
        pts = [(x - 24, y), (x + 24, y), (x + 24, y + 150), (x, y + 130), (x - 24, y + 150)]
        a.poly(pts, PAL["burgundy"], PAL["gold"], 1.6)
        a.hatch(pts, PAL["burgundy_dark"], 70, 3, 0.8, 140)
        a.circle(x, y + 50, 10, PAL["gold"], INK, 1)
    # crowds along both sides of carpet
    cols = [PAL["burgundy"], PAL["navy_mid"], hx("3a2a4a"), PAL["verdigris_dark"], INK]
    for side in (-1, 1):
        for i in range(8):
            f = (i + 1) / 8
            x = 480 + side * (60 + 220 * f * f + 46 * i * 0.4 + rr.uniform(-8, 8)) + side * 40
            y = hz + 36 + (H - hz - 36) * f * f * 0.95
            h = 60 + 150 * f * f
            person(a, x, y, h, rr.choice(cols), hat=rr.choice(["cap", None, "wide"]), arm=(0.2, 0.3) if rr.random() < 0.35 else None)
    # dust glints
    for _ in range(80):
        x, y = rr.uniform(200, 760), rr.uniform(80, 400)
        a.circle(x, y, rr.uniform(0.6, 1.5), rgba(PAL["gold_light"], rr.randint(90, 220)))
    done(a, "coronation", seed=32, vig=0.55)


# ------------------------------------------------------------------ 13 harbor
def crane(a, x, y, h, col):
    a.line([(x, y), (x, y - h)], col, 5)
    a.line([(x - 22, y), (x, y - h * 0.6)], col, 3)
    a.line([(x + 22, y), (x, y - h * 0.6)], col, 3)
    a.line([(x, y - h), (x + h * 0.7, y - h * 0.82)], col, 4)
    a.line([(x, y - h * 0.5), (x + h * 0.7, y - h * 0.82)], col, 2)
    a.line([(x + h * 0.7, y - h * 0.82), (x + h * 0.7, y - h * 0.4)], col, 1.4)
    a.rect(x + h * 0.7 - 10, y - h * 0.4, x + h * 0.7 + 10, y - h * 0.3, col)


def ev_harbor():
    a = new()
    hz = 330
    rr = random.Random(15)
    a.sky([(0, hx("2a3a5c")), (0.4, hx("7a7a90")), (0.75, hx("e0b27a")), (1, PAL["gold_light"])], 0, hz + 10, bands=9, seed=11, wob=0.014)
    sx, sy = 430, 300
    a.glow(sx, sy, 380, hx("fbe2a0"), 180, 2)
    a.circle(sx, sy, 40, hx("fbeec8"))
    for i, (y, x0, x1, th, c, al) in enumerate([(110, 40, 440, 8, hx("b49a8a"), 140), (170, 520, 920, 9, hx("d0a890"), 150), (240, 60, 300, 7, hx("e2b88a"), 150)]):
        strata(a, y, x0, x1, th, c, al, i + 10)
    sea(a, hz, H, hx("8a8aa0"), PAL["navy"], PAL["gold_light"], PAL["navy_deep"], sun_x=sx, seed=9, rows=22, bands=7)
    # distant ships with masts
    for x, y, s, fl in [(300, hz + 8, 60, False), (560, hz + 6, 50, True), (680, hz + 12, 80, False)]:
        galleon(a, x, y, s, mix(PAL["navy_deep"], PAL["steel"], 0.35), mix(PAL["parchment"], PAL["steel"], 0.4), PAL["gold_dark"], mix(PAL["navy_deep"], PAL["steel"], 0.2), flip=fl)
    # lighthouse (left)
    lx = 120
    a.poly([(lx - 42, 440), (lx - 24, 190), (lx + 24, 190), (lx + 42, 440)], hx("2a3048"), INK, 1.6)
    a.hatch([(lx + 4, 190), (lx + 24, 190), (lx + 42, 440), (lx + 4, 440)], INK, 80, 3, 0.8, 110)
    for k in range(4):
        y = 230 + k * 50
        a.line([(lx - 24 - k * 3, y), (lx + 24 + k * 3, y)], hx("c8b890"), 6, alpha=160)
    a.rect(lx - 30, 178, lx + 30, 192, hx("1a2038"), INK, 1.2)
    a.rect(lx - 18, 142, lx + 18, 178, hx("f0cc7a"), INK, 1.6)
    a.glow(lx, 160, 130, PAL["gold_light"], 200, 2)
    a.poly([(lx - 24, 142), (lx + 24, 142), (lx, 108)], hx("3a2a44"), INK, 1.4)
    a.poly([(lx + 18, 160), (lx + 420, 120), (lx + 420, 220)], rgba(PAL["gold_light"], 34))
    a.poly([(lx - 90, 440), (lx + 90, 440), (lx + 60, 470), (lx - 60, 470)], hx("1a1f33"), INK, 1.4)
    # quay
    qy = 420
    a.poly([(0, qy + 20), (230, qy + 20), (210, H), (0, H)], hx("20253a"), INK, 1.4)
    a.hatch([(0, qy + 20), (230, qy + 20), (210, H), (0, H)], INK, 80, 4, 0.8, 90)
    a.poly([(440, qy - 6), (W, qy - 6), (W, H), (440, H)], hx("2a2a3a"), INK, 1.4)
    a.hatch([(440, qy - 6), (W, qy - 6), (W, H), (440, H)], INK, 80, 4, 0.8, 90)
    # warehouses right
    crane(a, 590, qy - 6, 190, INK)
    for i, (x, w, h) in enumerate([(600, 110, 120), (730, 100, 150), (850, 130, 110)]):
        col = mix(hx("4a3a44"), PAL["navy"], 0.2 + i * 0.1)
        house(a, x, qy - 6, w, h, col, mix(col, PAL["burgundy_dark"], 0.5), ink=INK, rw=0.06)
        for k in range(3):
            a.rect(x + 14 + k * (w - 28) / 3, qy - 6 - h + 26, x + 24 + k * (w - 28) / 3, qy - 6 - h + 50, hx("e6c876") if k == 1 else hx("1a1020"), INK, 1)
        a.rect(x + w / 2 - 14, qy - 6 - 40, x + w / 2 + 14, qy - 6, hx("0e0a14"), INK, 1)
    # moored galleon (foreground, near right) with furled sails
    a.ellipse(400, 482, 250, 12, rgba(PAL["navy_deep"], 130))
    galleon(a, 420, 470, 420, PAL["ink"], hx("c8bfa0"), PAL["gold"], PAL["ink"], flip=True, flag=PAL["burgundy_light"], sail_hatch=PAL["ink"])
    # barrels, crates, workers
    for x, w, h in [(520, 40, 48), (565, 40, 48), (610, 40, 48)]:
        barrel(a, x, qy + 36, w, h, hx("6a4a30"))
    crate(a, 660, qy + 44, 54, 44, hx("7a5a3a"))
    crate(a, 700, qy + 44, 44, 36, hx("8a6a44"))
    for x, y, h, arm in [(500, 492, 90, (0.25, 0.3)), (780, 505, 110, None), (830, 520, 100, (0.2, 0.4)), (900, 530, 120, None)]:
        person(a, x, y, h, INK, hat="wide" if x % 3 else "cap", arm=arm)
    # gulls
    birds(a, [(300, 120, 1.2), (340, 140, 1.0), (260, 160, 0.9), (620, 90, 1.1), (700, 110, 0.9)], INK, 10)
    done(a, "harbor", seed=33)


# ------------------------------------------------------------------ 14 mine
def ev_mine():
    a = new()
    vx, vy = 480, 250
    rock = hx("1c1a22")
    a.rect(0, 0, W, H, hx("0a080e"))
    # tunnel walls (perspective), lit by lantern glows
    wallL = [(0, 0), (vx - 110, vy - 80), (vx - 110, vy + 80), (0, H)]
    wallR = [(W, 0), (vx + 110, vy - 80), (vx + 110, vy + 80), (W, H)]
    ceil = [(0, 0), (W, 0), (vx + 110, vy - 80), (vx - 110, vy - 80)]
    floor = [(0, H), (W, H), (vx + 110, vy + 80), (vx - 110, vy + 80)]
    for poly, c1, c2 in [(wallL, hx("2a2430"), hx("14101a")), (wallR, hx("14101a"), hx("2a2430")), (ceil, hx("0e0b14"), hx("1c1624")), (floor, hx("3a2c22"), hx("14100e"))]:
        a.fill_grad(poly, c1, c2, horizontal=(poly is wallL or poly is wallR))
        a.hatch(poly, INK, 40, 4, 0.9, 90)
    a.rect(vx - 110, vy - 80, vx + 110, vy + 80, hx("0a080e"))
    a.glow(vx, vy, 130, PAL["gold_light"], 170, 1.8)
    a.poly(pointed_arch(vx, vy + 44, 76, 84), hx("f6dc98"))
    a.glow(vx, vy, 90, hx("fff0c0"), 160, 2)
    rr = random.Random(2)
    # timber frames at decreasing depth
    for d in [0.0, 0.3, 0.5, 0.64, 0.75, 0.83, 0.89]:
        f = 1 - d
        xl, xr = vx - 110 - (vx - 110) * f * 0.97, vx + 110 + (W - vx - 110) * f * 0.97
        yt, yb = vy - 80 - (vy - 80) * f * 0.97, vy + 80 + (H - vy - 80) * f * 0.97
        tw = max(3, 34 * f)
        wood = mix(hx("6a4a2a"), INK, 0.35 + d * 0.3)
        a.rect(xl, yt, xl + tw, yb, wood, INK, 1)
        a.rect(xr - tw, yt, xr, yb, wood, INK, 1)
        a.rect(xl, yt, xr, yt + tw * 0.9, wood, INK, 1)
        a.hatch([(xl, yt), (xl + tw, yt), (xl + tw, yb), (xl, yb)], INK, 80, 2.5, 0.7, 90)
        a.line([(xl + tw, yt + tw * 0.9), (xl + tw * 2.6, yt + tw * 2.6)], wood, tw * 0.5)
        a.line([(xr - tw, yt + tw * 0.9), (xr - tw * 2.6, yt + tw * 2.6)], wood, tw * 0.5)
        if d in (0.3, 0.64):
            lx = xl + tw * 1.2
            ly = yt + tw * 3.2
            a.line([(lx, yt + tw * 0.9), (lx, ly - 8)], INK, 1.2)
            lantern(a, lx, ly, 6 * f + 3, 120 * f + 40)
    # rails
    for off in (-34, 34):
        a.line([(vx + off * 0.3, vy + 80), (vx + off * 7.5, H)], hx("7a7a88"), 3.0)
    for i in range(12):
        t = (i / 12) ** 1.7
        y = vy + 82 + t * (H - vy - 82)
        w = 12 + 240 * t
        a.line([(vx - w, y), (vx + w, y)], hx("5a3a22"), 2 + 5 * t)
    # ore veins glinting in walls
    for _ in range(46):
        side = rr.choice([-1, 1])
        t = rr.uniform(0.05, 0.7)
        x = vx + side * (110 + (W / 2 - 110) * (1 - t)) * rr.uniform(0.6, 1.0)
        y = vy + (rr.uniform(-1, 1)) * (80 + (H / 2) * (1 - t))
        s = 3 + 16 * (1 - t) * rr.random()
        col = rr.choice([PAL["gold_light"], PAL["gold"], PAL["verdigris"], hx("b9c7e0")])
        a.poly([(x, y - s), (x + s * 0.6, y), (x, y + s * 0.9), (x - s * 0.6, y)], col, INK, 0.8)
        a.poly([(x, y - s), (x + s * 0.6, y), (x, y)], rgba((255, 255, 255), 90))
        if s > 9:
            a.glow(x, y, s * 3, col, 80, 2)
    # miners
    def miner(x, y, h, swing):
        person(a, x, y, h, INK, hat="cap")
        a.line([(x + h * 0.1, y - h * 0.55), (x + h * 0.38 * swing, y - h * 0.85)], INK, max(1, h * 0.05))
        a.line([(x + h * 0.38 * swing - h * 0.12, y - h * 0.85), (x + h * 0.38 * swing + h * 0.14, y - h * 0.9)], INK, max(1.5, h * 0.06))
        a.glow(x, y - h * 0.9, h * 0.8, PAL["gold_light"], 130, 2)
    miner(300, 470, 150, 1)
    miner(620, 330, 70, -1)
    miner(420, 300, 44, 1)
    # ore cart (foreground right)
    cx, cy = 700, 520
    a.poly([(cx - 110, cy - 90), (cx + 110, cy - 90), (cx + 90, cy - 10), (cx - 90, cy - 10)], hx("2a2418"), INK, 2)
    a.hatch([(cx - 110, cy - 90), (cx + 110, cy - 90), (cx + 90, cy - 10), (cx - 90, cy - 10)], INK, 80, 4, 0.9, 90)
    a.line([(cx - 106, cy - 70), (cx + 106, cy - 70)], hx("7a7a88"), 3)
    for i in range(12):
        x = cx - 90 + i * 16 + rr.uniform(-4, 4)
        s = rr.uniform(14, 30)
        col = rr.choice([hx("4a4658"), PAL["gold"], hx("3a3648"), PAL["gold_light"], hx("5a5a6a")])
        a.poly([(x - s * 0.6, cy - 88), (x - s * 0.3, cy - 88 - s), (x + s * 0.4, cy - 88 - s * 0.9), (x + s * 0.6, cy - 88)], col, INK, 1.2)
        if col in (PAL["gold"], PAL["gold_light"]):
            a.glow(x, cy - 100, s * 2, PAL["gold_light"], 100, 2)
    for wx in (-70, 70):
        a.circle(cx + wx, cy + 4, 26, hx("14101a"), INK, 3)
        a.circle(cx + wx, cy + 4, 8, hx("7a7a88"), INK, 1)
    # pick leaning
    a.line([(850, 540), (900, 400)], hx("4a3220"), 6)
    a.line([(865, 420), (940, 395)], hx("8a8a98"), 7)
    done(a, "mine", seed=34, vig=0.6)


# ------------------------------------------------------------------ 15 generic (map table)
def ev_generic():
    a = new()
    rr = random.Random(3)
    # table
    a.sky([(0, hx("1a1410")), (1, hx("2a1e16"))], 0, H, bands=0, seed=1)
    for i in range(80):
        y = rr.uniform(0, H)
        pts = [(x, y + math.sin(x / 90 + i) * 3) for x in range(0, W + 20, 20)]
        a.line(pts, hx("4a3424"), rr.uniform(0.6, 1.6), alpha=rr.randint(50, 120))
    # sheet
    sheet = [(90, 60), (880, 40), (895, 480), (80, 500)]
    a.poly([(x + 10, y + 14) for x, y in sheet], rgba((0, 0, 0), 120))
    tex = make_parchment(W * 2, H * 2, 4, tile=False)
    texim = Image.fromarray(np.clip(tex, 0, 255).astype(np.uint8), "RGB")
    tex_fill(a, [(x, y) for x, y in sheet], texim)
    a.poly(sheet, None, INK, 1.4)
    # coast & contour map
    land = [(130, 130), (260, 100), (330, 160), (430, 150), (480, 230), (420, 300), (330, 330), (300, 420), (200, 440), (140, 360), (170, 280), (120, 210)]
    sm = []
    for i in range(len(land)):
        p0, p1, p2 = land[i - 1], land[i], land[(i + 1) % len(land)]
        sm += bez(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2), p1, ((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2), 8)
    for k, (sc, al) in enumerate([(1.12, 60), (1.08, 90), (1.04, 120)]):
        cx_, cy_ = 300, 280
        a.line([(cx_ + (x - cx_) * sc, cy_ + (y - cy_) * sc) for x, y in sm] + [(cx_ + (sm[0][0] - cx_) * sc, cy_ + (sm[0][1] - cy_) * sc)], PAL["navy"], 0.9, alpha=al)
    a.poly(sm, hx("f1e7cc"), INK, 1.8)
    a.hatch(sm, INK, 40, 6, 0.5, 40)
    from art_backgrounds import mountain_glyph
    for x, y, s in [(230, 200, 14), (270, 240, 12), (210, 260, 11), (330, 210, 13), (380, 190, 11), (300, 330, 12)]:
        mountain_glyph(a, x, y, s, INK, hx("efe6cc"))
    # route (dotted) with X
    route = bez((250, 310), (520, 480), (760, 250), 40)
    for i in range(0, len(route) - 1, 2):
        a.line([route[i], route[i + 1]], PAL["burgundy_light"], 2.2)
    ex, ey = route[-1]
    a.line([(ex - 9, ey - 9), (ex + 9, ey + 9)], PAL["burgundy"], 3.4)
    a.line([(ex - 9, ey + 9), (ex + 9, ey - 9)], PAL["burgundy"], 3.4)
    a.circle(250, 310, 6, PAL["burgundy"], INK, 1)
    # island & ship
    isl = [(680, 150), (712, 120), (760, 118), (792, 150), (770, 190), (720, 196), (690, 180)]
    ism = []
    for i in range(len(isl)):
        p0, p1, p2 = isl[i - 1], isl[i], isl[(i + 1) % len(isl)]
        ism += bez(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2), p1, ((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2), 8)
    for sc in (1.18, 1.1):
        a.line([(735 + (x - 735) * sc, 158 + (y - 158) * sc) for x, y in ism + [ism[0]]], PAL["navy"], 0.9, alpha=90)
    a.poly(ism, hx("f1e7cc"), INK, 1.4)
    mountain_glyph(a, 742, 160, 10, INK, hx("efe6cc"))
    for k in range(18):
        x, y = rr.uniform(430, 640), rr.uniform(120, 470)
        a.line(bez((x, y), (x + 6, y - 4), (x + 12, y)), INK, 0.9, alpha=100)
    galleon(a, 600, 400, 130, INK, hx("f1e7cc"), PAL["gold"], INK, flag=PAL["burgundy_light"], sail_hatch=INK)
    for i in range(8):
        x = 540 + i * 18
        a.line(bez((x, 410), (x + 7, 405), (x + 14, 410)), INK, 0.9, alpha=110)
    compass_rose(a, 770, 380, 70, INK, PAL["gold"], PAL["burgundy_light"], hx("efe6cc"))
    # dividers
    a.line([(905, 330), (820, 120)], hx("b8a47a"), 5)
    a.line([(905, 330), (880, 100)], hx("b8a47a"), 5)
    a.circle(905, 330, 8, PAL["gold"], INK, 1.4)
    # wax seal with crown
    sx, sy = 160, 440
    a.circle(sx, sy, 30, PAL["burgundy"], INK, 1.8)
    a.circle(sx - 4, sy - 4, 24, PAL["burgundy_light"], None)
    a.circle(sx, sy, 22, None, PAL["burgundy_dark"], 1.6)
    crown(a, sx, sy - 2, 30, outline_w=0.5, band_gems=False)
    a.line([(sx + 14, sy + 24), (sx + 60, sy + 70)], PAL["burgundy"], 5)
    # quill
    from art_kit import quill
    quill(a, 880, 500, 220, math.radians(-150))
    # candle glow
    a.glow(120, 80, 520, hx("f6c46a"), 110, 1.6)
    done(a, "generic", seed=35, vig=0.6)


def render_all(only=None):
    fns = [ev_famine, ev_plague, ev_uprising, ev_court, ev_battle, ev_trade, ev_storm, ev_fire, ev_church,
           ev_diplomacy, ev_science, ev_coronation, ev_harbor, ev_mine, ev_generic]
    for fn in fns:
        if only and fn.__name__[3:] not in only:
            continue
        fn()
