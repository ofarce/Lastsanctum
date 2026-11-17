#!/usr/bin/env python3
"""Planche « minerais v2 » : 5 pistes x 4 minerais x 3 états (filon, gisement inépuisable, icône).

Chaque sprite fait 32 x 32 px, comme l'atlas actuel `assets/ardoise/world/nodules.png`
(colonnes cuivre, fer, quartz, or ; lignes filon, gisement, icône). Chaque piste est aussi
exportée en atlas 128 x 96 au même format, prêt à remplacer nodules.png.

Usage : python3 tools/minerais/minerais_v2.py   (écrit planches/assets/minerais-v2/)
"""
from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "planches", "assets", "minerais-v2")
S = 32


def hexc(h: str, a: int = 255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# 5 tons : ombre profonde, ombre, moyen, clair, éclat
PAL = {
    "copper": [hexc(c) for c in ("#4a2116", "#7e3f26", "#b86a45", "#e09670", "#ffd2b4")],
    "iron": [hexc(c) for c in ("#26313a", "#46545f", "#73838f", "#a8b6c0", "#e4ecf0")],
    "quartz": [hexc(c) for c in ("#3e3456", "#6b5a8a", "#a897c4", "#d6cbe9", "#fbf7ff")],
    "gold": [hexc(c) for c in ("#5a3c0c", "#94681e", "#d4a446", "#f0d07a", "#fff3bf")],
}
ROCK = [hexc(c) for c in ("#12171e", "#1f2631", "#2f3845", "#434d5b", "#5a6574")]
OUTLINE = hexc("#0a0d12")
ORES = ["copper", "iron", "quartz", "gold"]
L2 = (-0.55, -0.83)  # lumière venant du haut-gauche (vue 3/4)


class _Multi:
    """Pseudo-calque : chaque primitive dessinée ouvre un nouveau calque."""

    def __init__(self, layers):
        self.layers = layers

    def __getattr__(self, name):
        L = Layer()
        self.layers.append(L)
        return getattr(L, name)


class Layer:
    def __init__(self):
        self.im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def px(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < S and 0 <= y < S:
            self.im.putpixel((x, y), c)

    def get(self, x, y):
        if 0 <= x < S and 0 <= y < S:
            return self.im.getpixel((x, y))
        return (0, 0, 0, 0)


def level(v: float, pal, lo=0):
    # v dans [-1, 1] -> index de palette en paliers francs
    if v > 0.55:
        i = 3
    elif v > 0.1:
        i = 2
    elif v > -0.4:
        i = 1
    else:
        i = 0
    return pal[max(lo, i)]


# ---------------------------------------------------------------- primitives

def blob(L: Layer, cx, cy, rx, ry, pal, shine=True):
    """Ellipsoïde ombré (paliers)."""
    lx, ly, lz = -0.5, -0.65, 0.58
    n = math.sqrt(lx * lx + ly * ly + lz * lz)
    lx, ly, lz = lx / n, ly / n, lz / n
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            nx = (x + 0.5 - cx) / rx
            ny = (y + 0.5 - cy) / ry
            d = nx * nx + ny * ny
            if d > 1:
                continue
            nz = math.sqrt(1 - d)
            v = nx * lx + ny * ly + nz * lz
            v = v * 1.6 - 0.55
            L.px(x, y, level(v, pal))
    if shine and rx >= 1.5:
        L.px(cx - rx * 0.4, cy - ry * 0.45, pal[4])


def poly(L: Layer, pts, c):
    L.d.polygon([(round(x), round(y)) for x, y in pts], fill=c)


def facets(L: Layer, hull, apex, pal, lo=0, bias=0.0):
    """Polygone low-poly : éventail depuis `apex`, chaque face ombrée selon sa normale."""
    n = len(hull)
    for k in range(n):
        a, b = hull[k], hull[(k + 1) % n]
        ex, ey = b[0] - a[0], b[1] - a[1]
        nx, ny = ey, -ex
        ln = math.hypot(nx, ny) or 1
        nx, ny = nx / ln, ny / ln
        # orientation : normale sortante
        mx, my = (a[0] + b[0]) / 2 - apex[0], (a[1] + b[1]) / 2 - apex[1]
        if nx * mx + ny * my < 0:
            nx, ny = -nx, -ny
        v = nx * L2[0] + ny * L2[1] + bias
        poly(L, [apex, a, b], level(v, pal, lo))


def hull_pts(rng, cx, cy, rx, ry, n=7, jitter=0.18, rot=None):
    rot = rng.random() * math.tau if rot is None else rot
    pts = []
    for k in range(n):
        t = rot + k * math.tau / n + rng.uniform(-0.25, 0.25)
        r = 1 + rng.uniform(-jitter, jitter)
        pts.append((cx + math.cos(t) * rx * r, cy + math.sin(t) * ry * r))
    pts.sort(key=lambda p: math.atan2(p[1] - cy, p[0] - cx))
    return pts


def boulder(L: Layer, rng, cx, cy, rx, ry, pal=ROCK, n=8, lo=1, bias=0.12):
    hull = hull_pts(rng, cx, cy, rx, ry, n)
    apex = (cx - rx * 0.22, cy - ry * 0.35)
    facets(L, hull, apex, pal, lo, bias)
    return hull


def prism(L: Layer, x, yb, w, h, pal, lean=0.0):
    """Prisme de quartz : base (x, yb), largeur w, hauteur h, inclinaison lean (px)."""
    hw = w / 2
    sh = max(1.5, w * 0.7)
    tip = (x + lean, yb - h)
    bl, br = (x - hw, yb), (x + hw, yb)
    sl, sr = (x - hw + lean * (h - sh) / h, yb - h + sh), (x + hw + lean * (h - sh) / h, yb - h + sh)
    mid_b = (x + lean * 0.0, yb)
    mid_s = (x + lean * (h - sh) / h, yb - h + sh)
    poly(L, [bl, mid_b, mid_s, sl], pal[3])
    poly(L, [mid_b, br, sr, mid_s], pal[1])
    poly(L, [sl, mid_s, tip], pal[4])
    poly(L, [mid_s, sr, tip], pal[2])
    # arête
    for i in range(int(h - sh)):
        t = i / max(1, h - sh)
        L.px(x + lean * (i / h) - 0.4, yb - i - 1, pal[3])


def cube(L: Layer, x, y, s, pal):
    """Petit cube 3/4 : (x, y) = sommet avant de la face du dessus."""
    t = s * 0.5
    top = [(x, y), (x + s, y - t), (x, y - 2 * t), (x - s, y - t)]
    left = [(x - s, y - t), (x, y), (x, y + s), (x - s, y + s - t)]
    right = [(x, y), (x + s, y - t), (x + s, y + s - t), (x, y + s)]
    poly(L, left, pal[2])
    poly(L, right, pal[1])
    poly(L, top, pal[3])
    L.px(x - s + 1, y - t, pal[4])


def nugget(L: Layer, rng, cx, cy, r, pal):
    hull = hull_pts(rng, cx, cy, r * 1.15, r * 0.8, 6, 0.22)
    facets(L, hull, (cx - r * 0.3, cy - r * 0.35), pal, lo=0, bias=0.15)
    L.px(cx - r * 0.35, cy - r * 0.35, pal[4])


def shard(L: Layer, rng, cx, cy, r, pal, ore):
    """Fragment dont la forme dépend du minerai."""
    if ore == "quartz":
        prism(L, cx, cy + r * 0.6, max(2.5, r * 0.9), r * 2.0, pal, rng.uniform(-1.5, 1.5))
    elif ore == "iron":
        cube(L, cx, cy - r * 0.2, max(2, round(r * 0.9)), pal)
    elif ore == "gold":
        nugget(L, rng, cx, cy, r, pal)
    else:  # cuivre : masse bosselée
        blob(L, cx, cy, r * 1.05, r * 0.85, pal)
        blob(L, cx + r * 0.6, cy - r * 0.5, r * 0.55, r * 0.5, pal)


def finish(layers, shadow=None, outline=True, rim=True):
    """Fusionne les calques, ajoute contour noir franc et ombre portée."""
    body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for L in layers:
        im = L.im
        if rim:
            im = rim_dark(im)
        body.alpha_composite(im)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if shadow:
        sx, sy, srx, sry = shadow
        sh = Layer()
        sh.d.ellipse([sx - srx, sy - sry, sx + srx, sy + sry], fill=(4, 6, 10, 110))
        out.alpha_composite(sh.im)
    if outline:
        a = body.split()[3]
        ol = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        for y in range(S):
            for x in range(S):
                if a.getpixel((x, y)) >= 128:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < S and 0 <= yy < S and a.getpixel((xx, yy)) >= 128:
                        ol.putpixel((x, y), OUTLINE)
                        break
        out.alpha_composite(ol)
    out.alpha_composite(body)
    return out


def rim_dark(im):
    """Assombrit d'un palier le bord bas-droit de chaque calque (séparation des volumes)."""
    im = im.copy()
    src = im.copy()
    for y in range(S):
        for x in range(S):
            c = src.getpixel((x, y))
            if c[3] < 128:
                continue
            edge = False
            for dx, dy in ((1, 0), (0, 1)):
                xx, yy = x + dx, y + dy
                if not (0 <= xx < S and 0 <= yy < S) or src.getpixel((xx, yy))[3] < 128:
                    edge = True
            if edge:
                im.putpixel((x, y), (int(c[0] * 0.62), int(c[1] * 0.62), int(c[2] * 0.66), 255))
    return im


def halo(cx, cy, radii, rgb, alphas):
    """Lueur en paliers (pas de dégradé ni de trame)."""
    L = Layer()
    for r, a in sorted(zip(radii, alphas), reverse=True):
        L.d.ellipse([cx - r, cy - r * 0.75, cx + r, cy + r * 0.75], fill=(*rgb[:3], a))
    return L.im


# ---------------------------------------------------------------- pistes

def p1_habitus(ore, state, rng):
    """1 · Habitus : chaque minerai garde sa forme cristalline propre, posé sur une dalle."""
    pal = PAL[ore]
    layers = []
    if state == "icon":
        L = Layer()
        layers.append(L)
        if ore == "quartz":
            prism(L, 12, 26, 5, 15, pal, -2)
            prism(L, 19, 27, 6, 19, pal, 1)
            prism(L, 24, 27, 4, 10, pal, 2)
        elif ore == "iron":
            cube(L, 11, 17, 5, pal)
            cube(L, 21, 18, 6, pal)
            cube(L, 16, 11, 5, pal)
        elif ore == "gold":
            nugget(L, rng, 12, 19, 6, pal)
            nugget(L, rng, 21, 16, 5, pal)
            nugget(L, rng, 19, 23, 4, pal)
        else:
            _dendrite(L, rng, 16, 25, pal, big=True)
        return finish(layers, shadow=(16, 27, 10, 2))
    big = state == "lode"
    base = Layer()
    layers.append(base)
    rx, ry = (13, 6) if big else (10, 5)
    boulder(base, rng, 16, 24, rx, ry, n=9)
    def ore_layer():
        L = Layer()
        layers.append(L)
        return L

    if ore == "quartz":
        specs = [(9, 24, 4, 9, -2), (14, 24, 5, 15, -1), (19, 24, 5, 12, 1), (23, 25, 4, 8, 2)]
        if big:
            specs = [(6, 25, 3, 7, -2), (10, 24, 4, 12, -2), (15, 23, 6, 20, 0), (20, 24, 5, 15, 1),
                     (25, 25, 4, 9, 2)]
        for x, y, w, h, le in specs:
            prism(ore_layer(), x, y, w, h, pal, le)
    elif ore == "iron":
        specs = [(11, 20, 4), (19, 20, 4), (15, 15, 4)] if not big else \
            [(8, 21, 4), (15, 21, 5), (23, 21, 4), (12, 14, 4), (19, 14, 4), (16, 8, 4)]
        for x, y, s in sorted(specs, key=lambda q: q[1]):
            cube(ore_layer(), x, y, s, pal)
    elif ore == "gold":
        specs = [(11, 20, 4), (19, 19, 4.5), (15, 22, 3)] if not big else \
            [(8, 21, 4), (14, 18, 5.5), (21, 19, 5), (17, 23, 3.5), (25, 23, 3)]
        for x, y, r in sorted(specs, key=lambda q: q[1]):
            nugget(ore_layer(), rng, x, y, r, pal)
    else:
        _dendrite(ore_layer(), rng, 16, 23, pal, big=big)
    if big:  # gisement : éclats répandus autour, ancré au sol
        foot = Layer()
        layers.insert(0, foot)
        for x, y in ((4, 27), (27, 28), (22, 29)):
            shard(foot, rng, x, y, 1.6, pal, ore)
    return finish(layers, shadow=(16, 26, rx + 2, 3))


def _dendrite(L: Layer, rng, x0, y0, pal, big=False):
    """Cuivre natif arborescent : tiges épaisses terminées par des boutons."""
    branches = [(-0.9, 9), (-0.2, 11), (0.6, 9)] if not big else [(-1.1, 10), (-0.5, 14), (0.1, 15), (0.7, 12), (1.2, 8)]
    if big and y0 > 24:  # icône
        branches = [(-0.9, 11), (-0.15, 15), (0.7, 12)]
    for ang, ln in branches:
        x, y = x0, y0
        dx, dy = math.sin(ang), -math.cos(ang)
        for i in range(int(ln)):
            x += dx + rng.uniform(-0.35, 0.35)
            y += dy
            L.px(x, y, pal[2])
            L.px(x + 1, y, pal[1])
            if i == int(ln * 0.55):
                bx, by = x + dx * 3 + (2 if ang < 0 else -2) * 0, y
                for j in range(3):
                    L.px(x + (j + 1) * (1 if ang >= 0 else -1), y - j, pal[2])
                blob(L, x + 3.5 * (1 if ang >= 0 else -1), y - 3, 1.8, 1.6, pal)
        blob(L, x, y - 1, 2.6, 2.2, pal)


def p2_affleurement(ore, state, rng):
    """2 · Affleurement : bloc d'ardoise à facettes traversé de veines métalliques."""
    pal = PAL[ore]
    if state == "icon":
        L = Layer()
        hull = hull_pts(rng, 16, 17, 10, 8, 7, 0.15)
        facets(L, hull, (13, 13), pal, lo=0, bias=0.1)
        V = Layer()
        _vein(V, rng, [(7, 21), (13, 18), (18, 20), (25, 15)], ROCK, w=1)
        V2 = Layer()
        V2.px(12, 13, pal[4]); V2.px(13, 13, pal[4]); V2.px(12, 12, pal[4])
        return finish([L, V, V2], shadow=(16, 26, 10, 2), rim=False)
    big = state == "lode"
    base = Layer()
    rx, ry = (14, 10) if big else (11, 8)
    cy = 18 if big else 19
    hull = boulder(base, rng, 16, cy, rx, ry, n=9 if big else 7)
    veins = Layer()
    w = 2 if big else 1
    paths = [[(16 - rx + 2, cy + 1), (12, cy - 2), (17, cy), (16 + rx - 2, cy - 4)],
             [(9, cy + ry - 3), (15, cy + 3), (21, cy + 5)]]
    if big:
        paths.append([(10, cy - ry + 3), (14, cy - 5), (19, cy - 6), (23, cy - 2)])
    for p in paths:
        _vein(veins, rng, p, pal, w=w)
    # inclusions
    for _ in range(4 if big else 2):
        x, y = rng.randint(10, 22), rng.randint(cy - 4, cy + 4)
        veins.px(x, y, pal[3])
        veins.px(x + 1, y, pal[2])
    layers = [base, veins]
    if big:
        crust = Layer()
        for x, y, r in ((6, 27, 2.2), (25, 27, 2.6), (20, 29, 1.6)):
            shard(crust, rng, x, y, r, pal, ore)
        layers.append(crust)
    return finish(layers, shadow=(16, cy + ry - 1, rx + 1, 3))


def _vein(L: Layer, rng, pts, pal, w=1):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / n
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t + (rng.random() < 0.2) * rng.choice((-1, 1))
            L.px(x, y - 1, pal[4] if w > 1 and rng.random() < 0.3 else pal[3])
            L.px(x, y, pal[2])
            if w > 1:
                L.px(x, y + 1, pal[1])


def p3_druse(ore, state, rng):
    """3 · Druse fendue : roche ouverte en deux, cavité tapissée de cristaux."""
    pal = PAL[ore]
    if state == "icon":
        shell = Layer()
        hull = [(4, 17), (7, 10), (14, 6), (22, 7), (28, 13), (27, 22), (19, 27), (9, 25)]
        facets(shell, hull, (13, 11), ROCK, lo=1, bias=0.2)
        cav = Layer()
        cav.d.polygon([(8, 15), (12, 10), (20, 9), (25, 14), (23, 21), (15, 23), (9, 20)], fill=ROCK[0])
        cav.d.polygon([(10, 15), (13, 11), (20, 11), (23, 15), (21, 20), (15, 21), (11, 19)], fill=pal[0])
        _lining(cav, rng, 16.5, 15.5, 5.2, 3.8, pal, ore, n=11)
        return finish([shell, cav], shadow=(16, 27, 10, 2), rim=False)
    big = state == "lode"
    left, right = Layer(), Layer()
    if big:
        boulder(left, rng, 8, 19, 7, 8, n=6, bias=0.2)
        boulder(right, rng, 24, 19, 7, 8, n=6, bias=-0.1)
        back = Layer()
        boulder(back, rng, 16, 11, 9, 5, n=6, bias=0.3)
        cav = Layer()
        cav.d.ellipse([7, 12, 25, 26], fill=ROCK[0])
        cav.d.ellipse([9, 14, 23, 25], fill=pal[0])
        _lining(cav, rng, 16, 19.5, 6.5, 4.8, pal, ore, n=16)
        front = Layer()
        for x, y in ((5, 28), (27, 28), (16, 29)):
            shard(front, rng, x, y, 1.8, pal, ore)
        return finish([back, left, right, cav, front], shadow=(16, 26, 15, 4))
    boulder(left, rng, 10, 20, 6, 7, n=6, bias=0.2)
    boulder(right, rng, 22, 20, 6, 7, n=6, bias=-0.1)
    cav = Layer()
    cav.d.ellipse([10, 15, 22, 26], fill=ROCK[0])
    cav.d.ellipse([11, 17, 21, 25], fill=pal[0])
    _lining(cav, rng, 16, 21, 4.2, 3.2, pal, ore, n=9)
    return finish([left, right, cav], shadow=(16, 26, 12, 3))


def _lining(L: Layer, rng, cx, cy, rx, ry, pal, ore, n=10):
    """Cristaux qui tapissent une cavité, pointés vers le centre."""
    for k in range(n):
        t = k * math.tau / n + rng.uniform(-0.15, 0.15)
        x, y = cx + math.cos(t) * rx, cy + math.sin(t) * ry
        dx, dy = cx - x, cy - y
        ln = math.hypot(dx, dy) or 1
        dx, dy = dx / ln, dy / ln
        top = math.sin(t) < 0
        for i in range(3 if ore == "quartz" else 2):
            c = pal[4] if i == 2 else (pal[1] if top else pal[3]) if i == 0 else pal[2] if top else pal[3]
            L.px(x + dx * i, y + dy * i, c)
    if ore in ("gold", "copper"):
        blob(L, cx, cy + 0.5, rx * 0.45, ry * 0.45, pal)
    elif ore == "iron":
        cube(L, cx, cy - 0.5, 2, pal)
    else:
        L.px(cx, cy, pal[4])


def p4_eboulis(ore, state, rng):
    """4 · Éboulis : tas de blocs de minerai détachés, mêlés de cailloux d'ardoise."""
    pal = PAL[ore]
    if state == "icon":
        L, L2_ = Layer(), Layer()
        shard(L, rng, 14, 17, 7, pal, ore) if ore != "quartz" else prism(L, 14, 25, 7, 18, pal, -1)
        shard(L2_, rng, 23, 23, 3.5, pal, ore) if ore != "quartz" else prism(L2_, 22, 26, 4, 9, pal, 2)
        return finish([L, L2_], shadow=(17, 26, 10, 2))
    big = state == "lode"
    layers = []
    if big:
        spur = Layer()
        hull = [(10, 26), (7, 16), (11, 5), (16, 2), (20, 6), (24, 15), (23, 26)]
        facets(spur, hull, (14, 8), ROCK, lo=1, bias=0.2)
        sv = Layer()
        _vein(sv, rng, [(10, 18), (14, 12), (18, 10), (21, 14)], pal, w=1)
        layers += [spur, sv]
        spots = [(6, 26, 3.2, "o"), (11, 25, 3.8, "o"), (17, 24, 4.2, "o"), (23, 25, 3.4, "o"), (27, 27, 2.4, "r"),
                 (9, 29, 2.2, "r"), (14, 28, 3.0, "o"), (20, 28, 2.8, "o")]
    else:
        spots = [(10, 23, 3.4, "o"), (17, 21, 4.2, "o"), (22, 24, 3, "o"), (7, 26, 2.2, "r"), (14, 26, 3.2, "o"),
                 (24, 27, 2, "r")]
    for x, y, r, kind in sorted(spots, key=lambda s: s[1]):
        L = Layer()
        if kind == "r":
            boulder(L, rng, x, y, r, r * 0.75, n=5)
        elif ore == "quartz":
            prism(L, x, y + r * 0.6, max(3, r), r * 2.4, pal, rng.uniform(-2, 2))
        else:
            shard(L, rng, x, y, r, pal, ore)
        layers.append(L)
    return finish(layers, shadow=(16, 27, 13 if big else 10, 3))


def p5_eclat(ore, state, rng):
    """5 · Éclat intérieur : cristaux sertis qui diffusent une lueur en paliers."""
    pal = PAL[ore]
    glow = pal[3]
    if state == "icon":
        h = halo(16, 17, [12, 8], glow, [48, 86])
        L = Layer()
        if ore == "quartz":
            prism(L, 16, 25, 8, 20, pal, 0)
        else:
            shard(L, rng, 16, 17, 7, pal, ore)
        core = Layer()
        core.px(14, 14, pal[4]); core.px(15, 14, pal[4]); core.px(14, 15, pal[4])
        im = finish([L, core], shadow=None)
        out = Image.new("RGBA", (S, S))
        out.alpha_composite(h)
        out.alpha_composite(im)
        return out
    big = state == "lode"
    cx, cy = 16, 20
    h = halo(cx, cy - 2, [15, 11, 7] if big else [11, 7], glow, [40, 62, 92] if big else [46, 80])
    base = Layer()
    boulder(base, rng, cx, 24, 12 if big else 9, 5 if big else 4, n=8)
    gems = Layer()
    extra = []
    if ore == "quartz":
        specs = [(11, 23, 4, 10, -2), (16, 23, 6, 17 if big else 13, 0), (21, 23, 4, 9, 2)]
        if big:
            specs += [(7, 25, 3, 6, -2), (25, 25, 3, 6, 2)]
        for x, y, w, hh, le in specs:
            prism(gems, x, y, w, hh, pal, le)
    else:
        specs = [(11, 20, 3.4), (17, 18, 4.6 if big else 3.8), (21, 22, 3)]
        if big:
            specs += [(7, 23, 2.4), (25, 23, 2.6), (14, 14, 3)]
        for x, y, r in sorted(specs, key=lambda s: s[1]):
            g = Layer()
            shard(g, rng, x, y, r, pal, ore)
            extra.append(g)
    motes = Layer()
    if big:
        for x, y in ((5, 9), (27, 7), (22, 3), (9, 4)):
            motes.px(x, y, pal[4])
    body = finish([base, gems] + extra, shadow=(16, 26, 13 if big else 10, 3))
    out = Image.new("RGBA", (S, S))
    out.alpha_composite(h)
    out.alpha_composite(body)
    out.alpha_composite(motes.im)
    return out


PISTES = [
    ("habitus", "Habitus", p1_habitus,
     "Chaque minerai garde sa forme cristalline propre : cuivre natif arborescent, fer en cubes, quartz en prismes, or en pépites. Lisible à la silhouette, même sans la couleur."),
    ("affleurement", "Affleurement", p2_affleurement,
     "Bloc d'ardoise à facettes traversé de veines métalliques. Le minerai fait partie de la roche ; le gisement s'élargit et déborde en croûte au pied."),
    ("druse", "Druse fendue", p3_druse,
     "La roche s'ouvre en deux sur une cavité tapissée de cristaux. Le gisement inépuisable devient une grande druse à trois pans."),
    ("eboulis", "Éboulis", p4_eboulis,
     "Tas de blocs de minerai détachés, mêlés de cailloux. Le gisement s'adosse à un éperon veiné qui semble ne jamais s'épuiser."),
    ("eclat", "Éclat intérieur", p5_eclat,
     "Cristaux sertis qui diffusent une lueur en paliers (sans dégradé ni trame). Repérables la nuit ; le gisement a trois anneaux et des poussières en suspension."),
]
STATES = ["vein", "lode", "icon"]


def main():
    os.makedirs(OUT, exist_ok=True)
    for pi, (key, _name, fn, _desc) in enumerate(PISTES):
        atlas = Image.new("RGBA", (S * 4, S * 3), (0, 0, 0, 0))
        for oi, ore in enumerate(ORES):
            for si, st in enumerate(STATES):
                rng = random.Random(f"{key}-{ore}-{st}")
                im = fn(ore, st, rng)
                im.save(os.path.join(OUT, f"{key}-{ore}-{st}.png"))
                atlas.alpha_composite(im, (oi * S, si * S))
        atlas.save(os.path.join(OUT, f"atlas-{key}.png"))
    # référence : atlas actuel découpé
    cur = Image.open(os.path.join(ROOT, "assets", "ardoise", "world", "nodules.png")).convert("RGBA")
    for oi, ore in enumerate(ORES):
        for si, st in enumerate(STATES):
            cur.crop((oi * S, si * S, oi * S + S, si * S + S)).save(os.path.join(OUT, f"actuel-{ore}-{st}.png"))
    _rock_tile()
    print("ok", OUT)


def _rock_tile():
    """Tuile de roche d'ardoise approximative pour le fond de la planche (64 x 64)."""
    rng = random.Random(7)
    t = Image.new("RGBA", (64, 64), hexc("#273041"))
    tones = [hexc("#222a39"), hexc("#2c3546"), hexc("#313b4d")]
    for _ in range(90):
        x, y, r = rng.randint(0, 63), rng.randint(0, 63), rng.randint(2, 6)
        c = rng.choice(tones)
        for yy in range(y - r, y + r):
            for xx in range(x - r, x + r):
                if (xx - x) ** 2 + (yy - y) ** 2 * 1.6 < r * r:
                    t.putpixel((xx % 64, yy % 64), c)
    for _ in range(26):
        t.putpixel((rng.randint(0, 63), rng.randint(0, 63)), hexc("#3a5a2c"))
    for _ in range(60):
        t.putpixel((rng.randint(0, 63), rng.randint(0, 63)), hexc("#1b2130"))
    t.save(os.path.join(OUT, "roche.png"))


if __name__ == "__main__":
    main()
