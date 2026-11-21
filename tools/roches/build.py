#!/usr/bin/env python3
"""Planche « Roches minables » : inline les vraies textures du jeu dans le gabarit.

    python3 tools/roches/build.py   ->  planches/roches-minables-propositions.html
"""
import base64
import io
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
W = os.path.join(ROOT, "assets", "ardoise", "world")


def uri(im):
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


def crop(name):
    return Image.open(os.path.join(W, "tiles", name)).convert("RGB").crop((0, 0, 384, 288))


faces = Image.new("RGBA", (32 * 6, 49))
for v in range(6):
    faces.paste(Image.open(os.path.join(W, "runtime", f"face5_{v}.png")).convert("RGBA"), (v * 32, 0))
subs = {
    "@@ROCK@@": uri(crop("rock.png")),
    "@@FLOOR@@": uri(crop("floor.png")),
    "@@DUG@@": uri(crop("dug.png")),
    "@@FACES@@": uri(faces),
    "@@NOD@@": uri(Image.open(os.path.join(W, "nodules.png")).convert("RGBA")),
}
html = open(os.path.join(os.path.dirname(__file__), "template.html"), encoding="utf-8").read()
for k, v in subs.items():
    assert k in html, k
    html = html.replace(k, v)
out = os.path.join(ROOT, "planches", "roches-minables-propositions.html")
open(out, "w", encoding="utf-8").write(html)
print(out, len(html) // 1024, "Ko")
