#!/usr/bin/env python3
"""Compare les captures Godot aux captures de référence du jeu d'origine.

    python3 tests/visual/compare.py --prefix etape2 [--threshold 98] [--tolerance 6]

Un pixel est « identique » si l'écart maximal entre canaux RVB est ≤ tolérance (le lissage
bilinéaire du feuillage peut différer d'une unité entre Firefox et le GPU). Pour chaque
scénario : pourcentage de pixels identiques et image des écarts (en rouge) dans
tests/visual/out/<préfixe>/diff_<nom>.png. Tolérances par scénario dans tests/visual/compare_config.json ; masques facultatifs dans tests/visual/masks.json :
{"<nom>": [[x0, y0, x1, y1], ...]} (zones exclues, en pixels d'écran).
Code de sortie 1 si un scénario est sous le seuil.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--threshold', type=float, default=98.0)
    parser.add_argument('--tolerance', type=int, default=6)
    args = parser.parse_args()
    out_dir = ROOT / 'out' / args.prefix
    masks = json.loads((ROOT / 'masks.json').read_text()) if (ROOT / 'masks.json').exists() else {}
    config = ROOT / 'compare_config.json'
    tolerances = json.loads(config.read_text()).get('tolerance', {}) if config.exists() else {}
    report, failed = [], False
    for ref_path in sorted((ROOT / 'reference').glob(f'{args.prefix}*.png')):
        name = ref_path.stem
        if name.endswith('_light'):
            continue
        got_path = out_dir / f'{name}.png'
        if not got_path.exists():
            print(f'MANQUANT {name}')
            failed = True
            continue
        ref_img = Image.open(ref_path).convert('RGBA')
        light_path = ref_path.with_name(f'{name}_light.png')
        if light_path.exists():
            # Calque d'éclairage du prototype : canvas au quart de la résolution, agrandi et lissé par le CSS.
            light = Image.open(light_path).convert('RGBA').resize(ref_img.size, Image.BILINEAR)
            ref_img = Image.alpha_composite(ref_img, light)
        ref = np.asarray(ref_img.convert('RGB')).astype(int)
        got = np.asarray(Image.open(got_path).convert('RGB')).astype(int)
        if ref.shape != got.shape:
            print(f'FAIL {name} : tailles {ref.shape} / {got.shape}')
            failed = True
            continue
        tol = tolerances.get(name, args.tolerance)
        same = np.abs(ref - got).max(axis=2) <= tol
        keep = np.ones(same.shape, bool)
        for x0, y0, x1, y1 in masks.get(name, []):
            keep[y0:y1, x0:x1] = False
        pct = 100.0 * (same & keep).sum() / keep.sum()
        exact = 100.0 * ((ref == got).all(axis=2) & keep).sum() / keep.sum()
        diff = (ref * 0.35).astype(np.uint8)
        diff[~same & keep] = [255, 40, 40]
        diff[~keep] = [40, 40, 120]
        Image.fromarray(diff).save(out_dir / f'diff_{name}.png')
        ok = pct >= args.threshold
        failed |= not ok
        report.append({'name': name, 'identical_pct': round(pct, 3), 'exact_pct': round(exact, 3), 'tolerance': tol, 'ok': bool(ok)})
        print(f"{'PASS' if ok else 'FAIL'} {name} : {pct:.2f} % identiques (±{tol}), {exact:.2f} % exacts")
    (out_dir / 'report.json').write_text(json.dumps({'threshold': args.threshold, 'tolerance': args.tolerance, 'results': report}, indent=1))
    return 1 if failed or not report else 0


if __name__ == '__main__':
    sys.exit(main())
