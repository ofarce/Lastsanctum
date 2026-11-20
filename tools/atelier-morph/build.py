#!/usr/bin/env python3
"""Planche « Atelier : les pièces prennent la forme de l'objet fabriqué ».

Reprend le moteur planches/assets/batiments-v3-planches.js, remplace les cinq madriers de la Table d'énonciation
par morph.js (une silhouette par recette), et écrit planches/atelier-morph-propositions.html.

    python3 tools/atelier-morph/build.py
"""
import json
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
js = (ROOT / "planches/assets/batiments-v3-planches.js").read_text()

a = js.index("dyn(4,(F,t)=>{const u=K?(t%6)/6:0,p=")
end = "},[LT(0,.9,0,44,.7,VIOBLUE,.1)])"
b = js.index(end, a)
js = js[:a] + "dyn(4,(F,t)=>{morphDraw(F,t,cx,cy)" + js[b:]
i = js.index("function vignette(i)")
js = js[:i] + (HERE / "morph.js").read_text() + js[i:]
ret = "return{ITEMS,GROUPS,vignette,"
assert ret in js
js = js.replace(ret, "return{morph:MO,shapes:MO_SHAPES,setMorph(o){Object.assign(MO,o)}," + ret[7:], 1)

(ROOT / "planches/assets/atelier-morph-planches.js").write_text(js + "\n")

# Icônes du jeu (assets/ardoise/ui/items.png, ordre de ui/inventory/item_icon.gd)
ORDER = ["wood", "rock", "torch", "pickaxe", "arrows", "bow", "sword", "shield", "chest", "wood_fiber",
         "firing_post", "barricade", "fishing_rod", "caltrops", "copper_ingot", "iron_ingot", "gold_ingot"]
strip = Image.open(ROOT / "assets/ardoise/ui/items.png").convert("RGBA")
RECIPES = [
    ("torch", "Torche", "1 bois", "Un manche en deux tronçons, la tête de chiffon, et la flamme qui prend dès que la tête est en place."),
    ("pickaxe", "Pioche", "1 bois, 1 fer", "Deux tronçons pour le manche ; trois pièces virent au fer et se courbent en tête."),
    ("arrows", "Flèches (× 15)", "1 bois", "Trois fûts parallèles, chacun avec sa pointe de fer et son empennage rouge."),
    ("chest", "Coffre", "5 bois, 1 fer", "Quatre planches empilées, deux ferrures verticales et la serrure."),
    ("wood_fiber", "Fibre de bois", "1 bois", "Quatre brins clairs à l’horizontale, deux liens plus sombres en travers."),
    ("firing_post", "Poste de tir", "10 bois", "Cinq pieux dressés en créneaux, tenus par deux traverses."),
    ("barricade", "Barricade", "10 bois, 10 roche", "Deux rondins en croix, un troisième en travers, deux blocs de roche au pied."),
    ("fishing_rod", "Canne à pêche", "2 bois, 1 fer, 1 fibre", "La canne en trois tronçons de plus en plus fins, le moulinet, le fil et l’hameçon."),
    ("bow", "Arc", "1 bois, 1 fibre", "Quatre tronçons courbés pour le bois, une corde de fibre tendue."),
    ("caltrops", "Chausse-trappe", "25 bois", "Trois trépieds de fer, comme sur l’icône. La recette ne demande pourtant que du bois : à trancher."),
]
icons = {}
for rid, *_ in RECIPES:
    k = ORDER.index(rid)
    px = strip.crop((k * 32, 0, k * 32 + 32, 32)).getdata()
    icons[rid] = [(r << 16 | g << 8 | bl) if al >= 128 else -1 for r, g, bl, al in px]
items = [{"id": r, "name": n, "cost": c, "note": d} for r, n, c, d in RECIPES]
items.append({"id": "", "name": "Au repos", "cost": "Personne au poste, ou aucune recette choisie.",
              "note": "Les bouts de bois restent posés sur la table, comme aujourd’hui."})

out = (HERE / "template.html").read_text().replace("/*ENGINE*/", js) \
    .replace("/*ICONS*/{}", json.dumps(icons, separators=(",", ":"))) \
    .replace("/*ITEMS*/[]", json.dumps(items, ensure_ascii=False))
dst = ROOT / "planches/atelier-morph-propositions.html"
dst.write_text(out)
print(dst, len(out))
