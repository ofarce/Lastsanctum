#!/usr/bin/env python3
"""Assemble planches/portes-tunnels-propositions.html : reprend le moteur de tools/sanctum/template.html
(palettes, primitives, dallage et roche réels) et y ajoute les portes de tools/portes/template.html."""
import base64, io, pathlib
from PIL import Image
root = pathlib.Path(__file__).resolve().parents[2]


def uri(p, box):
    im = Image.open(root / p).convert("RGB").crop(box)
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()


CSS = """.plan svg{width:100%;height:auto;display:block}
.uses{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:14px}
.use{background:var(--panel);border:1px solid var(--line);padding:12px 14px}
.use h3{font-family:var(--disp);font-size:1.3rem;margin:0}
.use h3 i{font-family:var(--mono);font-style:normal;font-size:.9rem;color:var(--acc);margin-right:8px}
.use p{margin:.4rem 0 0}.use .mute{color:var(--mute);font-size:13px}
.lead b{color:var(--acc);font-weight:600}
</style>"""
src = (root / "tools/sanctum/template.html").read_text()
head = src[:src.index("<main>")].replace("<title>Galeries du Temple</title>", "<title>Portes des tunnels</title>")
head = head.replace("</style>", CSS, 1)
engine = src[src.index("<script>") + len("<script>"):src.index("/* ---------- pièces de décor")]
decor = src[src.index("/* ---------- pièces de décor"):src.index("const gal=")]
html = (root / "tools/portes/template.html").read_text()
html = html.replace("%%HEAD%%", head).replace("%%ENGINE%%", engine + decor)
html = html.replace("%%SOL%%", uri("assets/ardoise/world/tiles/floor.png", (120, 200, 376, 392)))
html = html.replace("%%ROCHE%%", uri("assets/ardoise/world/tiles/rock.png", (0, 0, 256, 192)))
(root / "planches/portes-tunnels-propositions.html").write_text(html)
print("ok", len(html))
