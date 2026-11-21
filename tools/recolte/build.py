#!/usr/bin/env python3
"""Planche « Effets de récolte » : inline les vraies images du jeu dans le gabarit.

    python3 tools/recolte/build.py   ->  planches/recolte-effets-propositions.html
"""
import base64
import io
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
W = os.path.join(ROOT, "assets", "ardoise", "world")
A = os.path.join(ROOT, "assets", "baked", "adepts")


def uri(im):
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


def tile(name, w, h):
    return Image.open(os.path.join(W, "tiles", name)).convert("RGB").crop((0, 0, w, h))


faces = Image.new("RGBA", (32 * 6, 49))
for v in range(6):
    faces.paste(Image.open(os.path.join(W, "runtime", f"face5_{v}.png")).convert("RGBA"), (v * 32, 0))
subs = {
    "@@FLOOR@@": uri(tile("floor.png", 192, 144)),
    "@@DUG@@": uri(tile("dug.png", 192, 144)),
    "@@ROCK@@": uri(tile("rock.png", 192, 64)),
    "@@FACES@@": uri(faces),
    "@@LODE@@": uri(Image.open(os.path.join(W, "filons.png")).convert("RGBA").crop((0, 0, 96, 104))),
    "@@GROVE@@": uri(Image.open(os.path.join(W, "bosquet.png")).convert("RGBA").crop((0, 0, 96, 104))),
    "@@INDRA@@": uri(Image.open(os.path.join(A, "indra_work.png")).convert("RGBA")),
    "@@AETHER@@": uri(Image.open(os.path.join(A, "aether_work.png")).convert("RGBA")),
    "@@MEDEINA@@": uri(Image.open(os.path.join(A, "medeina_work.png")).convert("RGBA")),
}
html = open(os.path.join(os.path.dirname(__file__), "template.html"), encoding="utf-8").read()
for k, v in subs.items():
    assert k in html, k
    html = html.replace(k, v)
out = os.path.join(ROOT, "planches", "recolte-effets-propositions.html")
open(out, "w", encoding="utf-8").write(html)
print(out, len(html) // 1024, "Ko")
