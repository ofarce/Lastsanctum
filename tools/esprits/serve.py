#!/usr/bin/env python3
"""Export des esprits mineurs (choix de planches/esprits-v6-propositions.html) vers le jeu.

Sert le dossier planches/ et reçoit les PNG produits par planches/soldats-export.html :

    python3 tools/esprits/serve.py           # puis ouvrir http://127.0.0.1:8172/esprits-export.html?save=1

Écritures (POST /out/<nom>) limitées à une liste fermée :
- assets/baked/adepts/<rôle>_<idle|walk|work|carry|pray|fight>.png ;
- assets/baked/hud/portraits/<rôle>.png ;
- les métadonnées (ax, ay, modes) remplacent assets/baked/manifest.json → adepts.roles.<rôle>.
Rôles : medeina (feu follet, Flamme sylvestre), indra (Roue-mandala), aether (Orrery), sigil (Livre ailé).
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
ROLES = ("medeina", "indra", "aether", "sigil")
PORT = 8172


def target(name: str) -> Path | None:
    m = re.fullmatch(r"(\w+)_(idle|walk|work|carry|pray|fight)\.png", name)
    if m and m.group(1) in ROLES:
        return BAKED / "adepts" / name
    m = re.fullmatch(r"portrait-(\w+)\.png", name)
    if m and m.group(1) in ROLES:
        return BAKED / "hud" / "portraits" / (m.group(1) + ".png")
    m = re.fullmatch(r"meta-(\w+)\.json", name)
    if m and m.group(1) in ROLES:
        return BAKED / "manifest.json"
    return None


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(PLANCHES), **k)

    def end_headers(self) -> None:
        # la page peut aussi être servie ailleurs (serveur « planches ») et poster ici
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
            meta = json.loads(body)
            manifest = json.loads(dest.read_text(encoding="utf-8"))
            manifest["adepts"]["roles"][name[5:-5]] = meta
            dest.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print("écrit", dest.relative_to(ROOT), flush=True)
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    print(f"http://127.0.0.1:{PORT}/esprits-export.html?save=1", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
