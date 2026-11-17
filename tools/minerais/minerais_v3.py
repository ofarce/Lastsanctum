#!/usr/bin/env python3
"""Minerais v3 : piste « Affleurement » affinée, minerai pris dans la masse rocheuse.

Le sprite (32 x 32) recouvre exactement une case de roche 4 x 4. Pas d'ombre portée ni d'éclats au sol :
le minerai est pris dans un bloc de la masse rocheuse.

Bloc d'ardoise à facettes (palette des rochers de décor), contour noir en haut et sur les flancs,
base sans contour qui rentre dans la masse ; veines qui suivent les facettes, amas sertis dans une
fissure d'ombre ; mousse sur le dessus.

Usage : python3 tools/minerais/minerais_v3.py   (écrit planches/assets/minerais-v3/)
"""
from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import minerais_v2 as v2  # noqa: E402
from minerais_v2 import Layer, PAL, ORES, S, hexc, facets, hull_pts, prism, cube, nugget, blob, finish  # noqa: E402

OUT = os.path.join(v2.ROOT, "planches", "assets", "minerais-v3")
# Palette des blocs de décor en jeu (mesurée sur capture) : contour, ombre, moyen, clair, éclat
RB = [hexc(c) for c in ("#0b090b", "#1e232c", "#272d37", "#333a46", "#404955", "#515a66")]
MASS = [hexc(c) for c in ("#1b1e25", "#1c1f26", "#1d2128", "#23272f", "#252932")]
CRACK = RB[0]
MOSS = [hexc("#253f1e"), hexc("#305024")]
Y0 = 16  # hauteur de raccord des veines aux bords gauche et droit


def knot(L: Layer, rng, x, y, r, ore):
    """Amas de minerai dont la forme dépend du minerai (prismes, cubes, pépites, masses)."""
    pal = PAL[ore]
    if ore == "quartz":
        prism(L, x, y + r * 0.5, max(2, r * 0.9), r * 2.2, pal, rng.uniform(-1, 1))
    elif ore == "iron":
        cube(L, x, y, max(2, round(r * 0.8)), pal)
    elif ore == "gold":
        nugget(L, rng, x, y, r, pal)
    else:
        blob(L, x, y, r, r * 0.8, pal)


def seam_y(x, amp, rng_phase, y0=Y0):
    """Ondulation de veine, nulle aux bords (raccord)."""
    edge = math.sin(math.pi * x / 31.0)
    return y0 + amp * edge * math.sin(x * 0.33 + rng_phase) + amp * 0.6 * edge * math.sin(x * 0.71 + rng_phase * 2)


def seam(L: Layer, rng, ore, x0, x1, fy, w=2, lips=True, crack=True, sparkle=0.25):
    """Veine quasi horizontale de x0 à x1, centre y = fy(x), w rangées de minerai."""
    pal = PAL[ore]
    for x in range(x0, x1 + 1):
        yc = fy(x)
        top = round(yc - w / 2)
        if lips:
            L.px(x, top - 1, RB[4] if rng.random() < 0.75 else RB[5])
        for k in range(w):
            if k == 0:
                c = pal[4] if rng.random() < sparkle else pal[3]
            elif k == w - 1:
                c = pal[1]
            else:
                c = pal[2]
            L.px(x, top + k, c)
        if crack:
            L.px(x, top + w, CRACK)
            if w >= 3 and rng.random() < 0.5:
                L.px(x, top + w + 1, RB[1])


def mask_blob(rng, cx, cy, rx, ry, rough=0.2):
    pts = []
    ph = [rng.uniform(0, math.tau) for _ in range(3)]

    def inside(x, y):
        a = math.atan2(y - cy, x - cx)
        r = 1 + rough * (math.sin(a * 3 + ph[0]) * 0.5 + math.sin(a * 5 + ph[1]) * 0.35 + math.sin(a * 7 + ph[2]) * 0.2)
        return ((x - cx) / (rx * r)) ** 2 + ((y - cy) / (ry * r)) ** 2 <= 1
    return inside


# ---------------------------------------------------------------- Affleurement affiné

def block_mask(rng, cx, cy, rx, ry, flat):
    """Contour du bloc : à facettes en haut, base aplatie qui rentre dans la masse."""
    hull = hull_pts(rng, cx, cy, rx, ry, 9, 0.12, rot=-math.pi / 2)
    base = cy + ry * flat
    return [(x, min(y, base)) for x, y in hull], base


