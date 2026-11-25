#!/usr/bin/env python3
"""Assemble planches/salles-oubliees-decor-propositions.html : reprend le moteur de tools/sanctum/template.html
(palettes, primitives, dallage et roche réels), les pièces du monastère de tools/salles-decor/template.html, et y
ajoute les propositions de tools/salles-oubliees/template.html (couloirs, lumière, salles à thème, arènes, repères).

    python3 tools/salles-oubliees/build.py
"""
import base64, io, pathlib
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[2]


def uri(p, box):
    im = Image.open(root / p).convert("RGB").crop(box)
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


src = (root / "tools/sanctum/template.html").read_text()
head = src[:src.index("<main>")].replace("<title>Galeries du Temple</title>", "<title>Décor des Salles oubliées</title>")
engine = src[src.index("<script>") + len("<script>"):src.index("/* ---------- propositions")]
page = src[src.index("/* ---------- page"):src.index("</script>")]
page = page.replace("w=176,h=list===DECOR?112:128", "w=176,h=m.h||(list===DECOR?112:128)")
mono = (root / "tools/salles-decor/template.html").read_text()
pieces = mono[mono.index("/* ---------- palettes propres à cette planche"):mono.index("/* ---------- propositions")]
html = (root / "tools/salles-oubliees/template.html").read_text()
html = html.replace("%%HEAD%%", head).replace("%%ENGINE%%", engine).replace("%%PIECES%%", pieces).replace("%%PAGE%%", page)
html = html.replace("%%SOL%%", uri("assets/ardoise/world/tiles/floor.png", (120, 200, 376, 392)))
html = html.replace("%%ROCHE%%", uri("assets/ardoise/world/tiles/rock.png", (0, 0, 256, 192)))
(root / "planches/salles-oubliees-decor-propositions.html").write_text(html)
print("ok", len(html))
