#!/usr/bin/env python3
"""Export du bosquet pétrifié (piste 2.2 · Dernières feuilles vives) vers le jeu.

    python3 tools/bosquet/serve.py   # puis ouvrir http://127.0.0.1:8159/bosquet-feuilles-propositions.html?save=1

Écrit uniquement assets/ardoise/world/bosquet.png : 5 états d'usure (bois 20/20 → 0) de 96 × 104 px,
côte à côte ; l'emprise 2 × 2 cases (64 × 64) commence en (16, 40) dans chaque image.
"""
from __future__ import annotations

import base64
import http.server
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANCHES = ROOT / "planches"
PORT = 8159
TARGETS = {"bosquet.png": ROOT / "assets" / "ardoise" / "world" / "bosquet.png"}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(PLANCHES), **k)

    def do_POST(self) -> None:
        dest = TARGETS.get(self.path.removeprefix("/out/"))
        if dest is None:
            self.send_error(403, "cible refusée")
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        data = base64.b64decode(body.split(b",", 1)[1])
        if not data.startswith(b"\x89PNG"):
            self.send_error(400, "PNG attendu")
            return
        dest.write_bytes(data)
        print("écrit", dest.relative_to(ROOT))
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
