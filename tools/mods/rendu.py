#!/usr/bin/env python3
"""Planche planches/mods-rendu-en-jeu.html : les 15 mods animés (WebP) depuis tests/visual/out/mods_rendu/.
Capture : godot --path . res://tests/visual/mods_rendu_capture.tscn, puis python3 tools/mods/rendu.py (racine du projet)."""
import base64, io, json, os
from PIL import Image
D='tests/visual/out/mods_rendu/'
RAR={'uncommon':('Peu commun','#6fcf5a'),'rare':('Rare','#f2e14a'),'epic':('Épique','#f07a28'),'unique':('Unique','#b47af0')}
M=[
('veil','Voile de la Martyre','uncommon','Défense','Absorbe un coup entier, puis se reforme en 20 s.',
 'Pendentif d’améthyste et liseré violet autour de la silhouette.','Coup absorbé : la silhouette blanchit, onde violette, le liseré éclate.','Le coup absorbé en jeu : zone cyan et éclats qui tombent ; les PV ne bougent pas.'),
('iris','Iris de la Matrice','rare','Exploration','Les ennemis apparaissent sur la minicarte à travers la roche.',
 'Orbe à pupille carmin au-dessus de l’épaule.','Ennemi repéré derrière la roche : la pupille se fige, arcs de sonar vers lui.','Le ping part vers un rôdeur caché au nord-est, hors du champ de vision.'),
('drill','Foreuse de Gorge-Cuivre','unique','Exploration','L’Exilé creuse la roche deux fois plus vite.',
 'Cinq billes cuivre et argent autour de lui, à la place des trois du Sceau.','Il creuse : les cinq billes se mettent en mèche vers la case.','Creusement de la case à l’est (pose de visée du lance-pitons).'),
('scale','Écaille d’esquive','rare','Attaque','Après un tir ennemi frôlé de justesse, la prochaine attaque fait +50 % de dégâts.',
 'Écaille d’acier sur l’épaule avant.','Chargée après un frôlement : cœur cyan, étincelles, anneau.','Le tir chargé part sur un soldat ; l’écaille se décharge.'),
('ember','Cœur de braise','epic','Attaque','Sous 30 % de PV, cadence +25 % pendant 6 s, une fois par minute.',
 'Cœur de braise incrusté dans la poitrine.','Embrasé sous 30 % de PV : flammèches qui montent, halo orange. (L’Ingénieur blessé change d’apparence : c’est le jeu actuel.)','Trois tirs pendant l’embrasement.'),
('magnet','Aimant d’ichor','uncommon','Défense','Chaque ennemi abattu par l’Exilé lui rend 3 % de ses PV max.',
 'Fer à cheval rouge à la ceinture.','Un rôdeur abattu : une goutte d’ichor file vers l’aimant.','Le soin s’affiche en vert au-dessus de l’Exilé.'),
('lens','Lentille de souffle','rare','Tir','Les balles de l’Arbalestrie traversent un ennemi de plus.',
 'Lentille vert d’eau vissée à la bouche de l’Arbalestrie.','Reflet qui passe sur la lentille.','Deux tirs : chaque balle touche les deux soldats alignés.'),
('barrel','Barillet double','epic','Tir','Deux munitions chargées, la choisie et la précédente, qui alternent à chaque tir.',
 'Second barillet sur l’Arbalestrie, chambres cyan et carmin.','La chambre du prochain tir luit plus fort.','Cinq tirs : balles d’Indra et balles spirituelles en alternance.'),
('frost','Culasse froide','uncommon','Tir','Recharge 30 % plus courte pendant 3 s après un changement de munition.',
 'Culasse de l’Arbalestrie givrée.','Changement de munition (balles de Medeina) : fumée froide qui monte de la culasse.','Vue de jeu juste après le changement.'),
('seal','Sceau sensible','uncommon','Exploration','Les filons à moins de 12 cases brillent à travers la roche.',
 'Prisme d’argent au centre de l’orbite du Sceau.','Le prisme pulse vers le filon le plus proche.','Les cases de filon luisent par-dessus le brouillard, en losanges de la couleur du minerai.'),
('wisp','Lanterne de Medeina','rare','Exploration','La vision de l’Exilé passe de 5 à 8 cases.',
 'Feu follet vert derrière la tête, avec sa traîne.','Le follet flotte et scintille.','Champ de vision élargi (vue de loin).'),
('anchor','Ancre de rappel','epic','Mobilité','Retour à la capsule toutes les 3 minutes, hors combat (touche G).',
 'Petite sphère enchaînée à la hanche, lueur violette quand elle est prête.','Arrivée à la capsule : anneaux violets qui se resserrent.','À la sortie de la capsule ; le bouton « Rappel » montre sa recharge.'),
('chant','Voix du Chantre','rare','Colonie','Adeptes et bâtiments à moins de 8 cases travaillent 20 % plus vite.',
 'Diapason d’or dans le dos.','Un adepte travaille à portée : onde dorée qui part du diapason.','L’onde passe sur l’adepte voisin.'),
('sack','Sac sans fond','epic','Colonie','Le paquetage gagne une rangée ; le butin des corps se ramasse en passant.',
 'Sac de toile à la ceinture, tourbillon violet à l’ouverture.','Le bouclier d’un corps à 5 unités est ramassé sans marcher dessus.','Paquetage à deux rangées en bas de l’écran (13 objets + le bouclier).'),
('echo','Écho du pylône','rare','Défense','Les assauts et les meutes nocturnes s’annoncent 15 s avant leur départ.',
 'Éclat de pylône dans le dos.','Avant l’assaut : l’éclat tremble et lance des ondes.','La bannière annonce l’assaut 15 s à l’avance.'),
]
def b64(img,fmt,**kw):
    bio=io.BytesIO();img.save(bio,fmt,**kw);return base64.b64encode(bio.getvalue()).decode()
