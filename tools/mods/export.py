#!/usr/bin/env python3
"""Exporte les icônes des mods retenues sur planches/mods-icones-propositions.html (bilan du 2026-11-21 : style A
« Cartouche », rareté par la couleur du cadre) vers assets/ardoise/ui/mods.png.

    python3 tools/mods/export.py      # puis : godot --headless --path . --import

Ouvre la planche dans Firefox headless avec ?export=1 ; la page renvoie l'atlas par POST /out/mods.png.
Atlas : une colonne de 32 px par mod (ordre de MODS dans la planche = ui/inventory/item_icon.gd, MOD_ORDER),
rangées plaque, bord, reflet, motif. Le bord et le reflet sont blancs : le jeu les teinte à la rareté (sim/loot.gd).
"""
from __future__ import annotations

import base64, http.server, subprocess, sys, tempfile, threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets" / "ardoise" / "ui" / "mods.png"
WRITTEN: list[str] = []


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(ROOT / "planches"), **k)

    def do_POST(self) -> None:
        if self.path != "/out/mods.png":
            self.send_error(403, "cible refusée")
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        data = base64.b64decode(body.split(b",", 1)[1])
        if not data.startswith(b"\x89PNG"):
            self.send_error(400, "PNG attendu")
            return
        DEST.write_bytes(data)
        WRITTEN.append(DEST.name)
        self.send_response(204)
        self.end_headers()

    def log_message(self, *a) -> None:
        pass


def main() -> None:
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "prof").mkdir()
        subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(Path(tmp) / "prof"), "--window-size=1200,900",
                        "--screenshot", str(Path(tmp) / "apercu.png"),
                        f"http://127.0.0.1:{srv.server_address[1]}/mods-icones-propositions.html?export=1"],
                       check=True, timeout=180, capture_output=True)
    srv.shutdown()
    if not WRITTEN:
        sys.exit("ÉCHEC : aucun atlas reçu")
    print("Écrit :", DEST.relative_to(ROOT))


if __name__ == "__main__":
    main()
