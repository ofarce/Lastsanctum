#!/usr/bin/env python3
"""Assemble planches/assets/batiments-v2-planches.js : moteur de creuset-planches.js + dessins de batiments-v2-designs.js."""
from pathlib import Path
R = Path(__file__).resolve().parents[2] / "planches/assets"
src = (R / "creuset-planches.js").read_text().split("\n")
i_prop = next(i for i, l in enumerate(src) if l.startswith("// ---------- propositions"))
i_vig = next(i for i, l in enumerate(src) if l.startswith("function vignette"))
head = "\n".join(src[:i_prop]).replace("const CRE=(()=>{", "const BAT=(()=>{", 1)
head = head.replace("// Planche « Creuset des Exilés »", "// Planche « Bâtiments secondaires v2 » (moteur copié de creuset-planches.js)", 1)
tail = "\n".join(src[i_vig:]).replace("return{ITEMS,vignette,", "return{ITEMS,GROUPS,vignette,floorScene,", 1)
(R / "batiments-v2-planches.js").write_text(head + "\n" + (R / "batiments-v2-designs.js").read_text() + "\n" + tail + "\n")
print("ok")

# version autonome (script + sprites actuels intégrés) pour la publication
import base64, sys
P = R.parent
html = (P / "batiments-v2-propositions.html").read_text()
js = (R / "batiments-v2-planches.js").read_text()
cur = {k: "data:image/png;base64," + base64.b64encode((R / f"batiments-v2/actuel-{k}.png").read_bytes()).decode() for k in ("library", "workshop", "forge", "warehouse")}
import json
inline = "<script>window.CURRENT_ART=" + json.dumps(cur) + ";</script>\n<script>\n" + js + "\n</script>"
html = html.replace('<script src="assets/batiments-v2-planches.js?v=1"></script>', inline)
if len(sys.argv) > 1:  # page publiée : le squelette html/head/body est ajouté à la publication
    html = html.replace('<!doctype html>\n<html lang="fr"><head>', '').replace('</head><body>', '').replace('</body></html>', '')
    html = html.replace(':root{--bg:', ':root{color-scheme:dark;--bg:', 1)
out = Path(sys.argv[1]) if len(sys.argv) > 1 else P / "batiments-v2-propositions.autonome.html"
out.write_text(html)
print(out, len(html))
