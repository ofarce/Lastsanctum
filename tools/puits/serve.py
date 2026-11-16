#!/usr/bin/env python3
"""Export du Puits des Âmes (Lotus de pierre) vers le jeu.

Sert le dossier planches/ et reçoit les PNG produits par planches/puits-export.html :

    python3 tools/puits/serve.py            # puis ouvrir http://127.0.0.1:8143/puits-export.html?save=1

Écritures (POST /out/<nom>) limitées à une liste fermée :
- assets/baked/buildings/da-soulwell_anim.png et _base.png ;
- assets/baked/hud/portraits/bld-soulwell.png ;
- les métadonnées sont fusionnées dans assets/baked/manifest.json (buildings.arts.da-soulwell),
  relu juste avant l'écriture pour ne rien écraser d'autre.
"""
from __future__ import annotations

import base64
import http.server
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANCHES = ROOT / "planches"
BAKED = ROOT / "assets" / "baked"
PORT = 8143
TARGETS = {
    "da-soulwell_anim.png": BAKED / "buildings" / "da-soulwell_anim.png",
    "da-soulwell_base.png": BAKED / "buildings" / "da-soulwell_base.png",
    "bld-soulwell.png": BAKED / "hud" / "portraits" / "bld-soulwell.png",
    "meta-soulwell.json": BAKED / "manifest.json",
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
            meta = json.loads(body)
            manifest = json.loads(dest.read_text(encoding="utf-8"))
            manifest["buildings"]["arts"]["da-soulwell"] = meta
            dest.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print("écrit", dest.relative_to(ROOT))
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    print(f"http://127.0.0.1:{PORT}/puits-export.html?save=1")
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
