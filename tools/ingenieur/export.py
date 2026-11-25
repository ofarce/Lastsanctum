#!/usr/bin/env python3
"""Export de l'Ingénieur, tenue « Templier technomancien » (planches/assets/engineer-exile.js), vers le jeu.

    python3 tools/ingenieur/export.py          # Templier technomancien → assets/imported/engineer/templier/
    python3 tools/ingenieur/export.py exil     # avant la combinaison (planches/assets/engineer-ragged.js, piste A)
                                               # → assets/imported/engineer/exil/ (exil_base.png, exil_portrait.png, exil.json)

Capture planches/ingenieur-export.html?shot=1 avec Firefox headless (planche à 1:1 sur fond magenta,
portrait 128 × 128 dessous), retire le magenta et écrit dans assets/imported/engineer/templier/ :
- templier_base.png : toutes les animations, même gabarit que tyrien.json (images 48 × 48, pieds en 24, 45) ;
- templier_portrait.png : portrait du HUD ;
- templier.json : gabarit, animations, géométrie de la visée (mêmes formules que la page d'export).
"""
from __future__ import annotations

import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PAGE = ROOT / "planches" / "ingenieur-export.html"
BODIES = {
    "templier": ("", "planches/assets/engineer-maj.js (Templier technomancien, mains nues)"),
    "exil": ("&body=exil", "planches/assets/engineer-maj.js (avant la combinaison : torse nu, chausses déchirées, poings nus ; rangées c_* et helm = Templier)"),
}
FW = FH = 48
OX, OY = 8, 15
# nom, colonnes, lignes, images, fps, note — dans l'ordre de la page d'export.
ANIMS = [
    ("idle", 12, 6, 72, 12, "repos : souffle en quatre temps, cercle runique qui bat, clignements, geste d’attente toutes les 6 s"),
    ("walk", 12, 1, 12, None, "marche : 12 poses, phase += distance / stride (5 unités par cycle : 3 cycles/s à 15,2 unités/s, les pieds glissent)"),
    ("kneel", 12, 3, 36, 12, "à genoux, souffle court (24), puis se relève (12)"),
    ("pray", 12, 2, 24, 12, "agenouillé, mains jointes (incantation)"),
    ("settle", 12, 1, 10, 12, "s’assoit en tailleur (jouée à l’envers pour se relever)"),
    ("lotus", 12, 4, 48, 12, "méditation en tailleur, yeux clos, souffle lent"),
    ("slash1", 14, 1, 14, 21, "direct du gantelet, 21 i/s"),
    ("slash2", 16, 1, 16, 18, "coup de marteau des deux poings, onde au sol, 18 i/s"),
    ("shoot", 6, 1, 6, 12, "décharge du gantelet (0,5 s), 12 i/s"),
    ("aim", 19, 4, 76, None, "visée du gantelet : 19 angles (−90° à +90°) × 4 lignes (recul 0 / 1,5 / 3, suspension)"),
    ("shoot_d", 6, 1, 6, 12, "décharge vers le sud (de face), 12 i/s"),
    ("shoot_u", 6, 1, 6, 12, "décharge vers le nord (de dos), 12 i/s"),
    ("idle_d", 12, 2, 24, 12, "repos de face"),
    ("walk_d", 12, 1, 12, None, "marche vers le bas (de face)"),
    ("idle_u", 12, 2, 24, 12, "repos de dos"),
    ("walk_u", 12, 1, 12, None, "marche vers le haut (de dos)"),
    ("hit", 6, 1, 6, 12, "touché : buste rejeté en arrière (0,5 s)"),
    ("c_idle", 12, 4, 48, 12, "repos, Arbalestrie baissée (tête : +1 px sur les images 9 à 20 de chaque souffle de 24)"),
    ("c_walk", 12, 1, 12, None, "marche, Arbalestrie baissée (tête : +1 px sur les images 0, 1, 5, 6, 7, 11)"),
    ("c_shoot", 6, 1, 6, 24, "tir de l’Arbalestrie, Coup sec : le canon seul recule de 4 px et revient en ressort, 6 images à 24 i/s (tête fixe)"),
    ("c_idle_d", 12, 2, 24, 12, "repos de face, Arbalestrie sur l’épaule droite (gauche de l’image)"),
    ("c_walk_d", 12, 1, 12, None, "marche vers le bas, Arbalestrie sur l’épaule"),
    ("c_idle_u", 12, 2, 24, 12, "repos de dos, Arbalestrie sur l’épaule droite"),
    ("c_walk_u", 12, 1, 12, None, "marche vers le haut, Arbalestrie sur l’épaule"),
    ("c_shoot_d", 6, 1, 6, 24, "tir de l’Arbalestrie vers le sud (de face), canon à la hanche pointé vers le bas, 24 i/s"),
    ("c_shoot_u", 6, 1, 6, 24, "tir de l’Arbalestrie vers le nord (de dos), canon levé, 24 i/s"),
    ("idle_dr", 12, 2, 24, 12, "repos de trois quarts face (diagonale bas-droite ; miroir pour bas-gauche)"),
    ("walk_dr", 12, 1, 12, None, "marche de trois quarts face"),
    ("idle_ur", 12, 2, 24, 12, "repos de trois quarts dos (diagonale haut-droite ; miroir pour haut-gauche)"),
    ("walk_ur", 12, 1, 12, None, "marche de trois quarts dos"),
    ("c_idle_dr", 12, 2, 24, 12, "repos de trois quarts face, Arbalestrie sur l’épaule droite"),
    ("c_walk_dr", 12, 1, 12, None, "marche de trois quarts face, Arbalestrie sur l’épaule"),
    ("c_idle_ur", 12, 2, 24, 12, "repos de trois quarts dos, Arbalestrie sur l’épaule droite"),
    ("c_walk_ur", 12, 1, 12, None, "marche de trois quarts dos, Arbalestrie sur l’épaule"),
    ("shoot_dr", 6, 1, 6, 12, "décharge du gantelet de trois quarts face (diagonale bas-droite), 12 i/s"),
    ("shoot_ur", 6, 1, 6, 12, "décharge du gantelet de trois quarts dos (diagonale haut-droite), 12 i/s"),
    ("c_shoot_dr", 6, 1, 6, 24, "tir de l’Arbalestrie de trois quarts face, tube à 45° vers le bas, 24 i/s"),
    ("c_shoot_ur", 6, 1, 6, 24, "tir de l’Arbalestrie de trois quarts dos, tube à 45° vers le haut, 24 i/s"),
    ("fall", 8, 1, 8, 12, "mort Foudroyé : coup reçu, bascule en vol (3), couché sur le dos, lumières allumées / éteintes (7 = pose finale) ; images centrées sur le corps"),
    ("helm", 4, 1, 4, None, "calque du casque de combat : fermeture 25 / 50 / 75 / 100 % (tête au repos, décaler de dy)"),
    ("helm_d", 4, 1, 4, None, "casque de face : fermeture 25 / 50 / 75 / 100 % (tête au repos, décaler de head_dy)"),
    ("helm_u", 4, 1, 4, None, "casque de dos : fermeture 25 / 50 / 75 / 100 % (tête au repos, décaler de head_dy)"),
    ("helm_dr", 4, 1, 4, None, "casque de trois quarts face : fermeture 25 / 50 / 75 / 100 % (décaler de head_dy)"),
    ("helm_ur", 4, 1, 4, None, "casque de trois quarts dos : fermeture 25 / 50 / 75 / 100 % (décaler de head_dy)"),
]
W = 19 * FW
H = sum(r for _, _, r, *_ in ANIMS) * FH


