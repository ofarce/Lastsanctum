#!/usr/bin/env python3
"""Planches « modèles finaux » des biomes 1 et 2, autonomes (scripts de dessin embarqués).

    python3 tools/biomes-persos/build.py            # les deux planches
    python3 tools/biomes-persos/build.py persos     # planches/biomes-personnages-finaux.html
    python3 tools/biomes-persos/build.py monstres   # planches/biomes-monstres-finaux.html

Dessin : planches/assets/biomes/personnages.js et monstres.js (moteur engineer-colosse.js + rampes refonte-16bits.js).
Gabarit : tools/biomes-persos/template.html.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ("engineer-colosse.js", "refonte-16bits.js")
BTN = '<button data-v="{v}"{p}>{n}</button>'

PAGES = {
    "persos": {
        "out": "planches/biomes-personnages-finaux.html",
        "script": "biomes/personnages.js",
        "title": "Oublieux et mages, modèles",
        "lede": "Cinq modèles animés pour chacun des quatre nouveaux personnages : l’Oublieux de l’Église et les trois mages de l’École de magie cristallisée. Tous humains, dessinés avec le moteur des unités de la Caserne : aplats francs, contour teinté, lumière en haut à gauche, 24 images par seconde. Les lueurs restent vives de nuit. Rien n’est changé en jeu.",
        "anims": [("idle", "Repos"), ("walk", "Marche"), ("act", "Action"), ("death", "Mort")],
        "sols": "",
        "scale_sub": "Les vingt modèles au repos à côté des trois unités de la Caserne, deux fois la taille réelle.",
        "cfg": {
            "api": "PERSO", "store": "biomes-persos-choix", "scaleW": 640, "scaleH": 64, "refs": ["lame", "archer", "flammes"],
            "cap": "De gauche à droite : épée et bouclier, archer, lance-flammes, puis les cinq Oublieux, Guérisseuses, Chantres et Envoûteurs.",
            "text": {
                "obl": {"sub": "Sort de l’Église chaque nuit, ramasse 12 objets par trajet, ne se bat pas. Cendre et linceul, une veilleuse aux couleurs des Limbes, jamais d’or. « Action » = ramasser un objet et le ranger. « Mort » = il s’affaisse en tas de bure, sa lueur s’échappe, puis il se relève : c’est aussi son retour de la nuit suivante.",
                        "note": "<b>À trancher avec le modèle.</b> Le 3 n’a pas de veilleuse : de nuit il se lit moins bien que les autres, c’est voulu mais c’est un risque."},
                "heal": {"sub": "Vert de Medeina, cristal vert. Soigne l’allié le plus blessé à portée, n’attaque pas. « Action » = le soin, tenu tant qu’elle canalise. « Mort » = le cristal la gagne des pieds à la tête, puis elle vole en éclats ; même fin pour les trois mages."},
                "chant": {"sub": "Orange d’Indra, cristal orange. Aura : les alliés autour de lui frappent plus fort. Le cercle au sol marque le rayon de l’aura dans les cinq modèles ; ce qui change, c’est d’où part le chant."},
                "hex": {"sub": "Bleu-violet d’Aether, cristal violet. Marque une cible et ses voisins : leur armure baisse. Le petit bouclier fendu qui apparaît à droite est la marque posée sur la cible, pas une partie du personnage."},
            },
        },
    },
    "monstres": {
        "out": "planches/biomes-monstres-finaux.html",
        "script": "biomes/monstres.js",
        "title": "Monstres du cuivre, modèles",
        "lede": "Cinq modèles animés pour chacun des quatre monstres des Veines de vert-de-gris : l’anguille des puits, la tique de filon, la chauve-souris patinée et la Gorge-Cuivre, boss de fin du biome. Même moteur que les ennemis refondus, 24 images par seconde. Cuivre et vert-de-gris partout, décharges bleu pâle ; ni or, ni rouge. Rien n’est changé en jeu.",
        "anims": [("idle", "Repos"), ("walk", "Déplacement"), ("act", "Attaque"), ("death", "Mort")],
        "sols": "",
        "scale_sub": "Les vingt modèles à côté d’un soldat du Credo et d’une épée-bouclier de la Caserne, deux fois la taille réelle. Tous au repos, sauf les chauves-souris, montrées en vol.",
        "cfg": {
            "api": "MONSTRE", "store": "biomes-monstres-choix", "scaleW": 1040, "scaleH": 92, "refs": ["soldier", "lame"],
            "cap": "De gauche à droite : soldat du Credo, épée et bouclier, puis les cinq anguilles, tiques, chauves-souris et Gorges-Cuivre.",
            "text": {
                "eel": {"sub": "60 PV, ne quitte jamais l’eau ; sa décharge touche tout ce qui a les pieds dans la même flaque. La partie sombre et sans contour est le corps vu sous la surface : en jeu elle se fond dans l’eau. « Repos » = à l’affût, presque invisible. « Attaque » = elle dresse la tête, se charge, décharge."},
                "tick": {"sub": "40 PV, armure 4, neutre : collée sur son filon, elle mord le mineur qui la dérange puis retourne se coller. « Repos » = collée, pattes repliées. « Mort » = elle saute, retombe sur le dos, les pattes se recroquevillent."},
                "bat": {"sub": "18 PV, très rapide, en nuées de cinq, éteint les torches posées. Vue de face, ailes symétriques. « Repos » = suspendue à la roche, elle ouvre un œil et s’étire de temps en temps. « Attaque » = le piqué. L’ombre reste au sol pendant le vol."},
                "worm": {"sub": "Boss de fin du biome : 2 400 PV, armure 5 sur les anneaux, dégâts doublés dans la gueule. Cadre 104 × 88, quatre fois la surface d’un soldat. « Déplacement » = la Percée : elle s’enfonce, une butte file sous le sol, elle rejaillit plus loin. « Attaque » = elle se cabre, gueule grande ouverte (c’est la fenêtre de tir), puis s’abat.",
                         "note": "<b>Seuls ces quatre états sont dessinés.</b> La Pluie de minerai, le sillon de la phase 2 et l’appel des tiques de la phase 3 restent à faire sur le modèle retenu."},
            },
        },
    },
}


def build(key: str) -> None:
    pg = PAGES[key]
    src = ROOT / "planches/assets" / pg["script"]
    if not src.exists():
        print(f"{key} : {src.relative_to(ROOT)} absent, planche ignorée")
        return
    js = "\n".join((ROOT / "planches/assets" / s).read_text() for s in (*BASE, pg["script"]))
    cfg = dict(pg["cfg"])
    txt = HERE / f"textes-{key}.json"
    if txt.exists():
        cfg["text"] = json.loads(txt.read_text())
    html = (HERE / "template.html").read_text()
    html = html.replace("__TITLE__", pg["title"]).replace("__LEDE__", pg["lede"]).replace("__SCALE_SUB__", pg["scale_sub"]).replace("__SOLS__", pg["sols"])
    html = html.replace("__ANIMS__", "".join(BTN.format(v=v, n=n, p=' aria-pressed="true"' if i == 0 else "") for i, (v, n) in enumerate(pg["anims"])))
    html = html.replace("__CFG__", json.dumps(cfg, ensure_ascii=False))
    html = html.replace("/*DRAW*/", js.replace("</script", "<\\/script"))
    out = ROOT / pg["out"]
    out.write_text(html)
    print(f"{pg['out']} : {len(html) // 1024} Ko")


if __name__ == "__main__":
    for k in (sys.argv[1:] or PAGES):
        build(k)
