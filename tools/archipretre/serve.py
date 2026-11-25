#!/usr/bin/env python3
"""Sert le dépôt et reçoit l'export de planches/archipretre-hd-rendu.html#export : les bandes ×3 de l'Archiprêtre
aux racines (une par animation) et leur meta.json. Écritures limitées à assets/imported/archipretre/hd/.

    python3 tools/archipretre/serve.py [port]
    puis ouvrir http://127.0.0.1:8201/planches/archipretre-hd-rendu.html#export
"""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/imported/archipretre/hd"
ANIMS = {"idle", "regard", "strabisme", "pupilles", "larmes", "cils", "death"}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_POST(self):
        name = self.path.removeprefix("/archi-export/")
        size = int(self.headers.get("Content-Length", 0))
        if not self.path.startswith("/archi-export/") or size <= 0 or size > 24_000_000:
            self.send_error(400)
            return
        data = self.rfile.read(size)
        DEST.mkdir(parents=True, exist_ok=True)
        if name == "meta.json":
            meta = json.loads(data)
            if set(meta.get("anims", {})) != ANIMS:
                self.send_error(400)
                return
            (DEST / name).write_text(json.dumps(meta, separators=(",", ":"), ensure_ascii=False) + "\n")
        elif name.endswith(".png") and name[:-4] in ANIMS and data.startswith(b"\x89PNG\r\n\x1a\n"):
            (DEST / name).write_bytes(data)
        else:
            self.send_error(400)
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8201
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
