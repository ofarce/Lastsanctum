#!/usr/bin/env python3
"""Minerais v4 : le minerai ne se voit que sur le dessus du bloc de roche et sur son flanc, légèrement.

Deux calques par minerai et par état (filon, gisement inépuisable), sans forme propre ni contour :
  - dessus : 32 x 32, posé sur la masse rocheuse (même cadre que l'atlas nodules.png) ;
  - flanc  : 32 x 49, posé par-dessus la paroi `face5_*` (ancre 0, 45) quand la case au sud est creusée.
Plus une icône d'inventaire (32 x 32).

Cinq pistes : paillettes, filets, strate teintée, nodules affleurants, fissure cristalline.

Usage : python3 tools/minerais/minerais_v4.py   (écrit planches/assets/minerais-v4/)
        python3 tools/minerais/minerais_v4.py --jeu   (écrit aussi la piste retenue dans le jeu)

Piste retenue le 2026-11-17 : 4 · Nodules affleurants. `--jeu` écrit
  assets/ardoise/world/nodules.png    dessus (filon, gisement) + icônes, 128 x 96, lu par OreView et ItemIcon ;
  assets/ardoise/world/ore_faces.png  calques de flanc 128 x 98 (4 minerais x filon/gisement), lus par World.
"""
from __future__ import annotations

import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import minerais_v2 as v2  # noqa: E402
from minerais_v2 import Layer, PAL, ORES, hexc, hull_pts, facets, finish, prism  # noqa: E402

OUT = os.path.join(v2.ROOT, "planches", "assets", "minerais-v4")
FW, FH = 32, 49
FACE_Y0, FACE_Y1 = 27, 43  # bande du flanc sous les stalactites, au-dessus du pied
TOP_DARK = hexc("#121419")  # ombre portée d'un éclat sur la masse
FACE_DARK = hexc("#141922")
RB = [hexc(c) for c in ("#0b090b", "#1e232c", "#272d37", "#333a46", "#404955", "#515a66")]
GLINT = (11, 13)  # point du reflet animé d'OreView (-5, -3) dans le sprite
# Minerais des six strates (2026-11-22) : dessinés avec la forme d'un minerai existant et leur propre rampe.
# L'ordre suit data/mineable_blocks.gd ORES (colonnes des atlas).
NEW_ORES = {
    "silver": ("iron", [hexc(c) for c in ("#2a303c", "#566070", "#8e98a8", "#c4ccd8", "#f4f8fc")]),
    "tear": ("quartz", [hexc(c) for c in ("#2e4a44", "#5a8a80", "#a9cfc0", "#dcefe6", "#ffffff")]),
    "amber": ("gold", [hexc(c) for c in ("#4a1a06", "#8a3c10", "#d07a2a", "#f0a84a", "#ffe0a0")]),
    "orichalcum": ("copper", [hexc(c) for c in ("#4e2420", "#8a4a3c", "#c47a62", "#e09a78", "#ffd0b8")]),
}
ALL_ORES = list(ORES) + list(NEW_ORES)


def drawn(fn, ore, *args):
    """fn dessinée pour `ore` : un nouveau minerai emprunte la forme de son modèle, avec sa rampe."""
    if ore not in NEW_ORES:
        return fn(ore, *args)
    base, pal = NEW_ORES[ore]
    saved = PAL[base]
    PAL[base] = pal
    try:
        return fn(base, *args)
    finally:
        PAL[base] = saved


def tone(ore):
    """Le fer, gris sur gris, monte d'un palier pour rester lisible sur l'ardoise."""
    p = PAL[ore]
    return [p[1], p[2], p[3], p[4], p[4]] if ore == "iron" else p


