#!/usr/bin/env python3
"""Autel de Sigil : marbre gris veiné peu éclatant (charte), au lieu du blanc qui en faisait l'objet le plus
clair de la salle. Assombrit les gris clairs non saturés de assets/baked/buildings/da-sigil_{anim,base}.png et du
portrait bld-sigil.png ; les accents lumineux (presque blancs) et les teintes colorées ne bougent pas.

Idempotent : repart des originaux de git. À relancer après un nouvel export de planches/autels-export.html.
    python3 tools/charte/sigil_marbre.py
"""
import io, subprocess
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FILES = ["assets/baked/buildings/da-sigil_anim.png", "assets/baked/buildings/da-sigil_base.png", "assets/baked/hud/portraits/bld-sigil.png"]
KNEE, SLOPE, GLOW = 0.42, 0.55, 0.92  # au-dessus de KNEE la valeur est comprimée ; au-dessus de GLOW on ne touche pas


def main() -> None:
    # Périmé depuis les autels 16 bits : le marbre est assombri à la source (tools/autels-16bits/build.py),
    # et ce script, qui repart des sprites de git, écraserait le nouvel export.
    import sys
    if "--ancien" not in sys.argv:
        sys.exit("Périmé : utiliser tools/autels-16bits/build.py puis export.py (--ancien pour forcer).")
    for rel in FILES:
        data = subprocess.run(["git", "show", f"HEAD:{rel}"], cwd=ROOT, capture_output=True, check=True).stdout
        a = np.array(Image.open(io.BytesIO(data)).convert("RGBA")).astype(np.float32)
        rgb = a[..., :3] / 255.0
        v = rgb.max(-1)
        sat = np.where(v > 0, (v - rgb.min(-1)) / np.maximum(v, 1e-6), 0)
        hit = (a[..., 3] > 0) & (sat < 0.16) & (v > KNEE) & (v < GLOW)
        k = np.where(hit, (KNEE + (v - KNEE) * SLOPE) / np.maximum(v, 1e-6), 1.0)
        a[..., :3] = np.clip(rgb * k[..., None] * np.where(hit[..., None], [0.97, 0.99, 1.04], 1.0) * 255.0, 0, 255)
        Image.fromarray(a.round().astype(np.uint8)).save(ROOT / rel, optimize=True)
        print(rel, int(hit.sum()), "pixels")


if __name__ == "__main__":
    main()
