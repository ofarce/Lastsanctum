#!/usr/bin/env python3
"""Planche « Mise en valeur du butin » : inline les vrais sprites du jeu dans le gabarit.

    python3 tools/butin/build.py   ->  planches/butin-propositions.html
"""
import base64
import io
import json
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
A = os.path.join(ROOT, "assets")


def uri(im):
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


man = json.load(open(os.path.join(A, "imported", "enemies", "manifest.json")))["enemies"]


def corpse(kind):
    d = man[kind]["death"]
    i = d["count"] - 1
    sheet = Image.open(os.path.join(A, "imported", "enemies", f"{kind}_death.png")).convert("RGBA")
    fw, fh = d["frame_w"], d["frame_h"]
    x, y = (i % d["cols"]) * fw, (i // d["cols"]) * fh
    return sheet.crop((x, y, x + fw, y + fh)), man[kind]["ax"], man[kind]["ay"]


def icon(path, i, row=0):
    return Image.open(os.path.join(A, *path)).convert("RGBA").crop((i * 32, row * 32, i * 32 + 32, row * 32 + 32))


sprites = {}
for k in ["soldier", "brute", "strazhar"]:
    im, ax, ay = corpse(k)
    sprites[k] = {"src": uri(im), "ax": ax, "ay": ay, "w": im.width, "h": im.height}
wi = ["imported", "engineer", "tyrien", "tyrien_weaponicons.png"]
sprites["greatsword"] = {"src": uri(icon(wi, 2))}
sprites["shield"] = {"src": uri(icon(wi, 5))}
sprites["arrows"] = {"src": uri(icon(["ardoise", "ui", "items.png"], 4))}
mods = Image.open(os.path.join(A, "ardoise", "ui", "mods.png")).convert("RGBA")
sprites["mod_rows"] = [uri(mods.crop((3 * 32, r * 32, 3 * 32 + 32, r * 32 + 32))) for r in range(4)]
copper = Image.open(os.path.join(A, "ardoise", "world", "nodules.png")).convert("RGBA").crop((0, 64, 32, 96))
sprites["copper"] = {"src": uri(copper)}
floor = Image.open(os.path.join(A, "ardoise", "world", "tiles", "floor.png")).convert("RGB").crop((0, 0, 252, 252))
sprites["floor"] = {"src": uri(floor)}

html = open(os.path.join(os.path.dirname(__file__), "template.html"), encoding="utf-8").read()
assert "@@SPRITES@@" in html
html = html.replace("@@SPRITES@@", json.dumps(sprites))
out = os.path.join(ROOT, "planches", "butin-propositions.html")
open(out, "w", encoding="utf-8").write(html)
print(out, len(html) // 1024, "Ko")
