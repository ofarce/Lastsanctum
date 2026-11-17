#!/usr/bin/env python3
"""Icônes d'objets et Entrepôt logistique, style A « Objet franc » (planche planches/rendus-objets-propositions.html).

    python3 tools/objets/objets.py          # écrit les fichiers du jeu
    python3 tools/objets/objets.py --apercu # écrit seulement un aperçu ×4 dans le scratchpad indiqué par --out

Sorties :
- assets/ardoise/ui/items.png : bande d'icônes 32 × 32, dans l'ordre de ORDER (repris par ui/inventory/item_icon.gd) ;
- assets/baked/buildings/da-warehouse_anim.png et _base.png (repère 320 × 240, ancre 160,168, scale 1) ;
- assets/baked/hud/portraits/bld-warehouse.png (128 × 128) ;
- manifest.json → buildings.arts.da-warehouse (relu juste avant l'écriture).
Même dessin que la planche (contour #0b090b, quatre valeurs, lumière en haut à gauche). L'entrepôt de la planche
était en isométrique : il est redessiné ici dans la vue 3/4 du jeu (sol 64 × 64 vu de dessus, éléments verticaux
qui montent).
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = "#0b090b"
M = {
    "wood": ["#3e2617", "#6e4830", "#9c7048", "#c49a68"], "bark": ["#2e2016", "#4e3826", "#6e5238", "#8e7050"],
    "iron": ["#3c4550", "#6a7784", "#9aa8b4", "#d0dae0"], "copper": ["#5e2e1c", "#a45a34", "#d4885e", "#f2b890"],
    "gold": ["#6a4614", "#b8862a", "#e8c060", "#fff0a8"], "rock": ["#1e232b", "#333a46", "#4e5866", "#6e7a88"],
    "fiber": ["#6a5634", "#a08a5c", "#c8b080", "#ecdcb0"], "flame": ["#a8401a", "#e07a20", "#f8c040", "#fff4c8"],
    "cord": ["#6a5a40", "#a8946c", "#d8c8a0", "#f0e4c4"], "blue": ["#1c2c4c", "#2e4c80", "#4c76b0", "#7ea4d8"],
    "red": ["#4c1a18", "#802c24", "#b04a3a", "#d87a64"], "marble": ["#4a4c50", "#6e7074", "#94969a", "#bcbcb8"],
}
ORDER = ["wood", "rock", "torch", "pickaxe", "arrows", "bow", "sword", "shield", "chest", "wood_fiber",
         "firing_post", "barricade", "fishing_rod", "caltrops", "copper_ingot", "iron_ingot", "gold_ingot"]


class R:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.p: list[str | None] = [None] * (w * h)

    def px(self, x, y, c):
        x, y = round(x), round(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[y * self.w + x] = c

    def get(self, x, y):
        return self.p[y * self.w + x] if 0 <= x < self.w and 0 <= y < self.h else None

    def rect(self, x, y, w, h, c):
        for j in range(h):
            for i in range(w):
                self.px(x + i, y + j, c)

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0)) or 1
        n = math.ceil(n)
        for i in range(n + 1):
            self.px(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, c)

    def disc(self, cx, cy, rad, c):
        for y in range(math.floor(cy - rad), math.floor(cy + rad) + 1):
            for x in range(math.floor(cx - rad), math.floor(cx + rad) + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= rad * rad + 0.3:
                    self.px(x, y, c)

    def poly(self, pts, c):
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        for y in range(math.floor(min(ys)), math.floor(max(ys)) + 1):
            for x in range(math.floor(min(xs)), math.floor(max(xs)) + 1):
                ins, j = False, len(pts) - 1
                for i in range(len(pts)):
                    xi, yi = pts[i]
                    xj, yj = pts[j]
                    if (yi > y + .5) != (yj > y + .5) and x + .5 < (xj - xi) * (y + .5 - yi) / (yj - yi) + xi:
                        ins = not ins
                    j = i
                if ins:
                    self.px(x, y, c)

    def rod(self, x0, y0, x1, y1, rad, m):
        n = math.ceil(math.hypot(x1 - x0, y1 - y0) * 2) or 1
        pts = [(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n) for i in range(n + 1)]
        for x, y in pts:
            self.disc(x, y + 0.6, rad, m[0])
        for x, y in pts:
            self.disc(x, y, rad, m[1])
        if rad >= 1:
            for x, y in pts:
                self.px(x - 0.4, y - rad + 0.4, m[2])

    def outline(self, c=OUT):
        add = [(x, y) for y in range(self.h) for x in range(self.w) if not self.get(x, y) and (
            self.get(x + 1, y) or self.get(x - 1, y) or self.get(x, y + 1) or self.get(x, y - 1))]
        for x, y in add:
            self.px(x, y, c)

    def image(self) -> Image.Image:
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for i, c in enumerate(self.p):
            if c:
                im.putpixel((i % self.w, i // self.w), tuple(int(c[k:k + 2], 16) for k in (1, 3, 5)) + (255,))
        return im


# ---------- Objets (32 × 32), traduction directe de la planche ----------
def ingot(r, m):
    r.poly([[5, 20], [27, 20], [29, 25], [3, 25]], m[0])
    r.poly([[3, 25], [29, 25], [28, 27], [4, 27]], m[0])
    r.poly([[8, 12], [24, 12], [27, 20], [5, 20]], m[1])
    r.poly([[10, 9], [22, 9], [24, 12], [8, 12]], m[2])
    r.line(10, 9, 22, 9, m[3]); r.line(8, 12, 24, 12, m[3]); r.px(6, 19, m[2]); r.line(9, 13, 7, 18, m[2])
    r.line(14, 15, 18, 15, m[0]); r.line(16, 14, 16, 18, m[0])


def d_wood(r):
    r.rod(6, 22, 24, 10, 4, M["bark"]); r.rod(9, 25, 27, 17, 3.5, M["bark"])
    for x, y, s in [(24, 10, 4), (27, 17, 3.5)]:
        r.disc(x, y, s, M["wood"][2]); r.disc(x, y, s - 1.4, M["wood"][3]); r.disc(x, y, s - 2.6, M["wood"][1]); r.px(x, y, M["wood"][2])


def d_rock(r):
    k = M["rock"]
    r.poly([[6, 20], [9, 11], [17, 7], [25, 10], [28, 19], [22, 26], [10, 26]], k[1])
    r.poly([[9, 11], [17, 7], [25, 10], [20, 15], [12, 15]], k[3])
    r.poly([[20, 15], [25, 10], [28, 19], [22, 26]], k[2])
    r.poly([[6, 20], [12, 15], [20, 15], [22, 26], [10, 26]], k[1])
    r.line(12, 15, 20, 15, k[0]); r.line(20, 15, 22, 25, k[0]); r.px(14, 10, "#e8e4da"); r.px(15, 10, "#bcb8ae")


def d_torch(r):
    r.rod(10, 27, 19, 13, 1.6, M["wood"]); r.rect(17, 10, 5, 5, M["fiber"][1])
    r.line(17, 11, 21, 11, M["fiber"][3]); r.line(17, 13, 21, 13, M["fiber"][0])
    r.poly([[16, 10], [23, 10], [22, 5], [20, 1], [18, 4]], M["flame"][1])
    r.poly([[17, 10], [22, 10], [21, 6], [20, 3], [19, 6]], M["flame"][2]); r.rect(19, 7, 2, 3, M["flame"][3])


def d_pickaxe(r):
    r.rod(8, 27, 21, 9, 1.6, M["wood"])
    pts, a = [], -1.15
    while a <= 1.15:
        pts.append((18 + math.sin(a) * 11 - math.cos(a), 11 - math.cos(a) * 4 + math.sin(a) * 4)); a += 0.08
    for x, y in pts: r.disc(x, y + 0.7, 1.7, M["iron"][0])
    for x, y in pts: r.disc(x, y, 1.5, M["iron"][2])
    for x, y in pts: r.px(x, y - 1, M["iron"][3])
    r.rect(19, 9, 3, 4, M["iron"][1])


def d_arrows(r):
    for dx, dy in [(0, 0), (3, 3), (-3, 3)]:
        r.line(6 + dx, 23 + dy, 22 + dx, 7 + dy, M["wood"][2]); r.line(7 + dx, 23 + dy, 23 + dx, 7 + dy, M["wood"][1])
        r.poly([[21 + dx, 6 + dy], [26 + dx, 3 + dy], [24 + dx, 9 + dy]], M["iron"][2]); r.px(24 + dx, 5 + dy, M["iron"][3])
        r.poly([[5 + dx, 22 + dy], [3 + dx, 25 + dy], [7 + dx, 26 + dy], [9 + dx, 24 + dy]], M["red"][2]); r.px(5 + dx, 24 + dy, M["red"][3])


def d_bow(r):
    pts, a = [], -1.2
    while a <= 1.2:
        pts.append((9 + math.cos(a) * 11, 16 + math.sin(a) * 12)); a += 0.05
    r.line(pts[0][0], pts[0][1], pts[-1][0], pts[-1][1], M["cord"][3])
    for x, y in pts: r.disc(x, y, 1.3, M["wood"][1])
    for x, y in pts: r.px(x + 0.5, y, M["wood"][3])
    r.rect(18, 14, 3, 5, M["fiber"][1]); r.line(18, 15, 20, 15, M["fiber"][3])


def d_sword(r):
    r.poly([[25, 3], [28, 4], [14, 19], [12, 17]], M["iron"][2]); r.line(26, 4, 13, 18, M["iron"][3]); r.line(27, 5, 14, 19, M["iron"][1])
    r.rod(9, 15, 17, 23, 1.2, M["gold"]); r.rod(11, 21, 6, 26, 1.3, M["wood"]); r.disc(5, 27, 1.8, M["gold"][2])


def d_shield(r):
    r.disc(16, 17, 11.5, M["wood"][0]); r.disc(16, 16, 11, M["iron"][1]); r.disc(16, 16, 9.5, M["wood"][1])
    for x in range(8, 25, 4): r.line(x, 8, x, 25, M["wood"][0])
    r.disc(16, 16, 3.3, M["iron"][1]); r.disc(15.5, 15.5, 2.2, M["iron"][2]); r.px(15, 15, M["iron"][3])
    a = 0.0
    while a < 6.28:
        r.px(16 + math.cos(a) * 10.3 - 0.4, 16 + math.sin(a) * 10.3 - 0.6, M["iron"][3] if 3.6 < a < 5.8 else M["iron"][2]); a += 0.4


def d_chest(r):
    w = M["wood"]
    r.rect(5, 15, 22, 11, w[1]); r.rect(5, 24, 22, 2, w[0]); r.poly([[5, 15], [27, 15], [26, 8], [6, 8]], w[2]); r.line(6, 8, 26, 8, w[3])
    for x in range(6, 27, 5): r.line(x, 16, x, 23, w[0])
    for x in (8, 22): r.rect(x, 8, 2, 18, M["iron"][1]); r.line(x, 8, x, 25, M["iron"][2])
    r.rect(14, 14, 4, 5, M["iron"][2]); r.px(15, 16, OUT); r.px(16, 16, OUT)


def d_fiber(r):
    for i in range(7):
        y = 9 + i * 2.2
        r.line(5, y + 3, 27, y - 1, M["fiber"][1 if i % 2 else 2]); r.line(5, y + 4, 27, y, M["fiber"][0])
    r.rect(11, 7, 3, 16, M["cord"][0]); r.line(11, 7, 11, 22, M["cord"][2]); r.rect(19, 5, 3, 16, M["cord"][0]); r.line(19, 5, 19, 20, M["cord"][2])


def d_post(r):
    w = M["wood"]
    for i in range(5):
        x = 6 + i * 4
        r.poly([[x, 10], [x + 4, 9], [x + 4, 26], [x, 26]], w[1 if i % 2 else 2]); r.line(x, 10, x, 26, w[0]); r.poly([[x, 10], [x + 2, 6], [x + 4, 9]], w[3])
    r.rect(6, 15, 20, 2, w[0]); r.rect(6, 21, 20, 2, w[0]); r.rect(14, 12, 4, 2, OUT)


def d_barricade(r):
    r.rod(4, 25, 26, 8, 1.8, M["wood"]); r.rod(6, 8, 28, 24, 1.8, M["wood"]); r.rod(3, 17, 29, 17, 1.6, M["bark"])
    r.poly([[9, 27], [13, 22], [20, 22], [24, 27]], M["rock"][2]); r.line(13, 22, 20, 22, M["rock"][3]); r.line(9, 27, 24, 27, M["rock"][0])


def d_rod(r):
    r.line(4, 28, 27, 4, M["wood"][1]); r.line(5, 28, 27, 5, M["wood"][2]); r.rod(4, 28, 8, 24, 1.4, M["bark"]); r.disc(9, 23, 2.2, M["iron"][1]); r.px(9, 22, M["iron"][3])
    for y in range(5, 22): r.px(27 + math.sin(y * 0.4) * 0.6, y, M["cord"][3])
    r.disc(27, 23, 1.5, M["red"][2]); r.px(26, 22, M["red"][3]); r.line(27, 25, 27, 27, M["iron"][2]); r.px(26, 28, M["iron"][2]); r.px(25, 27, M["iron"][2])


def d_caltrops(r):
    for x, y in [(10, 20), (21, 23), (18, 12)]:
        r.line(x, y, x - 4, y + 3, M["iron"][1]); r.line(x, y, x + 4, y + 3, M["iron"][1]); r.line(x, y, x, y + 4, M["iron"][0])
        r.line(x, y, x + 1, y - 5, M["iron"][2]); r.px(x + 1, y - 5, M["iron"][3]); r.disc(x, y, 1, M["iron"][2])


DRAW = {"wood": d_wood, "rock": d_rock, "torch": d_torch, "pickaxe": d_pickaxe, "arrows": d_arrows, "bow": d_bow,
        "sword": d_sword, "shield": d_shield, "chest": d_chest, "wood_fiber": d_fiber, "firing_post": d_post,
        "barricade": d_barricade, "fishing_rod": d_rod, "caltrops": d_caltrops,
        "copper_ingot": lambda r: ingot(r, M["copper"]), "iron_ingot": lambda r: ingot(r, M["iron"]),
        "gold_ingot": lambda r: ingot(r, M["gold"])}


def icon_strip() -> Image.Image:
    strip = Image.new("RGBA", (32 * len(ORDER), 32), (0, 0, 0, 0))
    for i, k in enumerate(ORDER):
        r = R(32, 32); DRAW[k](r); r.outline(); strip.paste(r.image(), (i * 32, 0))
    return strip


# ---------- Entrepôt · Halle des rayonnages (vue 3/4 du jeu) ----------
def crate(r, x, y, s, m):
    r.rect(x, y, s, s, m[1]); r.line(x, y, x + s - 1, y, m[3]); r.line(x, y, x, y + s - 1, m[2])
    r.line(x, y + s - 1, x + s - 1, y + s - 1, m[0]); r.line(x + s - 1, y, x + s - 1, y + s - 1, m[0]); r.line(x + 1, y + 1, x + s - 2, y + s - 2, m[0])


def chest_small(r, x, y, m):
    r.rect(x, y + 3, 9, 5, m[1]); r.rect(x, y, 9, 3, m[2]); r.line(x, y, x + 8, y, m[3]); r.rect(x + 4, y + 2, 1, 3, M["iron"][3]); r.line(x, y + 7, x + 8, y + 7, m[0])


def warehouse() -> Image.Image:
    """Repère 320 × 240, ancre (160, 168) ; sol 64 × 64 de x 128 à 191 et y 134 à 197, comme le Creuset."""
    r = R(320, 240)
    mb, x0, x1, y0, y1 = M["marble"], 128, 191, 134, 197
    r.rect(x0, y0, 64, 64, mb[2])                                   # dallage de marbre veiné
    for gx in range(x0, x1, 16): r.line(gx, y0, gx, y1, mb[1])
    for gy in range(y0, y1, 16): r.line(x0, gy, x1, gy, mb[1])
    for vx, vy in [(x0 + 5, y0 + 5), (x0 + 37, y0 + 9), (x0 + 19, y0 + 37), (x0 + 50, y0 + 21), (x0 + 36, y0 + 50)]:
        r.line(vx, vy, vx + 4, vy + 3, mb[3]); r.px(vx + 5, vy + 3, mb[1])
    r.rect(x0, y1 - 2, 64, 3, mb[0])                                # chant avant
    # Mur du fond chargé d'étagères, qui monte au-dessus du bord nord du sol.
    wt = y0 - 34
    r.rect(x0 + 2, wt, 60, 36, mb[1]); r.line(x0 + 2, wt, x0 + 61, wt, mb[3]); r.rect(x0, wt - 3, 64, 4, mb[2]); r.line(x0, wt - 3, x0 + 63, wt - 3, mb[3])
    for s in range(3):
        r.rect(x0 + 3, wt + 10 + s * 11, 58, 2, M["wood"][1]); r.line(x0 + 3, wt + 10 + s * 11, x0 + 60, wt + 10 + s * 11, M["wood"][3])
    goods = [(x0 + 5, wt + 3, "c", M["wood"]), (x0 + 13, wt + 4, "c", M["bark"]), (x0 + 22, wt + 1, "b", M["blue"]),
             (x0 + 34, wt + 3, "c", M["wood"]), (x0 + 43, wt + 1, "r", M["red"]), (x0 + 54, wt + 4, "c", M["bark"]),
             (x0 + 6, wt + 14, "l", None), (x0 + 22, wt + 14, "c", M["wood"]), (x0 + 30, wt + 15, "c", M["bark"]),
             (x0 + 40, wt + 12, "b", M["blue"]), (x0 + 52, wt + 14, "c", M["wood"]),
             (x0 + 5, wt + 25, "c", M["bark"]), (x0 + 14, wt + 26, "c", M["wood"]), (x0 + 25, wt + 23, "r", M["red"]),
             (x0 + 38, wt + 25, "l", None), (x0 + 53, wt + 25, "c", M["wood"])]
    for x, y, k, m in goods:
        if k == "c": crate(r, x, y, 6, m)
        elif k in "br": chest_small(r, x, y, m)
        else:
            for i in range(3): r.disc(x + 2 + i * 4, y + 4, 2, M["bark"][1]); r.px(x + 2 + i * 4, y + 4, M["wood"][3])
    # Caisses et coffres sur le dallage.
    crate(r, x0 + 22, y0 + 26, 9, M["wood"]); crate(r, x0 + 28, y0 + 21, 7, M["bark"]); crate(r, x0 + 36, y0 + 30, 7, M["wood"])
    chest_small(r, x0 + 8, y0 + 44, M["blue"]); chest_small(r, x0 + 47, y0 + 44, M["red"])
    # Deux colonnes trapues aux coins avant.
    for cx in (x0 + 6, x0 + 57):
        top, bot = y1 - 46, y1 - 2
        r.rect(cx - 4, top, 8, bot - top, mb[2]); r.line(cx - 4, top, cx - 4, bot, mb[3]); r.line(cx + 3, top, cx + 3, bot, mb[0]); r.line(cx - 1, top + 2, cx - 1, bot - 2, mb[1])
        r.rect(cx - 6, top - 4, 12, 4, mb[3]); r.line(cx - 6, top - 1, cx + 5, top - 1, mb[1]); r.rect(cx - 6, bot - 3, 12, 3, mb[1])
    r.outline()
    im = r.image()
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    a = im.getchannel("A").point(lambda v: 70 if v else 0)
    shadow.paste((0, 0, 0, 255), (3, 3), a.crop((0, 0, 317, 237)))
    shadow.alpha_composite(im)
    return shadow


def write_game():
    ui = ROOT / "assets/ardoise/ui"; ui.mkdir(parents=True, exist_ok=True)
    icon_strip().save(ui / "items.png")
    w = warehouse()
    for n in ("da-warehouse_anim.png", "da-warehouse_base.png"):
        w.save(ROOT / "assets/baked/buildings" / n)
    bb = w.getbbox()
    side = max(bb[2] - bb[0], bb[3] - bb[1]) + 8
    cx, cy = (bb[0] + bb[2]) // 2, (bb[1] + bb[3]) // 2
    crop = w.crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side))
    crop.resize((128, 128), Image.NEAREST).save(ROOT / "assets/baked/hud/portraits/bld-warehouse.png")
    mf = ROOT / "assets/baked/manifest.json"
    man = json.loads(mf.read_text(encoding="utf-8"))
    man["buildings"]["arts"]["da-warehouse"] = {"anchor": [160, 168], "top": bb[1], "bottom": bb[3], "scale": 1,
        "anim": {"frame_w": 320, "frame_h": 240, "cols": 1, "rows": 1, "count": 1, "seconds": 1 / 12, "fps": 12, "exact": True, "seam_pixels": 0}}
    mf.write_text(json.dumps(man, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("écrit items.png, da-warehouse_*, bld-warehouse.png, manifeste")


if __name__ == "__main__":
    if "--apercu" in sys.argv:
        out = Path(sys.argv[sys.argv.index("--out") + 1])
        icon_strip().resize((32 * len(ORDER) * 4, 128), Image.NEAREST).save(out / "items_x4.png")
        warehouse().crop((100, 60, 220, 210)).resize((480, 600), Image.NEAREST).save(out / "warehouse_x4.png")
    else:
        write_game()
