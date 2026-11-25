#!/usr/bin/env python3
"""Export des repères d'entrée de quartier (planches/reperes-entrees-rendu.html, choix du 2026-11-23 : stèle S1
« Dalle d'ardoise », arche A1 « Piliers et linteau ») vers assets/imported/reperes/.

Par quartier (A ambre · Spirale, B azur · Fourche, C carmin · Œil fendu, fissuré ; Salles oubliées, variante verdie Q1 :
VA eau · Puits, VB cuivre · Vannes, VC vert-de-gris · Goutte) :
  stele_<q>.png : 2 images (éteinte, allumée), cadre 20 × 40, pied (10, 38) ;
  arch_<q>.png  : 3 images (éteinte, allumée flamme 1, allumée flamme 2), cadre 56 × 52, pied (28, 50).
Même moteur que les planches (rampes, ombre en haut à gauche, contour sélectif).

    python3 tools/reperes/export.py
"""
import json
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "imported", "reperes")
R = {
    "slate": ["#141922", "#262e3b", "#424e5f", "#6c7a8c", "#8a98a8"],
    "stone": ["#1c1e26", "#4a4c5a", "#7a7e8c", "#a8acb8", "#dcdee6"],
    "bronze": ["#1e140a", "#5a3a1a", "#8a5a2a", "#b8823e", "#e0b060"],
    "iron": ["#141820", "#3a4250", "#646e80", "#98a2b4", "#d6dce8"],
    "moss": ["#141e10", "#2c4a22", "#4e7a34", "#7eaa48", "#b8d878"],
    "A": ["#3a1e08", "#a8601a", "#f0a040", "#ffd890", "#fff6e0"],
    "B": ["#0a1e3a", "#1e5aa8", "#58a8f0", "#a8d8ff", "#f0faff"],
    "C": ["#3a080e", "#a01e28", "#e04048", "#ff9090", "#ffe8e8"],
    # Salles oubliées (planches/salles-oubliees-decor-propositions.html, Q1 « Stèle tyrienne verdie », 2026-11-25) :
    # ardoise verdie, croûte de vert-de-gris, braseros de cuivre ; Puits eau, Écluses cuivre, Grande Patine vert.
    "vslate": ["#121a1a", "#22302f", "#3a4c4a", "#5a706c", "#7e948e"],
    "verd": ["#15241f", "#24403a", "#3a6a5c", "#5a9a84", "#8ec8b0"],
    "copper": ["#24120a", "#5e2e16", "#9a5028", "#c87a42", "#eab07a"],
    "VA": ["#0a2a30", "#1e6a78", "#4aa6b8", "#a0dce6", "#effcff"],
    "VB": ["#3a1c08", "#9a5420", "#d88a48", "#f8c08a", "#fff0e0"],
    "VC": ["#0e3426", "#2a8060", "#6cc4a0", "#b0ecd2", "#f0fff8"],
}
MAT = list(R)
RGB = {k: [tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in v] for k, v in R.items()}
GLYPH = {
    "A": ["#######", "#.....#", "#.###.#", "#.#.#.#", "#.#...#", "#.#####", "#......"],
    "B": ["#..#..#", "#..#..#", "#..#..#", "#######", "...#...", "...#...", "..###.."],
    "C": ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
    "VA": ["#######", "#.....#", "#..#..#", "#..#..#", "#.###.#", "#.....#", "#######"],
    "VB": ["#.#.#.#", "#.#.#.#", "#######", "#.#.#.#", "#.#.#.#", ".......", ".#.#.#."],
    "VC": ["...#...", "..#.#..", ".#...#.", "#.....#", "#..#..#", ".#...#.", "..###.."],
}


class Buf:
    def __init__(self, w, h):
        self.w, self.h, self.m, self.s = w, h, [-1] * (w * h), [0.0] * (w * h)


def put(b, x, y, mat, s):
    x, y = int(x), int(y)
    if 0 <= x < b.w and 0 <= y < b.h:
        b.m[y * b.w + x] = MAT.index(mat)
        b.s[y * b.w + x] = s


