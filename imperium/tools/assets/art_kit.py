"""IMPERIUM art kit: shared drawing helpers for the procedural engraving-style generators.

Everything here is original, code-generated art (Pillow + numpy). No external art is used.
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


PAL = {
    "parchment": hx("e9dfc4"), "parchment_dark": hx("cdbf9c"), "ink": hx("2a2118"),
    "navy": hx("14203a"), "navy_deep": hx("0b1326"), "burgundy": hx("5b1a24"),
    "burgundy_light": hx("8a2b38"), "gold": hx("c9a24a"), "gold_light": hx("e6c876"),
    "verdigris": hx("3f7a6e"), "steel": hx("7d8aa3"),
    # derived tones (shades of the palette)
    "gold_dark": hx("8f7230"), "ember": hx("c4622d"), "navy_mid": hx("22345a"),
    "burgundy_dark": hx("3a1018"), "verdigris_dark": hx("27493f"), "steel_dark": hx("4a5570"),
}


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def rgba(c, a=255):
    return (c[0], c[1], c[2], int(a))


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- noise
def fbm(w, h, seed, scale=64, octaves=5, tile=False, persist=0.5):
    """Value-noise fBm, float32 in ~[0,1]. tile=True gives exact periodic output (w,h multiples of scale grid)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        gw = max(2, int(round(w / scale * 2 ** o)))
        gh = max(2, int(round(h / scale * 2 ** o)))
        g = rng.random((gh, gw)).astype(np.float32)
        if tile:
            g3 = np.tile(g, (3, 3))
            a = np.asarray(Image.fromarray(g3, "F").resize((3 * w, 3 * h), Image.BICUBIC))[h:2 * h, w:2 * w]
        else:
            a = np.asarray(Image.fromarray(g, "F").resize((w, h), Image.BICUBIC))
        out += a * amp
        tot += amp
        amp *= persist
    return out / tot


def norm(a):
    a = a - a.mean()
    return a / (a.std() + 1e-6)


def fractal_line(n, rough, rnd):
    """Midpoint displacement; returns list of n+1 values roughly in [-1,1]."""
    size = 1
    while size < n:
        size *= 2
    v = [0.0] * (size + 1)
    v[0] = rnd.uniform(-1, 1) * 0.5
    v[size] = rnd.uniform(-1, 1) * 0.5
    step, disp = size, 1.0
    while step > 1:
        half = step // 2
        for i in range(half, size, step):
            v[i] = (v[i - half] + v[i + half]) / 2 + rnd.uniform(-1, 1) * disp
        step = half
        disp *= rough
    m = max(abs(x) for x in v) or 1
    return [x / m for x in v]


def rot(pts, ang, ox=0.0, oy=0.0):
    c, s = math.cos(ang), math.sin(ang)
    return [(ox + x * c - y * s, oy + x * s + y * c) for x, y in pts]


def bez(p0, p1, p2, n=16):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / n for i in range(n + 1)]]


