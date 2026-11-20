#!/usr/bin/env python3
"""Planche « Brute et Strazhar » (piste G1), autonome : scripts de dessin et atlas actuels embarqués.

    python3 tools/unites-maj/build_g1.py      # écrit planches/brute-strazhar-propositions.html

Dessin : planches/assets/boss/brute-strazhar.js (moteur engineer-colosse.js + rampes refonte-16bits.js).
Gabarit : tools/unites-maj/template_g1.html.
"""
from __future__ import annotations

import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
# « Actuel » = atlas d'avant l'export du modèle retenu (tools/unites-maj/export_g1.py).
EN = HERE / "avant/enemies"
OUT = ROOT / "planches/brute-strazhar-propositions.html"
SCRIPTS = ("engineer-colosse.js", "refonte-16bits.js", "boss/brute-strazhar.js")


def main() -> None:
    man = json.loads((EN / "manifest.json").read_text())["enemies"]
    old = {}
    for kind in ("brute", "strazhar"):
        m = man[kind]
        old[kind] = {}
        for act in ("idle", "walk", "attack"):
            d = m[act]
            old[kind][act] = {
                "src": "data:image/png;base64," + base64.b64encode((EN / f"{kind}_{act}.png").read_bytes()).decode(),
                "fw": d["frame_w"], "fh": d["frame_h"], "n": d["count"],
                "ax": d.get("ax", m["ax"]), "ay": d.get("ay", m["ay"]),
            }
    js = "\n".join((ROOT / "planches/assets" / s).read_text() for s in SCRIPTS)
    html = (HERE / "template_g1.html").read_text()
    html = html.replace("/*DRAW*/", js.replace("</script", "<\\/script")).replace("/*OLD*/null", json.dumps(old))
    OUT.write_text(html)
    print(f"{OUT.relative_to(ROOT)} : {len(html) // 1024} Ko")


if __name__ == "__main__":
    main()