class Canvas:
    def __init__(self, w, h):
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.w, self.h = w, h

    def px(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            if len(c) == 4 and c[3] < 255:
                base = self.im.getpixel((x, y))
                if base[3]:
                    a = c[3] / 255
                    c = tuple(int(base[i] * (1 - a) + c[i] * a) for i in range(3)) + (255,)
            self.im.putpixel((x, y), c)

    def has(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h and self.im.getpixel((x, y))[3] > 0


def area(kind, big):
    """Zone où le minerai peut apparaître : (x0, y0, x1, y1)."""
    if kind == "top":
        return (3, 4, 28, 28) if big else (6, 7, 25, 25)
    return (1, FACE_Y0 - (4 if big else 0), 30, FACE_Y1)


def fleck(c: Canvas, x, y, pal, kind, size=1, bright=False):
    """Éclat minuscule : ton moyen, pixel clair en haut à gauche, ombre en bas."""
    dark = TOP_DARK if kind == "top" else FACE_DARK
    if size == 1:
        c.px(x, y, pal[3] if bright else pal[2])
        c.px(x, y + 1, pal[1])
    else:
        c.px(x, y, pal[4] if bright else pal[3])
        c.px(x + 1, y, pal[2])
        c.px(x, y + 1, pal[2])
        c.px(x + 1, y + 1, pal[1])
        c.px(x + 1, y + 2, dark)


# ---------------------------------------------------------------- 1 · Paillettes

def p_paillettes(ore, kind, big, rng):
    pal = tone(ore)
    w, h = (32, 32) if kind == "top" else (FW, FH)
    c = Canvas(w, h)
    x0, y0, x1, y1 = area(kind, big)
    n = (22 if big else 12) if kind == "top" else (30 if big else 16)
    # paillettes groupées en 2-3 essaims, pour éviter le semis uniforme
    swarms = [(rng.uniform(x0 + 3, x1 - 3), rng.uniform(y0 + 2, y1 - 2)) for _ in range(3 if big else 2)]
    if kind == "top":
        swarms[0] = GLINT
    for i in range(n):
        sx, sy = swarms[i % len(swarms)]
        x = min(x1, max(x0, sx + rng.gauss(0, 4.5)))
        y = min(y1, max(y0, sy + rng.gauss(0, 3.0 if kind == "face" else 4)))
        fleck(c, x, y, pal, kind, size=2 if (big and i % 4 == 0) or i == 0 else 1, bright=rng.random() < 0.25)
    return c.im


# ---------------------------------------------------------------- 2 · Filets

def p_filets(ore, kind, big, rng):
    pal = tone(ore)
    w, h = (32, 32) if kind == "top" else (FW, FH)
    c = Canvas(w, h)
    x0, y0, x1, y1 = area(kind, big)
    lines = 3 if big else 2
    for k in range(lines):
        if kind == "face":  # suit le litage de la paroi
            y = y0 + 3 + k * ((y1 - y0 - 4) / lines) + rng.uniform(-1, 1)
            x, ang = x0, rng.uniform(-0.12, 0.12)
            xe = x1
        else:
            x, y = x0 + rng.uniform(0, 4), y0 + 4 + k * 7 + rng.uniform(-1, 2)
            ang = rng.uniform(-0.6, 0.6)
            xe = x1 - rng.uniform(0, 5)
        while x < xe:
            c.px(x, y - 1, (*pal[4][:3], 120) if rng.random() < 0.25 else (0, 0, 0, 0))
            c.px(x, y, pal[3] if rng.random() < 0.35 else pal[2])
            c.px(x, y + 1, TOP_DARK if kind == "top" else FACE_DARK)
            if big and rng.random() < 0.45:
                c.px(x, y + 1, pal[1])
                c.px(x, y + 2, TOP_DARK if kind == "top" else FACE_DARK)
            x += 1
            y += math.sin(ang) + (rng.random() < 0.15) * rng.choice((-1, 1))
            if kind == "top" and rng.random() < 0.18:
                ang = max(-0.9, min(0.9, ang + rng.uniform(-0.7, 0.7)))
            if rng.random() < 0.06:  # interruption : le filet replonge dans la roche
                x += rng.randint(2, 4)
    if kind == "top":
        fleck(c, *GLINT, pal, kind, size=2, bright=True)
    return c.im


# ---------------------------------------------------------------- 3 · Strate teintée

def p_strate(ore, kind, big, rng):
    pal = tone(ore)
    w, h = (32, 32) if kind == "top" else (FW, FH)
    c = Canvas(w, h)
    x0, y0, x1, y1 = area(kind, big)
    tint = pal[2]
    if kind == "face":
        bands = [(y0 + 4, 3)] if not big else [(y0 + 3, 3), (y0 + 11, 2)]
        for yb, th in bands:
            for x in range(x0, x1 + 1):
                off = round(math.sin(x * 0.3 + yb) * 0.8)
                for t in range(th):
                    a = 70 if t == 0 else 55
                    if rng.random() < 0.88:
                        c.px(x, yb + t + off, (*tint[:3], a))
                if rng.random() < 0.14:
                    fleck(c, x, yb + off + rng.randint(0, th - 1), pal, kind, bright=rng.random() < 0.3)
    else:
        inside = lambda x, y, cx=16, cy=16, r=(13 if big else 9.5): ((x - cx) / r) ** 2 + ((y - cy) / (r * 0.75)) ** 2  # noqa: E731
        for y in range(32):
            for x in range(32):
                d = inside(x + rng.uniform(-0.6, 0.6), y + rng.uniform(-0.6, 0.6))
                if d < 1:
                    c.px(x, y, (*tint[:3], 34 if d > 0.45 else 58))
        for _ in range(9 if big else 5):
            fleck(c, rng.uniform(16 - 7, 16 + 7), rng.uniform(13, 21), pal, kind, bright=rng.random() < 0.3)
        fleck(c, *GLINT, pal, kind, size=2, bright=True)
    return c.im


# ---------------------------------------------------------------- 4 · Nodules affleurants

def p_nodules(ore, kind, big, rng):
    pal = tone(ore)
    w, h = (32, 32) if kind == "top" else (FW, FH)
    c = Canvas(w, h)
    x0, y0, x1, y1 = area(kind, big)
    dark = TOP_DARK if kind == "top" else FACE_DARK
    spots = []
    n = (6 if big else 3) if kind == "top" else (7 if big else 4)
    tries = 0
    while len(spots) < n and tries < 200:
        tries += 1
        r = rng.choice((1.5, 2.0, 2.5)) if big else rng.choice((1.5, 2.0))
        x, y = rng.uniform(x0 + 2, x1 - 2), rng.uniform(y0 + 2, y1 - 2)
        if all((x - a) ** 2 + (y - b) ** 2 > (r + rr + 2.5) ** 2 for a, b, rr in spots):
            spots.append((x, y, r))
    if kind == "top":
        spots[0] = (GLINT[0] + 1, GLINT[1] + 1, 2.0)
    for x, y, r in spots:
        # nodule à fleur de roche : disque plat, lumière en haut à gauche, liseré d'ombre en bas
        for yy in range(int(y - r - 1), int(y + r + 2)):
            for xx in range(int(x - r - 1), int(x + r + 2)):
                d = ((xx + 0.5 - x) / r) ** 2 + ((yy + 0.5 - y) / (r * 0.8)) ** 2
                if d <= 1:
                    v = -(xx + 0.5 - x) * 0.6 - (yy + 0.5 - y) * 0.8
                    c.px(xx, yy, pal[3] if v > r * 0.5 else pal[2] if v > -r * 0.3 else pal[1])
                elif d <= 1.7 and yy > y:
                    c.px(xx, yy, dark)
        c.px(x - r * 0.4, y - r * 0.4, pal[4])
    return c.im


# ---------------------------------------------------------------- 5 · Fissure cristalline

def p_fissure(ore, kind, big, rng):
    pal = tone(ore)
    w, h = (32, 32) if kind == "top" else (FW, FH)
    c = Canvas(w, h)
    x0, y0, x1, y1 = area(kind, big)
    dark = hexc("#0d0f14") if kind == "top" else hexc("#10141b")
    cracks = []
    if kind == "face":  # fissures obliques qui traversent le litage
        for k in range(3 if big else 2):
            x = x0 + 5 + k * (x1 - x0 - 8) / (2 if big else 1.4) + rng.uniform(-2, 2)
            cracks.append([(x, y0), (x + rng.uniform(-4, 4), (y0 + y1) / 2), (x + rng.uniform(-5, 5), y1)])
    else:
        cx, cy = 15, 15
        for k in range(4 if big else 3):
            a = k * math.tau / (4 if big else 3) + rng.uniform(-0.4, 0.4)
            ln = rng.uniform(8, 12) if big else rng.uniform(6, 9)
            mid = (cx + math.cos(a + 0.3) * ln * 0.5, cy + math.sin(a + 0.3) * ln * 0.45)
            cracks.append([(cx, cy), mid, (cx + math.cos(a) * ln, cy + math.sin(a) * ln * 0.8)])
    pts = []
    for poly in cracks:
        for (ax, ay), (bx, by) in zip(poly, poly[1:]):
            n = int(max(abs(bx - ax), abs(by - ay))) + 1
            for i in range(n + 1):
                x, y = ax + (bx - ax) * i / n, ay + (by - ay) * i / n
                c.px(x, y, dark)
                pts.append((x, y))
    # cristaux nichés dans la fissure
    rng.shuffle(pts)
    for x, y in pts[: (9 if big else 5)]:
        if ore == "quartz":
            c.px(x, y, pal[3]); c.px(x, y - 1, pal[4]); c.px(x + 1, y, pal[1])
        else:
            c.px(x, y, pal[3] if rng.random() < 0.5 else pal[2]); c.px(x + 1, y, pal[1])
            if rng.random() < 0.4:
                c.px(x, y - 1, pal[4])
    if kind == "top":
        c.px(*GLINT, pal[3])
    return c.im


PISTES = [
    ("paillettes", "Paillettes", p_paillettes,
     "Éclats d’un ou deux pixels groupés en essaims. Sur le flanc, ils suivent le litage de la paroi."),
    ("filets", "Filets", p_filets,
     "Fils de minerai d’un pixel qui serpentent sur le dessus, et suivent les strates sur le flanc, avec des interruptions."),
    ("strate", "Strate teintée", p_strate,
     "La roche prend la couleur du minerai : une tache diffuse sur le dessus, une ou deux strates teintées sur le flanc, avec quelques éclats."),
    ("nodules", "Nodules affleurants", p_nodules,
     "Petits disques plats à fleur de roche, éclairés en haut à gauche, cernés d’un fin liseré d’ombre."),
    ("fissure", "Fissure cristalline", p_fissure,
     "Fissures sombres où sont nichés de minuscules cristaux. Sur le dessus elles rayonnent, sur le flanc elles coupent les strates."),
]


def icon(key, ore, rng):
    """Icône : caillou d'ardoise portant le motif de la piste."""
    L = Layer()
    hull = hull_pts(rng, 16, 17, 11, 8.5, 7, 0.14)
    facets(L, hull, (13, 13), RB[1:], lo=1, bias=0.25)
    rock = finish([L], shadow=(16, 26, 10, 2), rim=False)
    fn = dict((k, f) for k, _n, f, _d in PISTES)[key]
    motif = fn(ore, "top", True, random.Random(f"icon-{key}-{ore}"))
    # le motif est recadré sur le caillou
    mask = rock.split()[3]
    out = rock.copy()
    for y in range(32):
        for x in range(32):
            p = motif.getpixel((x, y))
            if p[3] and mask.getpixel((x, y)) > 0 and rock.getpixel((x, y))[:3] != (10, 13, 18):
                base = out.getpixel((x, y))
                a = p[3] / 255
                out.putpixel((x, y), tuple(int(base[i] * (1 - a) + p[i] * a) for i in range(3)) + (255,))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    faces = [Image.open(os.path.join(v2.ROOT, "assets", "ardoise", "world", "runtime", f"face5_{v}.png")).convert("RGBA") for v in range(6)]
    for key, _name, fn, _d in PISTES:
        atlas = Image.new("RGBA", (32 * len(ALL_ORES), 96))
        fatlas = Image.new("RGBA", (32 * len(ALL_ORES), FH * 2))
        for oi, ore in enumerate(ALL_ORES):
            for si, (st, big) in enumerate((("vein", False), ("lode", True))):
                top = drawn(fn, ore, "top", big, random.Random(f"v4-{key}-{ore}-{st}-top"))
                face = drawn(fn, ore, "face", big, random.Random(f"v4-{key}-{ore}-{st}-face"))
                top.save(os.path.join(OUT, f"{key}-{ore}-{st}-top.png"))
                face.save(os.path.join(OUT, f"{key}-{ore}-{st}-face.png"))
                atlas.alpha_composite(top, (oi * 32, si * 32))
                fatlas.alpha_composite(face, (oi * 32, si * FH))
                # aperçu : calque posé sur une vraie paroi face5
                prev = faces[(oi + si) % 6].copy()
                prev.alpha_composite(face)
                prev.save(os.path.join(OUT, f"{key}-{ore}-{st}-face-apercu.png"))
            ic = drawn(lambda o, r: icon(key, o, r), ore, random.Random(f"v4-{key}-{ore}-icon"))
            ic.save(os.path.join(OUT, f"{key}-{ore}-icon.png"))
            atlas.alpha_composite(ic, (oi * 32, 64))
        atlas.save(os.path.join(OUT, f"atlas-{key}.png"))
        fatlas.save(os.path.join(OUT, f"flancs-{key}.png"))
    if "--jeu" in sys.argv:
        dst = os.path.join(v2.ROOT, "assets", "ardoise", "world")
        Image.open(os.path.join(OUT, f"atlas-{RETENUE}.png")).save(os.path.join(dst, "nodules.png"))
        Image.open(os.path.join(OUT, f"flancs-{RETENUE}.png")).save(os.path.join(dst, "ore_faces.png"))
        print("jeu", dst)
    print("ok", OUT)


RETENUE = "nodules"

if __name__ == "__main__":
    main()
