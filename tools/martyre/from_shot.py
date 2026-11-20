#!/usr/bin/env python3
"""Export de la Martyre sans serveur : remet en PNG la capture headless de planches/martyre-16bits-export.html?shot=1.

    firefox --headless --window-size 1800,5040 --screenshot shot.png ".../martyre-16bits-export.html?shot=1"
    python3 tools/martyre/from_shot.py shot.png

La capture pose les atlas l'un sous l'autre : en haut les couleurs prémultipliées sur noir, en bas l'alpha en
niveaux de gris. Écrit assets/imported/enemies/martyre_<anim>.png et l'entrée enemies.martyre du manifeste
(même format que tools/martyre/serve.py).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ENEMIES = ROOT / "assets" / "imported" / "enemies"
FW, FH, COLS, SPEED, FPS = 150, 120, 12, 1.3, 24
# Durées de la planche (MARTYRE16.ANIMS), dans l'ordre de la capture.
LEN = {"idle": 4.0, "walk": 1.1, "attack": 1.0, "cast": 2.2, "hit": 0.5, "death": 3.2}


def main(shot: str) -> None:
    im = Image.open(shot).convert("RGB")
    plan = []
    for name, length in LEN.items():
        dur = length / SPEED
        n = max(2, round(dur * FPS))
        plan.append((name, dur, n, -(-n // COLS)))
    total = sum(rows for *_, rows in plan) * FH
    W = FW * COLS
    assert im.width >= W and im.height >= 2 * total, f"capture trop petite : {im.size}, attendu {W}×{2 * total}"
    meta: dict = {"ax": 60, "ay": 114, "stride": round(2.2 * 1.1 / SPEED, 3), "self_bob": True, "version": 4}
    y = 0
    for name, dur, n, rows in plan:
        h = rows * FH
        col = im.crop((0, y, W, y + h))
        alpha = im.crop((0, total + y, W, total + y + h)).split()[0]
        out = Image.new("RGBA", (W, h))
        cp, ap, op = col.load(), alpha.load(), out.load()
        for j in range(h):
            for i in range(W):
                a = ap[i, j]
                if a == 0:
                    continue
                r, g, b = cp[i, j]
                op[i, j] = (min(255, round(r * 255 / a)), min(255, round(g * 255 / a)), min(255, round(b * 255 / a)), a)
        out.save(ENEMIES / f"martyre_{name}.png")
        print("écrit", f"martyre_{name}.png", n, "images")
        meta[name] = {"frame_w": FW, "frame_h": FH, "cols": COLS, "rows": rows, "count": n, "fps": round(n / dur, 4), "duration": round(dur, 4)}
        if name == "idle":
            meta[name]["loop"] = True
            first = out.crop((0, 0, FW, FH)).getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()
            meta["h"] = 114 - first[1]
        y += h
    manifest_path = ENEMIES / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["enemies"]["martyre"] = meta
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("manifeste : h =", meta["h"])


if __name__ == "__main__":
    main(sys.argv[1])
