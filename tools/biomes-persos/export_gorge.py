#!/usr/bin/env python3
"""Exporte la Gorge-Cuivre (modèle 3 · Le Mille-pattes mineur de planches/biomes-monstres-finaux.html) vers
assets/imported/gorge/ : un atlas par état du combat (sim/gorge.gd, world/gorge/gorge_view.gd) et meta.json.

    python3 tools/biomes-persos/export_gorge.py     # puis : godot --headless --path . --import

Les états sont des tranches des animations de la planche : « idle » (dressée), « rear » et « slam » (elle se cabre,
gueule ouverte, puis s'abat), « sink », « mound », « emerge » (la Percée : elle s'enfonce, la butte, elle rejaillit),
« death ». Dans la Percée le dessin glisse de 13 px dans son cadre : l'ancre de chaque tranche en tient compte.
"""
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PL = ROOT / "planches" / "assets"
OUT = ROOT / "assets" / "imported" / "gorge"
VARIANT, FW, FH, AX, AY, COLS = 2, 104, 88, 44, 80, 12
# état : (animation du dessin, début, fin (s), images, images par seconde, ancre x, boucle)
ANIMS = {
    "idle": ("idle", 0.0, 4.19, 50, 12, AX, True),
    "rear": ("act", 0.0, 0.7, 17, 24, AX, False),
    "slam": ("act", 0.7, 2.7, 48, 24, AX, False),
    "sink": ("walk", 0.0, 0.7, 17, 24, AX + 13, False),
    "mound": ("walk", 1.45, 1.55, 6, 12, AX, True),
    "emerge": ("walk", 2.3, 3.0, 17, 24, AX - 13, False),
    "death": ("death", 0.0, 3.4, 41, 12, AX, False),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    jobs, y = [], 0
    for name, (anim, t0, t1, n, _fps, _ax, _loop) in ANIMS.items():
        rows = -(-n // COLS)
        jobs.append((name, anim, t0, t1, n, y, rows))
        y += rows * FH
    width, height = COLS * FW, y
    js = "".join((PL / f).read_text(encoding="utf-8") + "\n" for f in ("engineer-colosse.js", "refonte-16bits.js", "biomes/monstres.js"))
    draw = "".join(
        f"for(let i=0;i<{n};i++){{const f=MONSTRE.frame('worm',{VARIANT},'{anim}',{t0}+i/{n}*({t1}-{t0})),x=(i%{COLS})*{FW},y={y0}+Math.floor(i/{COLS})*{FH};g.drawImage(f.c,x,y);g.drawImage(f.fx,x,y)}}"
        for _n, anim, t0, t1, n, y0, _r in jobs)
    html = (f'<!doctype html><html><body style="margin:0;overflow:hidden;background:#f0f"><canvas id=c width={width} height={height} style="display:block"></canvas><script>{js}\n'
            f"const g=document.getElementById('c').getContext('2d');g.imageSmoothingEnabled=false;g.fillStyle='#f0f';g.fillRect(0,0,{width},{height});{draw}</script></body></html>")
    with tempfile.TemporaryDirectory() as tmp:
        t = Path(tmp)
        (t / "prof").mkdir()
        (t / "x.html").write_text(html, encoding="utf-8")
        subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(t / "prof"), f"--window-size={width},{height}",
                        "--screenshot", str(t / "x.png"), (t / "x.html").as_uri()], check=True, timeout=240, capture_output=True)
        im = Image.open(t / "x.png").convert("RGBA")
    if im.size != (width, height):
        raise SystemExit(f"capture {im.size}, attendu {(width, height)}")
    px = im.load()
    for yy in range(im.height):
        for xx in range(im.width):
            if px[xx, yy][:3] == (255, 0, 255):
                px[xx, yy] = (0, 0, 0, 0)
    meta = {"frame_w": FW, "frame_h": FH, "ay": AY, "cols": COLS, "anims": {},
            "source": f"planches/biomes-monstres-finaux.html, modèle {VARIANT + 1} (tools/biomes-persos/export_gorge.py)"}
    for name, _anim, _t0, _t1, n, y0, rows in jobs:
        sheet = im.crop((0, y0, COLS * FW, y0 + rows * FH))
        if sheet.getbbox() is None:
            raise SystemExit(f"gorge_{name} : atlas vide")
        sheet.save(OUT / f"{name}.png")
        _a, _s, _e, _n, fps, ax, loop = ANIMS[name]
        meta["anims"][name] = {"count": n, "fps": fps, "ax": ax, "loop": loop}
    (OUT / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("export terminé :", ", ".join(ANIMS))


if __name__ == "__main__":
    main()
