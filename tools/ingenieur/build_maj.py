#!/usr/bin/env python3
"""Planche « Ingénieur : sprites et animations » (avant / après), autonome.

    python3 tools/ingenieur/build_maj.py      # écrit planches/ingenieur-maj-propositions.html

Le dessin proposé est planches/assets/engineer-maj.js ; la version du jeu est redessinée dans la page par les
fonctions de l'export actuel (engineer-exile.js, engineer-ragged.js, engineer-cannon.js). Gabarit : maj_template.html.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
JS = ["engineer-colosse.js", "engineer-exile.js", "engineer-cannon.js", "engineer-ragged.js", "engineer-maj.js"]
OUT = ROOT / "planches/ingenieur-maj-propositions.html"

src = "\n".join((ROOT / "planches/assets" / f).read_text().replace("'use strict';", "", 1) for f in JS)
html = (Path(__file__).parent / "maj_template.html").read_text().replace("/*JS*/", src)
OUT.write_text(html)
print(f"{OUT.relative_to(ROOT)} : {len(html) // 1024} Ko")
