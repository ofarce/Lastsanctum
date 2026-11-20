#!/usr/bin/env python3
"""Icônes 32 × 32 des recherches des biomes 1 et 2 → assets/ui/research/<id>.png (bouton Laiton : trait d'or tant
que la recherche n'est pas faite, couleur ensuite ; ui/hud/action_button.gd, RESEARCH_ICONS).

    python3 tools/biomes-persos/icones_recherche.py     # puis : godot --headless --path . --import

Dessin en aplats avec contour sombre, comme les objets de assets/ardoise/ui/items.png.
"""
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "ui" / "research"
INK = (11, 9, 11, 255)
WOOD = ["#4a2c14", "#7a4c24", "#a8743a", "#d4a462"]
STONE = ["#3a4f51", "#5e7678", "#8a9c9c", "#b8c4c0"]
LEAF = ["#1c5a2e", "#32924a", "#6cc870", "#c8f6b0"]
COPPER = ["#7a4530", "#c47b58", "#f0b088", "#ffe0c8"]
IRON = ["#3a4250", "#646e80", "#98a2b4", "#d6dce8"]
LIMBO = ["#1f9a6a", "#5ce8a8", "#c0ffe0", "#ffffff"]
IVORY = ["#b8a684", "#e2d6b4", "#fffaea", "#ffffff"]
WATER = ["#17383f", "#24565e", "#3f8a8c", "#8ad0c8"]


def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


