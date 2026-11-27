#!/usr/bin/env python3
"""IMPERIUM icon generator.

Writes one original SVG per icon id into assets/icons/<id>.svg.
Style (see docs/ART_DIRECTION.md): viewBox 0 0 64 64, pure white #ffffff glyphs on
transparent, 4px stroke, rounded joins and caps, ~6px padding. One concept per icon.

Run:  python3 tools/assets/gen_icons.py
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "icons"))

# --------------------------------------------------------------------------- primitives


def f(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def pts(p):
    return " ".join(f"{f(x)},{f(y)}" for x, y in p)


FILL = ' fill="#ffffff"'


def poly(p, close=True, fill=False):
    return f'<{"polygon" if close else "polyline"} points="{pts(p)}"{FILL if fill else ""}/>'


def line(*p):
    return poly(p, close=False)


def path(d, fill=False):
    return f'<path d="{d}"{FILL if fill else ""}/>'


def circle(cx, cy, r, fill=False):
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}"{FILL if fill else ""}/>'


def ellipse(cx, cy, rx, ry, fill=False):
    return f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}"{FILL if fill else ""}/>'


def rect(x, y, w, h, r=0, fill=False):
    return (f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="{f(r)}"'
            f'{FILL if fill else ""}/>')


def dot(cx, cy, r=2.5):
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="#ffffff" stroke="none"/>'


# --------------------------------------------------------------------------- geometry helpers


def polar(cx, cy, r, deg):
    a = math.radians(deg)
    return (cx + r * math.cos(a), cy + r * math.sin(a))


def arc(cx, cy, r, a0, a1):
    """Open arc path; angles in degrees, 0 = east, increasing clockwise on screen."""
    x0, y0 = polar(cx, cy, r, a0)
    x1, y1 = polar(cx, cy, r, a1)
    large = 1 if abs(a1 - a0) > 180 else 0
    sweep = 1 if a1 > a0 else 0
    return path(f"M{f(x0)} {f(y0)} A{f(r)} {f(r)} 0 {large} {sweep} {f(x1)} {f(y1)}")


def rrect(cx, cy, w, h, deg):
    """Rotated rectangle polygon points; w runs along `deg`."""
    a = math.radians(deg)
    ux, uy = math.cos(a), math.sin(a)
    vx, vy = -uy, ux
    out = []
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        out.append((cx + ux * w / 2 * sx + vx * h / 2 * sy, cy + uy * w / 2 * sx + vy * h / 2 * sy))
    return out


def leaf(x, y, deg, length, wid, fill=False):
    a = math.radians(deg)
    dx, dy = math.cos(a), math.sin(a)
    tx, ty = x + dx * length, y + dy * length
    mx, my = x + dx * length / 2, y + dy * length / 2
    nx, ny = -dy, dx
    c1 = (mx + nx * wid, my + ny * wid)
    c2 = (mx - nx * wid, my - ny * wid)
    return path(f"M{f(x)} {f(y)} Q{f(c1[0])} {f(c1[1])} {f(tx)} {f(ty)} "
                f"Q{f(c2[0])} {f(c2[1])} {f(x)} {f(y)} Z", fill)


def star(cx, cy, ro, ri, n=5, rot=-90):
    out = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        out.append(polar(cx, cy, r, rot + i * 180 / n))
    return out


def gear(cx, cy, ro, ri, n, hole):
    step = 360 / n
    out = []
    for i in range(n):
        a = i * step
        out += [polar(cx, cy, ri, a - step * 0.32), polar(cx, cy, ro, a - step * 0.17),
                polar(cx, cy, ro, a + step * 0.17), polar(cx, cy, ri, a + step * 0.32)]
    return [poly(out), circle(cx, cy, hole)]


def person(cx, cy, s=1.0, fill=False):
    """Head and shoulders; (cx, cy) = head centre."""
    r = 7 * s
    top = cy + 12 * s
    bot = cy + 30 * s
    w = 14 * s
    return [circle(cx, cy, r, fill),
            path(f"M{f(cx - w)} {f(bot)} Q{f(cx - w)} {f(top)} {f(cx)} {f(top)} "
                 f"Q{f(cx + w)} {f(top)} {f(cx + w)} {f(bot)} Z", fill)]


def crown(cx, y, w, h, fill=False):
    x0, x1 = cx - w / 2, cx + w / 2
    return poly([(x0, y + h), (x0, y + h * 0.15), (cx - w / 4, y + h * 0.55), (cx, y),
                 (cx + w / 4, y + h * 0.55), (x1, y + h * 0.15), (x1, y + h)], True, fill)


def sword(h, t, guard=8, gpos=11):
    dx, dy = t[0] - h[0], t[1] - h[1]
    d = math.hypot(dx, dy)
    dx, dy = dx / d, dy / d
    nx, ny = -dy, dx
    g = (h[0] + dx * gpos, h[1] + dy * gpos)
    return [line(h, g), line((g[0] - nx * guard, g[1] - ny * guard), (g[0] + nx * guard, g[1] + ny * guard)),
            line(g, t), dot(h[0], h[1], 3)]


def shield(x0=14, x1=50, top=10, mid=34, bot=58):
    cx = (x0 + x1) / 2
    return path(f"M{x0} {top} H{x1} V{mid} Q{x1} {bot - 8} {cx} {bot} Q{x0} {bot - 8} {x0} {mid} Z")


def coin_stack(cx, y, rx, layers=1):
    out = [ellipse(cx, y, rx, 8)]
    for i in range(layers):
        yy = y + i * 10
        out.append(path(f"M{cx - rx} {yy} V{yy + 6} Q{cx - rx} {yy + 14} {cx} {yy + 14} "
                        f"Q{cx + rx} {yy + 14} {cx + rx} {yy + 6} V{yy}"))
    return out


def pine(cx, top, w, h):
    """Two-tier conifer silhouette with trunk."""
    hw = w / 2
    m = top + h * 0.5
    b = top + h * 0.82
    return [poly([(cx, top), (cx + hw * 0.65, m - 2), (cx + hw * 0.3, m - 2), (cx + hw, b),
                  (cx - hw, b), (cx - hw * 0.3, m - 2), (cx - hw * 0.65, m - 2)]),
            line((cx, b), (cx, top + h))]


def crescent(cx, cy, R, fill=True):
    p1 = polar(cx, cy, R, -50)
    p2 = polar(cx, cy, R, 50)
    ic = (cx + R * 0.36, cy)
    r2 = math.hypot(p1[0] - ic[0], p1[1] - ic[1])
    return path(f"M{f(p1[0])} {f(p1[1])} A{f(R)} {f(R)} 0 1 0 {f(p2[0])} {f(p2[1])} "
                f"A{f(r2)} {f(r2)} 0 1 1 {f(p1[0])} {f(p1[1])} Z", fill)


def laurel(cx, cy, r, a0=105, a1=250, n=5):
    """Two mirrored laurel branches (left from a0..a1, right mirrored)."""
    out = []
    for side in (1, -1):
        def ang(a):
            return a if side == 1 else 180 - a
        pa, pb = ang(a0), ang(a1)
        out.append(arc(cx, cy, r, pa, pb) if side == 1 else arc(cx, cy, r, pa, pb))
        for i in range(n):
            a = a0 + (a1 - a0) * (i + 0.5) / n
            px, py = polar(cx, cy, r, ang(a))
            tang = ang(a) + (90 if side == 1 else -90)
            out.append(leaf(px, py, tang - 38 * side, 11, 4, True))
            out.append(leaf(px, py, tang + 38 * side, 11, 4, True))
    return out


# --------------------------------------------------------------------------- registry
ICONS = {}


def icon(*names):
    def deco(fn):
        for n in names:
            ICONS[n] = fn
        return fn
    return deco


# ============================================================= resources / stats


@icon("gold")
def _():
    return [circle(32, 32, 22), circle(32, 32, 12)]


@icon("food")
def _():
    e = [line((32, 56), (32, 26))]
    for y in (48, 36):
        e += [leaf(32, y, -135, 15, 5, True), leaf(32, y, -45, 15, 5, True)]
    e.append(leaf(32, 28, -90, 18, 5, True))
    return e


@icon("manpower")
def _():
    return [circle(25, 20, 7), path("M11 52 Q11 33 25 33 Q39 33 39 52 Z"),
            line((51, 56), (51, 24)), leaf(51, 28, -90, 20, 5, True)]


@icon("iron")
def _():
    return [poly([(20, 22), (54, 22), (46, 34), (12, 34)]), poly([(12, 34), (46, 34), (46, 50), (12, 50)]),
            poly([(46, 34), (54, 22), (54, 38), (46, 50)])]


@icon("wood")
def _():
    return [line((16, 18), (46, 18)), line((16, 46), (46, 46)), path("M16 18 A8 14 0 0 0 16 46"),
            ellipse(46, 32, 8, 14), dot(46, 32, 2.5)]


@icon("stone")
def _():
    return [poly([(8, 48), (12, 32), (24, 16), (42, 14), (54, 28), (56, 48)]),
            line((24, 16), (32, 32), (54, 28)), line((32, 32), (30, 48))]


@icon("coal")
def _():
    return [poly([(8, 42), (16, 24), (34, 16), (46, 28), (44, 44), (24, 50)], True, True),
            poly([(38, 50), (44, 44), (54, 46), (54, 52), (46, 56)], True, True)]


@icon("luxury")
def _():
    return [poly([(18, 14), (46, 14), (56, 26), (32, 54), (8, 26)]), line((8, 26), (56, 26)),
            line((24, 26), (32, 54), (40, 26)), line((24, 26), (32, 14), (40, 26))]


@icon("prestige")
def _():
    return [poly(star(32, 34, 25, 11))]


@icon("admin")
def _():
    return [leaf(16, 50, -48, 46, 15), line((16, 50), (44, 20)), line((16, 50), (10, 57))]


@icon("stability")
def _():
    return [rect(12, 8, 40, 8, 2), rect(12, 48, 40, 8, 2), line((20, 16), (20, 48)), line((44, 16), (44, 48)),
            line((32, 16), (32, 48))]


@icon("legitimacy")
def _():
    return [shield(12, 52, 8, 32, 56), crown(32, 22, 22, 18, True)]


@icon("inflation")
def _():
    return [circle(20, 40, 12), line((46, 56), (46, 12)), line((36, 22), (46, 12), (56, 22))]


@icon("debt")
def _():
    return [circle(20, 24, 12), line((46, 8), (46, 52)), line((36, 42), (46, 52), (56, 42))]


@icon("trade")
def _():
    return [line((10, 22), (54, 22)), line((44, 12), (54, 22), (44, 32)),
            line((54, 42), (10, 42)), line((20, 32), (10, 42), (20, 52))]


@icon("research")
def _():
    return [path("M26 8 V24 L10 50 Q8 56 14 56 H50 Q56 56 54 50 L38 24 V8"), line((22, 8), (42, 8)),
            line((17, 42), (47, 42))]


@icon("population")
def _():
    return person(32, 20, 1.0) + [circle(13, 28, 5), path("M7 52 Q7 40 13 40 Q16 40 19 42"),
                                  circle(51, 28, 5), path("M57 52 Q57 40 51 40 Q48 40 45 42")]


@icon("income")
def _():
    return coin_stack(32, 42, 20, 1) + [line((32, 8), (32, 26)), line((24, 18), (32, 26), (40, 18))]


@icon("expense")
def _():
    return coin_stack(32, 42, 20, 1) + [line((32, 28), (32, 8)), line((24, 16), (32, 8), (40, 16))]


# ============================================================= ui


@icon("end_turn")
def _():
    return [poly([(12, 12), (42, 32), (12, 52)], True, True), line((52, 12), (52, 52))]


@icon("menu")
def _():
    return [line((10, 16), (54, 16)), line((10, 32), (54, 32)), line((10, 48), (54, 48))]


@icon("settings")
def _():
    return gear(32, 32, 24, 18, 8, 7)


@icon("save")
def _():
    return [path("M10 14 Q10 10 14 10 H44 L54 20 V50 Q54 54 50 54 H14 Q10 54 10 50 Z"),
            rect(20, 10, 16, 12), rect(18, 34, 28, 20, 2)]


@icon("load")
def _():
    return [path("M8 50 V16 Q8 12 12 12 H24 L30 20 H52 Q56 20 56 24 V50 Q56 54 52 54 H12 Q8 54 8 50 Z"),
            line((32, 46), (32, 30)), line((25, 37), (32, 30), (39, 37))]


@icon("close")
def _():
    return [line((14, 14), (50, 50)), line((50, 14), (14, 50))]


@icon("back")
def _():
    return [line((12, 32), (54, 32)), line((26, 18), (12, 32), (26, 46))]


@icon("next")
def _():
    return [line((10, 32), (52, 32)), line((38, 18), (52, 32), (38, 46))]


@icon("plus")
def _():
    return [line((32, 12), (32, 52)), line((12, 32), (52, 32))]


@icon("minus")
def _():
    return [line((12, 32), (52, 32))]


@icon("check")
def _():
    return [circle(32, 32, 23), line((20, 33), (29, 42), (44, 24))]


@icon("cross")
def _():
    return [circle(32, 32, 23), line((23, 23), (41, 41)), line((41, 23), (23, 41))]


@icon("info")
def _():
    return [circle(32, 32, 23), dot(32, 20, 3), line((32, 29), (32, 45))]


@icon("warning")
def _():
    return [poly([(32, 10), (56, 52), (8, 52)]), line((32, 25), (32, 37)), dot(32, 44.5, 3)]


@icon("lock")
def _():
    return [rect(13, 28, 38, 26, 4), path("M21 28 V20 Q21 8 32 8 Q43 8 43 20 V28"), dot(32, 39, 3.5),
            line((32, 39), (32, 46))]


@icon("search")
def _():
    return [circle(26, 26, 16), line((38, 38), (54, 54))]


@icon("filter")
def _():
    return [poly([(8, 12), (56, 12), (38, 34), (38, 54), (26, 48), (26, 34)])]


@icon("map")
def _():
    return [path("M8 14 L22 10 L42 16 L56 12 V50 L42 54 L22 48 L8 52 Z"), line((22, 10), (22, 48)),
            line((42, 16), (42, 54))]


@icon("zoom_in")
def _():
    return [circle(27, 27, 17), line((40, 40), (54, 54)), line((19, 27), (35, 27)), line((27, 19), (27, 35))]


@icon("zoom_out")
def _():
    return [circle(27, 27, 17), line((40, 40), (54, 54)), line((19, 27), (35, 27))]


@icon("mode_political")
def _():
    return [poly([(8, 20), (24, 10), (44, 14), (56, 26), (52, 46), (34, 56), (14, 50)]),
            line((24, 10), (30, 34)), line((56, 26), (30, 34)), line((14, 50), (30, 34))]


@icon("mode_terrain")
def _():
    return [path("M10 34 Q8 14 28 12 Q54 10 54 32 Q54 54 30 54 Q12 54 10 34 Z"),
            path("M20 34 Q20 22 30 22 Q44 22 44 32 Q44 44 30 44 Q20 44 20 34 Z"), dot(32, 33, 3)]


@icon("mode_economic")
def _():
    return [ellipse(32, 14, 18, 7), path("M14 14 V24 Q14 31 32 31 Q50 31 50 24 V14"),
            path("M14 24 V34 Q14 41 32 41 Q50 41 50 34"), path("M14 34 V44 Q14 51 32 51 Q50 51 50 44 V34")]


@icon("mode_diplomatic")
def _():
    return [circle(32, 32, 23), ellipse(32, 32, 10, 23), line((9, 32), (55, 32))]


@icon("mode_military")
def _():
    return [rect(8, 16, 48, 32, 2), line((8, 16), (56, 48)), line((56, 16), (8, 48))]


@icon("mode_population")
def _():
    return [circle(32, 32, 24), circle(32, 24, 5), path("M22 44 Q22 34 32 34 Q42 34 42 44 Z")]


@icon("mode_supply")
def _():
    return [rect(8, 16, 36, 22, 2), line((44, 26), (56, 20)), circle(18, 48, 6), circle(36, 48, 6)]


@icon("mode_trade")
def _():
    return [circle(14, 48, 5, True), circle(50, 16, 5, True), path("M14 44 C14 22 50 42 50 21")]


@icon("mode_religion")
def _():
    return [line((32, 8), (32, 56)), line((16, 24), (48, 24)), circle(32, 24, 6)]


@icon("mode_culture")
def _():
    return [path("M12 52 L12 24 L32 10 L52 24 L52 52 Z"), line((24, 52), (24, 34)), line((40, 52), (40, 34)), line((8, 52), (56, 52))]


@icon("mode_infrastructure")
def _():
    return [line((14, 56), (26, 8)), line((50, 56), (38, 8)), line((20, 34), (44, 34)), line((17, 46), (47, 46)), line((23, 20), (41, 20))]


@icon("mode_unrest")
def _():
    return [line((30, 6), (22, 28), (34, 28), (26, 58)), line((44, 14), (50, 22)), line((16, 38), (10, 46))]


@icon("mode_admin")
def _():
    return [rect(14, 10, 36, 44, 3), line((22, 22), (42, 22)), line((22, 32), (42, 32)), line((22, 42), (34, 42))]


@icon("mode_development")
def _():
    return [line((10, 54), (54, 54)), rect(14, 38, 10, 16), rect(27, 28, 10, 26), rect(40, 14, 10, 40)]


@icon("mode_naval")
def _():
    return [circle(32, 14, 5), line((32, 19), (32, 54)), line((20, 30), (44, 30)), path("M12 40 Q14 54 32 56 Q50 54 52 40")]


# ============================================================= panels


@icon("country")
def _():
    return [line((14, 8), (14, 56)), poly([(14, 10), (52, 10), (44, 22), (52, 34), (14, 34)])]


@icon("economy")
def _():
    return [path("M24 10 L28 20 C14 28 10 40 14 48 C18 56 46 56 50 48 C54 40 50 28 36 20 L40 10 Z"),
            line((28, 20), (36, 20)), dot(32, 40, 4)]


@icon("military")
def _():
    return [line((32, 8), (32, 56)), line((16, 14), (48, 14)), poly([(20, 14), (44, 14), (44, 42), (32, 35), (20, 42)])]


@icon("diplomacy")
def _():
    return [rect(8, 14, 48, 36, 4), line((8, 17), (32, 36), (56, 17))]


@icon("technology")
def _():
    return [path("M22 38 Q12 30 12 22 Q12 8 32 8 Q52 8 52 22 Q52 30 42 38 V44 H22 Z"), line((24, 52), (40, 52))]


@icon("construction")
def _():
    return [rect(8, 10, 48, 44, 3), line((8, 24), (56, 24)), line((8, 38), (56, 38)), line((32, 10), (32, 24)),
            line((20, 24), (20, 38)), line((44, 24), (44, 38)), line((32, 38), (32, 54))]


@icon("events")
def _():
    return [rect(8, 14, 48, 42, 4), line((8, 26), (56, 26)), line((20, 8), (20, 18)), line((44, 8), (44, 18)),
            dot(20, 37), dot(32, 37), dot(44, 37), dot(20, 47), dot(32, 47)]


@icon("objectives")
def _():
    return [circle(32, 32, 23), circle(32, 32, 11), dot(32, 32, 3)]


@icon("politics")
def _():
    return [arc(32, 50, 24, 180, 360), arc(32, 50, 12, 180, 360), line((8, 50), (56, 50)), line((8, 56), (56, 56))]


@icon("history")
def _():
    return [line((16, 8), (48, 8)), line((16, 56), (48, 56)),
            path("M20 8 V18 Q20 28 32 32 Q20 36 20 46 V56"), path("M44 8 V18 Q44 28 32 32 Q44 36 44 46 V56")]


@icon("statistics")
def _():
    return [circle(30, 34, 22), path("M34 30 L34 10 A20 20 0 0 1 54 30 Z", True)]


@icon("achievements")
def _():
    return [path("M20 10 H44 V26 Q44 38 32 38 Q20 38 20 26 Z"), path("M20 14 H12 Q10 26 22 30"),
            path("M44 14 H52 Q54 26 42 30"), line((32, 38), (32, 50)), line((20, 54), (44, 54))]


@icon("editor")
def _():
    a = math.radians(-45)
    d = (math.cos(a), math.sin(a))
    n = (-d[1], d[0])
    T = (10, 54)
    C = (T[0] + d[0] * 11, T[1] + d[1] * 11)
    E = (T[0] + d[0] * 40, T[1] + d[1] * 40)
    k = 5.5
    body = [T, (C[0] + n[0] * k, C[1] + n[1] * k), (E[0] + n[0] * k, E[1] + n[1] * k),
            (E[0] - n[0] * k, E[1] - n[1] * k), (C[0] - n[0] * k, C[1] - n[1] * k)]
    F = (E[0] + d[0] * 9, E[1] + d[1] * 9)
    cap = [(E[0] + n[0] * k, E[1] + n[1] * k), (F[0] + n[0] * k, F[1] + n[1] * k),
           (F[0] - n[0] * k, F[1] - n[1] * k), (E[0] - n[0] * k, E[1] - n[1] * k)]
    return [poly(body), poly(cap)]


@icon("credits")
def _():
    return [rect(14, 8, 36, 48, 3), line((22, 20), (42, 20)), line((22, 30), (42, 30)), line((22, 40), (34, 40))]


@icon("language")
def _():
    return [path("M16 10 H48 Q56 10 56 18 V36 Q56 44 48 44 H34 L22 56 V44 H16 Q8 44 8 36 V18 Q8 10 16 10 Z"),
            line((19, 22), (45, 22)), line((19, 32), (35, 32))]


@icon("sound")
def _():
    return [poly([(8, 24), (18, 24), (30, 12), (30, 52), (18, 40), (8, 40)]), arc(30, 32, 12, -45, 45),
            arc(30, 32, 22, -45, 45)]


@icon("music")
def _():
    return [circle(18, 48, 6, True), circle(42, 44, 6, True), line((24, 48), (24, 16)), line((48, 44), (48, 12)),
            poly([(24, 14), (48, 9), (48, 18), (24, 23)], True, True)]


@icon("video")
def _():
    return [rect(8, 10, 48, 34, 4), line((32, 44), (32, 52)), line((20, 54), (44, 54)),
            poly([(27, 19), (27, 35), (40, 27)], True, True)]


# ============================================================= military


@icon("unit_infantry")
def _():
    return [circle(24, 38, 15), dot(24, 38, 3.5)] + sword((50, 56), (50, 8), 7, 12)


@icon("unit_heavy_infantry")
def _():
    return [shield(14, 50, 8, 32, 56), line((21, 24), (32, 36), (43, 24)), line((32, 36), (32, 50))]


@icon("unit_archers")
def _():
    return [path("M24 8 Q2 32 24 56"), line((24, 8), (24, 56)), line((24, 32), (56, 32)),
            line((48, 24), (56, 32), (48, 40))]


HORSE = [(14, 56), (18, 40), (28, 32), (20, 30), (10, 36), (8, 28), (22, 12), (28, 8), (32, 14),
         (42, 14), (52, 30), (52, 56)]


@icon("unit_cavalry")
def _():
    return [poly(HORSE), dot(33, 22, 2.5)]


@icon("unit_heavy_cavalry")
def _():
    return [poly(HORSE), dot(33, 22, 2.5), line((12, 52), (52, 12))]


@icon("unit_artillery")
def _():
    return [poly([(10, 30), (44, 12), (54, 24), (22, 42)]), circle(30, 46, 9), dot(30, 46, 2.5),
            line((8, 56), (56, 56))]


@icon("unit_engineer")
def _():
    return [line((12, 52), (46, 18)), path("M20 10 Q50 8 56 40")]


def ship():
    return [path("M8 40 H56 Q50 54 40 54 H24 Q14 54 8 40 Z"), line((32, 8), (32, 40)),
            poly([(34, 12), (52, 34), (34, 34)])]


@icon("unit_naval")
def _():
    return ship()


@icon("general")
def _():
    return [poly(star(32, 24, 18, 8), True, True), line((18, 48), (32, 56), (46, 48))]


@icon("siege")
def _():
    return [poly([(16, 56), (32, 30), (48, 56)]), line((10, 46), (50, 14)), circle(50, 14, 5),
            rect(8, 44, 10, 10, 1, True)]


@icon("battle")
def _():
    return [poly(star(32, 32, 25, 12, 10, -90)), dot(32, 32, 3)]


@icon("move")
def _():
    return [dot(10, 32), dot(22, 32), line((32, 32), (54, 32)), line((44, 20), (54, 32), (44, 44))]


@icon("recruit")
def _():
    return [circle(24, 22, 7), path("M10 54 Q10 35 24 35 Q38 35 38 54 Z"), line((46, 12), (46, 32)),
            line((36, 22), (56, 22))]


@icon("disband")
def _():
    return [circle(24, 22, 7), path("M10 54 Q10 35 24 35 Q38 35 38 54 Z"), line((42, 12), (56, 28)),
            line((56, 12), (42, 28))]


@icon("merge")
def _():
    return [line((12, 10), (32, 30)), line((52, 10), (32, 30)), line((32, 30), (32, 54)),
            line((23, 45), (32, 54), (41, 45))]


@icon("split")
def _():
    return [line((32, 8), (32, 30)), line((32, 30), (12, 54)), line((32, 30), (52, 54)),
            line((12, 42), (12, 54), (24, 54)), line((52, 42), (52, 54), (40, 54))]


@icon("fort")
def _():
    return [path("M10 56 V18 H18 V24 H26 V18 H38 V24 H46 V18 H54 V56 Z"),
            path("M26 56 V44 Q26 36 32 36 Q38 36 38 44 V56")]


# ============================================================= diplomacy


@icon("war")
def _():
    return sword((10, 54), (52, 12)) + sword((54, 54), (12, 12))


@icon("peace")
def _():
    p0, p1, p2 = (13, 50), (14, 28), (44, 20)
    e = [path(f"M{p0[0]} {p0[1]} Q{p1[0]} {p1[1]} {p2[0]} {p2[1]}")]
    for t in (0.25, 0.45, 0.65, 0.85):
        x = (1 - t) ** 2 * p0[0] + 2 * t * (1 - t) * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * t * (1 - t) * p1[1] + t * t * p2[1]
        tx = 2 * (1 - t) * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0])
        ty = 2 * (1 - t) * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1])
        ang = math.degrees(math.atan2(ty, tx))
        e.append(leaf(x, y, ang - 60, 12, 4.5, True))
        e.append(leaf(x, y, ang + 60, 12, 4.5, True))
    return e


@icon("alliance")
def _():
    return [circle(22, 32, 15), circle(42, 32, 15)]


@icon("nap")
def _():
    return [circle(32, 32, 24), line((15, 15), (49, 49))] + sword((20, 44), (44, 20), 6, 8)


@icon("defensive")
def _():
    return [shield(12, 52, 8, 32, 56), line((12, 26), (52, 26))]


@icon("access")
def _():
    return [path("M12 56 V28 Q12 8 32 8 Q52 8 52 28 V56"), line((22, 38), (46, 38)), line((38, 28), (46, 38), (38, 48))]


@icon("trade_agreement")
def _():
    return [rect(12, 8, 40, 48, 4), line((22, 24), (42, 24)), line((36, 17), (42, 24), (36, 31)),
            line((42, 40), (22, 40)), line((28, 33), (22, 40), (28, 47))]


@icon("vassal")
def _():
    return [crown(32, 8, 36, 22), circle(26, 46, 8), circle(38, 46, 8)]


@icon("guarantee")
def _():
    return [shield(12, 52, 8, 32, 56), line((21, 31), (29, 39), (43, 22))]


@icon("gift")
def _():
    return [rect(10, 28, 44, 26, 3), rect(8, 20, 48, 8, 2), line((32, 20), (32, 54)),
            path("M32 20 Q18 4 16 14 Q18 22 32 20"), path("M32 20 Q46 4 48 14 Q46 22 32 20")]


@icon("relations")
def _():
    return [path("M32 54 L10 30 Q4 20 12 14 Q22 8 32 20 Q42 8 52 14 Q60 20 54 30 Z")]


@icon("sanction")
def _():
    return [circle(32, 32, 22), circle(32, 32, 12), line((12, 52), (52, 12))]


@icon("embargo")
def _():
    return [rect(10, 16, 40, 36, 3), line((10, 28), (50, 28)), line((30, 28), (30, 52)), line((8, 56), (56, 8))]


@icon("coalition")
def _():
    return [line((32, 14), (14, 50), (50, 50), (32, 14)), circle(32, 14, 6, True), circle(14, 50, 6, True),
            circle(50, 50, 6, True)]


@icon("transfer")
def _():
    return [rect(8, 16, 26, 32, 3), line((28, 32), (56, 32)), line((46, 22), (56, 32), (46, 42))]


@icon("assist")
def _():
    return [shield(12, 52, 8, 32, 56), line((32, 20), (32, 42)), line((22, 31), (42, 31))]


# ============================================================= terrain


@icon("terrain_plains")
def _():
    e = [line((8, 50), (56, 50)), circle(44, 18, 7)]
    for x in (16, 32):
        e += [line((x, 50), (x - 6, 40)), line((x, 50), (x, 36)), line((x, 50), (x + 6, 40))]
    return e


@icon("terrain_hills")
def _():
    return [path("M8 50 Q22 16 36 50"), path("M28 50 Q42 24 56 50")]


@icon("terrain_mountains")
def _():
    return [poly([(8, 52), (24, 24), (32, 36), (42, 12), (56, 52)]), line((35, 26), (42, 34), (48, 26))]


@icon("terrain_forest")
def _():
    return pine(22, 10, 24, 46) + pine(44, 22, 20, 34)


@icon("terrain_desert")
def _():
    return [line((32, 56), (32, 10)), path("M32 40 H20 V24"), path("M32 32 H44 V18"), line((10, 56), (54, 56))]


@icon("terrain_jungle")
def _():
    return [path("M31 56 Q35 38 32 22"), path("M32 22 Q20 6 8 20"), path("M32 22 Q44 6 56 20"),
            path("M32 22 Q22 20 12 34"), path("M32 22 Q42 20 52 34"), path("M32 22 Q30 12 32 8")]


@icon("terrain_marsh")
def _():
    e = [path("M8 52 Q16 46 24 52 T40 52 T56 52")]
    for x, top in ((18, 16), (32, 10), (46, 18)):
        e += [line((x, 46), (x, top + 12)), ellipse(x, top + 6, 3, 7, True)]
    return e


@icon("terrain_steppe")
def _():
    return [path("M8 36 Q32 4 56 36"), rect(10, 36, 44, 18, 2), path("M26 54 V44 Q26 40 32 40 Q38 40 38 44 V54")]


@icon("terrain_arctic")
def _():
    e = []
    for a in (0, 60, 120):
        p1, p2 = polar(32, 32, 24, a), polar(32, 32, 24, a + 180)
        e.append(line(p1, p2))
        for ang in (a, a + 180):
            bx, by = polar(32, 32, 14, ang)
            e.append(line(polar(bx, by, 9, ang - 45), (bx, by), polar(bx, by, 9, ang + 45)))
    return e


# ============================================================= buildings


@icon("b_farm")
def _():
    return [path("M10 56 V28 L32 10 L54 28 V56 Z"), rect(22, 36, 20, 20), line((22, 36), (42, 56)),
            line((42, 36), (22, 56))]


@icon("b_market")
def _():
    return [path("M8 12 H56 V26 Q50 32 44 26 Q38 32 32 26 Q26 32 20 26 Q14 32 8 26 Z"),
            line((12, 32), (12, 56)), line((52, 32), (52, 56)), line((12, 46), (52, 46))]


@icon("b_workshop")
def _():
    return [path("M8 20 H52 Q56 20 56 26 Q56 32 44 32 V38 Q50 40 50 50 H18 Q18 40 24 38 V32 Q12 32 6 20 Z"),
            line((12, 56), (56, 56))]


@icon("b_mine")
def _():
    return [poly([(8, 56), (22, 16), (42, 16), (56, 56)]), path("M24 56 V40 Q24 32 32 32 Q40 32 40 40 V56")]


@icon("b_sawmill")
def _():
    step = 360 / 12
    p = []
    for i in range(12):
        a = i * step
        p += [polar(32, 32, 17, a), polar(32, 32, 25, a + step * 0.25)]
    return [poly(p), circle(32, 32, 6)]


@icon("b_port")
def _():
    return [circle(32, 12, 5), line((32, 17), (32, 54)), line((22, 26), (42, 26)),
            path("M10 38 Q14 54 32 54 Q50 54 54 38"), line((10, 46), (10, 38), (18, 40)),
            line((54, 46), (54, 38), (46, 40))]


@icon("b_trading_center")
def _():
    return [poly([(8, 28), (32, 8), (56, 28)]), path("M12 28 V54 H52 V28"), circle(32, 40, 8)]


@icon("b_barracks")
def _():
    return [poly([(8, 28), (32, 8), (56, 28)]), path("M12 28 V54 H52 V28"),
            line((24, 34), (40, 48)), line((40, 34), (24, 48))]


@icon("b_fort")
def _():
    return [path("M12 56 V14 H20 V22 H28 V14 H36 V22 H44 V14 H52 V56 Z"), line((32, 34), (32, 44))]


@icon("b_arsenal")
def _():
    return [circle(22, 42, 9), circle(42, 42, 9), circle(32, 23, 9), line((8, 56), (56, 56))]


@icon("b_military_academy")
def _():
    return [path("M8 38 Q20 32 32 40 Q44 32 56 38 V54 Q44 48 32 56 Q20 48 8 54 Z"), line((32, 40), (32, 56)),
            poly(star(32, 19, 11, 5), True, True)]


@icon("b_government_office")
def _():
    return [rect(12, 24, 40, 32, 2), line((32, 24), (32, 8)), poly([(32, 8), (46, 12), (32, 17)], True, True),
            path("M26 56 V44 Q26 38 32 38 Q38 38 38 44 V56"), dot(20, 34), dot(44, 34)]


@icon("b_court")
def _():
    return [poly(rrect(24, 24, 28, 17, -45)), line((30, 30), (50, 50)), line((30, 56), (56, 56))]


@icon("b_tax_office")
def _():
    return [rect(10, 30, 44, 24, 3), path("M10 30 V22 Q10 10 32 10 Q54 10 54 22 V30"), dot(32, 40, 4)]


@icon("b_admin_center")
def _():
    return [path("M16 38 Q16 14 32 14 Q48 14 48 38"), line((32, 14), (32, 8)), rect(10, 38, 44, 18, 2),
            line((24, 38), (24, 56)), line((40, 38), (40, 56))]


@icon("b_road")
def _():
    return [line((14, 56), (26, 8)), line((50, 56), (38, 8)), line((32, 54), (32, 46)), line((32, 36), (32, 28)),
            line((32, 20), (32, 14))]


@icon("b_bridge")
def _():
    return [line((8, 22), (56, 22)), path("M14 54 Q32 18 50 54"), line((16, 22), (16, 38)), line((48, 22), (48, 38)),
            line((8, 56), (56, 56))]


@icon("b_canal")
def _():
    return [line((8, 14), (56, 14)), line((8, 50), (56, 50)), path("M8 28 Q16 22 24 28 T40 28 T56 28"),
            path("M8 38 Q16 32 24 38 T40 38 T56 38")]


@icon("b_railway")
def _():
    e = [line((18, 56), (27, 8)), line((46, 56), (37, 8))]
    for y in (48, 34, 20):
        off = (56 - y) / 48 * 9
        e.append(line((18 + off - 4, y), (46 - off + 4, y)))
    return e


@icon("b_university")
def _():
    return [poly([(32, 14), (56, 26), (32, 38), (8, 26)]), path("M18 33 V44 Q32 54 46 44 V33"),
            line((56, 26), (56, 44))]


@icon("b_hospital")
def _():
    return [rect(8, 8, 48, 48, 6), line((32, 18), (32, 46)), line((18, 32), (46, 32))]


@icon("b_cultural_institution")
def _():
    return [path("M18 10 Q10 32 22 46 Q32 54 42 46 Q54 32 46 10"), line((14, 14), (50, 14)),
            line((26, 14), (26, 46)), line((32, 14), (32, 50)), line((38, 14), (38, 46)), line((24, 56), (40, 56))]


@icon("b_religious_building")
def _():
    return [path("M12 56 V32 Q12 20 32 8 Q52 20 52 32 V56 Z"), path("M26 56 V42 Q26 36 32 36 Q38 36 38 42 V56"),
            dot(32, 24, 3)]


# ============================================================= tech branches


@icon("t_military")
def _():
    return sword((12, 52), (50, 14), 10, 14)


@icon("t_economic")
def _():
    return [line((12, 52), (12, 40)), line((28, 52), (28, 32)), line((44, 52), (44, 22)),
            line((8, 56), (56, 56)), line((14, 24), (50, 10)), line((40, 8), (50, 10), (48, 20))]


@icon("t_administration")
def _():
    return gear(32, 28, 21, 17, 14, 8)[:1] + [circle(32, 28, 8), line((24, 46), (20, 56)),
                                               line((40, 46), (44, 56))]


@icon("t_society")
def _():
    return [path("M8 16 Q20 10 32 18 Q44 10 56 16 V50 Q44 44 32 52 Q20 44 8 50 Z"), line((32, 18), (32, 52))]


# ============================================================= governments


@icon("g_absolute_monarchy")
def _():
    return [crown(32, 20, 44, 32), dot(10, 14, 3.5), dot(32, 10, 3.5), dot(54, 14, 3.5)]


@icon("g_constitutional_monarchy")
def _():
    return [crown(32, 8, 30, 18), rect(14, 32, 36, 24, 3), line((22, 42), (42, 42)), line((22, 50), (34, 50))]


@icon("g_republic")
def _():
    return [poly([(8, 22), (32, 8), (56, 22)]), line((8, 56), (56, 56)), line((16, 30), (16, 50)),
            line((28, 30), (28, 50)), line((40, 30), (40, 50)), line((52, 30), (52, 50))]


@icon("g_merchant_republic")
def _():
    return [path("M8 42 H56 Q50 56 40 56 H24 Q14 56 8 42 Z"), line((32, 8), (32, 42)), poly([(28, 14), (28, 36), (12, 36)]),
            poly([(36, 10), (36, 36), (54, 36)])]


@icon("g_empire")
def _():
    return laurel(32, 32, 17, 100, 250, 5) + [poly(star(32, 32, 8, 3.6), True, True)]


@icon("g_tribal_confederation")
def _():
    return [poly([(8, 56), (32, 12), (56, 56)]), line((24, 8), (36, 22)), line((40, 8), (28, 22)),
            path("M25 56 L32 38 L39 56")]


@icon("g_theocracy")
def _():
    e = [circle(32, 34, 8), rect(16, 48, 32, 8, 2), line((32, 42), (32, 48))]
    for a in (180, 225, 270, 315, 360):
        e.append(line(polar(32, 34, 14, a), polar(32, 34, 20, a)))
    return e


@icon("g_feudal_kingdom")
def _():
    return [
        path("M14 56 V32 H22 V38 H30 V32 H38 V38 H46 V32 H54 V56 Z"), line((20, 32), (20, 8)),
        poly([(20, 8), (44, 8), (36, 15), (44, 22), (20, 22)])]


@icon("g_military_government")
def _():
    return [shield(12, 52, 8, 32, 56), poly(star(32, 31, 12, 5.5), True, True)]


# ============================================================= religions


@icon("r_catholic")
def _():
    return [line((32, 8), (32, 56)), line((18, 22), (46, 22)), line((26, 8), (38, 8)), line((26, 56), (38, 56)),
            line((18, 16), (18, 28)), line((46, 16), (46, 28))]


@icon("r_orthodox")
def _():
    return [line((32, 8), (32, 56)), line((24, 14), (40, 14)), line((16, 26), (48, 26)), line((22, 50), (42, 42))]


@icon("r_protestant")
def _():
    return [circle(32, 32, 24), line((32, 16), (32, 50)), line((22, 26), (42, 26))]


@icon("r_sunni")
def _():
    return [crescent(30, 32, 22)]


@icon("r_shia")
def _():
    return [crescent(26, 36, 16), poly(star(47, 23, 8, 3.6), True, True)]


@icon("r_jewish")
def _():
    t1 = [polar(32, 33, 24, a) for a in (-90, 30, 150)]
    t2 = [polar(32, 33, 24, a) for a in (90, 210, 330)]
    return [poly(t1), poly(t2)]


@icon("r_buddhist")
def _():
    e = [circle(32, 32, 23), circle(32, 32, 5)]
    for a in range(0, 360, 45):
        e.append(line(polar(32, 32, 5, a), polar(32, 32, 23, a)))
    return e


@icon("r_hindu")
def _():
    return [leaf(32, 50, -90, 40, 12), leaf(32, 50, -55, 34, 12), leaf(32, 50, -125, 34, 12),
            line((10, 56), (54, 56))]


@icon("r_eastern_faiths")
def _():
    return [circle(32, 32, 23), path("M32 9 A11.5 11.5 0 0 1 32 32 A11.5 11.5 0 0 0 32 55"), dot(32, 20, 3.5),
            dot(32, 44, 3.5)]


@icon("r_pagan")
def _():
    e = [circle(32, 32, 10)]
    for a in range(0, 360, 45):
        e.append(line(polar(32, 32, 17, a), polar(32, 32, 24, a)))
    return e


@icon("r_animist")
def _():
    p = []
    for i in range(0, 91):
        t = i / 90
        p.append(polar(32, 32, 3 + 20 * t, -90 + t * 810))
    return [poly(p, close=False)]


@icon("r_tengri")
def _():
    return [path("M16 54 Q8 54 8 45 Q8 36 16 36 Q18 26 29 26 Q38 26 42 33 Q56 33 56 45 Q56 54 47 54 Z"), circle(46, 14, 6)]


@icon("r_shinto")
def _():
    return [path("M8 13 Q32 21 56 13"), line((12, 26), (52, 26)), line((18, 26), (18, 56)), line((46, 26), (46, 56)),
            line((32, 18), (32, 26))]


@icon("r_secular")
def _():
    return [circle(32, 32, 23), path("M32 9 A23 23 0 0 0 32 55 Z", True)]


# ============================================================= classes


@icon("c_nobility")
def _():
    return [circle(32, 40, 16), poly([(24, 10), (40, 10), (46, 18), (32, 26), (18, 18)])]


@icon("c_merchants")
def _():
    return [line((32, 12), (32, 52)), line((20, 54), (44, 54)), line((10, 20), (54, 20)),
            path("M8 36 H24 Q24 44 16 44 Q8 44 8 36"), path("M40 36 H56 Q56 44 48 44 Q40 44 40 36"),
            line((14, 20), (10, 36)), line((14, 20), (22, 36)), line((50, 20), (42, 36)), line((50, 20), (54, 36))]


@icon("c_peasants")
def _():
    return [path("M20 8 V26 Q20 36 32 36 Q44 36 44 26 V8"), line((32, 8), (32, 56))]


@icon("c_clergy")
def _():
    return [path("M32 8 Q16 12 16 30 V40 L10 48 H54 L48 40 V30 Q48 12 32 8 Z"), dot(32, 55, 3)]


@icon("c_artisans")
def _():
    return [poly(rrect(40, 24, 26, 14, 43)), line((12, 54), (38, 26))]


@icon("c_military")
def _():
    return [line((12, 16), (32, 28), (52, 16)), line((12, 30), (32, 42), (52, 30)), line((12, 44), (32, 56), (52, 44))]


# --------------------------------------------------------------------------- output

REQUIRED = """
gold food manpower iron wood stone coal luxury prestige admin stability legitimacy inflation debt trade research population income expense
end_turn menu settings save load close back next plus minus check cross info warning lock search filter map zoom_in zoom_out
mode_political mode_terrain mode_economic mode_diplomatic mode_military mode_population mode_supply mode_trade
mode_religion mode_culture mode_infrastructure mode_unrest mode_admin mode_development mode_naval
country economy military diplomacy technology construction population events objectives politics history statistics achievements editor credits language sound music video
unit_infantry unit_heavy_infantry unit_archers unit_cavalry unit_heavy_cavalry unit_artillery unit_engineer unit_naval general siege battle move recruit disband merge split fort
war peace alliance nap defensive access trade_agreement vassal guarantee gift relations sanction coalition embargo transfer assist
terrain_plains terrain_hills terrain_mountains terrain_forest terrain_desert terrain_jungle terrain_marsh terrain_steppe terrain_arctic
b_farm b_market b_workshop b_mine b_sawmill b_port b_trading_center b_barracks b_fort b_arsenal b_military_academy b_government_office b_court b_tax_office b_admin_center b_road b_bridge b_canal b_railway b_university b_hospital b_cultural_institution b_religious_building
t_military t_economic t_administration t_society
g_absolute_monarchy g_constitutional_monarchy g_republic g_merchant_republic g_empire g_tribal_confederation g_theocracy g_feudal_kingdom g_military_government
r_catholic r_orthodox r_protestant r_sunni r_shia r_jewish r_buddhist r_hindu r_eastern_faiths r_pagan r_animist r_tengri r_shinto r_secular
c_nobility c_merchants c_peasants c_clergy c_artisans c_military
""".split()

HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">\n'
        '<g fill="none" stroke="#ffffff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">\n')
TAIL = "</g>\n</svg>\n"


def build(name):
    return HEAD + "\n".join(ICONS[name]()) + "\n" + TAIL


def main():
    missing = [n for n in REQUIRED if n not in ICONS]
    extra = [n for n in ICONS if n not in REQUIRED]
    if missing or extra:
        raise SystemExit(f"missing={missing} extra={extra}")
    os.makedirs(OUT_DIR, exist_ok=True)
    for n in REQUIRED:
        with open(os.path.join(OUT_DIR, n + ".svg"), "w", encoding="utf-8") as fh:
            fh.write(build(n))
    print(f"wrote {len(REQUIRED)} icons to {OUT_DIR}")


if __name__ == "__main__":
    main()
