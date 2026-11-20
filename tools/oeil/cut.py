#!/usr/bin/env python3
"""Découpe la capture de planches/oeil-matrice-export.html en atlas transparents (assets/imported/oeil/).

    tools/oeil/export.sh          # capture Firefox headless puis découpe

Fond magenta (#ff00ff) → transparent. Piste « L’Orbite », trois phases : corps au repos et en tir (un atlas par
phase), iris (une rangée par phase : 4 dilatations + orbite vide), paupières (une rangée par phase), plus oeil.json.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "imported" / "oeil"
W, H = 200, 150
PHASES = 3
# Ancrage : centre de l'emprise au sol du boss, 12 px au nord de la base du dessin (FY = 140).
META = {
    "source": "planches/oeil-matrice-export.html",
    "ax": 100, "ay": 128, "h": 132, "phases": PHASES,
    "idle": {"frame_w": W, "frame_h": H, "cols": 8, "count": 48, "fps": 12.0},
    "cast": {"frame_w": W, "frame_h": H, "cols": 8, "count": 24, "fps": 12.0},
    # Rangée = phase ; images 0..3 : dilatation, image `socket` : orbite vide (pupilles errantes).
    "iris": {"frame_w": 32, "frame_h": 32, "cols": 5, "count": 4, "socket": 4, "cx": 16, "cy": 16},
    "lids": {"frame_w": 72, "frame_h": 56, "cols": 12, "count": 12, "cx": 36, "cy": 28},
    # Centre de l'œil dans le cadre du corps, demi-axes (px), course de l'iris (px), ouverture au repos.
    "eye": {"x": 100, "y": 80, "rx": 27, "ry": 19, "look_x": 7.0, "look_y": 4.5, "rest_open": 0.22},
}


def key(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, _ = px[x, y]
            if r == 255 and g == 0 and b == 255:
                px[x, y] = (0, 0, 0, 0)
    return im


def main(shot: Path) -> None:
    src = Image.open(shot).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("oeil_*.png*"):
        old.unlink()
    y = 0
    for ph in range(PHASES):
        for name in ("idle", "cast"):
            m = META[name]
            rows = -(-m["count"] // m["cols"])
            key(src.crop((0, y, m["cols"] * W, y + rows * H))).save(OUT / f"oeil_{name}_p{ph}.png")
            m["rows"] = rows
            y += rows * H
    for name in ("iris", "lids"):
        m = META[name]
        key(src.crop((0, y, m["cols"] * m["frame_w"], y + PHASES * m["frame_h"]))).save(OUT / f"oeil_{name}.png")
        m["rows"] = PHASES
        y += PHASES * m["frame_h"]
    (OUT / "oeil.json").write_text(json.dumps(META, indent=1, ensure_ascii=False) + "\n")
    print("atlas écrits dans", OUT)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
