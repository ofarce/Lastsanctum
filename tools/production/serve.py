#!/usr/bin/env python3
"""Export des coffres de production (piste A) et de la caisse portée vers le jeu.

Sert le dossier planches/ et reçoit ce que produit planches/production-export.html :

    python3 tools/production/serve.py        # puis ouvrir http://127.0.0.1:8167/production-export.html?save=1

Écritures (POST /out/<nom>) limitées à une liste fermée :
- assets/baked/world/production_chests.png et production_crate.png ;
- assets/baked/world/production_chests.json (tailles, repères, rangées).
"""
from __future__ import annotations

import base64
import http.server
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANCHES = ROOT / "planches"
WORLD = ROOT / "assets" / "baked" / "world"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8167
TARGETS = {
    "production_chests.png": WORLD / "production_chests.png",
    "production_crate.png": WORLD / "production_crate.png",
    "production_chests.json": WORLD / "production_chests.json",
}


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
            dest.write_text(json.dumps(json.loads(body), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print("écrit", dest.relative_to(ROOT))
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