def blob(b, cx, cy, rx, ry, mat, bias=0.0):
    for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
        for x in range(math.floor(cx - rx), math.ceil(cx + rx) + 1):
            dx, dy = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            d = dx * dx + dy * dy
            if d <= 1:
                put(b, x, y, mat, (-dx * .55 - dy * .65 + math.sqrt(1 - min(d, 1)) * .75) * .62 + .28 + bias)


def rect(b, x0, y0, w, h, mat, bias=0.0):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            put(b, x, y, mat, .75 - (x - x0 + .5) / w * .45 - (y - y0 + .5) / h * .2 + bias)


def glyph(b, q, x0, y0, on, base="slate"):
    for j, row in enumerate(GLYPH[q]):
        for i, ch in enumerate(row):
            if ch == "#":
                put(b, x0 + i, y0 + j, q if on else base, .85 if on else .08)


def verdigris(b, rate, seed):
    """Croûte de vert-de-gris sur l'ardoise verdie, coulures vers le bas, angles ébréchés."""
    r = lcg(seed)
    m = MAT.index("vslate")
    for i in range(b.w * b.h):
        if b.m[i] == m and r() < rate:
            b.m[i] = MAT.index("verd")
            b.s[i] = .3 + r() * .5
    for _ in range(3):
        x = 2 + math.floor(r() * (b.w - 4))
        y = 6 + math.floor(r() * (b.h // 3))
        for k in range(6 + math.floor(r() * 8)):
            if b.m[(y + k) * b.w + x] == m:
                b.m[(y + k) * b.w + x] = MAT.index("verd")
                b.s[(y + k) * b.w + x] = .55


def lcg(seed):
    s = seed

    def r():
        nonlocal s
        s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
        return s / 4294967296
    return r


def cracks(b, x, y, h, on, seed):
    r = lcg(seed)
    for _ in range(3):
        cx = x + math.floor(r() * 6)
        for i in range(h):
            put(b, cx, y + i, "C" if on else "slate", .6 if on else .05)
            if r() < .4:
                cx += -1 if r() < .5 else 1


def moss(b, on, rate, seed):
    r = lcg(seed)
    m = MAT.index(on)
    for i in range(b.w * b.h):
        if b.m[i] == m and r() < rate:
            b.m[i] = MAT.index("moss")
            b.s[i] = .3 + r() * .5


def stele(q, on):
    b = Buf(20, 40)
    blob(b, 10, 38, 8, 1.6, "stone", -.45)
    rect(b, 4, 8, 12, 30, "slate")
    blob(b, 10, 8, 6, 4, "slate", .05)
    rect(b, 3, 35, 14, 3, "stone", -.1)
    for y in range(6, 38):
        put(b, 4, y, "slate", .9)
    glyph(b, q, 6, 14, on)
    if q == "C":
        cracks(b, 6, 24, 10, on, 7)
    moss(b, "slate", .04, 3)
    return b


def brazier(b, x, y, metal="bronze"):
    rect(b, x - 3, y, 7, 3, metal)
    blob(b, x, y, 4, 1.6, metal, .1)
    rect(b, x - 1, y + 3, 3, 5, "iron")


def stele_v(q, on):
    b = Buf(20, 40)
    blob(b, 10, 38, 8, 1.6, "stone", -.45)
    rect(b, 4, 8, 12, 30, "vslate")
    blob(b, 10, 8, 6, 4, "vslate", .05)
    rect(b, 3, 35, 14, 3, "stone", -.1)
    for y in range(6, 38):
        put(b, 4, y, "vslate", .9)
    for x, y in ((14, 5), (15, 6), (15, 7), (13, 5)):
        b.m[y * b.w + x] = -1
    glyph(b, q, 6, 14, on, "vslate")
    verdigris(b, .07, 3)
    return b


def arch_v(q, on, t=0):
    b = Buf(56, 52)
    blob(b, 28, 50, 26, 1.6, "stone", -.45)
    for x in (8, 42):
        rect(b, x, 10, 7, 38, "vslate")
        rect(b, x - 1, 46, 9, 3, "stone", -.1)
        rect(b, x - 1, 8, 9, 3, "stone")
    rect(b, 6, 4, 44, 6, "vslate", .05)
    for x in range(6, 50):
        put(b, x, 4, "vslate", .95)
    for x, y in ((48, 4), (49, 4), (49, 5), (6, 9)):
        b.m[y * b.w + x] = -1
    glyph(b, q, 25, 4, on, "vslate")
    brazier(b, 4, 40, "copper")
    brazier(b, 52, 40, "copper")
    if on:
        flame(b, 4, 40, q, t)
        flame(b, 52, 40, q, t)
    verdigris(b, .06, 9)
    return b


def flame(b, x, y, q, t):
    blob(b, x, y - 3, 2.6, 3.4 + (t % 2) * .6, q, .15)
    blob(b, x, y - 5, 1.4, 2, q, .4)


def arch(q, on, t=0):
    b = Buf(56, 52)
    blob(b, 28, 50, 26, 1.6, "stone", -.45)
    for x in (8, 42):
        rect(b, x, 10, 7, 38, "slate")
        rect(b, x - 1, 46, 9, 3, "stone", -.1)
        rect(b, x - 1, 8, 9, 3, "stone")
    rect(b, 6, 4, 44, 6, "slate", .05)
    for x in range(6, 50):
        put(b, x, 4, "slate", .95)
    glyph(b, q, 25, 4, on)
    brazier(b, 4, 40)
    brazier(b, 52, 40)
    if on:
        flame(b, 4, 40, q, t)
        flame(b, 52, 40, q, t)
    if q == "C":
        cracks(b, 9, 14, 22, on, 13)
        cracks(b, 43, 16, 18, on, 17)
    moss(b, "slate", .03, 9)
    return b


def paint(img, b, ox):
    pix = img.load()
    for y in range(b.h):
        for x in range(b.w):
            i = y * b.w + x
            if b.m[i] >= 0:
                ramp = RGB[MAT[b.m[i]]]
                k = math.floor(max(0.0, min(.999, b.s[i])) * (len(ramp) - 1.0001) + .5)
                pix[ox + x, y] = ramp[min(max(k, 1), len(ramp) - 1)] + (255,)
    for y in range(b.h):
        for x in range(b.w):
            if b.m[y * b.w + x] >= 0:
                continue
            for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)):
                X, Y = x + dx, y + dy
                if 0 <= X < b.w and 0 <= Y < b.h and b.m[Y * b.w + X] >= 0:
                    pix[ox + x, y] = RGB[MAT[b.m[Y * b.w + X]]][0] + (255,)
                    break


def strip(frames, name):
    w, h = frames[0].w, frames[0].h
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        paint(img, f, k * w)
    img.save(os.path.join(OUT, name))


def main():
    os.makedirs(OUT, exist_ok=True)
    for q in "ABC":
        strip([stele(q, False), stele(q, True)], f"stele_{q}.png")
        strip([arch(q, False), arch(q, True, 0), arch(q, True, 1)], f"arch_{q}.png")
    for q in ("VA", "VB", "VC"):
        strip([stele_v(q, False), stele_v(q, True)], f"stele_{q}.png")
        strip([arch_v(q, False), arch_v(q, True, 0), arch_v(q, True, 1)], f"arch_{q}.png")
    meta = {"stele": {"w": 20, "h": 40, "ax": 10, "ay": 38, "glow": [10, 17]},
            "arch": {"w": 56, "h": 52, "ax": 28, "ay": 50, "glow": [[4, 36], [52, 36], [28, 7]]}}
    with open(os.path.join(OUT, "meta.json"), "w", encoding="utf8") as f:
        json.dump(meta, f, indent=1)
    print("repères :", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
