#!/usr/bin/env python3
"""Sert le dépôt et reçoit l'export de tools/lanceurs/export.html (atlas « cast » des lanceurs de boule).
Écritures limitées à <ennemi>_cast.png, <ennemi>_cast_run.png et aux clés cast / cast_run de ces ennemis
dans le manifeste.
"""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/imported/enemies"
KINDS = {"spitter", "creep", "brute", "beast", "skeleton_bomb"}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_POST(self):
        name = self.path.removeprefix("/cast-export/")
        size = int(self.headers.get("Content-Length", 0))
        if not self.path.startswith("/cast-export/") or size <= 0 or size > 8_000_000:
            self.send_error(400)
            return
        data = self.rfile.read(size)
        if name == "cast.json":
            cast = json.loads(data)
            path = DEST / "manifest.json"
            man = json.loads(path.read_text())
            for kind, meta in cast.items():
                if kind not in KINDS:
                    self.send_error(400)
                    return
                group = next(g for g in man.values() if isinstance(g, dict) and isinstance(g.get(kind), dict) and "idle" in g[kind])
                for key in ("cast", "cast_run"):
                    group[kind].pop(key, None)
                    if key in meta:
                        group[kind][key] = meta[key]
            path.write_text(json.dumps(man, indent=2, ensure_ascii=False) + "\n")
        elif name.endswith(".png") and name[:-4].removesuffix("_run").removesuffix("_cast") in KINDS and "_cast" in name and data.startswith(b"\x89PNG\r\n\x1a\n"):
            (DEST / name).write_bytes(data)
        else:
            self.send_error(400)
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8199
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
