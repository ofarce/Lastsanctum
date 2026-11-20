#!/usr/bin/env python3
"""Planche « Unités : pistes de mise à jour » (graphisme, lisibilité, animations, fluidité), autonome.

    python3 tools/unites-maj/build.py      # écrit planches/unites-maj-propositions.html

Les démonstrations tournent sur les atlas du jeu (embarqués en base64) ; le tableau de mesures est recalculé
à chaque génération. Gabarit : tools/unites-maj/template.html.
"""
from __future__ import annotations

import base64
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
EN = ROOT / "assets/imported/enemies"
AD = ROOT / "assets/baked/adepts"
OUT = ROOT / "planches/unites-maj-propositions.html"

ENEMIES = {
    "creep": "Fanatique", "spitter": "Thuriféraire", "scout": "Éclaireur", "soldier": "Soldat",
    "shield": "Bouclier doré", "archer": "Archer du Credo", "brute": "Automate (Brute)", "strazhar": "Strazhar",
    "beast": "Chien de la Bête", "feline": "Félin", "croc": "Crocodile", "martyre": "Martyre",
}
ALLIES = {
    "lame": "Épée et bouclier", "archer": "Archer", "flammes": "Lance-flammes",
    "sigil": "Esprit de Sigil", "indra": "Esprit d’Indra", "aether": "Esprit d’Aether", "medeina": "Esprit de Medeina",
}
# Atlas embarqués pour les démonstrations : clé → (fichier, méta).
EMBED_EN = {"creep": ["idle"], "scout": ["idle"], "soldier": ["idle", "walk"], "shield": ["idle"], "archer": ["idle"],
            "brute": ["idle"], "strazhar": ["idle"], "beast": ["walk"], "croc": ["idle"], "feline": ["idle"]}
EMBED_AD = {"lame": ["idle", "walk"], "archer": ["idle"], "flammes": ["idle"], "sigil": ["idle"], "indra": ["idle"],
            "aether": ["idle"]}


def frames(path: Path, d: dict) -> list[np.ndarray]:
    im = Image.open(path).convert("RGBA")
    cols = im.size[0] // d["frame_w"]
    out = []
    for i in range(d["count"]):
        x, y = (i % cols) * d["frame_w"], (i // cols) * d["frame_h"]
        if y + d["frame_h"] > im.size[1]:
            break
        out.append(np.array(im.crop((x, y, x + d["frame_w"], y + d["frame_h"]))))
    return out


def measure(path: Path, d: dict, fps: float) -> dict:
    fr = frames(path, d)
    keys = {(a[..., :3] * (a[..., 3:] > 0)).tobytes() for a in fr}
    a = fr[0]
    op = a[..., 3] > 0
    ys, xs = np.where(op.any(1))[0], np.where(op.any(0))[0]
    return {"n": len(fr), "poses": len(keys), "fps": round(fps, 1), "dur": round(len(fr) / fps, 2),
            "w": int(xs[-1] - xs[0] + 1), "h": int(ys[-1] - ys[0] + 1),
            "colors": len({tuple(p) for p in a[op][:, :3]})}


def b64(path: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def main() -> None:
    em = json.loads((EN / "manifest.json").read_text())["enemies"]
    ad = json.loads((ROOT / "assets/baked/manifest.json").read_text())["adepts"]["roles"]
    rows, atlas = [], {}
    for k, name in ENEMIES.items():
        r = {"id": k, "name": name, "camp": "ennemi", "acts": {}}
        for act in ("idle", "walk", "attack", "death"):
            r["acts"][act] = measure(EN / f"{k}_{act}.png", em[k][act], em[k][act]["fps"])
        rows.append(r)
    for k, name in ALLIES.items():
        r = {"id": k, "name": name, "camp": "allié", "acts": {}}
        modes = ad[k]["modes"]
        for act, src in (("idle", "idle"), ("walk", "walk"), ("attack", "fight" if "fight" in modes else "work")):
            # AdeptView.ANIM_SPEED = 2 : cadence réelle doublée.
            r["acts"][act] = measure(AD / f"{k}_{src}.png", modes[src], modes[src].get("fps", 6) * 2.0)
        if "fight" in modes:
            same = (AD / f"{k}_idle.png").read_bytes() == (AD / f"{k}_walk.png").read_bytes()
            r["walk_is_idle"] = same
        rows.append(r)
    for k, acts in EMBED_EN.items():
        for act in acts:
            d = em[k][act]
            atlas[f"e_{k}_{act}"] = {"src": b64(EN / f"{k}_{act}.png"), "fw": d["frame_w"], "fh": d["frame_h"],
                                     "n": d["count"], "fps": d["fps"], "ax": em[k].get(act, {}).get("ax", em[k]["ax"]),
                                     "ay": em[k].get(act, {}).get("ay", em[k]["ay"])}
    for k, acts in EMBED_AD.items():
        for act in acts:
            d = ad[k]["modes"][act]
            atlas[f"a_{k}_{act}"] = {"src": b64(AD / f"{k}_{act}.png"), "fw": d["frame_w"], "fh": d["frame_h"],
                                     "n": d["count"], "fps": d.get("fps", 6) * 2.0, "ax": ad[k]["ax"], "ay": ad[k]["ay"]}
    html = (HERE / "template.html").read_text()
    html = html.replace("/*ROWS*/null", json.dumps(rows, ensure_ascii=False))
    html = html.replace("/*ATLAS*/null", json.dumps(atlas))
    OUT.write_text(html)
    print(f"{OUT.relative_to(ROOT)} : {len(html) // 1024} Ko, {len(atlas)} atlas")


if __name__ == "__main__":
    main()
