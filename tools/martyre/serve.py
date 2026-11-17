#!/usr/bin/env python3
"""Export de la Martyre de Byrsa (premier boss, piste 4 de planches/boss-propositions.html) vers le jeu.

Sert le dossier planches/ et reçoit les PNG produits par planches/martyre-export.html :

    python3 tools/martyre/serve.py           # puis ouvrir http://127.0.0.1:8165/martyre-export.html?save=1

Écritures (POST /out/<nom>) limitées à une liste fermée :
- assets/imported/enemies/martyre_<idle|walk|attack|death>.png ;
- meta-martyre.json remplace l'entrée enemies.martyre de assets/imported/enemies/manifest.json.
"""
from __future__ import annotations

import base64
import http.server
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANCHES = ROOT / "planches"
ENEMIES = ROOT / "assets" / "imported" / "enemies"
PORT = 8165


def target(name: str) -> Path | None:
    if re.fullmatch(r"martyre_(idle|walk|attack|death)\.png", name):
        return ENEMIES / name
    if name == "meta-martyre.json":
        return ENEMIES / "manifest.json"
    return None


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(PLANCHES), **k)

    def end_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Methods", "POST")
        self.end_headers()

    def do_POST(self) -> None:
        name = self.path.removeprefix("/out/")
        dest = target(name)
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
            manifest = json.loads(dest.read_text(encoding="utf-8"))
            manifest["enemies"]["martyre"] = json.loads(body)
            dest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("écrit", dest.relative_to(ROOT), flush=True)
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    print(f"http://127.0.0.1:{PORT}/martyre-export.html?save=1", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
