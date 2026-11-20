#!/usr/bin/env python3
"""Export de la refonte 16 bits (planches/refonte-16bits.html) vers le jeu.

Sert la racine du dépôt et reçoit les PNG produits par planches/refonte-16bits-export.html :

    python3 tools/refonte/serve.py      # puis ouvrir http://127.0.0.1:8179/planches/refonte-16bits-export.html?save=1

Écritures (POST /out/<nom>) limitées à une liste fermée :
- assets/imported/enemies/<ennemi>_<idle|walk|attack|death>.png (creep, spitter, scout, soldier, shield, archer,
  beast, feline, croc) et leurs entrées dans assets/imported/enemies/manifest.json ;
- assets/baked/adepts/<rôle>_<idle|walk|work>.png, assets/baked/hud/portraits/<rôle>.png (lame, archer, flammes)
  et assets/baked/manifest.json → adepts.roles.<rôle>.
Le Strazhar, la Martyre et la Brute ne sont pas touchés.
"""
from __future__ import annotations

import base64
import http.server
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Le chien de la Bête (beast) est exporté par tools/chiens/export_beast.py.
ENEMIES = ("creep", "spitter", "scout", "soldier", "shield", "archer", "feline", "croc")
ROLES = ("lame", "archer", "flammes")
ENEMY_DIR = ROOT / "assets" / "imported" / "enemies"
BAKED = ROOT / "assets" / "baked"
PORT = 8179


def target(name: str) -> Path | None:
    m = re.fullmatch(r"enemy_(\w+?)_(idle|walk|attack|death|hit)\.png", name)
    if m and m.group(1) in ENEMIES:
        return ENEMY_DIR / f"{m.group(1)}_{m.group(2)}.png"
    m = re.fullmatch(r"adept_(\w+?)_(idle|walk|work|death|hit)\.png", name)
    if m and m.group(1) in ROLES:
        return BAKED / "adepts" / f"{m.group(1)}_{m.group(2)}.png"
    m = re.fullmatch(r"portrait_(\w+)\.png", name)
    if m and m.group(1) in ROLES:
        return BAKED / "hud" / "portraits" / f"{m.group(1)}.png"
    if name == "meta.json":
        return ENEMY_DIR / "manifest.json"
    return None


def write_meta(meta: dict) -> None:
    path = ENEMY_DIR / "manifest.json"
    man = json.loads(path.read_text(encoding="utf-8"))
    for kind, entry in meta["enemies"].items():
        if kind in ENEMIES:
            man["enemies"][kind] = entry
    man["refonte"] = "planches/refonte-16bits-export.html (tools/refonte/serve.py) : " + ", ".join(sorted(meta["enemies"]))
    path.write_text(json.dumps(man, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    path = BAKED / "manifest.json"
    man = json.loads(path.read_text(encoding="utf-8"))
    for role, entry in meta["adepts"].items():
        if role in ROLES:
            man["adepts"]["roles"][role] = entry
    path.write_text(json.dumps(man, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(ROOT), **k)

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
            write_meta(json.loads(body))
        print("écrit", dest.relative_to(ROOT), flush=True)
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    print(f"http://127.0.0.1:{PORT}/planches/refonte-16bits-export.html?save=1", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
