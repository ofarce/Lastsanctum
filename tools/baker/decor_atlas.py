#!/usr/bin/env python3
"""Planche de textures commune du décor (étape 12) : rassemble les sprites du décor extraits par le baker
(assets/baked/world/sprites/*.png et runtime/*.png) dans une seule texture, pour que Godot regroupe les
appels de dessin (une texture et un matériau pour tout le décor).

    python3 tools/baker/decor_atlas.py      # après une extraction (serve.py)

Sortie : assets/baked/world/decor_atlas.png, decor_atlas.json ({id: [x, y, w, h]}) et decor_atlas_meta.png :
texture de même taille, vide sauf au point d'ancrage (x + ax, y + ay) de chaque feuillage, qui porte
(255, ay, type d'arbre, 255). Le shader des objets triés y lit, par sommet, s'il dessine un feuillage, sans
modulation (une modulation propre à chaque feuillage casserait le regroupement des appels de dessin).
Ordre des types : KINDS, identique à Wind.TREES (vérifié par test_baked_assets.gd).
Chaque sprite est entouré de 2 pixels qui prolongent ses bords (comme le « clamp to edge » d'une texture
isolée) : le lissage bilinéaire du feuillage lit alors exactement les mêmes valeurs qu'avant. Rangement
par étagères, trié par hauteur puis par nom : le résultat est déterministe.
"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORLD = ROOT / 'assets' / 'baked' / 'world'
PAD = 2
WIDTH = 1024
KINDS = ['big', 'cyp', 'palm', 'bush']


def sources() -> dict[str, Path]:
    out = {k: WORLD / 'sprites' / f'{k}.png' for k in json.loads((WORLD / 'decor_sprites.json').read_text())}
    for p in sorted((WORLD / 'runtime').glob('*.png')):
        out[p.stem] = p
    return out


def main() -> None:
    src = sources()
    images = {k: Image.open(p).convert('RGBA') for k, p in src.items()}
    order = sorted(images, key=lambda k: (-images[k].height, k))
    x = y = shelf = 0
    places = {}
    for k in order:
        w, h = images[k].size
        if x + w + 2 * PAD > WIDTH:
            x, y, shelf = 0, y + shelf, 0
        places[k] = (x + PAD, y + PAD, w, h)
        x += w + 2 * PAD
        shelf = max(shelf, h + 2 * PAD)
    height = y + shelf
    height = 1 << (height - 1).bit_length()
    atlas = Image.new('RGBA', (WIDTH, height), (0, 0, 0, 0))
    for k, (px, py, w, h) in places.items():
        im = images[k]
        # Bords prolongés (clamp to edge) : colonnes et lignes extrêmes recopiées sur PAD pixels.
        ext = Image.new('RGBA', (w + 2 * PAD, h + 2 * PAD))
        ext.paste(im.resize((w + 2 * PAD, h + 2 * PAD), Image.NEAREST), (0, 0))
        ext.paste(im.crop((0, 0, 1, h)).resize((PAD, h), Image.NEAREST), (0, PAD))
        ext.paste(im.crop((w - 1, 0, w, h)).resize((PAD, h), Image.NEAREST), (w + PAD, PAD))
        ext.paste(im.crop((0, 0, w, 1)).resize((w, PAD), Image.NEAREST), (PAD, 0))
        ext.paste(im.crop((0, h - 1, w, h)).resize((w, PAD), Image.NEAREST), (PAD, h + PAD))
        for cx, cy, sx, sy in [(0, 0, 0, 0), (w + PAD, 0, w - 1, 0), (0, h + PAD, 0, h - 1), (w + PAD, h + PAD, w - 1, h - 1)]:
            ext.paste(Image.new('RGBA', (PAD, PAD), im.getpixel((sx, sy))), (cx, cy))
        ext.paste(im, (PAD, PAD))
        atlas.paste(ext, (px - PAD, py - PAD))
    atlas.save(WORLD / 'decor_atlas.png', optimize=False, compress_level=9)
    sprites = json.loads((WORLD / 'decor_sprites.json').read_text())
    kind_of = {}
    for p in json.loads((WORLD / 'decor_placements.json').read_text())['placements']:
        if 'wind' in p:
            kind_of[sprites[p['s']]['foliage']] = p['wind']
    meta = Image.new('RGBA', (WIDTH, height), (0, 0, 0, 0))
    for fid, kind in sorted(kind_of.items()):
        x0, y0, _, _ = places[fid]
        ax, ay = sprites[fid]['ax'], sprites[fid]['ay']
        meta.putpixel((x0 + ax, y0 + ay), (255, ay, KINDS.index(kind), 255))
    meta.save(WORLD / 'decor_atlas_meta.png', optimize=False, compress_level=9)
    (WORLD / 'decor_atlas.json').write_text(json.dumps({'size': [WIDTH, height], 'pad': PAD, 'kinds': KINDS,
        'sprites': {k: list(v) for k, v in sorted(places.items())}}, indent=0))
    print(f'decor_atlas.png : {len(places)} sprites, {WIDTH}×{height}')


if __name__ == '__main__':
    main()