def meta(body: str) -> dict:
    anims, y = {}, 0
    for name, cols, rows, n, fps, note in ANIMS:
        m = {"y": y, "cols": cols, "rows": rows, "count": n, "note": note}
        if fps:
            m["fps"] = fps
        anims[name] = m
        y += rows * FH
    angles = list(range(-90, 91, 10))
    sx, sy = OX + 16 + 1 + 0.5, OY + 15 + 0.5
    return {
        "source": BODIES[body][1] + " — tools/ingenieur/export.py",
        "frame_w": FW, "frame_h": FH, "ax": 24, "ay": 45, "h": 31, "stride": 5.0, "self_bob": True,
        "overlays": False, "anims": anims,
        "aim": {
            "angles": angles,
            "rows_def": [{"recoil": 0, "pulse": 0.5}, {"recoil": 1.5, "pulse": 0.5}, {"recoil": 3, "pulse": 0.5}, {"recoil": 0, "pulse": 1}],
            "muzzle": [[round(sx + 7.5 * math.cos(math.radians(a)), 1), round(sy + 7.5 * math.sin(math.radians(a)), 1)] for a in angles],
            "shoulder": [sx, sy],
        },
    }


# Rangées de face et de dos à l'Arbalestrie : zone de la bouche (x0, x1, y0, y1), hors des gantelets et des bottes.
TIP_ZONES = {"c_idle_d": (0, 19, 0, 30), "c_walk_d": (0, 19, 0, 30), "c_idle_u": (29, 48, 0, 30), "c_walk_u": (29, 48, 0, 30),
             "c_shoot_d": (27, 36, 29, 41), "c_shoot_u": (26, 36, 8, 30),
             "c_idle_dr": (0, 20, 0, 30), "c_walk_dr": (0, 20, 0, 30), "c_idle_ur": (28, 48, 0, 30), "c_walk_ur": (28, 48, 0, 30),
             "c_shoot_dr": (30, 46, 30, 46), "c_shoot_ur": (30, 46, 10, 26)}
