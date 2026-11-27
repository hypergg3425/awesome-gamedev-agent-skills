#!/usr/bin/env python3
"""IMPERIUM v2.0 extra UI icons (same style as gen_icons.py: 64x64, white 4px strokes, round joins).

Run:  python3 tools/assets/gen_icons_ext.py
"""
import os

import gen_icons as g
from gen_icons import circle, dot, line, path, poly, rect

EXT = {}


def icon(name):
    def deco(fn):
        EXT[name] = fn
        return fn
    return deco


@icon("chevron_down")
def _():
    return [line((14, 24), (32, 42), (50, 24))]


@icon("chevron_up")
def _():
    return [line((14, 42), (32, 24), (50, 42))]


@icon("chevron_right")
def _():
    return [line((24, 14), (42, 32), (24, 50))]


@icon("bell")
def _():
    return [path("M32 8 Q16 12 16 30 V38 L10 46 H54 L48 38 V30 Q48 12 32 8 Z"), path("M26 52 Q32 58 38 52")]


@icon("more")
def _():
    return [dot(14, 32, 4), dot(32, 32, 4), dot(50, 32, 4)]


@icon("pin")
def _():
    return [path("M32 56 Q14 36 14 25 A18 18 0 0 1 50 25 Q50 36 32 56 Z"), circle(32, 25, 6)]


@icon("hourglass")
def _():
    return [line((16, 8), (48, 8)), line((16, 56), (48, 56)), path("M20 8 Q20 28 32 32 Q44 28 44 8"), path("M20 56 Q20 36 32 32 Q44 36 44 56")]


@icon("sparkle")
def _():
    return [path("M32 8 Q34 30 56 32 Q34 34 32 56 Q30 34 8 32 Q30 30 32 8 Z")]


@icon("shield")
def _():
    return [path("M32 8 L52 16 V32 Q52 48 32 57 Q12 48 12 32 V16 Z")]


@icon("eye")
def _():
    return [path("M6 32 Q32 8 58 32 Q32 56 6 32 Z"), circle(32, 32, 8)]


@icon("home")
def _():
    return [poly([(10, 30), (32, 10), (54, 30)], close=False), path("M16 26 V54 H48 V26"), rect(27, 36, 10, 18)]


@icon("refresh")
def _():
    return [path("M50 22 A20 20 0 1 0 52 36"), poly([(52, 8), (52, 22), (38, 22)], close=False)]


@icon("flag")
def _():
    return [line((16, 56), (16, 8)), path("M16 10 H50 L42 22 L50 34 H16")]


def main():
    os.makedirs(g.OUT_DIR, exist_ok=True)
    for n, fn in EXT.items():
        with open(os.path.join(g.OUT_DIR, n + ".svg"), "w", encoding="utf-8") as fh:
            fh.write(g.HEAD + "\n".join(fn()) + "\n" + g.TAIL)
    print(f"wrote {len(EXT)} extra icons")


if __name__ == "__main__":
    main()
