#!/usr/bin/env python3
"""Réexporte la boucle « au travail » de l'Atelier sans ses pièces de bois (BuildingView les dessine selon la recette).

    python3 tools/atelier-morph/build.py && python3 tools/atelier-morph/export.py
    godot --headless --path . --import

Même principe que tools/batiments-16bits/export.py ; n'écrit que assets/baked/buildings/da-workshop_anim.png
(copie de l'ancien dans avant/). La boucle de repos, la base, le portrait et le manifeste ne changent pas.
"""
import base64, http.server, shutil, subprocess, sys, tempfile, threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NAME = "da-workshop_anim.png"
DEST = ROOT / "assets/baked/buildings" / NAME
AVANT = Path(__file__).parent / "avant"
ERRORS, WRITTEN = [], []


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(ROOT / "planches"), **k)

    def log_message(self, *a):
        pass

    def do_POST(self):
        name = self.path.removeprefix("/out/")
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if name == "erreur.txt":
            ERRORS.append(body.decode("utf-8", "replace"))
        elif name != NAME:
            self.send_error(403, "cible refusée")
            return
        else:
            data = base64.b64decode(body.split(b",", 1)[1])
            if not data.startswith(b"\x89PNG"):
                self.send_error(400, "PNG attendu")
                return
            if not (AVANT / NAME).exists():
                AVANT.mkdir(exist_ok=True)
                shutil.copy2(DEST, AVANT / NAME)
            DEST.write_bytes(data)
            WRITTEN.append(name)
        self.send_response(204)
        self.end_headers()


srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=srv.serve_forever, daemon=True).start()
with tempfile.TemporaryDirectory() as tmp:
    (Path(tmp) / "prof").mkdir()
    subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(Path(tmp) / "prof"), "--window-size=600,400",
                    "--screenshot", str(Path(tmp) / "apercu.png"),
                    f"http://127.0.0.1:{srv.server_address[1]}/atelier-morph-export.html?save=sync"],
                   check=True, timeout=300, capture_output=True)
srv.shutdown()
if ERRORS or WRITTEN != [NAME]:
    sys.exit("ÉCHEC : " + ("; ".join(ERRORS) or "export incomplet"))
print("écrit", DEST)
