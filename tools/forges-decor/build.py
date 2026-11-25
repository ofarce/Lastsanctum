#!/usr/bin/env python3
"""Assemble planches/forges-mortes-decor-propositions.html : reprend le moteur de tools/sanctum/template.html
(palettes, primitives, page), les pièces du monastère de tools/salles-decor/template.html, et y ajoute les pièces et
propositions de tools/forges-decor/template.html (couloirs, lumière, salles à thème, arènes, repères du biome 3).
La paroi des vignettes passe de l'ardoise au basalte (palette FS) ; le sol et la roche sont floor3 et rock3 du jeu.

    python3 tools/forges-decor/build.py
"""
import base64, io, pathlib, re
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[2]


def uri(p, box):
    im = Image.open(root / p).convert("RGB").crop(box)
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


src = (root / "tools/sanctum/template.html").read_text()
head = src[:src.index("<main>")].replace("<title>Galeries du Temple</title>", "<title>Décor des Forges mortes</title>")
head = head.replace("--acc:#efeadc;--acc-dk:#5d6678", "--acc:#f0a040;--acc-dk:#7a3a22")
engine = src[src.index("<script>") + len("<script>"):src.index("/* ---------- propositions")]
page = src[src.index("/* ---------- page"):src.index("</script>")]
page = page.replace("w=176,h=list===DECOR?112:128", "w=176,h=m.h||(list===DECOR?112:128)")
# Paroi en basalte : seules les couleurs de la face du mur changent dans makeBg.
a = page.index("function makeBg")
b = page.index("function draw(")
page = page[:a] + re.sub(r"\bS\[", "FS[", page[a:b]) + page[b:]
mono = (root / "tools/salles-decor/template.html").read_text()
pieces = mono[mono.index("/* ---------- palettes propres à cette planche"):mono.index("/* ---------- propositions")]
html = (root / "tools/forges-decor/template.html").read_text()
html = html.replace("%%HEAD%%", head).replace("%%ENGINE%%", engine).replace("%%PIECES%%", pieces).replace("%%PAGE%%", page)
html = html.replace("%%SOL%%", uri("assets/ardoise/world/tiles/floor3.png", (120, 200, 376, 392)))
html = html.replace("%%ROCHE%%", uri("assets/ardoise/world/tiles/rock3.png", (0, 0, 256, 192)))
(root / "planches/forges-mortes-decor-propositions.html").write_text(html)
print("ok", len(html))
