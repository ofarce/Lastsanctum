#!/usr/bin/env python3
"""Bestiaire animé : planche avant / après des animations ennemies, autonome (atlas embarqués en base64).

    python3 tools/bestiaire/build.py            # écrit planches/bestiaire-anime.html

« Après » = atlas du jeu (assets/imported/enemies/ et son manifest.json).
« Avant » = tools/bestiaire/avant/ : atlas d'avant les poses intermédiaires (2026-11-19) et leur manifeste ;
un atlas absent de ce dossier n'a pas changé et reprend celui du jeu.
Gabarit : tools/bestiaire/template.html (constantes de nervosité recopiées de entities/unit/unit_view.gd).
La page décode les PNG en mémoire (base64 → Blob → ImageBitmap) : elle s'ouvre seule, sans serveur, et passe
dans les visionneuses qui refusent les images data:.
"""
from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
NEW = ROOT / "assets/imported/enemies"
OLD = HERE / "avant"
TEMPLATE = HERE / "template.html"
OUT = ROOT / "planches/bestiaire-anime.html"

# id : (nom, famille, vitesse en unités/s, recharge en s, cadence) — vitesse et recharge de data/catalog.gd,
# cadence ×1,3 des vagues (Catalog.WAVE_PACE) sauf faune et Martyre.
INFO = {
    "creep": ("Fanatique du Credo", "Credo souillé", 2.7, 1.15, 1.3),
    "spitter": ("Thuriféraire de Fortuna", "Credo souillé", 2.0, 1.15, 1.3),
    "scout": ("Infanterie légère", "Credo", 3.1, 1.05, 1.3),
    "soldier": ("Soldat du Credo", "Credo", 2.1, 1.3, 1.3),
    "shield": ("Bouclier doré", "Byrsa", 1.7, 1.5, 1.3),
    "archer": ("Archer de la Lumière", "Credo", 2.8, 1.4, 1.3),
    "brute": ("Automate doré de Byrsa", "Credo souillé", 1.4, 1.7, 1.3),
    "strazhar": ("Strazhar", "Champion de Byrsa", 8.4, 0.85, 1.3),
    "beast": ("Aberration du Dévoreur", "Chair du Dévoreur", 6.3, 1.15, 1.3),
    "feline": ("Félin de la jungle", "Faune", 4.3, 0.9, 1.0),
    "croc": ("Crocodile des berges", "Faune", 3.4, 1.6, 1.0),
    "martyre": ("Martyre de Byrsa", "Boss", 2.2, 3.0 / 1.3, 1.0),
}
NOTES = {
    "creep": "Respiration en trois temps, foulée sur 12 phases, élan et retour de garde à la dague.",
    "spitter": "Bâton levé en deux temps, flamme qui vacille, retour du bâton.",
    "scout": "Foulée sur 12 phases, estoc avec élan, traînée qui s’efface, retour de garde.",
    "soldier": "Le bras suit le lancer, redescend, va chercher un pilum dans le dos.",
    "shield": "Foulée sur 12 phases, estoc avec élan et retour derrière le pavois.",
    "archer": "Foulée sur 12 phases, corde qui vibre après le tir.",
    "brute": "Marche dessinée sur 24 poses au lieu de 6, tassement à chaque appui.",
    "strazhar": "Respiration du buste puis de la tête au repos (6 → 10 images).",
    "beast": "Refonte en chien de la Bête (Charognard aux trois gueules) : souffle et flair au repos, charge tête basse, bond sur la cible, éclatement en cendres.",
    "feline": "Foulée sur 12 phases, morsure en deux temps, queue qui balance au repos.",
    "croc": "Reptation sur 12 phases, gueule qui jaillit puis revient en deux temps.",
    "martyre": "Planches inchangées ; seule la nervosité en jeu s’ajoute.",
}
RADIUS = {"brute": 0.85, "strazhar": 0.85}


def main() -> None:
    pool: dict[str, str] = {}

    def ref(path: Path) -> str:
        data = path.read_bytes()
        key = hashlib.sha1(data).hexdigest()[:12]
        pool.setdefault(key, "data:image/png;base64," + base64.b64encode(data).decode())
        return key

    new_man = json.loads((NEW / "manifest.json").read_text(encoding="utf-8"))["enemies"]
    old_man = json.loads((OLD / "manifest.json").read_text(encoding="utf-8"))["enemies"]
    kinds = []
    for k, (name, family, speed, cd, pace) in INFO.items():
        entry = {"id": k, "name": name, "family": family, "speed": speed, "cd": cd, "pace": pace,
                 "radius": RADIUS.get(k, 0.6), "note": NOTES[k],
                 "meta": {"new": new_man[k], "old": old_man.get(k, new_man[k])}, "sheets": {"new": {}, "old": {}}}
        for a, v in new_man[k].items():
            if not isinstance(v, dict):
                continue
            entry["sheets"]["new"][a] = ref(NEW / f"{k}_{a}.png")
            old = OLD / f"{k}_{a}.png"
            entry["sheets"]["old"][a] = ref(old if old.exists() else NEW / f"{k}_{a}.png")
        kinds.append(entry)
    html = TEMPLATE.read_text(encoding="utf-8").replace(
        "/*__DATA__*/", "const DATA=" + json.dumps({"kinds": kinds, "pool": pool}, ensure_ascii=False) + ";")
    OUT.write_text(html, encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)} · {OUT.stat().st_size // 1024} Ko · {len(pool)} atlas")


if __name__ == "__main__":
    main()
