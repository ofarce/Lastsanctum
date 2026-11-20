#!/usr/bin/env python3
"""Réexporte les atlas d'unités vers le jeu sans serveur d'aperçu : sert le dépôt sur un port local le temps
d'ouvrir la page d'export dans Firefox headless avec ?save=sync (XHR synchrones, finis avant la capture).

    python3 tools/unites-maj/export.py refonte|esprits
"""
from __future__ import annotations

import http.server
import importlib.util
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
JOBS = {
    "refonte": ("tools/refonte/serve.py", "planches/refonte-16bits-export.html?save=sync"),
    "esprits": ("tools/esprits/serve.py", "esprits-export.html?save=sync"),
}


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in JOBS:
        sys.exit(__doc__)
    serve, url = JOBS[sys.argv[1]]
    spec = importlib.util.spec_from_file_location("serve", ROOT / serve)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), mod.Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "prof").mkdir()
        subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(Path(tmp) / "prof"), "--window-size=800,600",
                        "--screenshot", str(Path(tmp) / "x.png"), f"http://127.0.0.1:{srv.server_address[1]}/{url}"],
                       check=True, timeout=180, capture_output=True)
    srv.shutdown()


if __name__ == "__main__":
    main()
