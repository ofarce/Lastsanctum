#!/usr/bin/env python3
"""Planches de la faune hostile de la jungle (crocodile, félin), peintes en pixel art par le code.

    python3 tools/fauna/make_fauna.py

Écrit assets/imported/enemies/{croc,feline}_{idle,walk,attack,death}.png et ajoute les entrées au
manifest.json des ennemis (même format que les autres : ax, ay, h, stride, une planche par action).
Vue de profil tournée vers la droite (le jeu retourne le sprite quand la bête regarde à gauche).
"""
import json
import math
import os
import random

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "imported", "enemies")
OUT = (14, 20, 14, 255)


def outline(img):
    w, h = img.size
    px = img.load()
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if 0 <= q[0] < w and 0 <= q[1] < h and px[q][3] and px[q] != OUT:
                    edge.append((x, y))
                    break
    for p in edge:
        px[p] = OUT


def ellipse(px, w, h, cx, cy, rx, ry, col_fn):
    for y in range(max(0, int(cy - ry - 1)), min(h, int(cy + ry + 2))):
        for x in range(max(0, int(cx - rx - 1)), min(w, int(cx + rx + 2))):
            dx = (x + 0.5 - cx) / max(rx, 0.1)
            dy = (y + 0.5 - cy) / max(ry, 0.1)
            if dx * dx + dy * dy < 1.0:
                px[x, y] = col_fn(x, y, dx, dy)


# ------------------------------------------------------------------ Crocodile

CROC = [(38, 52, 32, 255), (52, 70, 40, 255), (70, 90, 50, 255), (96, 116, 64, 255)]
BELLY = (150, 150, 96, 255)
EYE = (220, 190, 60, 255)
TEETH = (232, 228, 206, 255)
MOUTH = (120, 40, 40, 255)
FW, FH = 52, 22


def croc_frame(walk=0.0, jaw=0.0, roll=0.0, sink=0.0):
    img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    px = img.load()
    base = FH - 4 + sink
    body_y = base - 4

    def tone(x, y, dx, dy):
        if dy > 0.45:
            return BELLY
        i = 2 if dy < -0.3 else 1
        if (x + int(y)) % 4 == 0 and dy < 0.1:
            i = 3 if dy < -0.5 else 0
        return CROC[i]

    # Queue : segments qui s'amincissent vers la gauche, ondulation à la marche.
    for k in range(14):
        t = k / 13.0
        cx = 16 - k * 1.1
        cy = body_y + 0.5 + math.sin(walk * math.tau + t * 3.0) * 1.2 * t
        ellipse(px, FW, FH, cx, cy, 2.2, 3.0 * (1.0 - t) + 0.8, tone)
    # Corps.
    ellipse(px, FW, FH, 24, body_y, 10.5, 4.2, tone)
    # Pattes (alternées).
    for i, lx in enumerate((18, 30)):
        ph = walk * math.tau + i * math.pi
        off = math.sin(ph) * 1.5
        for yy in range(int(body_y + 2), int(base + 1)):
            for xx in (int(lx + off), int(lx + off + 1)):
                if 0 <= xx < FW and 0 <= yy < FH:
                    px[xx, yy] = CROC[0]
    # Tête et museau (mâchoire supérieure relevée par jaw).
    ellipse(px, FW, FH, 37, body_y - 0.5, 4.5, 3.2, tone)
    up = jaw * 4.0
    for x in range(38, 51):
        t = (x - 38) / 12.0
        top = body_y - 1.5 - up * t
        for y in range(int(top), int(top + 2.2 - t * 0.6)):
            if 0 <= y < FH:
                px[x, y] = CROC[2] if y == int(top) else CROC[1]
        low = body_y + 1.0
        for y in range(int(low), int(low + 1.8 - t * 0.5)):
            if 0 <= y < FH:
                px[x, y] = BELLY if y > low else CROC[1]
        if jaw > 0.2 and x % 2 == 0:
            if 0 <= int(top + 2) < FH:
                px[x, int(top + 2)] = TEETH
            if 0 <= int(low - 1) < FH:
                px[x, int(low - 1)] = TEETH
        if jaw > 0.2:
            for y in range(int(top + 3), int(low - 1)):
                if 0 <= y < FH:
                    px[x, y] = MOUTH
    # Œil.
    ey = int(body_y - 3 - up * 0.1)
    if 0 <= ey < FH:
        px[39, ey] = EYE
        px[40, ey] = EYE
    outline(img)
    if roll:
        img = img.rotate(-roll, resample=Image.NEAREST, center=(26, FH - 4))
    return img


# ------------------------------------------------------------------ Félin (jaguar)

FUR = [(120, 78, 36, 255), (168, 116, 52, 255), (204, 152, 72, 255), (230, 190, 110, 255)]
SPOT = (52, 34, 22, 255)
CHEST = (236, 216, 170, 255)
GW, GH = 46, 30