TIP_LIGHT = (200, 251, 255)


def tips(sheet: Image.Image, anims: dict) -> dict:
    """Coin haut gauche de la lumière de la bouche (pixels cyan clair) dans chaque image : lumière de munition du jeu."""
    out = {}
    for name, (x0, x1, y0, y1) in TIP_ZONES.items():
        a, pts = anims[name], []
        for i in range(a["count"]):
            fx, fy = (i % a["cols"]) * FW, a["y"] + (i // a["cols"]) * FH
            lit = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if sheet.getpixel((fx + x, fy + y))[:3] == TIP_LIGHT]
            pts.append([min(x for x, _ in lit), min(y for _, y in lit)] if lit else [0, 0])
        out[name] = pts
    return out


# Hauteur de la tête (px, + = plus bas) dans les rangées de face et de dos à l'Arbalestrie, par rapport au repos :
# haut du crâne mesuré entre x = 21 et 26 (hors du canon), pour poser le casque helm_d / helm_u.
HEAD_ROWS = {"c_idle_d": "c_idle_d", "c_walk_d": "c_idle_d", "c_shoot_d": "c_idle_d",
             "c_idle_u": "c_idle_u", "c_walk_u": "c_idle_u", "c_shoot_u": "c_idle_u",
             "c_idle_dr": "c_idle_dr", "c_walk_dr": "c_idle_dr", "c_idle_ur": "c_idle_ur", "c_walk_ur": "c_idle_ur",
             "c_shoot_dr": "c_idle_dr", "c_shoot_ur": "c_idle_ur"}


def head_dy(sheet: Image.Image, anims: dict) -> dict:
    def top(name: str, i: int) -> int:
        a = anims[name]
        fx, fy = (i % a["cols"]) * FW, a["y"] + (i // a["cols"]) * FH
        for y in range(FH):
            if any(sheet.getpixel((fx + x, fy + y))[3] > 0 for x in range(22, 27)):
                return y
        return 0
    return {name: [top(name, i) - top(ref, 0) for i in range(anims[name]["count"])] for name, ref in HEAD_ROWS.items()}


# Coup sec (c_shoot de profil) : même table que SHOOT_REC (planches/assets/engineer-maj.js), à tenir en phase.
SHOOT_REC = [4, 4, 2, 0, -1, 0]


def shoot_tips() -> list:
    """Coin haut gauche de la lumière de la bouche sur les images de c_shoot (poignée à 6 − recul px de l'épaule)."""
    return [[25 + 6 - r + 9, 27] for r in SHOOT_REC]


def unkey(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, _ = px[x, y]
            if r > 240 and g < 16 and b > 240:
                px[x, y] = (0, 0, 0, 0)
    return img


def main() -> int:
    body = sys.argv[1] if len(sys.argv) > 1 else "templier"
    if body not in BODIES:
        print("corps inconnu :", body, "(", ", ".join(BODIES), ")", file=sys.stderr)
        return 2
    out = ROOT / "assets" / "imported" / "engineer" / body
    with tempfile.TemporaryDirectory() as tmp:
        shot = Path(tmp) / "shot.png"
        prof = Path(tmp) / "profil"
        prof.mkdir()
        subprocess.run(["firefox", "--headless", "--no-remote", "--profile", str(prof), "--window-size", f"{W},{H + 128}",
                        "--screenshot", str(shot), PAGE.as_uri() + "?shot=1" + BODIES[body][0]], check=True, timeout=120,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        img = Image.open(shot)
        img.load()
    if img.width < W or img.height < H + 128:
        print("capture trop petite :", img.size, file=sys.stderr)
        return 1
    out.mkdir(parents=True, exist_ok=True)
    sheet = unkey(img.crop((0, 0, W, H)))
    sheet.save(out / f"{body}_base.png")
    unkey(img.crop((0, H, 128, H + 128))).save(out / f"{body}_portrait.png")
    m = meta(body)
    m["tips"] = tips(sheet, m["anims"])
    m["tips"]["c_shoot"] = shoot_tips()
    m["head_dy"] = head_dy(sheet, m["anims"])
    (out / f"{body}.json").write_text(json.dumps(m, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("écrit", out.relative_to(ROOT), W, "×", H)
    return 0


if __name__ == "__main__":
    sys.exit(main())
