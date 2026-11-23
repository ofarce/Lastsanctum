#!/usr/bin/env python3
"""Exporte vers le jeu l’Établi d’exo retenu sur planches/etabli-propositions.html (piste 1, deux boucles : travail et repos).

    python3 tools/batiments-16bits/build_etabli.py && python3 tools/batiments-16bits/export_etabli.py
    godot --headless --path . --import

Sert planches/ le temps d'ouvrir etabli-export.html?save=sync dans Firefox headless (XHR synchrones).
Écrit assets/baked/buildings/da-<type>_{anim,rest,base}.png, hud/portraits/bld-<type>.png et fusionne
buildings.arts.da-<type> dans manifest.json. Les sprites remplacés sont copiés une fois dans avant/.
"""
from __future__ import annotations

import base64, http.server, json, shutil, subprocess, sys, tempfile, threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BAKED = ROOT / "assets" / "baked"
AVANT = Path(__file__).parent / "avant"
TYPES = ["etabli"]
TARGETS: dict[str, Path] = {}
for t in TYPES:
    for k in ("anim", "rest", "base"):
        TARGETS[f"da-{t}_{k}.png"] = BAKED / "buildings" / f"da-{t}_{k}.png"
    TARGETS[f"bld-{t}.png"] = BAKED / "hud" / "portraits" / f"bld-{t}.png"
    TARGETS[f"meta-da-{t}.json"] = BAKED / "manifest.json"
ERRORS: list[str] = []
WRITTEN: list[str] = []


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=str(ROOT / "planches"), **k)

    def log_message(self, *a):
        pass

    def do_POST(self) -> None:
        name = self.path.removeprefix("/out/")
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if name == "erreur.txt":
            ERRORS.append(body.decode("utf-8", "replace"))
        elif name not in TARGETS:
            self.send_error(403, "cible refusée")
            return
        elif name.endswith(".png"):
            data = base64.b64decode(body.split(b",", 1)[1])
            if not data.startswith(b"\x89PNG"):
                self.send_error(400, "PNG attendu")
                return
            dest = TARGETS[name]
            if dest.exists() and not (AVANT / name).exists():
                AVANT.mkdir(exist_ok=True)
                shutil.copy2(dest, AVANT / name)
            dest.write_bytes(data)
            WRITTEN.append(name)
        else:
            art = name.removeprefix("meta-").removesuffix(".json")
            dest = TARGETS[name]
            manifest = json.loads(dest.read_text(encoding="utf-8"))
            if not (AVANT / name).exists():
                AVANT.mkdir(exist_ok=True)
                (AVANT / name).write_text(json.dumps(manifest["buildings"]["arts"].get(art), ensure_ascii=False))
            manifest["buildings"]["arts"][art] = json.loads(body)
            dest.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
            WRITTEN.append(name)
        self.send_response(204)
        self.end_headers()


def main() -> None:
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "prof").mkdir()
        subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(Path(tmp) / "prof"), "--window-size=1400,900",
                        "--screenshot", str(Path(__file__).parent / "export-etabli-apercu.png"),
                        f"http://127.0.0.1:{srv.server_address[1]}/etabli-export.html?save=sync"],
                       check=True, timeout=300, capture_output=True)
    srv.shutdown()
    print(len(WRITTEN), "fichiers écrits")
    if ERRORS or len(WRITTEN) != len(TARGETS):
        sys.exit("ÉCHEC : " + ("; ".join(ERRORS) or "export incomplet"))


if __name__ == "__main__":
    main()
