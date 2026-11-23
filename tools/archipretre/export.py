#!/usr/bin/env python3
"""Export des sprites de l'Archiprêtre aux racines (silhouette A « Agenouillé, soudé à l'autel », choisie le
2026-11-22 sur planches/archipretre-racines-rendu.html) vers assets/imported/archipretre/.

Même dessin que planches/archipretre-export.html (moteur des planches : rampes, ombre en haut à gauche, contour
sélectif), porté en Python : une bande PNG par animation (cadre 56 × 56, pied en ax 28, ay 53) et meta.json.

    python3 tools/archipretre/export.py
"""
import json
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "imported", "archipretre")
W, H = 56, 56

R = {
    "linen": ["#2a2420", "#6e5e4c", "#a89478", "#d8c8a8", "#f2ead4"],
    "stole": ["#2a0e14", "#6a1e2a", "#a8323a", "#d85a4a", "#f6906a"],
    "skin": ["#2e2a30", "#5e5660", "#8c8490", "#b8b0b8", "#dcd6da"],
    "root": ["#160e12", "#3a2228", "#5c3a3a", "#7e5648", "#a07a5e"],
    "moss": ["#141e10", "#2c4a22", "#4e7a34", "#7eaa48", "#b8d878"],
    "bulb": ["#2a060c", "#6a1420", "#a8202e", "#d84a4a", "#ff9a7a"],
    "core": ["#5a2a10", "#c06a20", "#f0b040", "#ffe08a", "#ffffff"],
    "dead": ["#141014", "#2e2628", "#4a3e3e", "#665a56", "#80766e"],
}
MAT = list(R.keys())


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


RGB = {k: [hexrgb(c) for c in v] for k, v in R.items()}


class Buf:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.m = [-1] * (w * h)
        self.s = [0.0] * (w * h)


def put(b, x, y, mat, s):
    x, y = int(x), int(y)  # x|0 du JS : troncature vers zéro
    if x < 0 or y < 0 or x >= b.w or y >= b.h:
        return
    b.m[y * b.w + x] = MAT.index(mat)
    b.s[y * b.w + x] = s


def blob(b, cx, cy, rx, ry, mat, bias=0.0):
    for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
        for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
            dx, dy = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            d = dx * dx + dy * dy
            if d > 1:
                continue
            nz = math.sqrt(1 - min(d, 1))
            put(b, x, y, mat, (-dx * .55 - dy * .65 + nz * .75) * .62 + .28 + bias)


def rect(b, x0, y0, w, h, mat, bias=0.0):
    for y in range(int(y0), int(y0 + h)):
        for x in range(int(x0), int(x0 + w)):
            u, v = (x - x0 + .5) / w, (y - y0 + .5) / h
            put(b, x, y, mat, .75 - u * .45 - v * .2 + bias)


def trap(b, cx, y0, h, w0, w1, mat, bias=0.0):
    y = y0
    while y < y0 + h:
        v = (y - y0) / h
        w = w0 + (w1 - w0) * v
        for x in range(math.floor(cx - w / 2), math.ceil(cx + w / 2) + 1):
            u = (x - (cx - w / 2)) / w
            put(b, x, y, mat, .8 - u * .5 - v * .15 + bias)
        y += 1


def root(b, pts, w0, w1, mat="root"):
    n = len(pts) - 1
    for k in range(n):
        (x0, y0), (x1, y1) = pts[k], pts[k + 1]
        L = math.hypot(x1 - x0, y1 - y0)
        steps = max(1, math.ceil(L * 2))
        for s in range(steps + 1):
            t = s / steps
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            w = w0 + (w1 - w0) * ((k + t) / n)
            blob(b, x, y, max(.6, w / 2), max(.6, w / 2), mat, -.05)


def px(b, x, y, mat, s):
    put(b, x, y, mat, s)


def moss(b, on_mat, rate, seed):
    s = seed

    def rnd():
        nonlocal s
        s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
        return s / 4294967296

    m = MAT.index(on_mat)
    for i in range(b.w * b.h):
        if b.m[i] == m and rnd() < rate:
            b.m[i] = MAT.index("moss")
            b.s[i] = .3 + rnd() * .5


