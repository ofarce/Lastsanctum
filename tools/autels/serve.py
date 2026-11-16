#!/usr/bin/env python3
"""Export des autels des dieux vers le jeu.

Sert le dossier planches/ et reçoit les PNG produits par planches/autels-export.html :

    python3 tools/autels/serve.py            # puis ouvrir http://127.0.0.1:8141/autels-export.html?save=1

Écritures (POST /out/<nom>) limitées à une liste fermée :
- assets/baked/buildings/da-<dieu>_anim.png et _base.png ;
- assets/baked/hud/portraits/bld-<dieu>.png ;
- les métadonnées sont fusionnées dans assets/baked/manifest.json (buildings.arts.da-<dieu>).
"""
from __future__ import annotations

import base64
import http.server
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANCHES = ROOT / "planches"
BAKED = ROOT / "assets" / "baked"
GODS = ("aether", "indra", "medeina", "sigil")
PORT = 8141


def target(name: str) -> Path | None:
    m = re.fullmatch(r"da-(\w+)_(anim|base)\.png", name)
    if m and m.group(1) in GODS:
        return BAKED / "buildings" / name
    m = re.fullmatch(r"bld-(\w+)\.png", name)
    if m and m.group(1) in GODS:
        return BAKED / "hud" / "portraits" / name
    m = re.fullmatch(r"meta-(\w+)\.json", name)
    if m and m.group(1) in GODS:
        return BAKED / "manifest.json"
    return None


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(PLANCHES), **k)

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
            meta = json.loads(body)
            manifest = json.loads(dest.read_text(encoding="utf-8"))
            art = "da-" + name[5:-5]
            manifest["buildings"]["arts"][art] = meta
            dest.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print("écrit", dest.relative_to(ROOT))
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    print(f"http://127.0.0.1:{PORT}/autels-export.html?save=1")
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
