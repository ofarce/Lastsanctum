#!/usr/bin/env python3
"""Assemble planches/assets/batiments-etabli-planches.js et planches/etabli-propositions.html (Établi d'exo).

Même moteur que build_v4.py (finition 16 bits) ; les outils de batiments-v4-designs.js (avant GROUPS) sont repris,
les pistes viennent de batiments-etabli-designs.js.

    python3 tools/batiments-16bits/build_v4.py      # moteur v4 à jour
    python3 tools/batiments-16bits/build_etabli.py
"""
from pathlib import Path
import base64
import io
import json

from PIL import Image

R = Path(__file__).resolve().parents[2] / "planches/assets"
ROOT = R.parents[1]
v4 = (R / "batiments-v4-planches.js").read_text()
v4d = (R / "batiments-v4-designs.js").read_text()
# Le moteur v4 assemblé contient les pistes v4 : on remplace son bloc « GROUPS … ITEMS » par celui de l'Établi.
i0 = v4.index(v4d[:200])
i1 = i0 + len(v4d)
assert v4[i0:i1] == v4d, "moteur v4 désynchronisé : relancer build_v4.py"
tools_v4 = v4d[:v4d.index("const GROUPS")]
js = v4[:i0] + tools_v4 + (R / "batiments-etabli-designs.js").read_text() + v4[i1:]
(R / "batiments-etabli-planches.js").write_text(js)
print("ok", len(js))


def crop(art):  # ancre (160,168) du sprite placée en (66,102) dans la vignette 132 x 136
    im = Image.open(ROOT / "assets/baked/buildings" / f"{art}_base.png").convert("RGBA").crop((94, 66, 226, 202))
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


tpl = (Path(__file__).parent / "template_v4.html").read_text()
mods = (Path(__file__).parent / "etabli_mods.html").read_text()


def patch(a, b):
    global tpl
    assert a in tpl, a[:60]
    tpl = tpl.replace(a, b)


patch("<title>Nouveaux bâtiments de fabrication</title>", '<meta charset="utf-8">\n<title>Établi d’exo</title>')
i = tpl.index("<h1>")
j = tpl.index("</div>", i)
tpl = tpl[:i] + """<h1>ÉTABLI D’EXO</h1>
<p class="mut">Nouveau bâtiment de l’intro de la capsule (planche <b>intro-capsule-planche.html</b>) : on y fabrique les modules d’exo de l’Exilé d’après les plans retrouvés, à commencer par <b>Analyse</b>. En jeu, il porte aujourd’hui le dessin de l’Atelier (vignette « Actuel »). Cinq pistes au même rendu que la Scierie et l’Archerie : machines en plein air, finition 16 bits, emprise 2 × 2 cases agrandie trois fois, boucle « au travail » et « au repos » (bouton en haut). En bas, l’icône et le rendu porté du mod Analyse.</p>
<p class="mut" style="margin-top:8px"><b>Pour choisir :</b> bouton « Choisir » sous la piste voulue, puis « Envoyer mon choix » en bas de page.</p>
""" + tpl[j:]
patch("bat16v4-choix", "bat16-etabli-choix")
patch('<section id="choix">', mods + '\n<section id="choix">')
out = tpl.replace("/*ENGINE*/", js).replace("/*ACTUELS*/{}", json.dumps({"etabli": crop("da-workshop")}))
dst = ROOT / "planches/etabli-propositions.html"
dst.write_text(out)
print(dst, len(out))
