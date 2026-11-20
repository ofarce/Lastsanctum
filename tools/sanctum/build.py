#!/usr/bin/env python3
"""Assemble planches/sanctum-decor-propositions.html : gabarit + extraits du dallage et de la roche en base64."""
import base64, io, pathlib
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[2]


def uri(p, box):
    im = Image.open(root / p).convert("RGB").crop(box)
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


html = (root / "tools/sanctum/template.html").read_text()
html = html.replace("%%SOL%%", uri("assets/ardoise/world/tiles/floor.png", (120, 200, 376, 392)))
html = html.replace("%%ROCHE%%", uri("assets/ardoise/world/tiles/rock.png", (0, 0, 256, 192)))
(root / "planches/sanctum-decor-propositions.html").write_text(html)
print("ok", len(html))
