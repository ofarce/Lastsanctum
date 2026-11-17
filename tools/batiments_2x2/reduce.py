#!/usr/bin/env python3
"""Bâtiments en 2×2 : réduit à 2/3 les sprites dessinés pour une emprise 3×3.

Méthode retenue sur planches/batiments-2x2.html : « natif · plus proche ». Chaque pixel de sortie
reprend le pixel source le plus proche de son centre, avec le point au sol (160, 168) gardé sur un
pixel entier. L'image réduite est replacée dans le repère 320×240, point au sol en (160, 168), et
l'art est marqué « scale »: 1 dans le manifeste, comme le Puits des Âmes et le Creuset.

    python3 tools/batiments_2x2/reduce.py

Idempotent : un art déjà à « scale »: 1 est laissé tel quel. Après un nouveau passage du baker
(procédure R), relancer ce script.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BAKED = ROOT / "assets" / "baked"
MANIFEST = BAKED / "manifest.json"
FW, FH, AX, AY = 320, 240, 160, 168
F = 2.0 / 3.0


def _axis(length: int, anchor: int) -> np.ndarray:
    """Pour chaque pixel du repère réduit (même taille), l'indice source, ou -1 hors de l'image."""
    out_anchor = round(anchor * F)
    u0 = out_anchor - anchor * F
    # Pixel du repère final X ↔ pixel réduit u = X − (anchor − out_anchor).
    u = np.arange(length) - (anchor - out_anchor)
    src = np.floor((u + 0.5 - u0) / F).astype(int)
    src[(u < 0) | (src < 0) | (src >= length)] = -1
    return src


SX, SY = _axis(FW, AX), _axis(FH, AY)


def reduce_frame(frame: np.ndarray) -> np.ndarray:
    out = np.zeros_like(frame)
    ys, xs = np.nonzero(SY >= 0)[0], np.nonzero(SX >= 0)[0]
    out[np.ix_(ys, xs)] = frame[np.ix_(SY[ys], SX[xs])]
    return out


def reduce_sheet(path: Path, cols: int, rows: int) -> None:
    sheet = np.array(Image.open(path).convert("RGBA"))
    for r in range(rows):
        for c in range(cols):
            y, x = r * FH, c * FW
            sheet[y:y + FH, x:x + FW] = reduce_frame(sheet[y:y + FH, x:x + FW].copy())
    Image.fromarray(sheet).save(path, optimize=True)


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    B = manifest["buildings"]
    for art, meta in B["arts"].items():
        if float(meta.get("scale", 0)) == 1.0:
            continue
        a = meta["anim"]
        reduce_sheet(BAKED / "buildings" / f"{art}_anim.png", int(a["cols"]), int(a["rows"]))
        base = BAKED / "buildings" / f"{art}_base.png"
        img = reduce_frame(np.array(Image.open(base).convert("RGBA")))
        Image.fromarray(img).save(base, optimize=True)
        rows = np.nonzero(img[:, :, 3].any(axis=1))[0]
        meta["top"], meta["bottom"] = int(rows[0]), int(rows[-1]) + 1
        meta["scale"] = 1
        print(f"{art} : réduit en 2×2")
    for D in B.get("catalogue", {}).values():
        D["size"] = 2
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