def inside_poly(pts, x, y):
    c = False
    for (x1, y1), (x2, y2) in zip(pts, pts[1:] + pts[:1]):
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def affleurement(ore, state, rng):
    pal = PAL[ore]
    if state == "icon":
        return icon_shard(ore, rng, flat=False)
    big = state == "lode"
    cx, cy = 16, 16 if big else 17
    rx, ry = (15.5, 14) if big else (14, 11.5)
    hull, base = block_mask(rng, cx, cy, rx, ry, 0.74)
    body = Layer()
    # modelé arrondi des rochers de décor : dôme éclairé haut-gauche, bande sombre en bas
    lx, ly, lz = -0.45, -0.7, 0.55
    for y in range(S):
        for x in range(S):
            if not inside_poly(hull, x + 0.5, y + 0.5):
                continue
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            nz = math.sqrt(max(0.0, 1 - nx * nx - ny * ny))
            v = nx * lx + ny * ly + nz * lz
            body.px(x, y, RB[4] if v > 0.5 else RB[3] if v > -0.05 else RB[2])
    # grain de la pierre, comme les rochers de décor
    for y in range(S):
        for x in range(S):
            c = body.get(x, y)
            if c[3] and rng.random() < 0.16:
                i = RB.index(c) if c in RB else 3
                body.px(x, y, RB[max(1, min(5, i + rng.choice((-1, 1))))])
    m = {(x, y) for y in range(S) for x in range(S) if body.get(x, y)[3] > 0}
    # contour noir sur le haut et les flancs ; la base se fond dans la masse
    out = Layer()
    for y in range(S):
        for x in range(S):
            if (x, y) in m or y >= base - 1:
                continue
            if any((x + dx, y + dy) in m for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.px(x, y, CRACK)
    b = round(base)
    for x in range(S):
        if (x, b - 1) in m:
            body.px(x, b, RB[1])
            body.px(x, b + 1, RB[1] if x % 2 else MASS[3])
            body.px(x, b - 1, RB[2])
    m_in = {(x, y) for (x, y) in m if y < b - 1}

    def clip(L):
        for y in range(S):
            for x in range(S):
                if L.get(x, y)[3] and (x, y) not in m_in:
                    L.im.putpixel((x, y), (0, 0, 0, 0))
        return L

    # facettes : quelques arêtes claires qui cassent le dôme
    for _ in range(3 if big else 2):
        x, y = rng.uniform(cx - rx * 0.6, cx + rx * 0.2), rng.uniform(cy - ry * 0.7, cy - ry * 0.2)
        ang = rng.uniform(0.3, 1.2)
        for i in range(rng.randint(4, 7)):
            if (round(x), round(y)) in m:
                body.px(x, y, RB[5] if i % 3 else RB[4])
                body.px(x + 1, y + 1, RB[2])
            x += math.cos(ang); y += math.sin(ang)
    # veines : tracés brisés qui changent de direction comme aux arêtes des facettes
    V = Layer()
    n_v = 2 if big else 1
    for k in range(n_v):
        x = cx - rx + 3 + rng.uniform(0, 3)
        y = cy + 1 + k * 5 - (2 if big else 0) + rng.uniform(-1, 1)
        ang = rng.uniform(-0.5, 0.3)
        w = 2
        while x < cx + rx - 3:
            seg = rng.uniform(3, 6)
            for _ in range(int(seg)):
                x += math.cos(ang)
                y += math.sin(ang)
                V.px(x, y - 1, RB[5] if rng.random() < 0.6 else RB[4])
                for j in range(w):
                    V.px(x, y + j, pal[3] if j == 0 and rng.random() < 0.8 else pal[2])
                V.px(x, y + w, pal[1])
                V.px(x, y + w + 1, CRACK if rng.random() < 0.6 else RB[1])
            ang = max(-0.9, min(0.9, -ang * 0.7 + rng.uniform(-0.5, 0.5)))
    clip(V)
    # amas sertis : fissure d'ombre autour, la roche les tient
    K = Layer()
    knots = [(10, cy - 3, 3.4), (20, cy - 1, 3.0)] if not big else [(15, cy - 3, 4.6), (7, cy - 1, 3.0), (24, cy - 2, 3.4), (11, cy + 5, 2.6), (21, cy + 5, 2.6)]
    for x, y, r in knots:
        knot(K, rng, x, y, r, ore)
    km = {(x, y) for y in range(S) for x in range(S) if K.get(x, y)[3] > 0}
    ring = Layer()
    for (x, y) in list(m_in):
        if (x, y) in km:
            continue
        nb = [(x + dx, y + dy) in km for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        if any(nb):
            ring.px(x, y, CRACK if not nb[3] else RB[4])  # lèvre claire juste au-dessus du sertissage
    # ce qui dépasse du bloc (pointes de quartz…) reçoit le contour noir franc
    for y in range(S):
        for x in range(S):
            if (x, y) in km or (x, y) in m_in:
                continue
            if any((x + dx, y + dy) in km for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                ring.px(x, y, CRACK)
    # mousse sur le dessus, comme les rochers de décor
    mo = Layer()
    tops = sorted(m_in, key=lambda q: q[1])[: 70]
    for _ in range(5 if big else 3):
        x, y = rng.choice(tops)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 1)):
            if (x + dx, y + dy) in m_in and (x + dx, y + dy) not in km:
                mo.px(x + dx, y + dy, MOSS[(dx + dy) % 2])
    return _stack([out, body, mo, V, ring, K])


# ---------------------------------------------------------------- icônes (objet extrait)

def icon_shard(ore, rng, flat):
    pal = PAL[ore]
    L = Layer()
    hull = hull_pts(rng, 16, 17, 11, 8 if flat else 9, 7, 0.14)
    facets(L, hull, (13, 13), RB[1:], lo=1, bias=0.2)
    if not flat:
        for x in range(7, 26):
            L.px(x, 25, RB[1])
    V = Layer()
    ph = rng.uniform(0, math.tau)
    seam(V, rng, ore, 6, 26, lambda x: 17 + 1.8 * math.sin(x * 0.4 + ph), w=3, lips=True, sparkle=0.35)
    K = Layer()
    knot(K, rng, 12, 13, 3, ore)
    knot(K, rng, 21, 15, 2.2, ore)
    return finish([L, V, K], shadow=(16, 26, 10, 2), rim=False)


def icon_lump(ore, rng):
    pal = PAL[ore]
    L = Layer()
    hull = hull_pts(rng, 16, 17, 10, 8, 7, 0.15)
    facets(L, hull, (13, 13), pal, lo=0, bias=0.1)
    R = Layer()  # gangue de roche accrochée
    for x in range(8, 24):
        y = 22 + round(1.5 * math.sin(x * 0.6))
        R.px(x, y, RB[3])
        R.px(x, y + 1, RB[2])
    R.px(12, 12, pal[4]); R.px(13, 12, pal[4]); R.px(12, 11, pal[4])
    return finish([L, R], shadow=(16, 26, 10, 2), rim=False)


# ---------------------------------------------------------------- outils

def _moss(L, rng, inside, n):
    for _ in range(n):
        x, y = rng.randint(4, 27), rng.randint(3, 12)
        if inside(x, y):
            L.px(x, y, MOSS[1]); L.px(x + 1, y, MOSS[0])


def _stack(layers):
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for L in layers:
        out.alpha_composite(L.im)
    return out


VARIANTS = [("affleurement", "Affleurement", affleurement)]
STATES = ["vein", "lode", "icon"]


def mass_tile(seed=3, size=96):
    """Masse rocheuse imitant le grain du jeu (#1c1f26, bruit fin + taches basse fréquence)."""
    rng = random.Random(seed)
    im = Image.new("RGBA", (size, size))
    blobs = [(rng.uniform(0, size), rng.uniform(0, size), rng.uniform(6, 16)) for _ in range(18)]
    for y in range(size):
        for x in range(size):
            v = 0.0
            for bx, by, r in blobs:
                dx = min(abs(x - bx), size - abs(x - bx))
                dy = min(abs(y - by), size - abs(y - by))
                if dx * dx + dy * dy < r * r:
                    v += 1
            base = 1 if v < 1 else 3
            k = max(0, min(4, base + rng.choice((-1, 0, 0, 1))))
            im.putpixel((x, y), MASS[k])
    for _ in range(8):
        x, y = rng.randrange(size), rng.randrange(size)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (2, 1)):
            im.putpixel(((x + dx) % size, (y + dy) % size), MOSS[rng.randrange(2)])
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    for key, _n, fn in VARIANTS:
        atlas = Image.new("RGBA", (S * 4, S * 3))
        for oi, ore in enumerate(ORES):
            for si, st in enumerate(STATES):
                im = fn(ore, st, random.Random(f"v3-{key}-{ore}-{st}"))
                im.save(os.path.join(OUT, f"{key}-{ore}-{st}.png"))
                atlas.alpha_composite(im, (oi * S, si * S))
        atlas.save(os.path.join(OUT, f"atlas-{key}.png"))
    mass_tile().save(os.path.join(OUT, "masse.png"))
    print("ok", OUT)


if __name__ == "__main__":
    main()
