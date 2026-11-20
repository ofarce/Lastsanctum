#!/usr/bin/env python3
"""Met l'Ingénieur en armure (assets/baked/units/engineer_*.png) en conformité avec la charte :
l'or est réservé à Laetan et le rouge à la Bête, donc les galons dorés passent au cyan des Exilés et
l'écharpe rouge à un bordeaux sombre. Refait aussi le portrait du HUD en buste cadré (tête au tiers haut).

Idempotent : repart toujours des originaux de git (`git show HEAD:<fichier>`).
    python3 tools/charte/ingenieur_charte.py
"""
import colorsys, io, subprocess
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
UNITS = ["engineer_idle", "engineer_walk", "engineer_kneel"]


def original(rel: str) -> Image.Image:
    data = subprocess.run(["git", "show", f"HEAD:{rel}"], cwd=ROOT, capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


def recolor(im: Image.Image) -> Image.Image:
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            deg = h * 360
            if 28 <= deg <= 62 and s > 0.45 and v > 0.45:      # or, laiton -> cyan des Exilés
                h, s = 187 / 360, min(1.0, s * 0.85)
            elif (deg < 14 or deg > 344) and s > 0.5 and v > 0.25:  # rouge -> bordeaux sombre
                h, s, v = 348 / 360, s * 0.7, v * 0.62
            else:
                continue
            nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return im


BUST = (9, 1)  # coin haut gauche du carré de 16 px autour du casque, dans une image de 40 x 42


def bust(idle: Image.Image) -> Image.Image:
    """Buste 128 x 128 : première image du repos, 16 x 16 pixels de sprite autour de la tête, agrandis 8 fois."""
    out = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    out.alpha_composite(idle.crop((BUST[0], BUST[1], BUST[0] + 16, BUST[1] + 16)))
    return out.resize((128, 128), Image.NEAREST)


def main() -> None:
    idle = None
    for name in UNITS:
        rel = f"assets/baked/units/{name}.png"
        im = recolor(original(rel))
        im.save(ROOT / rel)
        if name == "engineer_idle":
            idle = im
    bust(idle).save(ROOT / "assets/baked/hud/portraits/engineer.png")
    print("Ingénieur : 3 atlas recolorés, portrait refait.")


if __name__ == "__main__":
    main()
