#!/usr/bin/env python3
"""Exporte vers le jeu les personnages retenus sur planches/biomes-personnages-finaux.html.

    python3 tools/biomes-persos/export.py        # puis : godot --headless --path . --import

L'Oublieux (modèle 5 · Pèlerin à la palanche) et les trois mages (Guérisseuse 3, Chantre 2, Envoûteur 2) →
assets/baked/adepts/<rôle>_{idle,walk,work,death}.png, adepts.roles.<rôle> du manifeste et hud/portraits/<rôle>.png. Rendu par Firefox headless sur fond magenta
détouré (pas de serveur), comme tools/unites-maj/export_g1.py. Les lueurs (calque fx) sont fondues dans l'atlas.
"""
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PL = ROOT / "planches" / "assets"
BAKED = ROOT / "assets" / "baked"
COLS = 12
FW, FH, AX, AY = 64, 56, 28, 50
# rôle du jeu : (rôle du dessin, variante, foulée, animations (mode, anim du dessin, images, durée en s))
UNITS = {
    "oublieux": ("obl", 4, 4.0,
                 [("idle", "idle", 67, 5.6), ("walk", "walk", 20, 0.85), ("work", "act", 62, 2.6), ("death", "death", 30, 1.25)]),
    # Mages de l'École de magie cristallisée. Repos de la Guérisseuse : 5,03 s, deux cinquièmes de tour de sa couronne.
    "guerisseuse": ("heal", 2, 4.0,
                    [("idle", "idle", 60, 5.03), ("walk", "walk", 20, 0.85), ("work", "act", 67, 2.8), ("death", "death", 43, 1.8)]),
    "chantre": ("chant", 1, 4.0,
                [("idle", "idle", 67, 5.6), ("walk", "walk", 20, 0.85), ("work", "act", 67, 2.8), ("death", "death", 43, 1.8)]),
    "envouteur": ("hex", 1, 4.0,
                  [("idle", "idle", 67, 5.6), ("walk", "walk", 20, 0.85), ("work", "act", 67, 2.8), ("death", "death", 43, 1.8)]),
}
# vignette du portrait : zone 32 × 32 de la première image de repos, agrandie 4 fois
PORTRAIT = (12, 7, 44, 39)


def main() -> None:
    jobs, y = [], 0
    for role, (unit, vi, _s, anims) in UNITS.items():
        for mode, anim, n, dur in anims:
            rows = -(-n // COLS)
            jobs.append((role, unit, vi, mode, anim, n, dur, y, rows))
            y += rows * FH
    width, height = COLS * FW, y
    js = "".join((PL / f).read_text(encoding="utf-8") + "\n" for f in ("engineer-colosse.js", "refonte-16bits.js", "biomes/personnages.js"))
    draw = "".join(
        f"for(let i=0;i<{n};i++){{const f=PERSO.frame('{unit}',{vi},'{anim}',i/{n}*{dur}),x=(i%{COLS})*{FW},y={y0}+Math.floor(i/{COLS})*{FH};g.drawImage(f.c,x,y);g.drawImage(f.fx,x,y)}}"
        for _r, unit, vi, _m, anim, n, dur, y0, _rows in jobs)
    html = (f'<!doctype html><html><body style="margin:0;overflow:hidden;background:#f0f"><canvas id=c width={width} height={height} style="display:block"></canvas><script>{js}\n'
            f"const g=document.getElementById('c').getContext('2d');g.imageSmoothingEnabled=false;g.fillStyle='#f0f';g.fillRect(0,0,{width},{height});PERSO.setExport(true);{draw}</script></body></html>")
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        (t / "prof").mkdir()
        (t / "x.html").write_text(html, encoding="utf-8")
        subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(t / "prof"), f"--window-size={width},{height}",
                        "--screenshot", str(t / "x.png"), (t / "x.html").as_uri()], check=True, timeout=180, capture_output=True)
        im = Image.open(t / "x.png").convert("RGBA")
    if im.size != (width, height):
        raise SystemExit(f"capture {im.size}, attendu {(width, height)}")
    px = im.load()
    for yy in range(im.height):
        for xx in range(im.width):
            if px[xx, yy][:3] == (255, 0, 255):
                px[xx, yy] = (0, 0, 0, 0)
    path = BAKED / "manifest.json"
    man = json.loads(path.read_text(encoding="utf-8"))
    for role, (_unit, vi, stride, _anims) in UNITS.items():
        entry = {"ax": AX, "ay": AY, "scale": 1, "stride": stride, "modes": {},
                 "source": f"planches/biomes-personnages-finaux.html, modèle {vi + 1} (tools/biomes-persos/export.py)"}
        for r, _u, _v, mode, _a, n, dur, y0, rows in jobs:
            if r != role:
                continue
            sheet = im.crop((0, y0, COLS * FW, y0 + rows * FH))
            if sheet.getbbox() is None:
                raise SystemExit(f"{role}_{mode} : atlas vide")
            sheet.save(BAKED / "adepts" / f"{role}_{mode}.png")
            entry["modes"][mode] = {"frame_w": FW, "frame_h": FH, "cols": COLS, "rows": rows, "count": n, "fps": round(n / dur)}
            if mode == "idle":
                por = sheet.crop(PORTRAIT).resize((128, 128), Image.NEAREST)
                por.save(BAKED / "hud" / "portraits" / f"{role}.png")
        man["adepts"]["roles"][role] = entry
    path.write_text(json.dumps(man, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("export terminé :", ", ".join(f"{j[0]}_{j[3]}" for j in jobs))


if __name__ == "__main__":
    main()