# ---------------------------------------------------------------- canvas
class Art:
    """Supersampled RGBA canvas; all coordinates are in logical (final-size) units."""

    def __init__(self, w, h, ss=2, bg=None):
        self.w, self.h, self.ss = w, h, ss
        self.im = Image.new("RGBA", (w * ss, h * ss), rgba(bg) if bg else (0, 0, 0, 0))
        self.rnd = random.Random(1234)

    # -- basics
    def sc(self, pts):
        k = self.ss
        return [(x * k, y * k) for x, y in pts]

    def dr(self):
        return ImageDraw.Draw(self.im, "RGBA")

    @staticmethod
    def _c(col):
        return col if len(col) == 4 else rgba(col)

    def _layer_draw(self, pts, pad, fn):
        """Draw translucent geometry on a temp layer and alpha-composite it (ImageDraw would overwrite alpha)."""
        x0, y0, x1, y1 = self._bbox(pts, int(pad) + 3)
        if x1 <= x0 or y1 <= y0:
            return
        layer = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        fn(ImageDraw.Draw(layer), x0, y0)
        self.im.alpha_composite(layer, (x0, y0))

    def poly(self, pts, fill=None, outline=None, ow=1.0):
        p = self.sc(pts)
        if fill is not None:
            f = self._c(fill)
            if f[3] >= 255:
                self.dr().polygon(p, fill=f)
            else:
                self._layer_draw(pts, 0, lambda d, x0, y0: d.polygon([(x - x0, y - y0) for x, y in p], fill=f))
        if outline is not None:
            self.line(list(pts) + [pts[0]], outline, ow)

    def line(self, pts, color, w=1.0, alpha=255):
        col = color if len(color) == 4 else rgba(color, alpha)
        wd = max(1, int(round(w * self.ss)))
        p = self.sc(pts)
        if col[3] >= 255:
            self.dr().line(p, fill=col, width=wd, joint="curve")
        else:
            self._layer_draw(pts, wd, lambda d, x0, y0: d.line([(x - x0, y - y0) for x, y in p], fill=col, width=wd, joint="curve"))

    def circle(self, cx, cy, r, fill=None, outline=None, ow=1.0):
        k = self.ss
        if (fill is None or self._c(fill)[3] >= 255) and (outline is None or self._c(outline)[3] >= 255):
            box = [(cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k]
            self.dr().ellipse(box, fill=None if fill is None else self._c(fill),
                              outline=None if outline is None else self._c(outline), width=max(1, int(ow * k)))
        else:
            self.ellipse(cx, cy, r, r, fill, outline, ow, n=max(24, min(160, int(r * k * 0.9))))

    def ellipse(self, cx, cy, rx, ry, fill=None, outline=None, ow=1.0, n=40):
        pts = [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]
        self.poly(pts, fill, outline, ow)

    def rect(self, x0, y0, x1, y1, fill=None, outline=None, ow=1.0):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill, outline, ow)

    # -- compositing helpers
    def paste(self, layer, x=0, y=0):
        """alpha_composite with clipping. x,y in device px."""
        lw, lh = layer.size
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.im.width, x + lw), min(self.im.height, y + lh)
        if x1 <= x0 or y1 <= y0:
            return
        sub = layer.crop((x0 - x, y0 - y, x1 - x, y1 - y))
        self.im.alpha_composite(sub, (x0, y0))

    def _bbox(self, pts, pad=2):
        k = self.ss
        xs = [p[0] * k for p in pts]
        ys = [p[1] * k for p in pts]
        x0 = max(0, int(min(xs)) - pad)
        y0 = max(0, int(min(ys)) - pad)
        x1 = min(self.im.width, int(max(xs)) + pad + 1)
        y1 = min(self.im.height, int(max(ys)) + pad + 1)
        return x0, y0, x1, y1

    def poly_mask(self, pts):
        x0, y0, x1, y1 = self._bbox(pts)
        m = Image.new("L", (max(1, x1 - x0), max(1, y1 - y0)), 0)
        ImageDraw.Draw(m).polygon([(x - x0, y - y0) for x, y in self.sc(pts)], fill=255)
        return m, x0, y0

    def hatch(self, pts, color, angle=45, gap=4.0, width=1.0, alpha=150, jitter=0.25):
        """Etched parallel hatching clipped to polygon pts."""
        mask, x0, y0 = self.poly_mask(pts)
        bw, bh = mask.size
        lines = Image.new("L", (bw, bh), 0)
        ld = ImageDraw.Draw(lines)
        a = math.radians(angle)
        dx, dy = math.cos(a), math.sin(a)
        nx, ny = -dy, dx
        L = math.hypot(bw, bh)
        cx, cy = bw / 2, bh / 2
        g = gap * self.ss
        n = int(L / g) + 2
        rr = random.Random(int(bw * 7 + bh * 13 + angle))
        for i in range(-n, n + 1):
            off = i * g + rr.uniform(-jitter, jitter) * g
            px, py = cx + nx * off, cy + ny * off
            ld.line([(px - dx * L, py - dy * L), (px + dx * L, py + dy * L)], fill=255,
                    width=max(1, int(round(width * self.ss * rr.uniform(0.7, 1.15)))))
        m = ImageChops.multiply(mask, lines).point(lambda v: v * alpha // 255)
        layer = Image.new("RGBA", (bw, bh), rgba(color, 0))
        layer.putalpha(m)
        self.paste(layer, x0, y0)

    def fill_grad(self, pts, c0, c1, horizontal=False, alpha=255, outline=None, ow=1.0):
        """Fill polygon with linear gradient c0->c1 across its bbox."""
        mask, x0, y0 = self.poly_mask(pts)
        bw, bh = mask.size
        t = np.linspace(0, 1, bw if horizontal else bh, dtype=np.float32)
        t = np.tile(t[None, :], (bh, 1)) if horizontal else np.tile(t[:, None], (1, bw))
        arr = np.zeros((bh, bw, 4), np.uint8)
        for i in range(3):
            arr[..., i] = (c0[i] + (c1[i] - c0[i]) * t).astype(np.uint8)
        arr[..., 3] = 255
        layer = Image.fromarray(arr, "RGBA")
        layer.putalpha(mask.point(lambda v: v * alpha // 255))
        self.paste(layer, x0, y0)
        if outline is not None:
            self.poly(pts, None, outline, ow)

    def glow(self, cx, cy, r, color, alpha=160, power=2.0):
        k = self.ss
        R = int(r * k)
        if R < 2:
            return
        yy, xx = np.mgrid[-R:R, -R:R].astype(np.float32)
        d = np.sqrt(xx * xx + yy * yy) / R
        a = np.clip(1 - d, 0, 1) ** power * alpha
        arr = np.zeros((2 * R, 2 * R, 4), np.uint8)
        arr[..., 0], arr[..., 1], arr[..., 2] = color
        arr[..., 3] = a.astype(np.uint8)
        self.paste(Image.fromarray(arr, "RGBA"), int(cx * k) - R, int(cy * k) - R)

    def blurred(self, draw_fn, radius, bbox=None):
        """Draw into a temp full-size layer, blur it (premultiplied, so no dark fringes), composite."""
        tmp = Art(self.w, self.h, self.ss)
        draw_fn(tmp)
        arr = np.asarray(tmp.im).astype(np.float32)
        al = arr[..., 3:4] / 255.0
        pm = np.concatenate([arr[..., :3] * al, arr[..., 3:4]], axis=2)
        r = radius * self.ss
        chans = [np.asarray(Image.fromarray(np.clip(pm[..., i], 0, 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(r)), np.float32) for i in range(4)]
        A = chans[3]
        out = np.zeros_like(arr)
        safe = np.maximum(A, 1.0)
        for i in range(3):
            out[..., i] = np.clip(chans[i] / safe * 255.0, 0, 255)
        out[..., 3] = A
        self.im.alpha_composite(Image.fromarray(out.astype(np.uint8), "RGBA"))

    def sky(self, stops, y0=0, y1=None, bands=8, seed=3, x0=0, x1=None, wob=0.035):
        y1 = self.h if y1 is None else y1
        x1 = self.w if x1 is None else x1
        k = self.ss
        W, Hh = int((x1 - x0) * k), int((y1 - y0) * k)
        n = norm(fbm(W, Hh, seed, scale=max(32, W // 6), octaves=4))
        t = np.linspace(0, 1, Hh, dtype=np.float32)[:, None] + n * wob
        if bands:
            t = np.floor(np.clip(t, 0, 0.9999) * bands) / (bands - 1)
        t = np.clip(t, 0, 1)
        out = np.zeros((Hh, W, 4), np.uint8)
        ts = [s[0] for s in stops]
        for ch in range(3):
            vals = [s[1][ch] for s in stops]
            out[..., ch] = np.interp(t, ts, vals).astype(np.uint8)
        out[..., 3] = 255
        self.paste(Image.fromarray(out, "RGBA"), int(x0 * k), int(y0 * k))

    # -- finishing
    def render(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)


# ---------------------------------------------------------------- finishing passes
def paper_grain(arr, seed=5, amount=0.05):
    h, w = arr.shape[:2]
    n1 = norm(fbm(w, h, seed, scale=max(16, w // 30), octaves=4))
    n2 = np.random.default_rng(seed + 1).normal(0, 1, (h, w)).astype(np.float32)
    g = 1 + (n1 * 0.45 + n2 * 0.55) * amount
    return arr * g[..., None]


def etch(arr, period=3.0, strength=0.25, angle=35.0, power=1.4, thresh=0.85):
    h, w = arr.shape[:2]
    lum = arr.mean(2) / 255.0
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    a = math.radians(angle)
    ph = ((xx * math.cos(a) + yy * math.sin(a)) / period) % 1.0
    thr = np.clip((1 - lum) ** power * thresh * 1.6, 0, 0.9)
    line = np.clip((thr - ph) * period * 1.2 + 0.5, 0, 1) * (thr > 0.05)
    return arr * (1 - strength * line[..., None])


def vignette(arr, strength=0.5, power=2.2, tint=None):
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / math.sqrt(2)
    v = np.clip(d, 0, 1) ** power * strength * 1.8
    v = np.clip(v, 0, 0.95)[..., None]
    t = np.array(tint if tint is not None else PAL["navy_deep"], np.float32)[None, None, :]
    return arr * (1 - v) + t * v


def finish(art, vig=0.45, grain=0.05, etch_k=0.22, etch_period=3.0, seed=5, tint=None, warm=0.0, angle=35.0):
    img = art.render().convert("RGB")
    arr = np.asarray(img).astype(np.float32)
    if etch_k > 0:
        arr = etch(arr, etch_period, etch_k, angle)
    if warm > 0:
        pt = np.array(PAL["parchment"], np.float32) / 255
        arr = arr * (1 - warm) + arr * pt * warm * 1.1
    if grain > 0:
        arr = paper_grain(arr, seed, grain)
    if vig > 0:
        arr = vignette(arr, vig, tint=tint)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def save_png(img, path, limit=None):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    if limit and path.stat().st_size > limit and img.mode == "RGB":
        q = img.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
        q.save(path, optimize=True)
        if path.stat().st_size > limit:
            q = img.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
            q.save(path, optimize=True)
    print(f"  wrote {path.relative_to(ROOT)}  {path.stat().st_size/1024:.0f} KB")


# ---------------------------------------------------------------- scenery primitives
def ridge_pts(art, y, amp, seed, x0=-10, x1=None, rough=0.55, tilt=0.0, n=128):
    x1 = art.w + 10 if x1 is None else x1
    rnd = random.Random(seed)
    v = fractal_line(n, rough, rnd)
    pts = []
    for i, val in enumerate(v):
        t = i / (len(v) - 1)
        pts.append((x0 + (x1 - x0) * t, y + val * amp + tilt * t))
    return pts


def ridge(art, y, amp, seed, color, outline=None, rough=0.55, tilt=0.0, bottom=None, x0=-10, x1=None, hatch=None):
    pts = ridge_pts(art, y, amp, seed, x0, x1, rough, tilt)
    bottom = art.h + 10 if bottom is None else bottom
    poly = pts + [(pts[-1][0], bottom), (pts[0][0], bottom)]
    art.poly(poly, color)
    if outline:
        art.line(pts, outline, 1.0)
    if hatch:
        art.hatch(poly, hatch[0], hatch[1], hatch[2], 0.8, hatch[3])
    return pts


def strata(art, y, x0, x1, thick, color, alpha=255, seed=0):
    """Elongated lens-shaped cloud streak."""
    rnd = random.Random(seed)
    n = 24
    top, bot = [], []
    for i in range(n + 1):
        t = i / n
        b = math.sin(math.pi * t) ** 0.8
        x = x0 + (x1 - x0) * t
        top.append((x, y - thick * b * (0.8 + 0.4 * rnd.random())))
        bot.append((x, y + thick * 0.35 * b))
    art.poly(top + bot[::-1], rgba(color, alpha))


def cloud(art, cx, cy, w, h, c_top, c_bot, seed=0, outline=None):
    """Engraved cloud bank: bumpy top envelope, flat shaded base with horizontal hatch."""
    rnd = random.Random(seed)
    n = max(4, int(w / (h * 0.9)))
    blobs = []
    for i in range(n):
        t = (i + 0.5) / n
        r = h * (0.45 + 0.6 * math.sin(math.pi * t) ** 0.8) * rnd.uniform(0.8, 1.1)
        blobs.append((cx - w / 2 + w * t + rnd.uniform(-1, 1) * w / n * 0.2, cy + h * 0.3 - r * 0.78, r))
    base = cy + h * 0.3
    x0, x1 = cx - w / 2 - h * 0.4, cx + w / 2 + h * 0.4
    xs = [x0 + (x1 - x0) * i / 70 for i in range(71)]
    env = []
    for x in xs:
        best = base
        for bx, by, r in blobs:
            d = x - bx
            if abs(d) < r:
                best = min(best, by - math.sqrt(r * r - d * d) * 0.75)
        env.append((x, best))
    # trim flat ends
    poly = env + [(xs[-1], base), (xs[0], base)]
    art.poly(poly, c_top)
    mid = cy - h * 0.05
    shade = [(x, max(y, mid)) for x, y in env] + [(xs[-1], base), (xs[0], base)]
    art.poly(shade, rgba(mix(c_top, c_bot, 0.55), 255))
    art.hatch(shade, c_bot, 0, 2.8, 0.7, 150, jitter=0.1)
    art.line(env, mix(c_bot, (0, 0, 0), 0.35), 0.8, alpha=140)


def birds(art, pts, color, size=5):
    for x, y, s in pts:
        r = size * s
        art.line(bez((x - r, y - r * 0.2), (x - r * 0.4, y - r * 0.9), (x, y)), color, 1.2)
        art.line(bez((x, y), (x + r * 0.4, y - r * 0.9), (x + r, y - r * 0.2)), color, 1.2)


def stars(art, rect, n, seed, color, maxr=1.2):
    rnd = random.Random(seed)
    x0, y0, x1, y1 = rect
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        a = rnd.uniform(100, 255)
        r = rnd.uniform(0.4, maxr)
        art.circle(x, y, r, rgba(color, a))
        if r > maxr * 0.8:
            art.glow(x, y, 6, color, 80)


def pine(art, x, y, h, color, hi=None):
    w = h * 0.34
    art.rect(x - h * 0.03, y - h * 0.1, x + h * 0.03, y, color)
    for i in range(4):
        t = i / 4
        yy = y - h * 0.08 - h * 0.8 * t
        ww = w * (1 - t * 0.6)
        art.poly([(x - ww, yy), (x + ww, yy), (x, yy - h * 0.32)], color)
    if hi:
        art.poly([(x, y - h), (x + w * 0.2, y - h * 0.6), (x, y - h * 0.5)], rgba(hi, 90))


def oak(art, x, y, h, color, rnd=None):
    rnd = rnd or random.Random(int(x * 3 + y))
    art.poly([(x - h * 0.04, y), (x - h * 0.02, y - h * 0.5), (x + h * 0.02, y - h * 0.5), (x + h * 0.04, y)], color)
    for _ in range(7):
        a = rnd.uniform(0, math.pi * 2)
        rr = rnd.uniform(0, h * 0.2)
        art.circle(x + math.cos(a) * rr, y - h * 0.68 + math.sin(a) * rr * 0.7, h * rnd.uniform(0.17, 0.26), color)


def tree_dead(art, x, y, h, color, seed=0):
    rnd = random.Random(seed)

    def branch(px, py, ang, ln, w, depth):
        ex, ey = px + math.cos(ang) * ln, py - math.sin(ang) * ln
        art.line([(px, py), (ex, ey)], color, w)
        if depth > 0:
            for s in (-1, 1):
                if rnd.random() < 0.85:
                    branch(ex, ey, ang + s * rnd.uniform(0.3, 0.8), ln * rnd.uniform(0.6, 0.75), max(0.8, w * 0.65), depth - 1)
    branch(x, y, math.pi / 2 + rnd.uniform(-0.1, 0.1), h * 0.38, h * 0.045, 5)


def house(art, x, y, w, h, wall, roof, lit=None, ink=None, rw=0.12):
    art.rect(x, y - h, x + w, y, wall, ink, 0.8)
    art.poly([(x - w * rw, y - h), (x + w * (1 + rw), y - h), (x + w * 0.5, y - h - w * 0.55)], roof, ink, 0.8)
    if lit:
        art.rect(x + w * 0.38, y - h * 0.65, x + w * 0.62, y - h * 0.3, lit)


def spire_tower(art, x, y, w, h, wall, roof, ink=None, lit=None, cone=1.4, crenel=False):
    art.rect(x - w / 2, y - h, x + w / 2, y, wall, ink, 0.8)
    if crenel:
        mw = w / 5
        for i in range(0, 5, 2):
            art.rect(x - w / 2 + i * mw, y - h - mw, x - w / 2 + (i + 1) * mw, y - h, wall, ink, 0.6)
    else:
        art.poly([(x - w * 0.62, y - h), (x + w * 0.62, y - h), (x, y - h - w * cone)], roof, ink, 0.8)
    if lit:
        art.rect(x - w * 0.09, y - h * 0.7, x + w * 0.09, y - h * 0.5, lit)


def crenel(art, x0, x1, y, h, color, mw=None, ink=None):
    mw = mw or h * 1.1
    n = int((x1 - x0) / (mw * 2))
    for i in range(n + 1):
        xa = x0 + i * mw * 2
        art.rect(xa, y - h, min(xa + mw, x1), y, color, ink, 0.5)


def castle(art, cx, by, s, wall, roof, lit, flag, ink=None, flagc=None):
    """Hill castle silhouette; s ~ overall width in logical px."""
    k = s / 100.0
    X = lambda v: cx + v * k
    Y = lambda v: by - v * k
    # curtain wall
    art.rect(X(-50), Y(26), X(50), Y(0), wall, ink, 0.8)
    crenel(art, X(-50), X(50), Y(26), 3.2 * k, wall, 3.2 * k, ink)
    # side towers
    for sx, hh in ((-50, 52), (50, 52), (-24, 44), (24, 44)):
        art.rect(X(sx - 8), Y(hh), X(sx + 8), Y(0), wall, ink, 0.8)
        art.poly([(X(sx - 10.5), Y(hh)), (X(sx + 10.5), Y(hh)), (X(sx), Y(hh + 15))], roof, ink, 0.8)
        art.rect(X(sx - 1.5), Y(hh * 0.7), X(sx + 1.5), Y(hh * 0.5), lit)
    # keep
    art.rect(X(-14), Y(78), X(14), Y(0), mix(wall, (0, 0, 0), 0.12), ink, 0.8)
    crenel(art, X(-14), X(14), Y(78), 3.8 * k, wall, 3.8 * k, ink)
    art.poly([(X(-11), Y(78)), (X(11), Y(78)), (X(0), Y(90))], roof, ink, 0.8)
    art.line([(X(0), Y(90)), (X(0), Y(112))], ink or wall, 1.2)
    art.poly([(X(0), Y(112)), (X(15), Y(107)), (X(0), Y(102))], flag)
    # gate and windows
    art.poly([(X(-6), Y(0)), (X(-6), Y(11)), (X(0), Y(17)), (X(6), Y(11)), (X(6), Y(0))], mix(wall, (0, 0, 0), 0.7))
    for wx in (-8, 0, 8):
        art.rect(X(wx - 1.5), Y(58), X(wx + 1.5), Y(48), lit)
    for wx in (-38, -30, 30, 38):
        art.rect(X(wx - 1.3), Y(18), X(wx + 1.3), Y(11), lit)


# ---------------------------------------------------------------- galleon
def galleon(art, x, y, s, hull, sail, trim, ink, flip=False, flag=None, heel=0.0, sail_hatch=None):
    """Side-view galleon. s = overall length (logical px). (x,y) = waterline centre."""
    k = s / 130.0
    f = -1 if flip else 1

    def P(px, py):
        # heel rotates slightly about the waterline
        a = heel * f
        rx = px * math.cos(a) - py * math.sin(a)
        ry = px * math.sin(a) + py * math.cos(a)
        return (x + f * rx * k, y + ry * k)

    def poly(pts, fill, outline=ink, ow=0.9):
        art.poly([P(*p) for p in pts], fill, outline, ow)

    def ln(pts, col, w=1.0):
        art.line([P(*p) for p in pts], col, w * max(0.6, k))

    # masts (behind sails)
    for mx, top in ((-30, -56), (0, -80), (30, -64)):
        ln([(mx, -8), (mx, top)], ink, 1.6)
    ln([(58, -8), (80, -17)], ink, 1.6)  # bowsprit
    # sails: (mast x, [(y_top, y_bot, half_w)])
    def sq(mx, yt, yb, hw, bulge):
        top = [(mx - hw, yt), (mx + hw, yt)]
        bot = bez((mx + hw * 0.95, yb), (mx, yb + bulge), (mx - hw * 0.95, yb), 8)
        poly(top + bot, sail)
        if sail_hatch:
            art.hatch([P(*p) for p in top + bot], sail_hatch, 90, 1.6 * max(1, k), 0.5, 90)
        ln([(mx - hw - 2, yt), (mx + hw + 2, yt)], ink, 1.3)
    sq(0, -44, -12, 21, 6)
    sq(0, -64, -45, 15, 4)
    sq(0, -80, -65, 10, 3)
    sq(30, -48, -12, 15, 5)
    sq(30, -64, -49, 11, 3)
    # lateen on mizzen
    poly([(-30, -16), (-30, -54), (-58, -14)], sail)
    ln([(-58, -14), (-30, -54)], ink, 1.2)
    # hull
    hull_pts = [(-52, -20), (-56, -6)] + bez((-56, -6), (-48, 10), (-20, 13), 8)[1:] + \
        bez((-20, 13), (30, 15), (56, 0), 8)[1:] + [(62, -9), (46, -7), (46, -15), (30, -15), (30, -8), (-30, -8), (-30, -20)]
    poly(hull_pts, hull)
    poly([(-52, -20), (-30, -20), (-30, -33), (-50, -33)], hull)  # sterncastle
    ln([(-56, -7), (-20, -5), (30, -6), (60, -9)], trim, 1.4)
    ln([(-50, -26), (-30, -26)], trim, 1.2)
    for wx in (-45, -38, -31):
        art.circle(*P(wx, -14), 1.1 * k, trim)
    for wx in range(-22, 28, 9):
        art.circle(*P(wx, 0), 1.3 * k, ink)
    if flag:
        for mx, top in ((0, -80), (30, -64), (-30, -56)):
            ln([(mx, top), (mx, top - 9)], ink, 1)
            poly([(mx, top - 9), (mx + 11, top - 6), (mx, top - 3)], flag, None)
    # rigging
    ln([(0, -80), (80, -17)], ink, 0.5)
    ln([(0, -80), (-52, -33)], ink, 0.5)
    ln([(30, -64), (60, -10)], ink, 0.5)
    # hull shadow/hatch
    art.hatch([P(*p) for p in hull_pts], ink, 25, 1.8, 0.6, 90)


# ---------------------------------------------------------------- figures
def soldier(art, x, y, h, color, pike=True, helm=True, lean=0.0, banner=None, ink=None):
    w = h * 0.2
    # legs
    for sx in (-1, 1):
        art.poly([(x + sx * w * 0.1, y - h * 0.42), (x + sx * w * 0.62, y - h * 0.42), (x + sx * w * 0.7, y), (x + sx * w * 0.28, y)], color)
    # tunic / tabard (flared skirt)
    art.poly([(x - w * 0.9, y - h * 0.34), (x - w * 0.62, y - h * 0.5), (x - w * 0.8, y - h * 0.74), (x + w * 0.8, y - h * 0.74),
              (x + w * 0.62, y - h * 0.5), (x + w * 0.9, y - h * 0.34)], color)
    art.circle(x, y - h * 0.84, h * 0.085, color)
    if helm:
        art.ellipse(x, y - h * 0.88, h * 0.16, h * 0.028, color)
        art.poly([(x - h * 0.085, y - h * 0.88), (x + h * 0.085, y - h * 0.88), (x + h * 0.05, y - h * 0.97), (x - h * 0.05, y - h * 0.97)], color)
    if pike:
        gx, gy = x + w * 1.05, y - h * 0.5
        tx, ty = x + w * 1.4 + lean * h, y - h * 2.0
        art.line([(x + w * 0.6, y - h * 0.68), (gx, gy)], color, max(0.8, h * 0.07))
        art.line([(gx - lean * h * 0.4, y - h * 0.1), (tx, ty)], color, max(0.8, h * 0.035))
        art.poly([(tx - h * 0.035, ty + h * 0.12), (tx + h * 0.035, ty + h * 0.12), (tx, ty - h * 0.1)], color)
    if banner:
        bx, by = x + w * 1.0, y - h * 2.1
        art.line([(bx, y - h * 0.3), (bx, by)], color, max(0.8, h * 0.05))
        art.poly([(bx, by), (bx + h * 0.7, by + h * 0.12), (bx + h * 0.6, by + h * 0.35), (bx, by + h * 0.55)], banner)


def person(art, x, y, h, color, hat=None, arm=None, ink=None):
    w = h * 0.2
    light = mix(color, PAL["parchment"], 0.28)
    # sleeves (arms hanging, give a human silhouette)
    for sx in (-1, 1):
        art.poly([(x + sx * w * 0.5, y - h * 0.68), (x + sx * w * 0.92, y - h * 0.62), (x + sx * w * 1.18, y - h * 0.36),
                  (x + sx * w * 1.0, y - h * 0.34), (x + sx * w * 0.66, y - h * 0.52)], color)
    # robe: narrow waist, flared skirt
    art.poly([(x - w * 1.0, y), (x - w * 0.62, y - h * 0.42), (x - w * 0.6, y - h * 0.64), (x - w * 0.4, y - h * 0.71),
              (x + w * 0.4, y - h * 0.71), (x + w * 0.6, y - h * 0.64), (x + w * 0.62, y - h * 0.42), (x + w * 1.0, y)], color)
    art.poly([(x - h * 0.035, y - h * 0.7), (x + h * 0.035, y - h * 0.7), (x + h * 0.03, y - h * 0.76), (x - h * 0.03, y - h * 0.76)], color)
    art.circle(x, y - h * 0.82, h * 0.082, color)
    art.poly([(x - h * 0.07, y - h * 0.7), (x + h * 0.07, y - h * 0.7), (x, y - h * 0.6)], rgba(light, 200))
    if hat == "cap":
        art.poly([(x - h * 0.095, y - h * 0.84), (x + h * 0.095, y - h * 0.84), (x + h * 0.07, y - h * 0.95), (x - h * 0.02, y - h * 0.97)], color)
    elif hat == "wide":
        art.ellipse(x, y - h * 0.87, h * 0.16, h * 0.026, color)
        art.poly([(x - h * 0.075, y - h * 0.87), (x + h * 0.075, y - h * 0.87), (x + h * 0.05, y - h * 0.97), (x - h * 0.05, y - h * 0.97)], color)
    elif hat == "crown":
        art.poly([(x - h * 0.075, y - h * 0.88), (x + h * 0.075, y - h * 0.88), (x + h * 0.09, y - h * 0.98),
                  (x + h * 0.045, y - h * 0.94), (x, y - h * 1.0), (x - h * 0.045, y - h * 0.94), (x - h * 0.09, y - h * 0.98)], color)
    if arm:
        ax, ay = arm
        art.line([(x + w * 0.7, y - h * 0.62), (x + ax * h, y - h * 0.62 - ay * h)], color, max(1, h * 0.07))


def flame(art, x, y, h, w, phase=0.0, colors=None):
    colors = colors or [PAL["burgundy_light"], PAL["ember"], PAL["gold"], PAL["gold_light"]]
    for i, c in enumerate(colors):
        s = 1 - i * 0.22
        hh, ww = h * s, w * s
        L, R = [], []
        for j in range(21):
            t = j / 20
            hw = ww * (1 - t) ** 0.85 * (0.75 + 0.25 * math.sin(t * 7 + phase + i))
            lean = ww * 0.5 * math.sin(phase + 2.0) * t * t
            L.append((x - hw + lean, y - hh * t))
            R.append((x + hw + lean, y - hh * t))
        art.poly(L + R[::-1], c)


def smoke(art, x, y, h, w, color, alpha=120, seed=0, blur=6):
    rnd = random.Random(seed)

    def fn(t):
        for i in range(26):
            u = i / 25
            r = w * (0.4 + u * 1.1) * rnd.uniform(0.8, 1.2)
            t.circle(x + math.sin(u * 4 + seed) * w * 0.9 * u + rnd.uniform(-w, w) * 0.2 * u, y - h * u, r,
                     rgba(color, alpha * (1 - u * 0.65)))
    art.blurred(fn, blur)


def rain(art, rect, n, seed, color, length=14, slant=0.35, alpha=120, w=0.9):
    rnd = random.Random(seed)
    x0, y0, x1, y1 = rect
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        l = length * rnd.uniform(0.6, 1.2)
        art.line([(x, y), (x - l * slant, y + l)], color, w, alpha=alpha * rnd.uniform(0.5, 1))


def sea(art, y0, y1, c_far, c_near, light, dark, sun_x=None, seed=0, rows=26, bands=6):
    art.sky([(0, c_far), (1, c_near)], y0, y1, bands=bands, seed=seed + 40, wob=0.02)
    rnd = random.Random(seed)
    for i in range(rows):
        t = (i / rows) ** 1.7
        yy = y0 + (y1 - y0) * (0.03 + 0.97 * t)
        sc = 0.4 + 2.6 * t
        x = -rnd.uniform(0, 60)
        while x < art.w + 40:
            L = rnd.uniform(26, 70) * sc
            a = rnd.uniform(1.0, 2.6) * sc
            pts = bez((x, yy), (x + L / 2, yy - a * 1.6), (x + L, yy), 10)
            col = light if rnd.random() < 0.55 else dark
            art.line(pts, col, max(0.7, 0.8 * sc), alpha=rnd.uniform(70, 170))
            x += L * rnd.uniform(0.9, 1.8)
    if sun_x is not None:
        for i in range(28):
            t = (i / 28) ** 1.4
            yy = y0 + (y1 - y0) * (0.02 + 0.95 * t)
            half = (6 + 60 * t) * rnd.uniform(0.7, 1.2)
            art.line([(sun_x - half, yy), (sun_x + half, yy)], light, 0.8 + 2.4 * t, alpha=110 + 90 * (1 - t))


# ---------------------------------------------------------------- emblems (shared)
def gold_fill(art, pts, outline=None, ow=1.2, top=None, bot=None):
    art.fill_grad(pts, top or PAL["gold_light"], bot or PAL["gold_dark"], outline=outline or PAL["ink"], ow=ow)


def leaf(art, x, y, ang, L, W, fill, outline=None, ow=0.8):
    pts = []
    n = 10
    for i in range(n + 1):
        t = i / n
        pts.append((L * t, W * math.sin(math.pi * t) ** 0.9))
    for i in range(n, -1, -1):
        t = i / n
        pts.append((L * t, -W * math.sin(math.pi * t) ** 0.9))
    art.poly(rot(pts, ang, x, y), fill, outline, ow)


def laurel_branch(art, cx, cy, r, a0, a1, leaf_len, n, fill_a, fill_b, outline, side):
    """Branch along circle from angle a0 to a1 (radians, screen coords)."""
    pts = [(cx + r * math.cos(a0 + (a1 - a0) * i / 60), cy + r * math.sin(a0 + (a1 - a0) * i / 60)) for i in range(61)]
    art.line(pts, outline, max(1.0, leaf_len * 0.1))
    for i in range(n):
        t = (i + 0.5) / n
        a = a0 + (a1 - a0) * t
        px, py = cx + r * math.cos(a), cy + r * math.sin(a)
        tang = a + (math.pi / 2 if a1 > a0 else -math.pi / 2)
        ll = leaf_len * (1.0 - 0.35 * t)
        for sgn, col in ((1, fill_a), (-1, fill_b)):
            leaf(art, px, py, tang + sgn * 0.75, ll, ll * 0.3, col, outline, max(0.6, leaf_len * 0.04))
    # tip leaf
    a = a1
    px, py = cx + r * math.cos(a), cy + r * math.sin(a)
    tang = a + (math.pi / 2 if a1 > a0 else -math.pi / 2)
    leaf(art, px, py, tang, leaf_len * 0.7, leaf_len * 0.22, fill_a, outline, max(0.6, leaf_len * 0.04))


def crown(art, cx, cy, w, ink=None, outline_w=1.4, band_gems=True, hatch=True, cap=None):
    """Gold crown, front view. w = full width in logical px; (cx,cy) = visual centre."""
    k = w / 100.0
    ink = ink or PAL["ink"]
    cap = cap or PAL["burgundy"]
    cy = cy + 7 * k
    P = lambda pts: [(cx + x * k, cy + y * k) for x, y in pts]
    ow = outline_w
    # velvet cap behind
    capp = [(x, 8 - 36 * math.sqrt(max(0, 1 - (x / 39.0) ** 2))) for x in np.linspace(-39, 39, 24)]
    art.poly(P(capp + [(39, 12), (-39, 12)]), cap, ink, ow * 0.8)
    art.hatch(P(capp + [(39, 12), (-39, 12)]), PAL["burgundy_dark"], 60, 2.2 * max(0.6, k), 0.6, 130)
    # arches
    for sgn in (-1, 1):
        arch = bez((sgn * 42, -14), (sgn * 30, -52), (0, -40), 14)
        art.line(P(arch), ink, 4.6 * k + ow)
        art.line(P(arch), PAL["gold"], 3.4 * k)
        art.line(P([(x, y - 0.9) for x, y in arch]), PAL["gold_light"], 1.1 * k)
    # body
    body = [(-40, 16), (-47, -19), (-31, -3), (-22, -27), (-10, -5), (0, -34), (10, -5), (22, -27), (31, -3), (47, -19), (40, 16)]
    gold_fill(art, P(body), ink, ow)
    if hatch:
        art.hatch(P([(0, -34), (10, -5), (22, -27), (31, -3), (47, -19), (40, 16), (0, 16)]), PAL["gold_dark"], 70, 2.0 * max(0.6, k), 0.55, 110)
    # inner filigree
    for x0 in (-31, -10, 10, 31):
        art.line(P([(x0, -2 if abs(x0) > 20 else -3), (x0, 15)]), PAL["gold_dark"], 0.9 * k + 0.2, alpha=170)
    # band
    band = [(-41, 15), (41, 15), (42, 32), (-42, 32)]
    gold_fill(art, P(band), ink, ow, PAL["gold_light"], PAL["gold"])
    art.line(P([(-41, 18.5), (41, 18.5)]), PAL["gold_light"], 1.2 * k)
    art.line(P([(-41.5, 28.8), (41.5, 28.8)]), PAL["gold_dark"], 1.2 * k)
    # orbs
    for ox, oy, r in ((-47, -19, 4.2), (47, -19, 4.2), (-22, -27, 4.6), (22, -27, 4.6), (0, -40, 5.6)):
        ex, ey = cx + ox * k, cy + oy * k
        art.circle(ex, ey, r * k, PAL["gold"], ink, ow * 0.9)
        art.circle(ex - r * k * 0.3, ey - r * k * 0.3, r * k * 0.35, PAL["gold_light"])
    # jewels
    if band_gems:
        jewels = [(-30, PAL["navy_mid"], 4.2), (-15, PAL["verdigris"], 3.8), (0, PAL["burgundy_light"], 5.4),
                  (15, PAL["verdigris"], 3.8), (30, PAL["navy_mid"], 4.2)]
        for jx, jc, r in jewels:
            ex, ey = cx + jx * k, cy + 24 * k
            art.poly([(ex, ey - r * k * 1.25), (ex + r * k, ey), (ex, ey + r * k * 1.25), (ex - r * k, ey)], jc, ink, ow * 0.8)
            art.poly([(ex, ey - r * k * 1.25), (ex + r * k * 0.5, ey - r * k * 0.1), (ex, ey - r * k * 0.1), (ex - r * k * 0.5, ey - r * k * 0.1)],
                     rgba(mix(jc, (255, 255, 255), 0.55), 200))


def sword(art, cx, cy, length, ang, blade=None, ink=None, grip=None, gold=None):
    ink = ink or PAL["ink"]
    L = length
    pts = lambda p: rot([(x * L / 100, y * L / 100) for x, y in p], ang, cx, cy)
    bl = pts([(-50, -2.2), (28, -2.2), (50, 0), (28, 2.2), (-50, 2.2)])
    art.fill_grad(bl, mix(PAL["parchment"], (255, 255, 255), 0.4), PAL["steel"], outline=ink, ow=max(1, L * 0.012))
    art.line(pts([(-48, 0), (40, 0)]), PAL["steel_dark"], max(0.8, L * 0.008), alpha=180)
    guard = pts([(-56, -8.5), (-52, -8.5), (-52, 8.5), (-56, 8.5)])
    gold_fill(art, guard, ink, max(1, L * 0.012))
    gr = pts([(-72, -2.2), (-56, -2.2), (-56, 2.2), (-72, 2.2)])
    art.poly(gr, grip or PAL["burgundy"], ink, max(1, L * 0.01))
    x, y = rot([(-76 * L / 100, 0)], ang, cx, cy)[0]
    art.circle(x, y, L * 0.04, PAL["gold"], ink, max(1, L * 0.012))


def quill(art, cx, cy, length, ang, ink=None):
    ink = ink or PAL["ink"]
    L = length
    P = lambda p: rot([(x * L / 100, y * L / 100) for x, y in p], ang, cx, cy)
    vane = [(-50, 0)] + bez((-30, -2), (0, -20), (50, -6), 14) + bez((50, -6), (60, 0), (50, 6), 6)[1:]
    vane2 = bez((50, 6), (0, 16), (-30, 2), 14)
    art.fill_grad(P(vane + vane2), mix(PAL["parchment"], (255, 255, 255), 0.5), PAL["parchment_dark"], outline=ink, ow=max(1, L * 0.012))
    for i in range(10):
        t = -28 + i * 7.5
        art.line(P([(t, 0), (t + 12, -9 + abs(t) * 0.03)]), PAL["parchment_dark"], max(0.7, L * 0.006))
    art.line(P([(-62, 0), (56, 0)]), ink, max(1.0, L * 0.014))
    art.poly(P([(-62, -1.5), (-76, 0), (-62, 1.5)]), ink)