def feline_frame(walk=0.0, pounce=0.0, lie=0.0):
    img = Image.new("RGBA", (GW, GH), (0, 0, 0, 0))
    px = img.load()
    base = GH - 3
    stretch = pounce * 5.0
    body_y = base - 9 + lie * 6 - pounce * 2

    def tone(x, y, dx, dy):
        i = 2 if dy < -0.2 else 1
        if dy > 0.55:
            return CHEST
        r = random.Random(x * 7 + int(y) * 131).random()
        if r < 0.13 and -0.6 < dy < 0.5:
            return SPOT
        if dy < -0.65:
            i = 3
        return FUR[i]

    # Pattes.
    if lie < 0.5:
        for i, lx in enumerate((13, 17, 27 + stretch, 31 + stretch)):
            ph = walk * math.tau + (math.pi if i in (1, 2) else 0)
            off = math.sin(ph) * 2.0
            lift = max(0.0, math.cos(ph)) * 1.5
            for yy in range(int(body_y + 2), int(base + 1 - lift)):
                for xx in (int(lx + off), int(lx + off + 1)):
                    if 0 <= xx < GW and 0 <= yy < GH:
                        px[xx, yy] = FUR[0] if xx % 2 else FUR[1]
    # Queue relevée en S.
    for k in range(12):
        t = k / 11.0
        cx = 10 - k * 0.8
        cy = body_y - 1 - math.sin(t * 2.5 + walk * math.tau * 0.5) * 3.0 - t * 2.0 * (1 - lie)
        ellipse(px, GW, GH, cx, cy, 1.2, 1.2, lambda x, y, dx, dy: SPOT if k > 9 else FUR[1])
    # Corps.
    ellipse(px, GW, GH, 22 + stretch * 0.5, body_y, 10 + stretch * 0.5, 4.5 - lie, tone)
    # Tête.
    hx = 35 + stretch
    hy = body_y - 3 + lie * 2 + pounce * 1
    ellipse(px, GW, GH, hx, hy, 4.2, 3.6, tone)
    ellipse(px, GW, GH, hx + 3.5, hy + 1.2, 2.0, 1.6, lambda x, y, dx, dy: FUR[2] if dy < 0.3 else CHEST)
    # Oreilles, œil, crocs.
    for ex in (hx - 2, hx + 1):
        for y in range(int(hy - 5), int(hy - 3)):
            if 0 <= int(ex) < GW and 0 <= y < GH:
                px[int(ex), y] = FUR[1]
    if lie < 0.8:
        px[int(hx + 1), int(hy - 1)] = (240, 220, 90, 255)
    if pounce > 0.4:
        px[int(hx + 4), int(hy + 3)] = (245, 245, 235, 255)
        px[int(hx + 2), int(hy + 3)] = (245, 245, 235, 255)
    outline(img)
    return img


def sheet(frames, cols=12):
    w, h = frames[0].size
    rows = (len(frames) + cols - 1) // cols
    out = Image.new("RGBA", (w * min(cols, len(frames)), h * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, ((i % cols) * w, (i // cols) * h))
    return out, {"frame_w": w, "frame_h": h, "cols": min(cols, len(frames)), "rows": rows, "count": len(frames)}


def main():
    actions = {
        "croc": {
            "idle": ([croc_frame(sink=1.0 + 0.5 * math.sin(i / 24 * math.tau)) for i in range(24)], 8),
            "walk": ([croc_frame(walk=(i % 8) / 8) for i in range(24)], 20),
            "attack": ([croc_frame(jaw=v) for v in (0.2, 0.6, 1.0, 1.0, 0.6, 0.1, 0.0, 0.0)], 16),
            "death": ([croc_frame(roll=min(180, i * 30), sink=min(i, 9) * 0.4) for i in range(45)], 24),
            "meta": {"ax": 28, "ay": FH - 3, "h": 9, "stride": 1.2, "self_bob": False},
        },
        "feline": {
            "idle": ([feline_frame(walk=0.0) if i % 12 else feline_frame(walk=0.05) for i in range(24)], 8),
            "walk": ([feline_frame(walk=(i % 8) / 8) for i in range(24)], 24),
            "attack": ([feline_frame(pounce=v) for v in (0.2, 0.6, 1.0, 1.0, 0.7, 0.3, 0.0, 0.0)], 18),
            "death": ([feline_frame(lie=min(1.0, i / 12)) for i in range(45)], 24),
            "meta": {"ax": 23, "ay": GH - 3, "h": 14, "stride": 1.8, "self_bob": False},
        },
    }
    man_path = os.path.join(ROOT, "manifest.json")
    man = json.load(open(man_path))
    for kind, spec in actions.items():
        entry = dict(spec["meta"])
        for action in ("idle", "walk", "attack", "death"):
            frames, fps = spec[action]
            img, meta = sheet(frames)
            meta["fps"] = fps
            img.save(os.path.join(ROOT, "%s_%s.png" % (kind, action)))
            entry[action] = meta
        man["enemies"][kind] = entry
    with open(man_path, "w") as f:
        json.dump(man, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("ok")


if __name__ == "__main__":
    main()
