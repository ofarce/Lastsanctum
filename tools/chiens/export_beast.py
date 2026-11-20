#!/usr/bin/env python3
"""Exporte les atlas du chien de la Bête (modèle C de planches/chiens-bete-propositions.html) vers
assets/imported/enemies/beast_{idle,walk,attack,death}.png et met à jour le manifeste.
Rendu par Firefox headless (profil temporaire, fond magenta détouré) : pas de serveur nécessaire.
Usage, depuis la racine du dépôt : python3 tools/chiens/export_beast.py"""
import json, pathlib, subprocess, tempfile
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
PL = ROOT / "planches" / "assets"
EN = ROOT / "assets" / "imported" / "enemies"
FW, FH, COLS = 84, 48, 12
ANIMS = [("idle", 48, 2.0, True), ("walk", 12, 0.5, False), ("attack", 18, 0.75, False), ("death", 36, 1.5, False)]

def main():
    rows = {a: -(-n // COLS) for a, n, _, _ in ANIMS}
    y, offs = 0, {}
    for a, *_ in ANIMS:
        offs[a] = y
        y += rows[a] * FH
    W, H = FW * COLS, y
    js = "".join((PL / f).read_text(encoding="utf-8") for f in ("engineer-colosse.js", "refonte-16bits.js", "bete/chiens-bete.js"))
    draw = "".join(f"for(let i=0;i<{n};i++)g.drawImage(CHIENS.frame('C','{a}',i/24),(i%{COLS})*{FW},{offs[a]}+Math.floor(i/{COLS})*{FH});" for a, n, _, _ in ANIMS)
    html = (f'<!doctype html><html><body style="margin:0;overflow:hidden;background:#f0f"><canvas id=c width={W} height={H} style="display:block"></canvas><script>{js}\n'
            f"const g=document.getElementById('c').getContext('2d');g.imageSmoothingEnabled=false;g.fillStyle='#f0f';g.fillRect(0,0,{W},{H});{draw}</script></body></html>")
    with tempfile.TemporaryDirectory() as tmp:
        t = pathlib.Path(tmp)
        (t / "prof").mkdir()
        (t / "x.html").write_text(html, encoding="utf-8")
        subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(t / "prof"), f"--window-size={W},{H}",
                        "--screenshot", str(t / "x.png"), (t / "x.html").as_uri()], check=True, timeout=90, capture_output=True)
        im = Image.open(t / "x.png").convert("RGBA")
    px = im.load()
    for yy in range(im.height):
        for xx in range(im.width):
            if px[xx, yy][:3] == (255, 0, 255):
                px[xx, yy] = (0, 0, 0, 0)
    for a, *_ in ANIMS:
        im.crop((0, offs[a], W, offs[a] + rows[a] * FH)).save(EN / f"beast_{a}.png")
    top = im.crop((0, 0, FW, FH)).getbbox()[1]
    path = EN / "manifest.json"
    man = json.loads(path.read_text(encoding="utf-8"))
    fr = lambda n, r, d, loop: {"frame_w": FW, "frame_h": FH, "cols": COLS, "rows": r, "count": n, "fps": 24, "duration": d, **({"loop": True} if loop else {})}
    man["enemies"]["beast"] = {"ax": 36, "ay": 44, "h": 44 - top + 2, "stride": 4.125, "self_bob": True, "version": 2,
                               **{a: fr(n, rows[a], d, loop) for a, n, d, loop in ANIMS}}
    path.write_text(json.dumps(man, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("export terminé :", ", ".join(f"beast_{a}.png" for a, *_ in ANIMS))

if __name__ == "__main__":
    main()
