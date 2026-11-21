#!/usr/bin/env python3
"""Planche « Premier ramassage d'un mod » : inline la vraie capture, l'atlas des mods et la police du HUD.

    python3 tools/mod_reveal/build.py   ->  planches/mod-revelation-propositions.html
"""
import base64
import io
import json
import os
import re

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def uri(im, fmt="PNG"):
    b = io.BytesIO()
    if fmt == "JPEG":
        im.convert("RGB").save(b, "JPEG", quality=90)
        return "data:image/jpeg;base64," + base64.b64encode(b.getvalue()).decode()
    im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


# Mods : nom, rareté, clé et effet tirés de data/gear_items.gd (ordre de l'atlas : item_icon.gd, MOD_ORDER).
src = open(os.path.join(ROOT, "data", "gear_items.gd"), encoding="utf-8").read()
order = re.search(r"MOD_ORDER := \[(.*?)\]", open(os.path.join(ROOT, "ui", "inventory", "item_icon.gd"),
                                                    encoding="utf-8").read(), re.S).group(1)
order = re.findall(r'"(\w+)"', order)
mods = {}
for m in re.finditer(r'"module_(\w+)": \{(.*?)"desc": "(.*?)"\}', src, re.S):
    body = m.group(2)
    mods[m.group(1)] = {
        "name": re.search(r'"name": "(.*?)"', body).group(1),
        "rarity": re.search(r'"rarity": "(.*?)"', body).group(1),
        "col": order.index(m.group(1)),
        "desc": m.group(3).replace("Module d’exo. ", ""),
    }

D = {
    "mods": mods,
    "atlas": uri(Image.open(os.path.join(ROOT, "assets", "ardoise", "ui", "mods.png")).convert("RGBA")),
    "backdrop": uri(Image.open(os.path.join(ROOT, "tests", "visual", "out", "mods_douze", "b_1_porte.png")), "JPEG"),
}
font = base64.b64encode(open(os.path.join(ROOT, "assets", "fonts", "NotoSerif-Regular.ttf"), "rb").read()).decode()

html = open(os.path.join(os.path.dirname(__file__), "template.html"), encoding="utf-8").read()
html = html.replace("@@DATA@@", json.dumps(D, ensure_ascii=False)).replace("@@FONT@@", font)
out = os.path.join(ROOT, "planches", "mod-revelation-propositions.html")
open(out, "w", encoding="utf-8").write(html)
print(out, len(html) // 1024, "Ko", len(mods), "mods")
