#!/usr/bin/env python3
"""Assemble planches/batiments-16bits-propositions.html (page autonome).

Le gabarit template.html contient le moteur de dessin et les 30 pistes ; ce script y
injecte les sprites actuels du jeu (recadrés 112 × 128 autour de l'ancre 160,168)
en data URI, pour la vignette « Actuel » de chaque bâtiment.

    python3 tools/batiments-16bits/build.py
"""
import base64, io, json, pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
ARTS = {"forge": "da-forge", "workshop": "da-workshop", "library": "da-library",
        "caserne": "da-caserne", "bedroom": "da-bedroom", "warehouse": "da-warehouse"}

def crop(art):
    im = Image.open(ROOT / "assets/baked/buildings" / f"{art}_base.png").convert("RGBA")
    # ancre (160,168) = centre de l'emprise, placé en (56,90) dans la vignette
    im = im.crop((104, 78, 216, 206))
    buf = io.BytesIO(); im.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

tpl = (pathlib.Path(__file__).parent / "template.html").read_text(encoding="utf-8")
out = tpl.replace("/*ACTUELS*/{}", json.dumps({k: crop(v) for k, v in ARTS.items()}))
dst = ROOT / "planches/batiments-16bits-propositions.html"
dst.write_text(out, encoding="utf-8")
print(dst, len(out))
