#!/usr/bin/env python3
"""Export des sprites des mini-boss des Salles oubliées (planches/mini-boss-biome2-rendu.html, choix du 2026-11-25) :
l'Éclusier de Byrsa en silhouette E2 « Le Porte-clef », la Martyre de la Patine en silhouette P1 « L'Automate verdi »,
et la pompe de la Grande Écluse, vers assets/imported/miniboss2/.

Même dessin que la planche (moteur des planches : rampes, ombre en haut à gauche, contour sélectif), porté en Python
et animé : une bande PNG par animation et meta.json (cadre, pied, images, cadence).

    python3 tools/miniboss2/export.py
"""
import json
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "imported", "miniboss2")

R = {
    "copper": ["#24120a", "#5e2e16", "#9a5028", "#c87a42", "#eab07a"],
    "verd": ["#0e1a1a", "#1f3433", "#365a55", "#5e8f80", "#9fcab8"],
    "gold": ["#2a1e08", "#6a4c18", "#a87c2a", "#ddb457", "#fff0b0"],
    "iron": ["#0e1214", "#22292c", "#3a4448", "#5a6a6e", "#8a9a9c"],
    "glass": ["#0a1a22", "#174652", "#2f8494", "#74cad6", "#dcfbff"],
    "water": ["#08161c", "#12343e", "#1f5a68", "#3a8a9a", "#8ed6e0"],
    "mossc": ["#0e1812", "#1c3226", "#2f5240", "#4a7a5e", "#7eaa8a"],
    "ivory": ["#26261f", "#5e5c52", "#9e9a8c", "#d0ccbc", "#f2efe4"],
    "mine": ["#06200f", "#11582e", "#2aa452", "#78e098", "#e0ffe8"],
    "stone": ["#121a1a", "#2c3a3a", "#4a5c5a", "#7a8e8a", "#c0ccc8"],
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
    b.m[y * b.w + x] = -1 if mat is None else MAT.index(mat)
    b.s[y * b.w + x] = s


def get(b, x, y):
    x, y = int(x), int(y)
    if x < 0 or y < 0 or x >= b.w or y >= b.h:
        return -1
    return b.m[y * b.w + x]


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
    y = y0
    while y < y0 + h:
        x = x0
        while x < x0 + w:
            u, v = (x - x0 + .5) / w, (y - y0 + .5) / h
            put(b, x, y, mat, .75 - u * .45 - v * .2 + bias)
            x += 1
        y += 1


def trap(b, cx, y0, h, w0, w1, mat, bias=0.0):
    y = y0
    while y < y0 + h:
        v = (y - y0) / h
        w = w0 + (w1 - w0) * v
        for x in range(math.floor(cx - w / 2), math.ceil(cx + w / 2) + 1):
            u = (x - (cx - w / 2)) / w
            put(b, x, y, mat, .8 - u * .5 - v * .15 + bias)
        y += 1


def line(b, pts, w0, w1, mat, bias=-.05):
    n = len(pts) - 1
    for k in range(n):
        (x0, y0), (x1, y1) = pts[k], pts[k + 1]
        L = math.hypot(x1 - x0, y1 - y0)
        steps = max(1, math.ceil(L * 2))
        for s in range(steps + 1):
            t = s / steps
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            w = w0 + (w1 - w0) * ((k + t) / n)
            blob(b, x, y, max(.6, w / 2), max(.6, w / 2), mat, bias)


def px(b, x, y, mat, s):
    put(b, x, y, mat, s)


def rng(seed):
    s = seed & 0xFFFFFFFF

    def r():
        nonlocal s
        s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
        return s / 4294967296
    return r


def speck(b, on, to, rate, seed):
    r, m = rng(seed), MAT.index(on)
    for i in range(b.w * b.h):
        if b.m[i] == m and r() < rate:
            b.m[i] = MAT.index(to)
            b.s[i] = .3 + r() * .45


def edges(b, on, to, rate, seed):
    r, m = rng(seed), MAT.index(on)
    out = []
    for y in range(b.h):
        for x in range(b.w):
            if b.m[y * b.w + x] != m:
                continue
            if (get(b, x - 1, y) != m or get(b, x, y - 1) != m) and r() < rate:
                out.append(y * b.w + x)
    for i in out:
        b.m[i] = MAT.index(to)
        b.s[i] = .75


def crack(b, x, y, n, mat, seed, only, glow=0.0):
    r = rng(seed)
    on = [MAT.index(k) for k in only]
    for _ in range(n):
        if get(b, x, y) in on:
            put(b, x, y, mat, .55 + r() * .4 + glow)
        x += -1 if r() < .5 else 1
        y += 1 if r() < .7 else 0


def decay(b, dead, seed, keep_rows):
    """Chute : le corps s'affaisse de `dead` × 6 px, s'assombrit et s'effrite (sauf l'ombre, sous keep_rows)."""
    if dead <= 0:
        return b
    sink = round(dead * 6)
    o = Buf(b.w, b.h)
    r = rng(seed)
    for y in range(b.h):
        for x in range(b.w):
            i = y * b.w + x
            if b.m[i] < 0:
                continue
            if y >= keep_rows:
                o.m[i], o.s[i] = b.m[i], b.s[i]
                continue
            ny = min(keep_rows - 1, y + sink)
            if r() < dead * dead * .85:
                continue
            j = ny * b.w + x
            o.m[j] = MAT.index("verd") if dead > .55 and b.m[i] in (MAT.index("copper"), MAT.index("gold")) else b.m[i]
            o.s[j] = b.s[i] - dead * .35
    return o


# ================= Éclusier · E2 « Le Porte-clef » =================

def porthole(b, cx, cy, r, dry, bubble=0):
    blob(b, cx, cy, r + 1.4, r + 1.3, "gold")
    if dry:
        blob(b, cx, cy, r, r * .95, "iron", -.35)
        px(b, cx, cy + r - 1, "water", .7)
    else:
        blob(b, cx, cy, r, r * .95, "glass", .05)
        px(b, cx - 2, cy - 2, "glass", .99)
        px(b, cx - 1, cy - 3, "glass", .99)
        px(b, cx + 1, cy + 1 - bubble, "glass", .9)
    for dx, dy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
        px(b, cx + dx * (r + .8), cy + dy * (r + .6), "iron", .8)


E_W, E_H, E_G = 56, 76, 72


def e2(o):
    """dry : scaphandre vidé ; bob : souffle (px) ; step : jambe levée (-1, 0, 1) ; arm : harpon (-1 armé, 0, 1 lancé) ;
    klift : clef soulevée (px) ; splash : gerbe au pied de la clef ; dead : chute (0 → 1)."""
    dry, u, step = o.get("dry", False), o.get("bob", 0), o.get("step", 0)
    arm, kl, dead = o.get("arm", 0), o.get("klift", 0), o.get("dead", 0)
    b, g = Buf(E_W, E_H), E_G
    blob(b, 26, g + 1, 18, 2.4, "stone", -.45)
    if dry:
        blob(b, 26, g, 13, 1.5, "water", .2)
    if o.get("splash"):
        for k, (dx, dy) in enumerate([(-4, -2), (-2, -4), (0, -5), (2, -4), (4, -2), (6, -1), (-6, -1)]):
            blob(b, 44 + dx, g + dy, 1.2, 1.0, "water", .35 + (k % 2) * .2)
    # clef plantée (hampe à droite), soulevée pendant l'ouverture des vannes
    line(b, [[44, g - kl], [44, 8 - kl]], 3, 3, "gold")
    blob(b, 44, 6 - kl, 5, 5, "gold")
    blob(b, 44, 6 - kl, 2.2, 2.2, None)
    rect(b, 45, 14 - kl, 5, 3, "gold")
    rect(b, 45, 19 - kl, 4, 3, "gold")
    # réservoir dorsal (à gauche, derrière)
    rect(b, 9, 24 + u, 8, 22, "verd")
    blob(b, 13, 24 + u, 4, 2, "verd", .1)
    if not dry:
        rect(b, 11, 30 + u, 4, 14, "glass", -.05)
    else:
        rect(b, 11, 40 + u, 4, 4, "glass", -.1)
    # jambes (une levée à la marche)
    la, ra = (2 if step > 0 else 0), (2 if step < 0 else 0)
    rect(b, 18, g - 24 - la, 6, 20, "copper", -.05)
    rect(b, 28, g - 24 - ra, 6, 20, "copper", -.12)
    blob(b, 21, g - 3 - la, 5, 2.6, "iron")
    blob(b, 31, g - 3 - ra, 5, 2.6, "iron", -.05)
    # corps en cloche
    trap(b, 26, 28 + u, (22 if dry else 20) - u, 14, 20 if dry else 24, "copper")
    rect(b, 15, g - 26, 22, 3, "verd")
    for k in range(5):
        px(b, 17 + k * 4, g - 25, "gold", .85)
    # bras droit sur la clef
    blob(b, 39, 32 + u - kl * .5, 3.6, 6, "copper", -.12)
    blob(b, 42, 36 + u - kl, 3, 2.6, "iron")
    # bras gauche au harpon : armé (ramené), au repos, ou lancé (tendu, la tête est partie)
    if arm < 0:
        blob(b, 16, 33 + u, 3.6, 7, "copper", -.05)
        line(b, [[15, 38 + u], [9, 25 + u]], 2, 2, "iron")
        px(b, 8, 24 + u, "iron", .9)
        px(b, 7, 25 + u, "iron", .9)
        px(b, 9, 23 + u, "iron", .9)
        blob(b, 15, 39 + u, 3, 2.6, "iron")
    elif arm > 0:
        line(b, [[16, 30 + u], [9, 33 + u], [5, 34 + u]], 4, 3.4, "copper", -.05)
        blob(b, 4, 34 + u, 3, 2.6, "iron")
        line(b, [[4, 34 + u], [0, 33 + u]], 1.6, 1.6, "iron")
    else:
        blob(b, 14, 34 + u, 3.6, 7, "copper", -.05)
        line(b, [[12, 40 + u], [3, 30 + u]], 2, 2, "iron")
        px(b, 2, 29 + u, "iron", .9)
        px(b, 1, 30 + u, "iron", .9)
        px(b, 3, 28 + u, "iron", .9)
        blob(b, 12, 41 + u, 3, 2.6, "iron")
    # tête-cloche
    blob(b, 26, 27 + u, 9, 2.6, "gold", -.05)
    trap(b, 26, 9 + u, 17, 10, 16, "copper", .05)
    blob(b, 26, 10 + u, 5.5, 3.5, "copper", .1)
    porthole(b, 26, 18 + u, 3.6, dry, o.get("bubble", 0))
    line(b, [[20, 12 + u], [12, 18 + u], [11, 24 + u]], 2.2, 2, "verd")
    speck(b, "copper", "verd", .08, 5)
    return decay(b, dead, 41, g - 1)


E_ANIMS = {
    "idle": {"count": 4, "fps": 4, "loop": True, "f": lambda k: {"bob": [0, 0, 1, 1][k], "bubble": [0, 1, 2, 1][k]}},
    "walk": {"count": 4, "fps": 8, "loop": True, "f": lambda k: {"step": [1, 0, -1, 0][k], "bob": [0, 1, 0, 1][k]}},
    "harpoon": {"count": 6, "fps": 10, "loop": False, "f": lambda k: {"arm": [-1, -1, -1, 1, 1, 0][k], "bob": [0, 1, 1, 0, 0, 0][k]}},
    "vanne": {"count": 6, "fps": 8, "loop": False,
              "f": lambda k: {"klift": [0, 3, 6, 6, 0, 0][k], "bob": [0, 0, 1, 1, 0, 0][k], "splash": k in (4, 5)}},
}


# ================= Martyre de la Patine · P1 « L'Automate verdi » =================

P_W, P_H, P_G = 56, 76, 72


def p1(o):
    """ox : oxydation (fissures vertes allumées, glow : intensité) ; bob ; step ; raise_ : bras levés (0 → 1) ;
    dead : chute."""
    ox, u, step = o.get("ox", False), o.get("bob", 0), o.get("step", 0)
    ra, dead, gl = o.get("raise", 1.0), o.get("dead", 0), o.get("glow", 0.0)
    b, g = Buf(P_W, P_H), P_G
    blob(b, 28, g + 1, 18, 2.4, "stone", -.45)
    # cape de mousse de cuivre derrière
    trap(b, 28, 20 + u, 50 - u, 18, 34, "mossc", -.05)
    speck(b, "mossc", "verd", .12, 4)
    # jambes et jupe d'écailles
    la, rr = (2 if step > 0 else 0), (2 if step < 0 else 0)
    rect(b, 21, g - 18 - la, 5, 16, "verd", -.05)
    rect(b, 30, g - 18 - rr, 5, 16, "verd", -.12)
    blob(b, 23, g - 2 - la, 4, 2.2, "verd")
    blob(b, 33, g - 2 - rr, 4, 2.2, "verd", -.05)
    trap(b, 28, 38 + u, 18, 14, 22, "verd")
    for y in range(41, 56, 4):
        for x in range(19, 38, 4):
            px(b, x + ((y >> 2) & 1) * 2, y + u, "verd", .9)
    # torse, épaulières
    trap(b, 28, 22 + u, 17, 18, 14, "verd", .05)
    blob(b, 17, 24 + u, 5, 4, "verd", .05)
    blob(b, 39, 24 + u, 5, 4, "verd", -.05)
    # bras : le long du corps (raise 0) ou levés, mains ouvertes (raise 1, elle lance ses anneaux)
    def lerp(a, c, t):
        return a + (c - a) * t
    el, hl = (lerp(13, 9, ra), lerp(34, 18, ra)), (lerp(12, 7, ra), lerp(42, 10, ra))
    er, hr = (lerp(43, 47, ra), lerp(34, 18, ra)), (lerp(44, 49, ra), lerp(42, 10, ra))
    line(b, [[15, 26 + u], [el[0], el[1] + u], [hl[0], hl[1] + u]], 4, 3, "verd")
    line(b, [[41, 26 + u], [er[0], er[1] + u], [hr[0], hr[1] + u]], 4, 3, "verd", -.12)
    blob(b, hl[0], hl[1] - 2 + u, 2.6, 2.4, "ivory")
    blob(b, hr[0], hr[1] - 2 + u, 2.6, 2.4, "ivory", -.05)
    # heaume, fente dorée
    blob(b, 28, 15 + u, 6.5, 7, "verd", .08)
    rect(b, 25, 15 + u, 7, 1, "gold", .2)
    blob(b, 28, 8 + u, 2, 3, "gold", .1)
    edges(b, "verd", "gold", .3, 11)
    if ox:
        crack(b, 26, 26 + u, 14, "mine", 3, ["verd"], gl)
        crack(b, 32, 40 + u, 12, "mine", 8, ["verd"], gl)
        crack(b, 20, 44 + u, 10, "mine", 5, ["verd"], gl)
    return decay(b, dead, 23, g - 1)


P_ANIMS = {
    "idle": {"count": 4, "fps": 4, "loop": True, "f": lambda k: {"bob": [0, 0, 1, 1][k], "raise": .15}},
    "walk": {"count": 4, "fps": 8, "loop": True, "f": lambda k: {"step": [1, 0, -1, 0][k], "bob": [0, 1, 0, 1][k], "raise": .1}},
    "cast": {"count": 6, "fps": 10, "loop": False, "f": lambda k: {"raise": [.15, .45, .8, 1, 1, .6][k], "bob": [0, 0, 1, 1, 0, 0][k]}},
    "ox": {"count": 6, "fps": 8, "loop": False,
           "f": lambda k: {"ox": True, "raise": [.3, .7, 1, 1, 1, .5][k], "glow": [0, .1, .25, .4, .25, 0][k], "bob": [0, 1, 1, 0, 0, 0][k]}},
    "idle_ox": {"count": 4, "fps": 4, "loop": True, "f": lambda k: {"ox": True, "bob": [0, 0, 1, 1][k], "raise": .15}},
    "walk_ox": {"count": 4, "fps": 8, "loop": True, "f": lambda k: {"ox": True, "step": [1, 0, -1, 0][k], "bob": [0, 1, 0, 1][k], "raise": .1}},
}


# ================= Pompe de la Grande Écluse =================

def pump(o):
    held, spurt = o.get("held", False), o.get("spurt", 0)
    b = Buf(40, 34)
    blob(b, 12, 31, 11, 1.8, "stone", -.45)
    rect(b, 4, 12, 16, 18, "copper")
    blob(b, 12, 12, 8, 3, "copper", .1)
    blob(b, 12, 20, 4.4, 4.4, "gold")
    blob(b, 12, 20, 2.4, 2.4, "glass" if held else "iron", .1 if held else -.2)
    line(b, [[12, 8 - (2 if held and spurt else 0)], [12, 2 - (2 if held and spurt else 0)], [20, 2 - (2 if held and spurt else 0)]], 2, 2, "iron")
    line(b, [[20, 26], [30, 30], [38, 30]], 3, 3, "verd")
    if held:
        blob(b, 34 + spurt * 2, 26 - spurt, 4, 2, "water", .1 + spurt * .2)
    speck(b, "copper", "verd", .07, 2)
    return b


PUMP_ANIMS = {
    "pump_free": {"count": 1, "fps": 1, "loop": True, "f": lambda k: {}},
    "pump_held": {"count": 2, "fps": 4, "loop": True, "f": lambda k: {"held": True, "spurt": k}},
}


def paint(img, b, ox):
    pix = img.load()

    def col(i):
        ramp = RGB[MAT[b.m[i]]]
        v = max(0.0, min(.999, b.s[i])) * (len(ramp) - 1.0001)
        k = math.floor(v + 0.5)
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
                j = get(b, x + dx, y + dy)
                if j >= 0:
                    best = j
                    break
            if best >= 0:
                pix[ox + x, y] = RGB[MAT[best]][0] + (255,)


def strip(name, w, h, count, draw):
    img = Image.new("RGBA", (w * count, h), (0, 0, 0, 0))
    for k in range(count):
        paint(img, draw(k), k * w)
    img.save(os.path.join(OUT, name + ".png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {
        "eclusier": {"frame_w": E_W, "frame_h": E_H, "ax": 26, "ay": E_G, "anims": {}},
        "patine": {"frame_w": P_W, "frame_h": P_H, "ax": 28, "ay": P_G, "anims": {}},
        "pump": {"frame_w": 40, "frame_h": 34, "ax": 12, "ay": 31, "anims": {}},
    }
    # Éclusier : chaque animation scaphandre plein (full_) et vidé (dry_) ; la chute part du scaphandre vidé.
    for name, a in E_ANIMS.items():
        for dry in (False, True):
            key = ("dry_" if dry else "full_") + name
            strip("eclusier_" + key, E_W, E_H, a["count"], lambda k, a=a, dry=dry: e2(dict(a["f"](k), dry=dry)))
            meta["eclusier"]["anims"][key] = {"count": a["count"], "fps": a["fps"], "loop": a["loop"]}
    strip("eclusier_death", E_W, E_H, 8, lambda k: e2({"dry": True, "dead": k / 7}))
    meta["eclusier"]["anims"]["death"] = {"count": 8, "fps": 8, "loop": False}
    for name, a in P_ANIMS.items():
        strip("patine_" + name, P_W, P_H, a["count"], lambda k, a=a: p1(a["f"](k)))
        meta["patine"]["anims"][name] = {"count": a["count"], "fps": a["fps"], "loop": a["loop"]}
    strip("patine_death", P_W, P_H, 8, lambda k: p1({"ox": True, "raise": .2, "dead": k / 7}))
    meta["patine"]["anims"]["death"] = {"count": 8, "fps": 8, "loop": False}
    for name, a in PUMP_ANIMS.items():
        strip(name, 40, 34, a["count"], lambda k, a=a: pump(a["f"](k)))
        meta["pump"]["anims"][name] = {"count": a["count"], "fps": a["fps"], "loop": a["loop"]}
    with open(os.path.join(OUT, "meta.json"), "w", encoding="utf8") as f:
        json.dump(meta, f, indent=1)
    n = sum(len(m["anims"]) for m in meta.values())
    print("Mini-boss des Salles oubliées :", n, "bandes →", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
