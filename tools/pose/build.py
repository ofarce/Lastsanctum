#!/usr/bin/env python3
"""Construit les planches de pose d'un bâtiment (autonomes, images en data URI) :
planches/pose-batiment-propositions.html (template.html) et planches/pose-rendu-propositions.html
(template-rendu.html).

Sprites et empreinte dorée repris de planches/chantier-debut-propositions.html ; empreintes de visée verte et
rouge tirées de l'image 0 de assets/baked/overlay/footprint_{valid,invalid}.png.
"""
import base64
import io
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

old = (ROOT / "planches/chantier-debut-propositions.html").read_text().split("\n")
line = next(l for l in old if l.startswith("const IMG = "))
img = json.loads(line[len("const IMG = "):].rstrip(";"))

for key, name in (("fpv", "valid"), ("fpi", "invalid")):
    buf = io.BytesIO()
    Image.open(ROOT / f"assets/baked/overlay/footprint_{name}.png").crop((0, 0, 396, 134)).save(buf, "PNG")
    img[key] = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

for template, page in (("template.html", "pose-batiment-propositions.html"), ("template-rendu.html", "pose-rendu-propositions.html")):
    out = (HERE / template).read_text().replace("/*IMG*/", json.dumps(img))
    dest = ROOT / "planches" / page
    dest.write_text(out)
    print(dest, len(out))
