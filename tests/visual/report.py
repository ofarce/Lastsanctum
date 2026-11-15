#!/usr/bin/env python3
"""Rapport visuel global (étape 10) : une page HTML autonome avec, pour chaque scénario de référence,
le prototype (éclairage composé), la capture Godot et la carte des écarts, et les scores de compare.py.

    godot --path . res://tests/visual/capture.tscn -- --prefix=etape   # captures de tous les scénarios
    python3 tests/visual/compare.py --prefix etape                     # scores et cartes d'écarts
    python3 tests/visual/report.py                                     # tests/visual/out/rapport_visuel.html
"""
import base64
import html
import io
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'out' / 'etape'
STEPS = {'2': 'Monde statique', '3': 'Terrain dynamique', '4': 'Ambiance', '6': 'HUD', '7': 'Économie et bâtiments',
         '8': 'Combat', '9': 'Héros et effets'}


def thumb(img: Image.Image, width: int = 470) -> str:
    img = img.convert('RGB')
    img = img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, 'JPEG', quality=80)
    return 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode()


def reference(name: str) -> Image.Image:
    ref = Image.open(ROOT / 'reference' / f'{name}.png').convert('RGBA')
    light = ROOT / 'reference' / f'{name}_light.png'
    if light.exists():
        ref = Image.alpha_composite(ref, Image.open(light).convert('RGBA').resize(ref.size, Image.BILINEAR))
    return ref


def main() -> None:
    results = json.loads((OUT / 'report.json').read_text())['results']
    rows, cards = [], []
    for r in results:
        name = r['name']
        step = re.match(r'etape(\d+)', name).group(1)
        rows.append(f"<tr><td>{step}</td><td><a href='#{name}'>{name}</a></td><td>{r['identical_pct']:.2f} %</td>"
                    f"<td>{r['exact_pct']:.2f} %</td><td>±{r['tolerance']}</td><td class='{'ok' if r['ok'] else 'ko'}'>"
                    f"{'conforme' if r['ok'] else 'sous le seuil'}</td></tr>")
        imgs = [('Prototype (73b410f)', reference(name)), ('Godot', Image.open(OUT / f'{name}.png')),
                ('Écarts (rouge : au-delà de la tolérance)', Image.open(OUT / f'diff_{name}.png'))]
        figs = ''.join(f"<figure><img src='{thumb(im)}' alt='{html.escape(t)}'><figcaption>{html.escape(t)}</figcaption></figure>"
                       for t, im in imgs)
        cards.append(f"<section id='{name}'><h3>{name} · étape {step} — {STEPS.get(step, '')}</h3>"
                     f"<p>{r['identical_pct']:.2f} % de pixels identiques (±{r['tolerance']}), {r['exact_pct']:.2f} % exacts.</p>"
                     f"<div class='row'>{figs}</div></section>")
    n_ok = sum(r['ok'] for r in results)
    mean = sum(r['identical_pct'] for r in results) / len(results)
    worst = min(results, key=lambda r: r['identical_pct'])
    page = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rapport visuel global</title><style>
:root{{--bg:#f6f4ef;--fg:#1d1b18;--mute:#6b665d;--line:#d9d3c7;--ok:#2f7d4a;--ko:#b3322b;--card:#fff}}
@media (prefers-color-scheme:dark){{:root{{--bg:#16150f;--fg:#ece7dc;--mute:#a49d90;--line:#3a362e;--ok:#6cc58a;--ko:#ff7a70;--card:#1f1d17}}}}
body{{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;margin:0;padding:24px 16px;max-width:1500px;margin:auto}}
h1{{font-size:24px;margin:0 0 4px}} h3{{margin:0 0 4px;font-size:16px}} p{{margin:0 0 10px;color:var(--mute)}}
table{{border-collapse:collapse;width:100%;margin:16px 0 28px;background:var(--card)}} td,th{{border-bottom:1px solid var(--line);padding:6px 10px;text-align:left}}
th{{font-weight:600}} .ok{{color:var(--ok)}} .ko{{color:var(--ko);font-weight:600}} a{{color:inherit}}
section{{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:14px;margin:0 0 18px}}
.row{{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:10px}}
figure{{margin:0}} img{{width:100%;height:auto;image-rendering:auto;border-radius:4px;display:block}} figcaption{{font-size:13px;color:var(--mute)}}
</style></head><body>
<h1>Rapport visuel global — migration Godot</h1>
<p>{len(results)} scénarios de référence, {n_ok} conformes (seuil 98 % de pixels à ±6, ±20 pour le vent).
Moyenne {mean:.2f} % ; plus faible : {worst['name']} ({worst['identical_pct']:.2f} %). Écarts expliqués dans tests/visual/ECARTS.md.</p>
<table><tr><th>Étape</th><th>Scénario</th><th>Identiques</th><th>Exacts</th><th>Tolérance</th><th>Verdict</th></tr>{''.join(rows)}</table>
{''.join(cards)}
</body></html>"""
    dest = ROOT / 'out' / 'rapport_visuel.html'
    dest.write_text(page, 'utf-8')
    print(f'{dest.relative_to(ROOT.parents[1])} : {len(results)} scénarios, {n_ok} conformes, moyenne {mean:.2f} %')


if __name__ == '__main__':
    main()
