#!/usr/bin/env python3
"""Export du Pylône de Merenor (Obélisque suintant) vers le jeu.

Sert le dossier planches/ et reçoit les PNG produits par planches/pylone-merenor-v2-propositions.html :

    python3 tools/pylone/serve.py   # puis ouvrir http://127.0.0.1:8179/pylone-merenor-v2-propositions.html?export=1&save=1

Écritures (POST /out/<nom>) limitées à assets/imported/pylon/ : atlas corrompu, atlas canalisé,
rainures du socle par culte et métadonnées.
"""
from __future__ import annotations

import base64
import http.server
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANCHES = ROOT / "planches"
OUT = ROOT / "assets" / "imported" / "pylon"
PORT = 8179
TARGETS = {n: OUT / n for n in ("pylon_corrupt.png", "pylon_channel.png", "pylon_sides.png", "pylon.json")}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(PLANCHES), **k)

    def do_POST(self) -> None:
        name = self.path.removeprefix("/out/")
        dest = TARGETS.get(name)
        if dest is None:
            self.send_error(403, "cible refusée")
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if name.endswith(".png"):
            data = base64.b64decode(body.split(b",", 1)[1])
            if not data.startswith(b"\x89PNG"):
                self.send_error(400, "PNG attendu")
                return
            dest.write_bytes(data)
        else:
            dest.write_bytes(body + b"\n")
        print("écrit", dest.relative_to(ROOT))
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    print(f"http://127.0.0.1:{PORT}/pylone-merenor-v2-propositions.html?export=1&save=1")
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
