#!/usr/bin/env python3
"""Assemble planches/ancre-style-propositions.html : gabarit + fond et vignette actuelle en base64."""
import base64, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
uri = lambda p: "data:image/png;base64," + base64.b64encode((root / p).read_bytes()).decode()
html = (root / "tools/ancre/template.html").read_text()
html = html.replace("%%FOND%%", uri("planches/assets/ancre/fond.png")).replace("%%ACTUELLE%%", uri("planches/assets/ancre/actuelle.png"))
(root / "planches/ancre-style-propositions.html").write_text(html)
print("ok", len(html))
