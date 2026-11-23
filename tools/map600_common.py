"""Shared helpers for the extended (map600) generators."""
import math, os, re, unicodedata
import numpy as np
from shapely.geometry import Polygon, MultiPolygon, LineString, MultiLineString, GeometryCollection

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NE = '/tmp/claude-0/ne/'
NE2 = '/tmp/claude-0/ne2/'
WORK = '/tmp/claude-0/'
CLASSIC_PKL = WORK + 'provinces_step1.pkl'
UNITS_PKL = WORK + 'units600.pkl'
MAP600_PKL = WORK + 'provinces600_step1.pkl'


def slug(s):
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode()
    s = re.sub(r'[^a-zA-Z0-9]+', '_', s).strip('_').lower()
    return s or 'x'


def km2(geom):
    c = geom.centroid
    return geom.area * 111.32 * 111.32 * math.cos(math.radians(c.y))


def polys(g):
    if g.is_empty:
        return []
    if isinstance(g, Polygon):
        return [g]
    if isinstance(g, (MultiPolygon, GeometryCollection)):
        out = []
        for x in g.geoms:
            out += polys(x)
        return out
    return []


def lines(g):
    if g.is_empty:
        return []
    if isinstance(g, LineString):
        return [g]
    if isinstance(g, (MultiLineString, GeometryCollection)):
        out = []
        for x in g.geoms:
            out += lines(x)
        return out
    return []


def hav_km(lon1, lat1, lon2, lat2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2 - lon1)
    a = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 6371.0 * 2 * math.asin(math.sqrt(a))


def cos_lat(y):
    return math.cos(math.radians(y))


def kmeans(items, k, iters=40):
    """Deterministic area-weighted k-means on (cx, cy, w) items; returns index groups."""
    n = len(items)
    if k >= n:
        return [[i] for i in range(n)]
    P = np.array([[it['cx'] * cos_lat(it['cy']), it['cy']] for it in items])
    W = np.array([max(it['area'], 1.0) for it in items])
    idx = [int(np.argmax(W))]
    while len(idx) < k:
        d = np.min(((P[:, None, :] - P[idx][None, :, :]) ** 2).sum(-1), axis=1) * np.sqrt(W)
        idx.append(int(np.argmax(d)))
    C = P[idx].copy()
    for _ in range(iters):
        lab = ((P[:, None, :] - C[None, :, :]) ** 2).sum(-1).argmin(1)
        newC = C.copy()
        for j in range(k):
            m = lab == j
            if m.any():
                newC[j] = (P[m] * W[m, None]).sum(0) / W[m].sum()
        if np.allclose(newC, C):
            break
        C = newC
    lab = ((P[:, None, :] - C[None, :, :]) ** 2).sum(-1).argmin(1)
    return [[i for i in range(n) if lab[i] == j] for j in range(k) if (lab == j).any()]