def frames(k,view):
    out=[];i=0
    while os.path.exists(f'{D}{k}_{view}_{i:03d}.png'):
        out.append(Image.open(f'{D}{k}_{view}_{i:03d}.png').convert('RGB'));i+=1
    if not out:
        raise SystemExit(f'aucune image pour {k} {view} : lancer la capture')
    return out
def anim(imgs,ms,**kw):
    bio=io.BytesIO()
    imgs[0].save(bio,'WEBP',save_all=True,append_images=imgs[1:],duration=ms,loop=0,**kw)
    return base64.b64encode(bio.getvalue()).decode()
# Cadrages : gros plan ×2 sur l'Ingénieur (caméra × 4), vue de jeu sans la barre du bas.
CLOSE=(560,140,760,330)
GAME=(160,60,1120,600)
cards=[]
for i,(k,name,rar,fam,eff,c1,c2,c3) in enumerate(M):
    a=[f.crop(CLOSE) for f in frames(k,'porte')]
    b=[f.crop(CLOSE) for f in frames(k,'declenche')]
    g=[f.crop(GAME).resize((576,324),Image.LANCZOS) for f in frames(k,'jeu')]
    rn,rc=RAR[rar]
    col=[m[0] for m in M].index(k)
    cards.append(f'''<article class="mod" id="m-{k}">
<header><span class="ico" data-col="{col}" data-rc="{rc}"></span><div><h2 style="color:{rc}">{name}</h2><p class="meta"><b style="color:{rc}">{rn}</b> · {fam}</p></div></header>
<p class="eff">{eff}</p>
<div class="shots">
<figure class="close"><img src="data:image/webp;base64,{anim(a,100,lossless=True)}" alt="{name} porté, au repos, animé"><figcaption><b>Porté · temps réel</b>{c1}</figcaption></figure>
<figure class="close"><img src="data:image/webp;base64,{anim(b,100,lossless=True)}" alt="{name} au déclenchement, animé"><figcaption><b>Déclenché · ralenti ×2</b>{c2}</figcaption></figure>
<figure class="game"><img src="data:image/webp;base64,{anim(g,120,quality=55,method=6)}" alt="{name} en jeu, animé" loading="lazy"><figcaption><b>En jeu · ralenti ×2</b>{c3}</figcaption></figure>
</div></article>''')
    print(k, len(cards[-1])//1024, 'Ko')
atlas=b64(Image.open('assets/ardoise/ui/mods.png'),'PNG')
nav=''.join(f'<a href="#m-{m[0]}">{m[1].split(" ")[0] if m[0] not in ("veil","iris","drill") else m[1].split(" de ")[0]}</a>' for m in M)
html=f'''<title>Mods de l’Exilé en jeu</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Pixelify+Sans:wght@400;600&display=swap" rel="stylesheet">
<style>
/* Planche de rendu : une fiche par mod, deux gros plans (×4) et la vue de jeu ; ambiance sombre unique comme les autres planches. */
:root{{--bg:#0c0d10;--panel:#14161b;--line:#2c3038;--txt:#e2dccb;--mut:#9a9ca2;--acc:#5ce8ff;--gold:#d0a038;--fiche:#081920;color-scheme:dark;
 --display:'Pixelify Sans',system-ui,sans-serif;--body:system-ui,-apple-system,'Segoe UI',sans-serif}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--txt);font:15px/1.45 var(--body)}}
.wrap{{max-width:1280px;margin:auto;padding-block:18px 80px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}}
h1{{font:600 26px var(--display);letter-spacing:.08em;color:var(--acc);margin:0;text-wrap:balance}}
.lead{{color:var(--mut);max-width:75ch;margin:6px 0 0}}
nav{{position:sticky;top:env(safe-area-inset-top,0px);z-index:5;background:var(--bg);border-bottom:1px solid var(--line);display:flex;flex-wrap:wrap;gap:4px 12px;padding-block:8px;margin-top:14px;font:13px var(--display)}}
body::before{{content:"";position:fixed;inset:0 0 auto;height:env(safe-area-inset-top,0px);z-index:10;background:var(--bg)}}
nav a{{color:var(--mut);text-decoration:none}}nav a:hover,nav a:focus-visible{{color:var(--acc)}}
.mod{{background:var(--panel);border:1px solid var(--line);margin-top:16px;padding:14px;scroll-margin-top:60px}}
.mod header{{display:flex;gap:12px;align-items:center}}
.ico{{width:48px;height:48px;flex:none;display:block}}.ico canvas{{width:48px;height:48px;image-rendering:pixelated}}
h2{{font:600 20px var(--display);margin:0;letter-spacing:.03em}}.meta{{margin:0;color:var(--mut);font-size:13px}}
.eff{{margin:8px 0 12px;max-width:75ch}}
.shots{{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr) minmax(0,2.6fr);gap:12px;align-items:start}}
figure{{margin:0;min-width:0}}figure img{{display:block;width:100%;height:auto;image-rendering:pixelated;background:var(--fiche);border:1px solid var(--line)}}
.game img{{image-rendering:auto}}
figcaption{{font-size:13px;color:var(--mut);margin-top:6px}}figcaption b{{display:block;color:var(--gold);font:600 12px var(--display);letter-spacing:.08em;text-transform:uppercase}}
@media (prefers-reduced-motion:reduce){{.mod img{{animation:none}}}}
@media (max-width:760px){{.shots{{grid-template-columns:1fr 1fr}}.game{{grid-column:1/-1}}}}
</style>
<div class="wrap">
<h1>MODS DE L’EXILÉ EN JEU</h1>
<p class="lead">Les 15 mods, un seul porté à la fois, capturés dans le jeu et animés (tests/visual/mods_rendu_capture, tools/mods/rendu.py). Pour chacun : l’Ingénieur de près au repos, de près au déclenchement (gros plans ×4), puis la vue de jeu où l’effet passe par les vraies règles : tir, coup reçu, ennemi abattu, rappel, annonce de vague. Le jeu est en pause pendant les captures et avance image par image ; déclenchements et vues de jeu sont au ralenti ×2.</p>
<nav aria-label="Mods">{nav}</nav>
{''.join(cards)}
</div>
<script>
// Icônes des mods depuis l'atlas du jeu (assets/ardoise/ui/mods.png) : plaque, bord et reflet teintés à la rareté, motif.
const atlas=new Image();atlas.onload=()=>{{document.querySelectorAll('.ico').forEach(el=>{{const col=+el.dataset.col,rc=el.dataset.rc;
 const c=document.createElement('canvas');c.width=c.height=32;const g=c.getContext('2d');g.imageSmoothingEnabled=false;
 const tint=(row,color)=>{{const t=document.createElement('canvas');t.width=t.height=32;const tg=t.getContext('2d');tg.drawImage(atlas,col*32,row*32,32,32,0,0,32,32);
  if(color){{tg.globalCompositeOperation='multiply';tg.fillStyle=color;tg.fillRect(0,0,32,32);tg.globalCompositeOperation='destination-in';tg.drawImage(atlas,col*32,row*32,32,32,0,0,32,32);}}g.drawImage(t,0,0);}};
 const mix=(h,k)=>{{const n=parseInt(h.slice(1),16);return'#'+[16,8,0].map(s=>Math.round(((n>>s)&255)*(1-k)+255*k).toString(16).padStart(2,'0')).join('');}};
 tint(0);tint(1,rc);tint(2,mix(rc,.45));tint(3);el.appendChild(c);}});}};
atlas.src='data:image/png;base64,{atlas}';
</script>
'''
open('planches/mods-rendu-en-jeu.html','w',encoding='utf-8').write(html)
print(len(html)//1024,'Ko')