class Icon:
    def __init__(self):
        self.im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))

    def r(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                if 0 <= xx < 32 and 0 <= yy < 32:
                    self.im.putpixel((xx, yy), rgb(c))

    def line(self, x0, y0, x1, y1, c, t=1):
        n = max(abs(x1 - x0), abs(y1 - y0)) or 1
        for i in range(n + 1):
            self.r(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), t, t, c)

    def save(self, name):
        px = self.im.load()
        out = self.im.copy()
        for y in range(32):
            for x in range(32):
                if px[x, y][3]:
                    continue
                if any(0 <= x + dx < 32 and 0 <= y + dy < 32 and px[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    out.putpixel((x, y), INK)
        out.save(OUT / f"{name}.png")


def gallery_props():  # étai : deux poteaux, un linteau, la galerie noire derrière
    i = Icon()
    i.r(8, 9, 16, 18, "#10181a")
    for x in (6, 22):
        i.r(x, 8, 4, 20, WOOD[1]); i.r(x, 8, 1, 20, WOOD[3]); i.r(x + 3, 8, 1, 20, WOOD[0])
    i.r(4, 5, 24, 4, WOOD[2]); i.r(4, 5, 24, 1, WOOD[3]); i.r(4, 8, 24, 1, WOOD[0])
    i.line(10, 13, 13, 9, WOOD[1], 2); i.line(21, 13, 18, 9, WOOD[1], 2)
    for x in (7, 24):
        i.r(x, 6, 1, 1, IRON[3])
    i.r(4, 28, 24, 1, STONE[1])
    i.save("gallery_props")


def sylviculture():  # souche et jeune pousse
    i = Icon()
    i.r(9, 22, 14, 6, WOOD[1]); i.r(9, 22, 14, 1, WOOD[3]); i.r(11, 23, 10, 1, WOOD[2]); i.r(9, 27, 14, 1, WOOD[0])
    i.r(7, 26, 3, 2, WOOD[0]); i.r(22, 26, 3, 2, WOOD[0])
    i.r(15, 9, 2, 13, LEAF[0]); i.r(15, 9, 1, 13, LEAF[1])
    for x, y, w, h in ((9, 10, 6, 4), (17, 6, 7, 4), (8, 15, 6, 3), (17, 13, 6, 3), (13, 3, 6, 5)):
        i.r(x, y, w, h, LEAF[1]); i.r(x, y, w, 1, LEAF[2]); i.r(x + 1, y + 1, 2, 1, LEAF[3]); i.r(x, y + h - 1, w, 1, LEAF[0])
    i.save("sylviculture")


def fletching():  # flèche en travers, pennes blanches
    i = Icon()
    i.line(6, 25, 24, 7, WOOD[2], 2)
    for k in range(7):  # pointe : triangle tourné vers le haut à droite
        i.r(21 + k, 4, 1, 7 - k, IRON[2] if k < 4 else IRON[1])
    i.r(22, 4, 5, 1, IRON[3]); i.r(27, 4, 1, 1, IRON[3])
    for k in range(4):
        x, y = 5 + k * 2, 26 - k * 2
        i.line(x, y, x - 3, y - 3, IVORY[2], 2); i.line(x + 1, y + 1, x + 4, y + 4, IVORY[1], 2)
    i.r(12, 19, 2, 2, COPPER[1])
    i.save("fletching")


def palisades():  # muret de pierre, pieux, bardage riveté
    i = Icon()
    i.r(3, 13, 26, 15, STONE[1]); i.r(3, 13, 26, 2, STONE[3]); i.r(3, 26, 26, 2, STONE[0])
    for x in (7, 13, 19, 25):
        i.r(x, 4, 2, 11, WOOD[1]); i.r(x, 4, 1, 11, WOOD[3]); i.r(x, 3, 1, 1, WOOD[3])
    i.r(3, 18, 26, 5, WOOD[1]); i.r(3, 18, 26, 1, WOOD[3]); i.r(3, 22, 26, 1, WOOD[0])
    for x in (6, 15, 24):
        i.r(x, 20, 2, 1, IRON[3])
    i.save("palisades")


def limbo_mastery():  # cristal des Limbes au-dessus du fleuve
    i = Icon()
    for k, w in enumerate((2, 4, 6, 8, 10, 10, 10, 8, 8, 6, 6, 4, 4, 2, 2)):
        x = 16 - w // 2
        i.r(x, 3 + k, w, 1, LIMBO[1]); i.r(x, 3 + k, max(1, w // 3), 1, LIMBO[2]); i.r(x + w - max(1, w // 4), 3 + k, max(1, w // 4), 1, LIMBO[0])
    i.r(14, 5, 1, 6, LIMBO[3])
    for y, off in ((21, 0), (24, 3), (27, 0)):
        for x in range(3 + off, 29, 8):
            i.r(x, y, 5, 1, WATER[3]); i.r(x + 1, y + 1, 5, 1, WATER[2])
    i.r(11, 19, 10, 1, LIMBO[0])
    i.save("limbo_mastery")


def copper_seal():  # sceau de cuivre : disque frappé d'un prisme de forage
    i = Icon()
    for y in range(32):
        for x in range(32):
            d = ((x - 15.5) ** 2 + (y - 15.5) ** 2) ** 0.5
            if d <= 12.5:
                c = COPPER[3] if d > 10.5 and x + y < 28 else COPPER[0] if d > 10.5 else COPPER[2] if x + y < 26 else COPPER[1]
                i.im.putpixel((x, y), rgb(c))
    for k, w in enumerate((2, 4, 6, 8, 8, 6, 6, 4, 4, 2, 2)):
        x = 16 - w // 2
        i.r(x, 9 + k, w, 1, COPPER[0]); i.r(x, 9 + k, max(1, w // 2), 1, "#4a2418")
    i.r(15, 10, 1, 5, COPPER[3])
    i.r(9, 22, 14, 1, COPPER[0])
    i.save("copper_seal")


def copper_tips():  # trois pointes de flèche en cuivre
    i = Icon()
    for cx, top in ((8, 9), (16, 4), (24, 9)):
        for k in range(9):
            w = 1 + k if k < 5 else 9 - k
            i.r(cx - w // 2, top + k, max(1, w), 1, COPPER[2] if k < 5 else COPPER[1])
            i.r(cx - w // 2, top + k, 1, 1, COPPER[3])
        i.r(cx, top + 9, 1, 12, WOOD[2]); i.r(cx - 1, top + 9, 1, 12, WOOD[0])
    i.save("copper_tips")


def verdigris_balm():  # pot de baume vert-de-gris
    i = Icon()
    i.r(8, 12, 16, 15, STONE[1]); i.r(8, 12, 3, 15, STONE[3]); i.r(21, 12, 3, 15, STONE[0]); i.r(8, 26, 16, 1, STONE[0])
    i.r(10, 8, 12, 4, WOOD[1]); i.r(10, 8, 12, 1, WOOD[3])
    i.r(11, 16, 10, 7, "#2f6a5c"); i.r(11, 16, 10, 2, "#8fd0b0"); i.r(12, 18, 3, 2, "#d8f4e0")
    i.r(15, 3, 2, 4, "#8fd0b0"); i.r(14, 4, 4, 2, "#8fd0b0")
    i.save("verdigris_balm")


if __name__ == "__main__":
    for f in (gallery_props, sylviculture, fletching, palisades, limbo_mastery, copper_seal, copper_tips, verdigris_balm):
        f()
    print("icônes écrites dans", OUT)
