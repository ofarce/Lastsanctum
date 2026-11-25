#!/usr/bin/env python3
"""Assemble planches/couloirs-boss-decor-propositions.html : reprend le moteur de tools/sanctum/template.html
(palettes, pièces, rendu du dallage et de la roche) et y ajoute les propositions de tools/salles-decor/template.html."""
import base64, io, pathlib
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[2]


def uri(p, box):
    im = Image.open(root / p).convert("RGB").crop(box)
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


src = (root / "tools/sanctum/template.html").read_text()
head = src[:src.index("<main>")].replace("<title>Galeries du Temple</title>", "<title>Couloirs et salles de boss</title>")
engine = src[src.index("<script>") + len("<script>"):src.index("/* ---------- propositions")]
page = src[src.index("/* ---------- page"):src.index("</script>")].replace("['rec','Récompense']", "['rec','Où']")
html = (root / "tools/salles-decor/template.html").read_text()
html = html.replace("%%HEAD%%", head).replace("%%ENGINE%%", engine).replace("%%PAGE%%", page)
html = html.replace("%%SOL%%", uri("assets/ardoise/world/tiles/floor.png", (120, 200, 376, 392)))
html = html.replace("%%ROCHE%%", uri("assets/ardoise/world/tiles/rock.png", (0, 0, 256, 192)))
(root / "planches/couloirs-boss-decor-propositions.html").write_text(html)
print("ok", len(html))