def kneeling(o):
    """Silhouette A paramétrée : pulse (bulbe qui gonfle), open (bulbe ouvert), raise (appel), dead (chute)."""
    b = Buf(W, H)
    pulse, raise_, dead = o.get("pulse", 0), o.get("raise", 0), o.get("dead", 0)
    body = "dead" if dead > 0.5 else "linen"
    bulb_m = "dead" if dead > 0.3 else "bulb"
    sink = round(dead * 4 + 1e-9)
    lift = raise_ * 7
    root(b, [[28, 26 + sink], [16 - raise_ * 2, 30 - lift], [9 - raise_ * 3, 42 - lift * 1.4], [4, 53]], 4, 1.4)
    root(b, [[28, 26 + sink], [41 + raise_ * 2, 31 - lift], [47 + raise_ * 3, 43 - lift * 1.4], [52, 53]], 4, 1.4)
    root(b, [[26, 30 + sink], [19, 42 - lift * .6], [16, 53]], 3, 1.2)
    root(b, [[30, 30 + sink], [37, 42 - lift * .6], [40, 53]], 3, 1.2)
    if dead < 0.95:
        root(b, [[28, 27 + sink], [27, 18 + sink * 1.5], [28, 12 + sink * 3]], 4, 3)
    by = 9 + sink * 3
    br = (1 + pulse * 0.1) * (1 - dead * 0.6)
    if o.get("open") and dead == 0:
        for dx, dy in [(-8, -3), (8, -3), (-6, 4), (6, 4)]:
            blob(b, 28 + dx * (1 + pulse * .08), by + dy, 3.6, 2.6, "bulb", -.1)
        blob(b, 28, by, 7 * br, 6 * br, "bulb", .05)
        blob(b, 28, by - 1, 4 * br, 3.4 * br, "core", .2 + pulse * .1)
    elif br > 0.2:
        blob(b, 28, by, 6.5 * br, 6 * br, bulb_m, -.2 if dead > 0 else 0)
        if dead == 0:
            for k in range(4):
                px(b, 25 + k * 2, by - 3 + (k & 1), "bulb", .95)
    trap(b, 28, 40 + sink, 12 - sink, 18, 28 + sink * 2, body, -.05)
    trap(b, 28, 28 + sink * 2, 13 - sink, 16, 18, body)
    rect(b, 26, 29 + sink * 2, 4, 22 - sink * 2, "dead" if dead > 0.5 else "stole")
    blob(b, 28, 25 + sink * 2.5, 5.4, 5, body, -.12)
    blob(b, 28, 27 + sink * 2.5, 3.2, 2.8, "dead" if dead > 0.5 else "skin", -.1)
    if dead < 0.3:
        px(b, 27, 27, "bulb", .9)
        px(b, 29, 27, "bulb", .9)
    hx = raise_ * 4
    hand = "dead" if dead > 0.5 else "skin"
    blob(b, 26.5 - hx, 35 + sink * 2 + raise_ * 3, 2.2, 2.4, hand)
    blob(b, 29.5 + hx, 35 + sink * 2 + raise_ * 3, 2.2, 2.4, hand, .05)
    root(b, [[22, 46], [15 - raise_ * 3, 51]], 2, 1)
    root(b, [[34, 46], [42 + raise_ * 3, 51]], 2, 1)
    moss(b, "linen" if body == "linen" else "dead", .05 + dead * .1, 11)
    moss(b, "root", .1, 5)
    return b


def paint(img, b, ox):
    pix = img.load()

    def col(i):
        ramp = RGB[MAT[b.m[i]]]
        v = max(0.0, min(.999, b.s[i])) * (len(ramp) - 1.0001)
        k = math.floor(v + 0.5)  # Math.round du JS
        return ramp[min(max(k, 1), len(ramp) - 1)]

    for y in range(b.h):
        for x in range(b.w):
            i = y * b.w + x
            if b.m[i] >= 0:
                pix[ox + x, y] = col(i) + (255,)
    for y in range(b.h):
        for x in range(b.w):
            if b.m[y * b.w + x] >= 0:
                continue
            best = -1
            for dx, dy in [(0, 1), (1, 0), (-1, 0), (0, -1)]:
                X, Y = x + dx, y + dy
                if X < 0 or Y < 0 or X >= b.w or Y >= b.h:
                    continue
                j = Y * b.w + X
                if b.m[j] >= 0:
                    best = b.m[j]
                    break
            if best >= 0:
                pix[ox + x, y] = RGB[MAT[best]][0] + (255,)


ANIMS = {
    "idle": {"count": 6, "fps": 6, "loop": True, "f": lambda k: {"pulse": (1 - math.cos(k / 6 * math.pi * 2)) / 2}},
    "open": {"count": 4, "fps": 8, "loop": True, "f": lambda k: {"open": True, "pulse": (1 - math.cos(k / 4 * math.pi * 2)) / 2}},
    "cast": {"count": 6, "fps": 10, "loop": False, "f": lambda k: {"raise": math.sin(k / 5 * math.pi), "pulse": k / 5}},
    "death": {"count": 8, "fps": 8, "loop": False, "f": lambda k: {"dead": k / 7}},
}


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {"frame_w": W, "frame_h": H, "ax": 28, "ay": 53, "anims": {}}
    for name, a in ANIMS.items():
        img = Image.new("RGBA", (W * a["count"], H), (0, 0, 0, 0))
        for k in range(a["count"]):
            paint(img, kneeling(a["f"](k)), k * W)
        img.save(os.path.join(OUT, name + ".png"))
        meta["anims"][name] = {"count": a["count"], "fps": a["fps"], "loop": a["loop"]}
    with open(os.path.join(OUT, "meta.json"), "w", encoding="utf8") as f:
        json.dump(meta, f, indent=1)
    print("Archiprêtre :", ", ".join(f"{n} ({a['count']})" for n, a in ANIMS.items()), "→", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
