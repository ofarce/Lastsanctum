#!/usr/bin/env python3
"""Exporte vers le jeu les monstres du biome 2 retenus sur planches/biomes-monstres-finaux.html.

    python3 tools/biomes-persos/export_monstres.py     # puis : godot --headless --path . --import

Pour l'instant la tique (modèle 4 · Tique à rostre) et la chauve-souris (modèle 3 · La Cuirassée) →
assets/imported/enemies/<type>_{idle,walk,attack,death}.png et leur entrée du manifeste, au format des ennemis
refondus (tools/unites-maj/export_g1.py). La chauve-souris n'a pas de repos au sol : son « idle » est son vol.
Rendu par Firefox headless sur fond magenta détouré ; les lueurs (calque fx) sont fondues dans l'atlas.
"""
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PL = ROOT / "planches" / "assets"
EN = ROOT / "assets" / "imported" / "enemies"
COLS = 12
# type du jeu : (clé du dessin, variante, cadre, ancre, foulée, animations (mode, anim du dessin, images, durée en s, boucle))
UNITS = {
    "tick": ("tick", 3, (48, 40), (23, 34), 1.0,
             [("idle", "idle", 42, 3.49, True), ("walk", "walk", 14, 0.6, False), ("attack", "act", 36, 1.5, False), ("death", "death", 48, 2.0, False)]),
    # Anguille à crête : immobile dans son bassin, l'ancre est le centre du bassin à la surface de l'eau.
    "eel": ("eel", 4, (64, 44), (32, 32), 3.0,
            [("idle", "idle", 50, 4.19, True), ("walk", "idle", 50, 4.19, False), ("attack", "act", 62, 2.6, False), ("death", "death", 36, 3.0, False)]),
    "bat": ("bat", 2, (64, 56), (32, 50), 12.5,
            [("idle", "walk", 43, 1.786, True), ("walk", "walk", 43, 1.786, False), ("attack", "act", 46, 1.9, False), ("death", "death", 36, 1.5, False)]),
}


def main() -> None:
    jobs, y, width = [], 0, 0
    for kind, (key, vi, (fw, fh), _a, _s, anims) in UNITS.items():
        width = max(width, COLS * fw)
        for mode, anim, n, dur, _loop in anims:
            rows = -(-n // COLS)
            jobs.append((kind, key, vi, mode, anim, n, dur, fw, fh, y, rows))
            y += rows * fh
    height = y
    js = "".join((PL / f).read_text(encoding="utf-8") + "\n" for f in ("engineer-colosse.js", "refonte-16bits.js", "biomes/monstres.js"))
    draw = "".join(
        f"for(let i=0;i<{n};i++){{const f=MONSTRE.frame('{key}',{vi},'{anim}',i/{n}*{dur}),x=(i%{COLS})*{fw},y={y0}+Math.floor(i/{COLS})*{fh};g.drawImage(f.c,x,y);g.drawImage(f.fx,x,y)}}"
        for _k, key, vi, _m, anim, n, dur, fw, fh, y0, _r in jobs)
    html = (f'<!doctype html><html><body style="margin:0;overflow:hidden;background:#f0f"><canvas id=c width={width} height={height} style="display:block"></canvas><script>{js}\n'
            f"const g=document.getElementById('c').getContext('2d');g.imageSmoothingEnabled=false;g.fillStyle='#f0f';g.fillRect(0,0,{width},{height});{draw}</script></body></html>")
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
    path = EN / "manifest.json"
    man = json.loads(path.read_text(encoding="utf-8"))
    for kind, (_key, vi, (fw, fh), (ax, ay), stride, anims) in UNITS.items():
        entry = {"ax": ax, "ay": ay, "stride": stride, "self_bob": True, "version": 3,
                 "source": f"planches/biomes-monstres-finaux.html, modèle {vi + 1} (tools/biomes-persos/export_monstres.py)"}
        for k, _ky, _v, mode, _a, n, dur, _fw, _fh, y0, rows in jobs:
            if k != kind:
                continue
            sheet = im.crop((0, y0, COLS * fw, y0 + rows * fh))
            if sheet.getbbox() is None:
                raise SystemExit(f"{kind}_{mode} : atlas vide")
            sheet.save(EN / f"{kind}_{mode}.png")
            loop = next(a[4] for a in anims if a[0] == mode)
            entry[mode] = {"frame_w": fw, "frame_h": fh, "cols": COLS, "rows": rows, "count": n, "fps": round(n / dur, 3), "duration": dur,
                           **({"loop": True} if loop else {})}
            if mode == "idle":
                entry["h"] = ay - sheet.crop((0, 0, fw, fh)).getbbox()[1] + 2
        man["enemies"][kind] = entry
    path.write_text(json.dumps(man, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("export terminé :", ", ".join(f"{j[0]}_{j[3]}" for j in jobs))


if __name__ == "__main__":
    main()
