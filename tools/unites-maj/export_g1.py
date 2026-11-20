#!/usr/bin/env python3
"""Exporte la Brute (modèle B · Colosse cuirassé) et le Strazhar (modèle A · Champion couronné, à quatre pattes
partout) de planches/brute-strazhar-propositions.html vers assets/imported/enemies/ et met à jour le manifeste.
Rendu par Firefox headless sur fond magenta détouré : pas de serveur nécessaire.

    python3 tools/unites-maj/export_g1.py     # puis : godot --headless --path . --import
"""
import json
import pathlib
import subprocess
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
PL = ROOT / "planches" / "assets"
EN = ROOT / "assets" / "imported" / "enemies"
COLS = 12
# kind : (unité du dessin, variante, cadre, ancre, foulée en unités de monde, animations (nom, images, durée en s, boucle))
UNITS = {
    "brute": ("brute", 1, (48, 46), (24, 43), 1.75,
              [("idle", 48, 2.0, True), ("walk", 24, 0.9, False), ("attack", 29, 29 / 24, False), ("hit", 6, 0.25, False), ("death", 45, 1.875, False)]),
    "strazhar": ("straz", 0, (68, 48), (33, 45), 5.5,
                 [("idle", 72, 3.0, True), ("walk", 24, 0.56, False), ("attack", 21, 0.875, False), ("hit", 6, 0.25, False), ("death", 45, 1.875, False)]),
}


def main() -> None:
    jobs, y = [], 0
    for kind, (unit, vi, (fw, fh), _a, _s, anims) in UNITS.items():
        for name, n, dur, _loop in anims:
            rows = -(-n // COLS)
            jobs.append((kind, unit, vi, name, n, dur, fw, fh, y, rows))
            y += rows * fh
    width, height = COLS * 68, y
    js = "".join((PL / f).read_text(encoding="utf-8") for f in ("engineer-colosse.js", "refonte-16bits.js", "boss/brute-strazhar.js"))
    draw = "".join(
        f"for(let i=0;i<{n};i++)g.drawImage(G1.at('{unit}',{vi},'{name}',i/{n}*{dur}),(i%{COLS})*{fw},{y0}+Math.floor(i/{COLS})*{fh});"
        for _k, unit, vi, name, n, dur, fw, fh, y0, _r in jobs)
    html = (f'<!doctype html><html><body style="margin:0;overflow:hidden;background:#f0f"><canvas id=c width={width} height={height} style="display:block"></canvas><script>{js}\n'
            f"const g=document.getElementById('c').getContext('2d');g.imageSmoothingEnabled=false;g.fillStyle='#f0f';g.fillRect(0,0,{width},{height});{draw}</script></body></html>")
    with tempfile.TemporaryDirectory() as tmp:
        t = pathlib.Path(tmp)
        (t / "prof").mkdir()
        (t / "x.html").write_text(html, encoding="utf-8")
        subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(t / "prof"), f"--window-size={width},{height}",
                        "--screenshot", str(t / "x.png"), (t / "x.html").as_uri()], check=True, timeout=120, capture_output=True)
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
    for kind, (_unit, _vi, (fw, fh), (ax, ay), stride, anims) in UNITS.items():
        entry = {"ax": ax, "ay": ay, "stride": stride, "self_bob": True, "version": 3}
        for k, _u, _v, name, n, dur, _fw, _fh, y0, rows in jobs:
            if k != kind:
                continue
            sheet = im.crop((0, y0, COLS * fw, y0 + rows * fh))
            if sheet.getbbox() is None:
                raise SystemExit(f"{kind}_{name} : atlas vide")
            sheet.save(EN / f"{kind}_{name}.png")
            loop = next(a[3] for a in anims if a[0] == name)
            entry[name] = {"frame_w": fw, "frame_h": fh, "cols": COLS, "rows": rows, "count": n, "fps": round(n / dur, 3), "duration": dur,
                           **({"loop": True} if loop else {})}
            if name == "idle":
                entry["h"] = ay - sheet.crop((0, 0, fw, fh)).getbbox()[1] + 2
        man["enemies"][kind] = entry
    man["g1"] = "planches/brute-strazhar-propositions.html (tools/unites-maj/export_g1.py) : brute B, strazhar A"
    path.write_text(json.dumps(man, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("export terminé :", ", ".join(f"{k}_{j[3]}" for k in UNITS for j in jobs if j[0] == k))


if __name__ == "__main__":
    main()
