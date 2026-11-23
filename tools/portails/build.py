#!/usr/bin/env python3
"""Construit planches/portails-pylones-propositions.html : remplace chaque @@chemin@@ du gabarit
par l'image en data URI (chemins relatifs à la racine du projet), pour que la planche s'ouvre seule."""
import base64
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/portails/template.html"
OUT = ROOT / "planches/portails-pylones-propositions.html"


def inline(m: re.Match) -> str:
    data = (ROOT / m.group(1)).read_bytes()
    return "data:image/png;base64," + base64.b64encode(data).decode()


html = re.sub(r"@@([^@]+)@@", inline, SRC.read_text(encoding="utf-8"))
OUT.write_text(html, encoding="utf-8")
print(OUT.relative_to(ROOT), len(html) // 1024, "Ko")
