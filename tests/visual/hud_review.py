#!/usr/bin/env python3
"""Planche de revue du HUD (étape 6, plan v2) : prototype (73b410f) et Godot, contexte par contexte.

1. Captures du prototype : lance le serveur du baker (lecture seule de la version figée), puis Firefox sans
   fenêtre sur tools/baker/hud_shot.html?ctx=<nom> → tests/visual/out/etape6/proto_<nom>.png.
2. Captures Godot : à produire avant avec
     godot --path . res://tests/visual/hud_capture.tscn -- --ctx=<noms>
   → tests/visual/out/etape6/hud_<nom>.png.
3. Planche : pour chaque contexte, bandeau du haut et bandeau de commandement des deux versions, l'un sous
   l'autre → tests/visual/out/etape6/revue_hud.png ; plus une image complète côte à côte par contexte.

Usage : python3 tests/visual/hud_review.py [--skip-proto] nom1 nom2 …
"""
import argparse
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tests' / 'visual' / 'out' / 'etape6'
DEFAULT = ['ingenieur_ancre_eteinte', 'ingenieur_reactivation', 'ingenieur_menu_construire', 'ingenieur_reparer_recharge',
           'ancre_eteinte', 'ancre_active_heros', 'temple_sigil', 'caserne', 'puits_des_ames', 'adepte_sigil_en_route',
           'heros_tireur', 'multi_selection', 'aucune_selection']


def proto_shots(names):
    with tempfile.TemporaryDirectory() as tmp:
        server = subprocess.Popen([sys.executable, str(ROOT / 'tools/baker/serve.py'), '--no-browser', '--timeout', '3600',
                                   '--out', str(Path(tmp) / 'serve')], stdout=subprocess.PIPE, text=True)
        try:
            line = server.stdout.readline()
            port = re.search(r':(\d+)/', line).group(1)
            for name in names:
                profile = Path(tmp) / f'profile_{name}'
                profile.mkdir()
                target = OUT / f'proto_{name}.png'
                subprocess.run(['firefox', '--headless', '--no-remote', '--profile', str(profile), '--window-size=1440,900',
                                '--screenshot', str(target), f'http://127.0.0.1:{port}/hud_shot.html?ctx={name}'],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
                print(('ok  ' if target.exists() else 'ÉCHEC ') + f'proto_{name}.png')
        finally:
            server.terminate()
            server.wait(10)


def sheet(names):
    rows = []
    for name in names:
        a, b = OUT / f'proto_{name}.png', OUT / f'hud_{name}.png'
        if not (a.exists() and b.exists()):
            print(f'capture manquante pour {name}')
            continue
        pa, pb = Image.open(a).convert('RGB'), Image.open(b).convert('RGB')
        both = Image.new('RGB', (2880 + 8, 900), '#ff2030')
        both.paste(pa, (0, 0))
        both.paste(pb, (1448, 0))
        both.save(OUT / f'cote_a_cote_{name}.png')
        rows.append((name, pa, pb))
    if not rows:
        return
    band_h = 2 * (72 + 140) + 30
    img = Image.new('RGB', (1440, band_h * len(rows)), '#06080a')
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(str(ROOT / 'assets/fonts/DejaVuSans.ttf'), 13)
    for k, (name, pa, pb) in enumerate(rows):
        y = k * band_h
        d.text((6, y + 4), f'{name} — prototype (haut), Godot (bas)', fill='#f0e0b0', font=font)
        img.paste(pa.crop((0, 0, 1440, 72)), (0, y + 20))
        img.paste(pa.crop((0, 760, 1440, 900)), (0, y + 20 + 72))
        img.paste(pb.crop((0, 0, 1440, 72)), (0, y + 20 + 212))
        img.paste(pb.crop((0, 760, 1440, 900)), (0, y + 20 + 284))
    img.save(OUT / 'revue_hud.png')
    print(f'planche : {OUT / "revue_hud.png"} ({len(rows)} contextes)')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('names', nargs='*')
    p.add_argument('--skip-proto', action='store_true')
    args = p.parse_args()
    names = args.names or DEFAULT
    OUT.mkdir(parents=True, exist_ok=True)
    if not args.skip_proto:
        proto_shots(names)
    sheet(names)


if __name__ == '__main__':
    main()
