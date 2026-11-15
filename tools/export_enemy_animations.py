#!/usr/bin/env python3
"""Exporter depuis /planches/ennemis-animations.html?export=1 sur ce serveur.
Les écritures sont limitées aux PNG et au manifest des animations ennemies.
"""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import json

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/imported/enemies"


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_POST(self):
        name = self.path.removeprefix("/enemy-export/")
        if not self.path.startswith("/enemy-export/") or "/" in name or not (name.endswith(".png") or name == "manifest.json"):
            self.send_error(400)
            return
        size = int(self.headers.get("Content-Length", 0))
        if size <= 0 or size > 8_000_000:
            self.send_error(413)
            return
        data = self.rfile.read(size)
        if name.endswith(".png") and not data.startswith(b"\x89PNG\r\n\x1a\n"):
            self.send_error(400)
            return
        if name == "manifest.json":
            json.loads(data)
        DEST.mkdir(parents=True, exist_ok=True)
        (DEST / name).write_bytes(data)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8791)
    args = parser.parse_args()
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
