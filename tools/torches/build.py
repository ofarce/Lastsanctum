#!/usr/bin/env python3
"""Assemble planches/torches-tunnels-propositions.html : reprend le moteur de tools/sanctum/template.html
(palettes, primitives, dallage et roche réels) et y ajoute les torches de tools/torches/template.html."""
import base64, io, pathlib
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[2]


def uri(p, box):
    im = Image.open(root / p).convert("RGB").crop(box)
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


src = (root / "tools/sanctum/template.html").read_text()
head = src[:src.index("<main>")].replace("<title>Galeries du Temple</title>", "<title>Torches des tunnels</title>")
engine = src[src.index("<script>") + len("<script>"):src.index("/* ---------- pièces de décor")]
html = (root / "tools/torches/template.html").read_text()
html = html.replace("%%HEAD%%", head).replace("%%ENGINE%%", engine)
html = html.replace("%%SOL%%", uri("assets/ardoise/world/tiles/floor.png", (120, 200, 376, 392)))
html = html.replace("%%ROCHE%%", uri("assets/ardoise/world/tiles/rock.png", (0, 0, 256, 192)))
(root / "planches/torches-tunnels-propositions.html").write_text(html)
print("ok", len(html))
