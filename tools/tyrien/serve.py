#!/usr/bin/env python3
"""Export de l'Ingénieur tyrien (corps sans armure + un calque par pièce d'équipement) vers le jeu.

Sert le dossier planches/ et reçoit ce que produit planches/tyrien-export.html :

    python3 tools/tyrien/serve.py            # puis ouvrir http://127.0.0.1:8149/tyrien-export.html?save=1

Écritures (POST /out/<nom>) limitées à assets/imported/engineer/tyrien/ :
- tyrien_<calque>.png (planche de toutes les animations : corps « base », puis une par pièce) ;
- tyrien_portrait.png (portrait du HUD) ;
- tyrien.json (gabarit, animations, visée, pièces et ordre d'empilement).
"""
from __future__ import annotations

import base64
import http.server
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANCHES = ROOT / "planches"
OUT = ROOT / "assets" / "imported" / "engineer" / "tyrien"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8149
NAME = re.compile(r"^tyrien(_[a-z]+)?\.(png|json)$")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(PLANCHES), **k)

    def do_POST(self) -> None:
        name = self.path.removeprefix("/out/")
        if not NAME.match(name):
            self.send_error(403, "cible refusée")
            return
        OUT.mkdir(parents=True, exist_ok=True)
        dest = OUT / name
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if name.endswith(".png"):
            data = base64.b64decode(body.split(b",", 1)[1])
            if not data.startswith(b"\x89PNG"):
                self.send_error(400, "PNG attendu")
                return
            dest.write_bytes(data)
        else:
            dest.write_text(json.dumps(json.loads(body), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print("écrit", dest.relative_to(ROOT), flush=True)
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
